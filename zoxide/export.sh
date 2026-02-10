#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
out_file="${1:-"$repo_dir/entries.tsv"}"

if ! command -v zoxide >/dev/null 2>&1; then
  echo "error: zoxide not found on PATH" >&2
  exit 1
fi

tmp="$(mktemp "${out_file}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

{
  printf '# score\tpath\n'
  zoxide query -ls | awk 'NF {score=$1; $1=""; sub(/^ +/, "", $0); print score "\t" $0 }'
} >"$tmp"

mv -f "$tmp" "$out_file"
echo "wrote: $out_file"

