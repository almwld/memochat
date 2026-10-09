'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ipv4ToNumber,
  parseCidr,
  inTunnelCidr,
  constantTimeEqual,
  encodeFrame,
  parseIpv4Packet,
} = require('./server');

test('IPv4 parser rejects invalid addresses', () => {
  assert.equal(ipv4ToNumber('10.254.0.2'), 0x0afe0002);
  assert.equal(ipv4ToNumber('10.254.0.999'), null);
  assert.equal(ipv4ToNumber('10.254.0'), null);
});

test('CIDR parser and default tunnel network enforce the private route', () => {
  assert.deepEqual(parseCidr('10.254.0.0/24'), {
    ip: 0x0afe0000,
    prefix: 24,
    mask: 0xffffff00,
    network: 0x0afe0000,
  });
  assert.equal(inTunnelCidr('10.254.0.2'), true);
  assert.equal(inTunnelCidr('10.254.1.2'), false);
  assert.throws(() => parseCidr('10.254.0.999/24'));
});

test('constant-time peer secret comparison rejects mismatches', () => {
  assert.equal(constantTimeEqual('same-secret', 'same-secret'), true);
  assert.equal(constantTimeEqual('same-secret', 'other-secret'), false);
  assert.equal(constantTimeEqual('short', 'longer'), false);
});

test('MCVT frame includes the exact header and payload length', () => {
  const payload = Buffer.from([1, 2, 3, 4]);
  const frame = encodeFrame(1, payload);
  assert.deepEqual(frame.subarray(0, 4), Buffer.from('MCVT'));
  assert.equal(frame[4], 1);
  assert.equal(frame[5], 1);
  assert.equal(frame.readUInt32BE(6), payload.length);
  assert.deepEqual(frame.subarray(10), payload);
  assert.throws(() => encodeFrame(1, Buffer.alloc(0)));
});

test('IPv4 packet parser returns source and destination for valid packets', () => {
  const packet = Buffer.alloc(20);
  packet[0] = 0x45;
  packet.writeUInt16BE(20, 2);
  packet.set([10, 254, 0, 2], 12);
  packet.set([10, 254, 0, 3], 16);
  assert.deepEqual(parseIpv4Packet(packet), {
    source: '10.254.0.2',
    destination: '10.254.0.3',
    packet,
  });
  assert.equal(parseIpv4Packet(Buffer.alloc(12)), null);
});
