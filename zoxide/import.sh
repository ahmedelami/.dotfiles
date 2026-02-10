#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
in_file="$repo_dir/entries.tsv"

force=0
existing_only=0

usage() {
  cat <<'EOF'
Usage: import.sh [--existing-only] [--force] [entries.tsv]

Seeds zoxide's database from a text export (score<TAB>path).

Options:
  --existing-only  Only import directories that exist on disk
  --force          Import even if already present (increases scores)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --existing-only) existing_only=1 ;;
    --force) force=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "error: unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
    *) in_file="$arg" ;;
  esac
done

if ! command -v zoxide >/dev/null 2>&1; then
  echo "error: zoxide not found on PATH" >&2
  exit 1
fi

if [[ ! -r "$in_file" ]]; then
  echo "error: cannot read: $in_file" >&2
  exit 1
fi

declare -A existing=()
if [[ $force -eq 0 ]]; then
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    existing["$dir"]=1
  done < <(zoxide query -l || true)
fi

imported=0
skipped=0

while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  [[ "${line:0:1}" == "#" ]] && continue

  score="${line%%$'\t'*}"
  path="${line#*$'\t'}"

  if [[ "$score" == "$path" ]]; then
    score="${line%%[[:space:]]*}"
    path="${line#"$score"}"
    path="${path#"${path%%[![:space:]]*}"}"
  fi

  [[ -n "$score" && -n "$path" ]] || continue

  if [[ $existing_only -eq 1 && ! -d "$path" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [[ $force -eq 0 && -n "${existing["$path"]+x}" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  zoxide add -s "$score" -- "$path"
  existing["$path"]=1
  imported=$((imported + 1))
done <"$in_file"

echo "imported: $imported"
echo "skipped:  $skipped"

