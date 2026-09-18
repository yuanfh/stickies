#!/usr/bin/env python3
"""Read/write Stickies JSON with a rotating .bak backup."""

from __future__ import annotations

import base64
import json
import shutil
import sys
from pathlib import Path

DATA_DIR = Path.home() / ".local/share/plasma/plasmoids/org.yuanfh.sidenotes"
NOTES = DATA_DIR / "notes.json"
BAK = DATA_DIR / "notes.bak.json"


def ensure_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def cmd_read() -> int:
    ensure_dir()
    if NOTES.exists():
        sys.stdout.write(NOTES.read_text(encoding="utf-8"))
    else:
        sys.stdout.write("[]")
    return 0


def cmd_read_b64() -> int:
    """Emit notes JSON as base64 so Plasma/QML never mangles UTF-8 stdout."""
    ensure_dir()
    if NOTES.exists():
        raw = NOTES.read_bytes()
    else:
        raw = b"[]"
    sys.stdout.write(base64.b64encode(raw).decode("ascii"))
    return 0


def cmd_write_b64(payload_b64: str) -> int:
    ensure_dir()
    raw = base64.b64decode(payload_b64).decode("utf-8")
    data = json.loads(raw)
    if not isinstance(data, list):
        raise ValueError("notes root must be a JSON array")
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
