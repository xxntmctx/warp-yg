#!/usr/bin/env python3
"""Lightweight, configurable direct-egress SOCKS5 proxy for warp-yg.

Designed as a drop-in local listener (default 127.0.0.1:40000) when the local
Cloudflare WARP POP is geo-polluted (e.g. RU/IR) while the VPS native IP is
clean. Supports RFC 1928 TCP CONNECT with configurable IPv4/IPv6 preference.
"""

from __future__ import annotations

import argparse
import asyncio
import errno
import ipaddress
import logging
import os
import signal
import socket
import struct
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

SOCKS_VERSION = 5
AUTH_NONE = 0x00
AUTH_NO_ACCEPTABLE = 0xFF

CMD_CONNECT = 0x01
ATYP_IPV4 = 0x01
ATYP_DOMAIN = 0x03
ATYP_IPV6 = 0x04

REP_SUCCEEDED = 0x00
REP_GENERAL_FAILURE = 0x01
REP_NETWORK_UNREACHABLE = 0x03
REP_HOST_UNREACHABLE = 0x04
REP_CONNECTION_REFUSED = 0x05
REP_COMMAND_NOT_SUPPORTED = 0x07
REP_ADDRESS_TYPE_NOT_SUPPORTED = 0x08

VALID_STACK_MODES = ("prefer_v6", "prefer_v4", "v6_only", "v4_only")
BUFFER_SIZE = 65536
DEFAULT_CONNECT_TIMEOUT = 6.0
TIMEOUT_ERRORS = (TimeoutError, asyncio.TimeoutError)

LOGGER = logging.getLogger("warp-direct-socks5")

AddrInfoEntry = tuple[
    socket.AddressFamily,
    socket.SocketKind,
    int,
    str,
    tuple[Any, ...],
]


@dataclass(frozen=True)
class ProxyConfig:
    """Runtime configuration for the direct SOCKS5 listener."""

    listen_host: str = "127.0.0.1"
    listen_port: int = 40000
    stack_mode: str = "prefer_v6"
    connect_timeout: float = DEFAULT_CONNECT_TIMEOUT
    debug: bool = False


def parse_config_file(path: str) -> dict[str, str]:
    """Read simple KEY=VALUE lines from an optional configuration file."""
    values: dict[str, str] = {}
    if not path or not os.path.isfile(path):
        return values
    try:
        with open(path, encoding="utf-8") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                values[key.strip()] = val.strip().strip('"').strip("'")
    except OSError as exc:
        LOGGER.warning("Failed to read config file %s: %s", path, exc)
    return values


def build_config(argv: Sequence[str] | None = None) -> ProxyConfig:
    """Merge CLI flags over config file and defaults."""
    parser = argparse.ArgumentParser(description="Direct-egress SOCKS5 server")
    parser.add_argument("--config", default="/etc/warp-direct-socks5.conf")
    parser.add_argument("--host", default=None)
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--stack", choices=VALID_STACK_MODES, default=None)
    parser.add_argument("--timeout", type=float, default=None)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args(argv)

    file_cfg = parse_config_file(args.config)
    listen_host = args.host or file_cfg.get("LISTEN_HOST", "127.0.0.1")
    listen_port = args.port or int(file_cfg.get("LISTEN_PORT", "40000"))
    stack_mode = args.stack or file_cfg.get("STACK_MODE", "prefer_v6")
    if stack_mode not in VALID_STACK_MODES:
        LOGGER.warning("Invalid STACK_MODE=%s, falling back to prefer_v6", stack_mode)
        stack_mode = "prefer_v6"
    connect_timeout = args.timeout or float(
        file_cfg.get("CONNECT_TIMEOUT", str(DEFAULT_CONNECT_TIMEOUT))
    )
    debug = args.debug or file_cfg.get("DEBUG", "false").lower() in ("1", "true", "yes")
    return ProxyConfig(
        listen_host=listen_host,
        listen_port=listen_port,
        stack_mode=stack_mode,
        connect_timeout=connect_timeout,
        debug=debug,
    )


def build_reply(rep: int, sockname: Sequence[Any] | None = None) -> bytes:
    """Construct an RFC 1928 SOCKS5 reply packet."""
    if sockname and len(sockname) >= 2:
        addr_str = str(sockname[0]).split("%", 1)[0]
        raw_port = sockname[1]
        if isinstance(raw_port, int):
            try:
                ip_obj = ipaddress.ip_address(addr_str)
                if ip_obj.version == 4:
                    return (
                        struct.pack("!BBBB", SOCKS_VERSION, rep, 0x00, ATYP_IPV4)
                        + ip_obj.packed
                        + struct.pack("!H", raw_port)
                    )
                return (
                    struct.pack("!BBBB", SOCKS_VERSION, rep, 0x00, ATYP_IPV6)
                    + ip_obj.packed
                    + struct.pack("!H", raw_port)
                )
            except ValueError:
                pass
    return struct.pack(
        "!BBBB4sH", SOCKS_VERSION, rep, 0x00, ATYP_IPV4, b"\x00\x00\x00\x00", 0
    )


def map_errno_to_rep(exc: BaseException) -> int:
    """Translate OS/socket exceptions into RFC 1928 reply codes."""
    if isinstance(exc, (TimeoutError, asyncio.TimeoutError)):
        return REP_HOST_UNREACHABLE
    err_no = getattr(exc, "errno", None)
    if err_no == errno.ENETUNREACH:
        return REP_NETWORK_UNREACHABLE
    if err_no == errno.EHOSTUNREACH:
        return REP_HOST_UNREACHABLE
    if err_no == errno.ECONNREFUSED:
        return REP_CONNECTION_REFUSED
    return REP_GENERAL_FAILURE


def order_addrinfo(
    infos: Sequence[AddrInfoEntry],
    stack_mode: str,
) -> list[AddrInfoEntry]:
    """Order resolved addresses according to configured IP stack preference."""
    v6_list = [item for item in infos if item[0] == socket.AF_INET6]
    v4_list = [item for item in infos if item[0] == socket.AF_INET]
    if stack_mode == "v6_only":
        return v6_list
    if stack_mode == "v4_only":
        return v4_list
    if stack_mode == "prefer_v4":
        return v4_list + v6_list
    return v6_list + v4_list


async def open_upstream(
    host: str, port: int, atyp: int, cfg: ProxyConfig
) -> tuple[asyncio.StreamReader, asyncio.StreamWriter]:
    """Resolve and connect to the target upstream respecting stack_mode."""
    loop = asyncio.get_running_loop()

    if atyp == ATYP_IPV4:
        if cfg.stack_mode == "v6_only":
            raise OSError(errno.ENETUNREACH, "IPv4 target blocked by v6_only policy")
        return await asyncio.wait_for(
            asyncio.open_connection(host, port, family=socket.AF_INET),
            timeout=cfg.connect_timeout,
        )

    if atyp == ATYP_IPV6:
        if cfg.stack_mode == "v4_only":
            raise OSError(errno.ENETUNREACH, "IPv6 target blocked by v4_only policy")
        return await asyncio.wait_for(
            asyncio.open_connection(host, port, family=socket.AF_INET6),
            timeout=cfg.connect_timeout,
        )

    req_family = socket.AF_UNSPEC
    if cfg.stack_mode == "v6_only":
        req_family = socket.AF_INET6
    elif cfg.stack_mode == "v4_only":
        req_family = socket.AF_INET

    raw_infos = await asyncio.wait_for(
        loop.getaddrinfo(host, port, family=req_family, type=socket.SOCK_STREAM),
        timeout=cfg.connect_timeout,
    )
    candidates = order_addrinfo(raw_infos, cfg.stack_mode)
    if not candidates:
        raise OSError(
            errno.EHOSTUNREACH, f"No matching {cfg.stack_mode} address for {host}"
        )

    last_exc: BaseException = OSError(
        errno.EHOSTUNREACH, f"Failed to reach {host}:{port}"
    )
    for family, _socktype, _proto, _canon, sockaddr in candidates:
        target_ip = str(sockaddr[0])
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(target_ip, port, family=family),
                timeout=cfg.connect_timeout,
            )
            LOGGER.debug(
                "Connected %s:%d -> %s (%s)", host, port, target_ip, family.name
            )
            return reader, writer
        except (OSError, *TIMEOUT_ERRORS) as exc:
            last_exc = exc
            LOGGER.debug(
                "Candidate %s (%s) failed for %s:%d: %s",
                target_ip,
                family.name,
                host,
                port,
                exc,
            )
    raise last_exc


def tune_socket(writer: asyncio.StreamWriter) -> None:
    """Enable TCP_NODELAY and keepalive on a connected transport socket."""
    sock = writer.get_extra_info("socket")
    if sock is None:
        return
    try:
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
    except OSError:
        pass


async def relay_stream(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) -> None:
    """Forward data one-way until EOF or benign client reset."""
    try:
        while True:
            chunk = await reader.read(BUFFER_SIZE)
            if not chunk:
                break
            writer.write(chunk)
            await writer.drain()
        if writer.can_write_eof():
            writer.write_eof()
    except (ConnectionResetError, BrokenPipeError, asyncio.CancelledError):
        pass
    except OSError as exc:
        LOGGER.debug("Relay socket closed: %s", exc)


async def read_target_address(
    reader: asyncio.StreamReader, atyp: int
) -> tuple[str, int] | None:
    """Parse destination address and port based on SOCKS5 ATYP."""
    if atyp == ATYP_IPV4:
        addr_bytes = await reader.readexactly(4)
        host = socket.inet_ntop(socket.AF_INET, addr_bytes)
    elif atyp == ATYP_IPV6:
        addr_bytes = await reader.readexactly(16)
        host = socket.inet_ntop(socket.AF_INET6, addr_bytes)
    elif atyp == ATYP_DOMAIN:
        length_byte = await reader.readexactly(1)
        domain_len = length_byte[0]
        if domain_len == 0:
            return None
        domain_bytes = await reader.readexactly(domain_len)
        host = domain_bytes.decode("utf-8", errors="replace")
    else:
        return None
    port_bytes = await reader.readexactly(2)
    port = struct.unpack("!H", port_bytes)[0]
    return host, port


async def close_writer(writer: asyncio.StreamWriter | None) -> None:
    """Safely close a StreamWriter without propagating disconnect errors."""
    if writer is None:
        return
    try:
        writer.close()
        await writer.wait_closed()
    except (OSError, asyncio.CancelledError):
        pass


async def handle_client(
    client_reader: asyncio.StreamReader,
    client_writer: asyncio.StreamWriter,
    cfg: ProxyConfig,
) -> None:
    """Handle one incoming SOCKS5 client connection."""
    remote_writer: asyncio.StreamWriter | None = None
    try:
        header = await asyncio.wait_for(client_reader.readexactly(2), timeout=10.0)
        ver, nmethods = header[0], header[1]
        if ver != SOCKS_VERSION or nmethods == 0:
            return
        methods = await asyncio.wait_for(
            client_reader.readexactly(nmethods), timeout=10.0
        )
        if AUTH_NONE not in methods:
            client_writer.write(struct.pack("!BB", SOCKS_VERSION, AUTH_NO_ACCEPTABLE))
            await client_writer.drain()
            return

        client_writer.write(struct.pack("!BB", SOCKS_VERSION, AUTH_NONE))
        await client_writer.drain()

        req = await asyncio.wait_for(client_reader.readexactly(4), timeout=10.0)
        req_ver, cmd, _rsv, atyp = req[0], req[1], req[2], req[3]
        if req_ver != SOCKS_VERSION:
            return
        if cmd != CMD_CONNECT:
            client_writer.write(build_reply(REP_COMMAND_NOT_SUPPORTED))
            await client_writer.drain()
            return

        parsed = await asyncio.wait_for(
            read_target_address(client_reader, atyp), timeout=10.0
        )
        if parsed is None:
            client_writer.write(build_reply(REP_ADDRESS_TYPE_NOT_SUPPORTED))
            await client_writer.drain()
            return

        target_host, target_port = parsed
        try:
            remote_reader, remote_writer = await open_upstream(
                target_host, target_port, atyp, cfg
            )
        except (OSError, ValueError, *TIMEOUT_ERRORS) as exc:
            LOGGER.debug(
                "Upstream connect failed for %s:%d: %s", target_host, target_port, exc
            )
            client_writer.write(build_reply(map_errno_to_rep(exc)))
            await client_writer.drain()
            return

        tune_socket(client_writer)
        tune_socket(remote_writer)
        sockname = remote_writer.get_extra_info("sockname")
        client_writer.write(build_reply(REP_SUCCEEDED, sockname))
        await client_writer.drain()

        await asyncio.gather(
            relay_stream(client_reader, remote_writer),
            relay_stream(remote_reader, client_writer),
            return_exceptions=True,
        )
    except (
        asyncio.IncompleteReadError,
        ConnectionResetError,
        BrokenPipeError,
        *TIMEOUT_ERRORS,
    ):
        pass
    except OSError as exc:
        LOGGER.debug("Client session error: %s", exc)
    finally:
        await close_writer(remote_writer)
        await close_writer(client_writer)


async def run_server(cfg: ProxyConfig) -> None:
    """Start SOCKS5 server and wait until shutdown signal."""
    server = await asyncio.start_server(
        lambda r, w: handle_client(r, w, cfg),
        host=cfg.listen_host,
        port=cfg.listen_port,
        reuse_address=True,
        backlog=512,
    )
    LOGGER.info(
        "Listening on %s:%d (stack_mode=%s, debug=%s)",
        cfg.listen_host,
        cfg.listen_port,
        cfg.stack_mode,
        cfg.debug,
    )

    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig_name in ("SIGINT", "SIGTERM"):
        sig = getattr(signal, sig_name, None)
        if sig is not None:
            try:
                loop.add_signal_handler(sig, stop_event.set)
            except NotImplementedError:
                pass

    async with server:
        await stop_event.wait()


def main() -> None:
    """Entrypoint for direct-socks5."""
    cfg = build_config()
    logging.basicConfig(
        level=logging.DEBUG if cfg.debug else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )
    try:
        asyncio.run(run_server(cfg))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
