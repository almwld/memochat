# MemoChat Offline Link — Authenticated Peer Tunnel

This directory contains an **optional, isolated transport layer** for the Android VPN/TUN feature. It does not replace Firebase messaging, start automatically, or change the normal MemoChat chat path.

## Recommended gateway

Use `server.js` for the authenticated, peer-to-peer IPv4 tunnel. It accepts the same MCVT frame format as the Android client and adds a small registration handshake before packet traffic. The legacy `gateway.py` is retained for compatibility but does not authenticate clients and should not be exposed to untrusted networks.

The gateway is not an Internet exit and cannot create a physical connection between routers. The two MikroTik routers must already have a routed LAN/WAN/radio link so both devices can reach the gateway host on TCP 4433. Internet access is not required when that private routed link works.

## 1. TLS certificate

On the Linux gateway host, create or install a TLS certificate and key. For a private/self-signed certificate:

```sh
openssl req -x509 -newkey rsa:3072 -nodes -days 365 \
  -keyout tunnel-key.pem -out tunnel-cert.pem \
  -subj "/CN=memochat-tunnel-gateway"
openssl x509 -in tunnel-cert.pem -outform DER | sha256sum
```

Copy the 64-character SHA-256 certificate fingerprint into the VPN Tunnel screen on both devices. Keep the private key on the gateway only.

## 2. Configure both peers

Use unique random secrets of at least 24 characters. Do not commit real secrets or private keys.

```sh
export TUNNEL_BIND=0.0.0.0
export TUNNEL_PORT=4433
export TUNNEL_CIDR=10.254.0.0/24
export TUNNEL_TLS_CERT_FILE=/etc/memochat/tunnel-cert.pem
export TUNNEL_TLS_KEY_FILE=/etc/memochat/tunnel-key.pem
export TUNNEL_PEERS_JSON='{
  "phone-a": {"address": "10.254.0.2", "secret": "REPLACE_WITH_RANDOM_SECRET_A"},
  "phone-b": {"address": "10.254.0.3", "secret": "REPLACE_WITH_RANDOM_SECRET_B"}
}'
node server.js
```

Configure device A with peer ID `phone-a`, secret A, TUN address `10.254.0.2/32`, and route `10.254.0.0/24`. Configure device B with peer ID `phone-b`, secret B, TUN address `10.254.0.3/32`, and the same route. Enter the gateway's reachable private IP/DNS and the certificate fingerprint on both devices.

## 3. MikroTik network requirements

1. Ensure both routers have a working routed path between their LANs, including return routes. No public Internet route is required.
2. Run this gateway on a Linux host reachable from both sides through that routed path.
3. Permit TCP 4433 from only the trusted device networks to the gateway.
4. Keep `10.254.0.0/24` separate from both LAN subnets.
5. Configure the routers' input/forward firewall rules and return routes. The gateway only forwards packets to another configured, connected peer address.

If the routers have no Ethernet, radio, Wi-Fi, or other routed path between them, this configuration cannot make the devices reachable by itself.

## Protocol and limitations

- TLS 1.2 or newer, certificate pinning on Android, and a unique per-peer shared secret.
- Only valid IPv4 packets are accepted; source addresses must match the peer's configured virtual address.
- Packets are forwarded to the exact destination peer. Broadcast, multicast, IPv6, whole-LAN bridging, and Internet exit are not provided.
- Both peers must be connected to the same gateway at the same time.
- The separate Offline Link screen in MemoChat provides the application-level listener on TCP 1440. Both devices must start that listener and configure each other's virtual IP/peer ID. Message bodies are encrypted with the same manually shared AES-GCM key before entering the TLS gateway. Normal Firebase chat traffic is never redirected or changed.
- The service is manually enabled and isolated from normal MemoChat behavior.
