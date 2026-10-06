#!/usr/bin/env python3
import argparse
import os
import socket
import ssl
import struct
import threading
import fcntl

MAGIC = b"MCVT"
VERSION = 1
TYPE_PACKET = 1
HEADER = struct.Struct("!4sBBI")
MAX_PACKET = 65535
TUNSETIFF = 0x400454CA
IFF_TUN = 0x0001
IFF_NO_PI = 0x1000

clients = set()
lock = threading.Lock()

def open_tun(name):
    fd = os.open("/dev/net/tun", os.O_RDWR)
    request = struct.pack("16sH", name.encode("ascii"), IFF_TUN | IFF_NO_PI)
    result = fcntl.ioctl(fd, TUNSETIFF, request)
    actual = result[:16].split(b"\0", 1)[0].decode("ascii")
    return fd, actual

def recv_exact(conn, size):
    data = bytearray()
    while len(data) < size:
        chunk = conn.recv(size - len(data))
        if not chunk:
            return None
        data.extend(chunk)
    return bytes(data)

def send_frame(conn, payload):
    if len(payload) > MAX_PACKET:
        raise ValueError("packet too large")
    conn.sendall(HEADER.pack(MAGIC, VERSION, TYPE_PACKET, len(payload)) + payload)

def client_loop(conn, tun_fd):
    try:
        while True:
            header = recv_exact(conn, HEADER.size)
            if header is None:
                return
            magic, version, kind, length = HEADER.unpack(header)
            if magic != MAGIC or version != VERSION or kind != TYPE_PACKET or length > MAX_PACKET:
                return
            packet = recv_exact(conn, length)
            if packet is None:
                return
            os.write(tun_fd, packet)
    finally:
        with lock:
            clients.discard(conn)
        try:
            conn.close()
        except OSError:
            pass

def accept_loop(server, context, tun_fd):
    while True:
        raw, _ = server.accept()
        try:
            conn = context.wrap_socket(raw, server_side=True)
            with lock:
                clients.add(conn)
            threading.Thread(target=client_loop, args=(conn, tun_fd), daemon=True).start()
        except Exception:
            try:
                raw.close()
            except OSError:
                pass

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=4433)
    parser.add_argument("--tun", default="memochat0")
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()

    tun_fd, actual = open_tun(args.tun)
    print("TUN ready:", actual)

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(args.cert, args.key)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.listen, args.port))
    server.listen(8)
    print("TLS gateway listening on", args.listen, args.port)

    threading.Thread(target=accept_loop, args=(server, context, tun_fd), daemon=True).start()

    try:
        while True:
            packet = os.read(tun_fd, MAX_PACKET)
            if not packet:
                continue
            with lock:
                peers = list(clients)
            for conn in peers:
                try:
                    send_frame(conn, packet)
                except OSError:
                    with lock:
                        clients.discard(conn)
                    try:
                        conn.close()
                    except OSError:
                        pass
    finally:
        server.close()
        os.close(tun_fd)

if __name__ == "__main__":
    main()
