#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const tls = require('node:tls');
const crypto = require('node:crypto');

const PORT = Number(process.env.TUNNEL_PORT || 4433);
const HOST = String(process.env.TUNNEL_BIND || '0.0.0.0');
const MAX_PACKET = Math.min(65535, Math.max(576, Number(process.env.TUNNEL_MAX_PACKET || 65535)));
const IDLE_TIMEOUT_MS = Math.max(30000, Number(process.env.TUNNEL_IDLE_TIMEOUT_MS || 180000));
const CIDR = String(process.env.TUNNEL_CIDR || '10.254.0.0/24');
const MAGIC = Buffer.from([0x4d, 0x43, 0x56, 0x54]); // MCVT
const VERSION = 1;
const TYPE_PACKET = 1;
const TYPE_REGISTER = 2;
const TYPE_REGISTER_ACK = 3;
const peersById = new Map();
const peersByAddress = new Map();

function ipv4ToNumber(value) {
  const parts = String(value || '').split('.');
  if (parts.length !== 4) return null;
  let result = 0;
  for (const part of parts) {
    if (!/^\d{1,3}$/.test(part)) return null;
    const octet = Number(part);
    if (octet < 0 || octet > 255) return null;
    result = ((result << 8) | octet) >>> 0;
  }
  return result >>> 0;
}

function parseCidr(value) {
  const [address, rawPrefix] = String(value).split('/');
  const ip = ipv4ToNumber(address);
  const prefix = rawPrefix === undefined ? 32 : Number(rawPrefix);
  if (ip === null || !Number.isInteger(prefix) || prefix < 0 || prefix > 32) {
    throw new Error('TUNNEL_CIDR must be a valid IPv4 CIDR');
  }
  const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
  return { ip, prefix, mask, network: (ip & mask) >>> 0 };
}

const tunnelCidr = parseCidr(CIDR);

function inTunnelCidr(address) {
  const ip = ipv4ToNumber(address);
  return ip !== null && ((ip & tunnelCidr.mask) >>> 0) === tunnelCidr.network;
}

function readPeers() {
  let parsed;
  try {
    parsed = JSON.parse(process.env.TUNNEL_PEERS_JSON || '{}');
  } catch (_) {
    throw new Error('TUNNEL_PEERS_JSON is not valid JSON');
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('TUNNEL_PEERS_JSON must be an object keyed by peer ID');
  }
  for (const [peerId, config] of Object.entries(parsed)) {
    const address = String(config?.address || '').trim();
    const secret = String(config?.secret || '');
    if (!/^[a-zA-Z0-9_.-]{1,64}$/.test(peerId)) {
      throw new Error('Invalid peer ID in TUNNEL_PEERS_JSON');
    }
    if (!inTunnelCidr(address)) {
      throw new Error(`Peer ${peerId} address must be inside ${CIDR}`);
    }
    if (secret.length < 24) {
      throw new Error(`Peer ${peerId} secret must contain at least 24 characters`);
    }
    if (peersByAddress.has(address)) {
      throw new Error(`Duplicate virtual address configured: ${address}`);
    }
    peersById.set(peerId, { peerId, address, secret });
    peersByAddress.set(address, null);
  }
  if (peersById.size < 2) {
    throw new Error('Configure at least two distinct peers in TUNNEL_PEERS_JSON');
  }
}

function constantTimeEqual(left, right) {
  const a = Buffer.from(String(left), 'utf8');
  const b = Buffer.from(String(right), 'utf8');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function encodeFrame(type, payload) {
  const body = Buffer.isBuffer(payload) ? payload : Buffer.from(payload);
  if (body.length <= 0 || body.length > MAX_PACKET) throw new Error('Invalid tunnel frame size');
  const header = Buffer.alloc(10);
  MAGIC.copy(header, 0);
  header[4] = VERSION;
  header[5] = type;
  header.writeUInt32BE(body.length, 6);
  return Buffer.concat([header, body]);
}

function sendControl(socket, type, value) {
  socket.write(encodeFrame(type, Buffer.from(JSON.stringify(value), 'utf8')));
}

function parseIpv4Packet(packet) {
  if (packet.length < 20 || (packet[0] >> 4) !== 4) return null;
  const headerLength = (packet[0] & 0x0f) * 4;
  const totalLength = packet.readUInt16BE(2);
  if (headerLength < 20 || totalLength < headerLength || totalLength > packet.length) return null;
  const source = [...packet.subarray(12, 16)].join('.');
  const destination = [...packet.subarray(16, 20)].join('.');
  return { source, destination, packet: packet.subarray(0, totalLength) };
}

function unregister(socket) {
  const peer = socket.memoPeer;
  if (!peer) return;
  if (peersById.get(peer.peerId)?.socket === socket) {
    peersById.delete(peer.peerId);
    peersByAddress.set(peer.address, null);
    console.log(`peer disconnected: ${peer.peerId} (${peer.address})`);
  }
  socket.memoPeer = null;
}

function registerPeer(socket, payload) {
  if (socket.memoPeer) throw new Error('Peer is already registered');
  let request;
  try {
    request = JSON.parse(payload.toString('utf8'));
  } catch (_) {
    throw new Error('Invalid registration payload');
  }
  const peerId = String(request.peerId || '').trim();
  const address = String(request.address || '').trim();
  const secret = String(request.secret || '');
  const configured = peersById.get(peerId);
  if (!configured || !constantTimeEqual(secret, configured.secret) || address !== configured.address) {
    sendControl(socket, TYPE_REGISTER_ACK, { ok: false, message: 'Peer credentials or virtual address are invalid' });
    socket.end();
    return;
  }

  const previous = peersById.get(peerId)?.socket;
  if (previous && previous !== socket) previous.destroy();
  const peer = { peerId, address, socket };
  peersById.set(peerId, peer);
  peersByAddress.set(address, peer);
  socket.memoPeer = peer;
  socket.setTimeout(IDLE_TIMEOUT_MS);
  sendControl(socket, TYPE_REGISTER_ACK, { ok: true, peerId, address, cidr: CIDR });
  console.log(`peer connected: ${peerId} (${address})`);
}

function handlePacket(socket, payload) {
  const peer = socket.memoPeer;
  if (!peer) throw new Error('Register the peer before sending IP packets');
  const parsed = parseIpv4Packet(payload);
  if (!parsed) throw new Error('Only valid IPv4 packets are supported');
  if (parsed.source !== peer.address) {
    throw new Error(`Source address mismatch for peer ${peer.peerId}`);
  }
  if (!inTunnelCidr(parsed.destination)) return;
  const destination = peersByAddress.get(parsed.destination);
  if (!destination || !destination.socket || destination.socket.destroyed || destination.socket === socket) return;
  destination.socket.write(encodeFrame(TYPE_PACKET, parsed.packet));
}

function handleFrame(socket, type, payload) {
  if (type === TYPE_REGISTER) {
    registerPeer(socket, payload);
    return;
  }
  if (type === TYPE_PACKET) {
    handlePacket(socket, payload);
    return;
  }
  throw new Error('Unsupported tunnel frame type');
}

function start() {
  readPeers();
  const certPath = String(process.env.TUNNEL_TLS_CERT_FILE || '').trim();
  const keyPath = String(process.env.TUNNEL_TLS_KEY_FILE || '').trim();
  if (!certPath || !keyPath) throw new Error('Set TUNNEL_TLS_CERT_FILE and TUNNEL_TLS_KEY_FILE');
  const server = tls.createServer({
    cert: fs.readFileSync(certPath),
    key: fs.readFileSync(keyPath),
    minVersion: 'TLSv1.2',
    requestCert: false,
    rejectUnauthorized: false,
  }, socket => {
    socket.setNoDelay(true);
    socket.setTimeout(IDLE_TIMEOUT_MS);
    socket.memoBuffer = Buffer.alloc(0);
    socket.on('timeout', () => socket.destroy(new Error('Tunnel idle timeout')));
    socket.on('data', chunk => {
      try {
        socket.memoBuffer = Buffer.concat([socket.memoBuffer, chunk]);
        while (socket.memoBuffer.length >= 10) {
          const header = socket.memoBuffer.subarray(0, 10);
          if (!header.subarray(0, 4).equals(MAGIC) || header[4] !== VERSION) {
            throw new Error('Invalid tunnel frame header');
          }
          const type = header[5];
          const length = header.readUInt32BE(6);
          if (length <= 0 || length > MAX_PACKET) throw new Error('Invalid tunnel frame length');
          if (socket.memoBuffer.length < 10 + length) break;
          const payload = socket.memoBuffer.subarray(10, 10 + length);
          socket.memoBuffer = socket.memoBuffer.subarray(10 + length);
          handleFrame(socket, type, payload);
          if (socket.destroyed) break;
        }
      } catch (error) {
        console.warn('tunnel client rejected:', error.message);
        try {
          if (!socket.memoPeer) sendControl(socket, TYPE_REGISTER_ACK, { ok: false, message: 'Tunnel registration or packet validation failed' });
        } catch (_) {}
        socket.destroy();
      }
    });
    socket.on('error', error => {
      if (!socket.destroyed) console.warn('tunnel socket error:', error.message);
    });
    socket.on('close', () => unregister(socket));
  });

  server.on('error', error => {
    console.error('tunnel gateway error:', error.message);
    process.exitCode = 1;
  });
  server.listen(PORT, HOST, () => {
    console.log(`MemoChat tunnel gateway listening on ${HOST}:${PORT}; virtual network ${CIDR}; peers configured: ${peersById.size}`);
  });
}

try {
  start();
} catch (error) {
  console.error('Unable to start MemoChat tunnel gateway:', error.message);
  process.exit(1);
}
