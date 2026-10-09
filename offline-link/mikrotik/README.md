# MemoChat Offline Link — MikroTik WireGuard

This folder is an optional, separate network layer. It does not change MemoChat's normal Firebase, Nextcloud, or LiveKit paths, app startup, existing VPN service, or security settings. Nothing is enabled automatically in the app.

## Purpose

Create a site-to-site encrypted network between two RouterOS v7 MikroTik routers over an existing local transport link. Internet access is not required. A real transport path must already exist between the routers (Ethernet, radio bridge, Wi-Fi bridge, or an existing routed private link).

WireGuard uses UDP port 1440 in these examples. This is not a TCP port and is not the Android TLS gateway port 4433.

## Example addressing (change to match your real network)

| Item | Router A | Router B |
|---|---|---|
| LAN | 192.168.10.0/24 | 192.168.20.0/24 |
| WireGuard address | 10.144.0.1/30 | 10.144.0.2/30 |
| Transport endpoint | actual reachable IP of A | actual reachable IP of B |
| WireGuard listen port | UDP 1440 | UDP 1440 |

The two LAN subnets must not overlap. The router transport endpoint IPs must be reachable over the existing inter-router link, and each router needs a valid return path to the other endpoint. If the transport network filters traffic, allow UDP/1440 between the two endpoint IPs. No public IP, cloud server, or Internet is needed when the transport link is local.

## Safe setup order

1. Confirm both routers run RouterOS v7 and export a backup before changing configuration.
2. Confirm the routers can reach each other's transport endpoint IPs over the existing non-Internet link. If this fails, WireGuard cannot repair a missing physical or routed path.
3. Edit both .rsc.example files. Replace __ROUTER_A_TRANSPORT_IP__, __ROUTER_B_TRANSPORT_IP__, and the public-key placeholders. Replace the example LAN subnets in peer allowed-addresses, routes, firewall rules, and NAT bypass rules if your actual LANs differ.
4. Import Router A's script once, then Router B's script once. Do not re-import unchanged scripts: RouterOS will reject duplicate interface/address entries.
5. Obtain each public key with: /interface/wireguard/print detail where name=wg-memochat
   Exchange only public keys; never share or export private keys.
6. Check /interface/wireguard/peers/print detail and confirm last-handshake updates and RX/TX counters increase.
7. Test from each router: ping the remote WireGuard address, then a host/router address in the remote LAN. Test a real host in each LAN in both directions.
8. Review firewall rule order and counters if a final-drop rule blocks traffic. The sample inserts narrowly scoped rules at the top, but inspect your actual policy before production use.

## Important limits

- These are editable templates for a stated example topology, not a verified configuration for your particular routers. The real transport IPs, LAN subnets, RouterOS version, and firewall policy have not been supplied or tested.
- The scripts use place-before=0 for narrowly scoped firewall/NAT exceptions. Review them against your existing policy before import; export a backup first.
- The tunnel creates network reachability only. It does not by itself implement offline MemoChat message delivery, local message storage, or app-to-app discovery. Those require a separate application transport layer and a two-device test.
- Do not point Android's existing TLS VPN screen at UDP/1440. That Android screen currently speaks TLS to a gateway on TCP/4433, a different protocol. MikroTik WireGuard and the Android TLS gateway are not interchangeable.
