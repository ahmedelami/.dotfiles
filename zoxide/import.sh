#!/bin/zsh

set -euo pipefail

repo_dir=${0:A:h}
input="$repo_dir/entries.tsv"
existing_only=0
force=0

while (( $# > 0 )); do
  case "$1" in
    --existing-only)
      existing_only=1
      ;;
    --force)
      force=1
      ;;
    -*)
      print -u2 "error: unknown option: $1"
      exit 1
      ;;
    *)
      input="$1"
      ;;
  esac
  shift
done

if ! command -v zoxide >/dev/null 2>&1; then
  print -u2 'error: zoxide not found on PATH'
  exit 1
fi

if [[ ! -r "$input" ]]; then
  print -u2 "error: cannot read: $input"
  exit 1
fi

existing_file=""
if (( ! force )); then
  existing_file=$(mktemp)
  zoxide query -l >"$existing_file"
fi

cleanup() {
  [[ -n "$existing_file" ]] && rm -f "$existing_file"
}
trap cleanup EXIT

imported=0
skipped=0

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "${line//[[:space:]]/}" ]] && continue
  [[ "$line" == \#* ]] && continue

  local_score=""
  local_path=""
  if [[ "$line" == *$'\t'* ]]; then
    local_score=${line%%$'\t'*}
    local_path=${line#*$'\t'}
  else
    local_score=${line%%[[:space:]]*}
    local_path=${line#"$local_score"}
    local_path=${local_path#"${local_path%%[![:space:]]*}"}
  fi

  [[ -z "$local_score" || -z "$local_path" ]] && continue

  if (( existing_only )) && [[ ! -e "$local_path" ]]; then
    ((skipped += 1))
    continue
  fi

  if (( ! force )) && grep -Fqx -- "$local_path" "$existing_file"; then
    ((skipped += 1))
    continue
  fi

  zoxide add -s "$local_score" -- "$local_path"
  ((imported += 1))
done <"$input"

print "imported: $imported"
print "skipped:  $skipped"
