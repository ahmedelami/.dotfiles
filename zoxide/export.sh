#!/bin/zsh

set -euo pipefail

repo_dir=${0:A:h}
target=${1:-"$repo_dir/entries.tsv"}

if ! command -v zoxide >/dev/null 2>&1; then
  print -u2 'error: zoxide not found on PATH'
  exit 1
fi

{
  print '# score\tpath'
  zoxide query -ls | awk 'NF { score=$1; sub(/^[^[:space:]]+[[:space:]]+/, ""); print score "\t" $0 }'
} >"$target"

print "wrote: $target"
