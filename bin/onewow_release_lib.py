#!/usr/bin/env python3
"""Shared TOC discovery and parsing for OneWoW release tooling."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Desktop companion — not a WoW load unit; never ship in the CurseForge zip.
SKIP_ADDONS = frozenset({"OneWoW_AccountSync"})

INTERFACE_RE = re.compile(r"^(##\s*Interface:\s*)(.+)$", re.IGNORECASE | re.MULTILINE)
VERSION_RE = re.compile(r"^(##\s*Version:\s*)(.+)$", re.IGNORECASE | re.MULTILINE)
INTERFACE_LINE_RE = re.compile(r"^##\s*Interface:\s*(.+)$", re.IGNORECASE)
VERSION_LINE_RE = re.compile(r"^##\s*Version:\s*(.+)$", re.IGNORECASE)


def discover_tocs() -> list[Path]:
    """Shippable addon TOCs: OneWoW/ and OneWoW_*/ with a matching .toc."""
    tocs: list[Path] = []
    for path in sorted(ROOT.iterdir()):
        if not path.is_dir():
            continue
        name = path.name
        if name == "OneWoW" or name.startswith("OneWoW_"):
            if name in SKIP_ADDONS:
                continue
            toc = path / f"{name}.toc"
            if toc.is_file():
                tocs.append(toc)
    return tocs


def discover_addon_dirs() -> list[Path]:
    """Shippable addon directories (parents of discover_tocs())."""
    return [toc.parent for toc in discover_tocs()]


def parse_interface_list(raw: str) -> list[str]:
    """Split a ## Interface: value into digit strings."""
    parts: list[str] = []
    for piece in raw.split(","):
        piece = piece.strip()
        if not piece:
            continue
        if not piece.isdigit():
            raise SystemExit(f"Invalid interface value (digits only): {piece!r}")
        parts.append(piece)
    if not parts:
        raise SystemExit("## Interface: has no values")
    return parts


def format_interfaces(values: list[str]) -> str:
    """Normalize interface args to '120007, 121000'."""
    parts: list[str] = []
    for raw in values:
        parts.extend(parse_interface_list(raw))
    if not parts:
        raise SystemExit("--interfaces requires at least one interface number")
    return ", ".join(parts)


def interface_to_game_version(interface: str | int) -> str:
    """Map TOC interface 120007 -> '12.0.7'."""
    n = int(interface)
    major = n // 10000
    minor = (n // 100) % 100
    patch = n % 100
    return f"{major}.{minor}.{patch}"


def _read_field(path: Path, line_re: re.Pattern[str], label: str) -> str:
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        m = line_re.match(line.strip())
        if m:
            value = m.group(1).strip()
            if not value:
                raise SystemExit(f"{path}: empty ## {label}:")
            return value
    raise SystemExit(f"{path}: missing ## {label}: line")


def read_toc_version(path: Path) -> str:
    return _read_field(path, VERSION_LINE_RE, "Version")


def read_toc_interfaces(path: Path) -> list[str]:
    raw = _read_field(path, INTERFACE_LINE_RE, "Interface")
    return parse_interface_list(raw)


def require_uniform_version(tocs: list[Path] | None = None) -> str:
    """Return the shared ## Version: across all shippable TOCs, or exit."""
    paths = tocs if tocs is not None else discover_tocs()
    if not paths:
        raise SystemExit("No shippable OneWoW*.toc files found")
    versions: dict[str, list[str]] = {}
    for toc in paths:
        ver = read_toc_version(toc)
        versions.setdefault(ver, []).append(toc.relative_to(ROOT).as_posix())
    if len(versions) != 1:
        lines = ["TOC ## Version: values disagree:"]
        for ver, files in sorted(versions.items()):
            lines.append(f"  {ver}: {', '.join(files)}")
        raise SystemExit("\n".join(lines))
    return next(iter(versions))


def require_uniform_interfaces(tocs: list[Path] | None = None) -> list[str]:
    """Return the shared ## Interface: list across all shippable TOCs, or exit."""
    paths = tocs if tocs is not None else discover_tocs()
    if not paths:
        raise SystemExit("No shippable OneWoW*.toc files found")
    by_key: dict[tuple[str, ...], list[str]] = {}
    for toc in paths:
        ifaces = tuple(read_toc_interfaces(toc))
        by_key.setdefault(ifaces, []).append(toc.relative_to(ROOT).as_posix())
    if len(by_key) != 1:
        lines = ["TOC ## Interface: values disagree:"]
        for ifaces, files in sorted(by_key.items()):
            lines.append(f"  {', '.join(ifaces)}: {', '.join(files)}")
        raise SystemExit("\n".join(lines))
    return list(next(iter(by_key)))


def load_dotenv(path: Path | None = None) -> dict[str, str]:
    """Parse a simple KEY=VALUE .env file (no export, no multiline)."""
    env_path = path if path is not None else ROOT / ".env"
    if not env_path.is_file():
        return {}
    out: dict[str, str] = {}
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if key:
            out[key] = value
    return out
