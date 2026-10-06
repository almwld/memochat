# MemoChat Tunnel Gateway

Real remote endpoint for the optional Android VPN/TUN mode.

Requirements:
- Linux host with /dev/net/tun
- Python 3.9+
- TLS certificate and private key
- IP forwarding/routing configured by the operator

Start:
sudo python3 gateway.py --cert /etc/memochat/server.crt --key /etc/memochat/server.key

Default listener: TCP/TLS 4433. Default TUN interface: memochat0.

The gateway does not create a physical link between MikroTik routers. A radio, Ethernet, Wi-Fi or other physical/IP link must already exist.

Packet framing:
4 bytes magic MCVT
1 byte version 1
1 byte type 1 (IP packet)
4 bytes big-endian payload length
raw IP packet
