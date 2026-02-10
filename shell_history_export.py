#!/usr/bin/env python3

from __future__ import annotations

import argparse
import platform
import re
import shutil
import sys
import time
from pathlib import Path


def _default_nushell_history_path() -> Path:
    home = Path.home()
    if platform.system() == "Darwin":
        return home / "Library" / "Application Support" / "nushell" / "history.txt"
    return home / ".local" / "share" / "nushell" / "history.txt"


def _default_export_path() -> Path:
    return Path.home() / ".dotfiles" / "history" / "shell_history_sanitized.txt"


def _compile_sensitive_patterns() -> list[re.Pattern[str]]:
    patterns = [
        # Common "secret in command" cases.
        r"(?i)\bauthorization\s*:\s*bearer\b",
        r"(?i)\bbearer\s+[A-Za-z0-9\-_\.=]{10,}",
        r"(?i)\b(x-api-key|api[-_]?key|apikey)\b\s*[:=]",
        r"(?i)\b(--?(token|auth-token|access-token|refresh-token|client-secret|api[-_]?key|password|passwd))\b",
        # Env var assignments that likely contain secrets.
        r"(?i)\b([A-Z0-9_]*(TOKEN|SECRET|PASSWORD|PASSWD|API_KEY|APIKEY|KEY)[A-Z0-9_]*)\s*=",
        # Known token/key formats (best-effort).
        r"\bsk-[A-Za-z0-9._=-]{20,}\b",  # OpenAI (best-effort; covers sk-... and sk-proj-...)
        r"\bghp_[A-Za-z0-9]{20,}\b",  # GitHub classic token
        r"\bgithub_pat_[A-Za-z0-9_]{20,}\b",  # GitHub fine-grained
        r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b",  # Slack
        r"\bAIza[0-9A-Za-z\-_]{20,}\b",  # Google API key
        r"\bya29\.[0-9A-Za-z\-_]+\b",  # Google OAuth token
        r"(?i)-----BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY-----",
    ]
    return [re.compile(p) for p in patterns]


def _looks_sensitive(command: str, sensitive_patterns: list[re.Pattern[str]]) -> bool:
    if len(command) > 2000:
        return True
    for pattern in sensitive_patterns:
        if pattern.search(command):
            return True
    return False


def _read_history_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    return [line.rstrip("\n").rstrip("\r") for line in text.splitlines()]


def _recent_unique(commands: list[str], max_unique: int) -> list[str]:
    seen: set[str] = set()
    out_reversed: list[str] = []

    for cmd in reversed(commands):
        if cmd in seen:
            continue
        seen.add(cmd)
        out_reversed.append(cmd)
        if max_unique > 0 and len(out_reversed) >= max_unique:
            break

    return list(reversed(out_reversed))


def _write_lines(path: Path, lines: list[str], *, backup: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if backup and path.exists():
        ts = time.strftime("%Y%m%d-%H%M%S")
        backup_path = path.with_name(f"{path.name}.bak-{ts}")
        shutil.copy2(path, backup_path)
    data = "\n".join(lines) + ("\n" if lines else "")
    path.write_text(data, encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Export a sanitized, git-trackable shell history snapshot.\n\n"
            "Reads the shared Nushell plaintext history (which may also be used by zsh),\n"
            "filters out lines that look like they contain secrets, de-duplicates, and\n"
            "writes a bounded-size snapshot into ~/.dotfiles/history/.\n\n"
            "NOTE: Always review before committing."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "--in",
        dest="in_path",
        type=Path,
        default=_default_nushell_history_path(),
        help="Input history path (default: shared Nushell history.txt).",
    )
    parser.add_argument(
        "--out",
        dest="out_path",
        type=Path,
        default=_default_export_path(),
        help="Output snapshot path (default: ~/.dotfiles/history/shell_history_sanitized.txt).",
    )
    parser.add_argument(
        "--max-unique",
        type=int,
        default=5000,
        help="Keep at most this many unique commands (default: 5000). Use 0 for unlimited.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print counts only; do not write.",
    )
    parser.add_argument(
        "--backup",
        action="store_true",
        help="Create a timestamped backup before overwriting the output file.",
    )
    args = parser.parse_args(argv)

    in_path: Path = args.in_path.expanduser()
    out_path: Path = args.out_path.expanduser()

    raw = _read_history_lines(in_path)
    normalized = [c.strip() for c in raw if c.strip()]

    sensitive_patterns = _compile_sensitive_patterns()
    safe = [c for c in normalized if not _looks_sensitive(c, sensitive_patterns)]
    exported = _recent_unique(safe, args.max_unique)

    if args.dry_run:
        print(f"in:  {in_path} ({len(normalized)} commands)")
        print(f"out: {out_path}")
        print(f"kept: {len(exported)} unique commands")
        dropped = len(normalized) - len(safe)
        if dropped:
            print(f"dropped (sensitive/too-long): {dropped}")
        return 0

    _write_lines(out_path, exported, backup=args.backup)
    print(f"Wrote: {out_path} ({len(exported)} unique commands)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
