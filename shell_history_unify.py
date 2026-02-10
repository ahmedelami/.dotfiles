#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import platform
import shutil
import sys
import time
from pathlib import Path


def _default_nushell_history_path() -> Path:
    home = Path.home()
    if platform.system() == "Darwin":
        return home / "Library" / "Application Support" / "nushell" / "history.txt"
    return home / ".local" / "share" / "nushell" / "history.txt"


def _parse_history_lines(lines: list[str]) -> list[str]:
    commands: list[str] = []

    buffer = ""
    for raw in lines:
        line = raw.rstrip("\n").rstrip("\r").replace("\0", "")

        # zsh extended-history format:
        #   : <epoch>:<duration>;<command>
        if line.startswith(": ") and ";" in line:
            cmd = line.split(";", 1)[1]
            if buffer:
                commands.append(buffer)
                buffer = ""
        else:
            cmd = line

        buffer = f"{buffer}{cmd}" if buffer else cmd

        # zsh stores multi-line commands as backslash-newline continuations.
        if buffer.endswith("\\"):
            buffer = buffer[:-1]
            continue

        if buffer.strip():
            commands.append(buffer)
        buffer = ""

    if buffer.strip():
        commands.append(buffer)

    return commands


def _read_commands(path: Path) -> list[str]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    return _parse_history_lines(text.splitlines(keepends=True))


def _write_commands(path: Path, commands: list[str], *, backup: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    if backup and path.exists():
        ts = time.strftime("%Y%m%d-%H%M%S")
        backup_path = path.with_name(f"{path.name}.bak-{ts}")
        shutil.copy2(path, backup_path)

    tmp_path = path.with_name(f".{path.name}.tmp")
    data = "\n".join(commands) + ("\n" if commands else "")
    tmp_path.write_text(data, encoding="utf-8")
    os.replace(tmp_path, path)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Unify zsh + Nushell history into a single plaintext history file.\n\n"
            "This is intended to support sharing suggestions between zsh "
            "(zsh-autosuggestions) and Nushell (history hints)."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "--zsh-history",
        type=Path,
        default=Path.home() / ".zsh_history",
        help="Path to the existing zsh history file (default: ~/.zsh_history).",
    )
    parser.add_argument(
        "--nu-history",
        type=Path,
        default=_default_nushell_history_path(),
        help="Path to Nushell plaintext history file (default: OS-dependent).",
    )
    parser.add_argument(
        "--max-lines",
        type=int,
        default=100_000,
        help="Keep at most this many history entries (default: 100000).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would change, but do not write anything.",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not create a timestamped backup before rewriting the nu history file.",
    )
    args = parser.parse_args(argv)

    zsh_history_path: Path = args.zsh_history.expanduser()
    nu_history_path: Path = args.nu_history.expanduser()

    zsh_cmds = _read_commands(zsh_history_path)
    nu_cmds = _read_commands(nu_history_path)

    # Make the file idempotent:
    # If the nu history already starts with some prefix of the zsh history (e.g.
    # after a previous unify), avoid duplicating that prefix.
    overlap = 0
    max_overlap = min(len(zsh_cmds), len(nu_cmds))
    while overlap < max_overlap and zsh_cmds[overlap] == nu_cmds[overlap]:
        overlap += 1

    combined = zsh_cmds + nu_cmds[overlap:]

    if args.max_lines > 0 and len(combined) > args.max_lines:
        combined = combined[-args.max_lines :]

    if args.dry_run:
        print(f"zsh history: {zsh_history_path} ({len(zsh_cmds)} entries)")
        print(f"nu  history: {nu_history_path} ({len(nu_cmds)} entries)")
        print(f"overlap: {overlap} entries")
        print(f"combined: {len(combined)} entries")
        return 0

    _write_commands(nu_history_path, combined, backup=not args.no_backup)
    print(f"Wrote unified history to: {nu_history_path} ({len(combined)} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

