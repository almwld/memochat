# Memo Offline Link — MikroTik setup

This optional local-network messaging path is separate from Firestore chat and
the existing VPN/TUN service. It does not start automatically. The first
implementation listens/connects only while the **Memo Offline Link** screen is
open. It uses TCP port **1440** and AES-GCM with a shared passphrase (12+
characters). Both phones must use the exact same passphrase.

## Topology

- Phone A is connected to MikroTik A and runs **Receive on :1440**.
- Phone B is connected to MikroTik B, enters Phone A's reachable LAN IP, and
  taps **Connect**.
- Messages and acknowledgements travel in both directions over that TCP
  connection. The app stores its local history on-device. Delivery is shown only
  after the receiver acknowledges the message.
- No public internet or Firebase is used for this channel.

## Required MikroTik network path

Example addressing only (replace with the real IP plan):

- Router A phone LAN: `192.168.10.0/24`; Phone A: `192.168.10.10`
- Router B phone LAN: `192.168.20.0/24`; Phone B: `192.168.20.10`
- Router-to-router link has its own transit subnet.

The routers must already have a working IP path between their transit interfaces.
Configure a static route on Router A to Router B's LAN through Router B's transit
address, and a reciprocal route on Router B to Router A's LAN through Router A's
transit address. Add narrowly scoped **forward-chain** firewall permits for TCP
1440 between the two phone IP addresses, before any general drop rules. Make sure
the routers' inter-LAN forwarding policy permits return traffic. Avoid
masquerading between these two LANs when routed source addresses should remain
visible. Do not enable a broad bridge or disable the firewall merely to make this
work; bridging unrelated LANs can create loops and DHCP/address conflicts.

If the two MikroTik devices are truly isolated and have no physical/radio/WireGuard/
Ethernet transit link between them, software on the phones cannot create a path
through the routers. The routers need a real link between them first. Internet
access is not required once that private path is working.

## On-device test

1. Connect each phone to its respective MikroTik LAN and note its IP address.
2. Open Memo Offline Link on both phones; enter the same strong passphrase.
3. On Phone A tap **Receive on :1440**. Keep that screen open.
4. On Phone B enter Phone A's LAN IP and tap **Connect**.
5. Send a short message in both directions. Confirm the other phone shows it and
   the sender changes from **waiting for receipt** to **received**.
6. Disconnect the router path, verify the channel drops without crashing the app,
   then restore the path and reconnect. This screen currently requires manual
   reconnect; it is not a background daemon.

## Limits

- The first implementation is text-only and foreground-only. It intentionally
  does not touch existing chat, VPN/TUN, call, media, or security settings.
- AES-GCM encrypts each frame and authenticates it using the shared passphrase.
  Anyone who knows that passphrase can read messages, so exchange it privately.
- This is a direct app-to-app TCP link, not a generic VPN bridge for all IP
  traffic. Router routes/firewall rules still need to be configured for the
  actual topology.
- Build/CI success does not replace a two-phone test over the actual MikroTik
  routers.
