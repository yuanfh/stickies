#!/usr/bin/env python3
"""Read/write Stickies JSON with a rotating .bak backup.

Data lives outside the plasmoid install dir so kpackagetool6 -u cannot wipe it.
"""

from __future__ import annotations

import base64
import json
import shutil
import sys
from pathlib import Path

# NOT under ~/.local/share/plasma/plasmoids/… — that tree is replaced on upgrade.
DATA_DIR = Path.home() / ".local/share" / "stickies"
NOTES = DATA_DIR / "notes.json"
BAK = DATA_DIR / "notes.bak.json"

# Legacy location (inside the package) — migrate once if needed.
_LEGACY_DIR = Path.home() / ".local/share/plasma/plasmoids/org.yuanfh.sidenotes"
_LEGACY_NOTES = _LEGACY_DIR / "notes.json"
_LEGACY_BAK = _LEGACY_DIR / "notes.bak.json"


def ensure_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def _looks_mojibake(s: str) -> bool:
    if len(s) < 2:
        return False
    high = sum(1 for c in s if "\x80" <= c <= "\xff")
    cjk = sum(1 for c in s if "\u4e00" <= c <= "\u9fff")
    if cjk >= 2:
        return False
    return high >= 4 and high / len(s) >= 0.12


def _repair_str(s: str) -> str:
    cur = s
    for _ in range(3):
        try:
            nxt = cur.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
        if nxt == cur:
            break
        cur = nxt
    return cur


def _repair_obj(obj):
    if isinstance(obj, dict):
        return {k: _repair_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_repair_obj(x) for x in obj]
    if isinstance(obj, str) and _looks_mojibake(obj):
        return _repair_str(obj)
    return obj


def _migrate_legacy() -> None:
    """Copy notes out of the plasmoid package dir if we only have legacy files."""
    ensure_dir()
    if NOTES.exists():
        return
    src = _LEGACY_NOTES if _LEGACY_NOTES.exists() else (
        _LEGACY_BAK if _LEGACY_BAK.exists() else None
    )
    if src is None:
        return
    shutil.copy2(src, NOTES)
    if _LEGACY_BAK.exists() and not BAK.exists():
        shutil.copy2(_LEGACY_BAK, BAK)


def _load_notes_bytes() -> bytes:
    ensure_dir()
    _migrate_legacy()
    if not NOTES.exists():
        return b"[]"
    raw = NOTES.read_bytes()
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return raw if raw else b"[]"
    if not isinstance(data, list):
        return raw
    fixed = _repair_obj(data)
    if fixed != data:
        text = json.dumps(fixed, ensure_ascii=False, indent=2) + "\n"
        if NOTES.exists():
            shutil.copy2(NOTES, BAK)
        tmp = NOTES.with_suffix(".json.tmp")
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(NOTES)
        return text.encode("utf-8")
    return raw


def cmd_read() -> int:
    raw = _load_notes_bytes()
    sys.stdout.buffer.write(raw)
    return 0


def cmd_read_b64() -> int:
    """Emit notes JSON as base64 so Plasma/QML never mangles UTF-8 stdout."""
    raw = _load_notes_bytes()
    sys.stdout.write(base64.b64encode(raw).decode("ascii"))
    return 0


def cmd_write_b64(payload_b64: str) -> int:
    ensure_dir()
    raw = base64.b64decode(payload_b64).decode("utf-8")
    data = json.loads(raw)
    if not isinstance(data, list):
        raise ValueError("notes root must be a JSON array")
    # Never clobber good data with an empty write (upgrade / race guard).
    if len(data) == 0 and NOTES.exists():
        try:
            existing = json.loads(NOTES.read_text(encoding="utf-8"))
            if isinstance(existing, list) and len(existing) > 0:
                sys.stdout.write("skip-empty")
                return 0
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            pass
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if NOTES.exists():
        shutil.copy2(NOTES, BAK)
    tmp = NOTES.with_suffix(".json.tmp")
    tmp.write_text(text + "\n", encoding="utf-8")
    tmp.replace(NOTES)
    sys.stdout.write("ok")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: notes_io.py read | read-b64 | write-b64 <base64>", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "read":
        return cmd_read()
    if cmd == "read-b64":
        return cmd_read_b64()
    if cmd == "write-b64":
        if len(argv) < 3:
            print("missing payload", file=sys.stderr)
            return 2
        return cmd_write_b64(argv[2])
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as exc:  # noqa: BLE001 — surface to plasmoid stderr
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
