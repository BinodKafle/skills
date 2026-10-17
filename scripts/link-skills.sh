#!/usr/bin/env bash
# Symlinks every skill, drafts included, into ~/.claude/skills (or $1). Re-run after adding or renaming one.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/.claude/skills}"
mkdir -p "$DEST"

if [ -L "$DEST" ]; then
  case "$(readlink -f "$DEST")" in
    "$REPO"|"$REPO"/*) echo "refusing: $DEST resolves into this repo" >&2; exit 1 ;;
  esac
fi

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "skip $name: $target exists and is not a symlink (move it aside first)" >&2
    continue
  fi
  ln -sfn "$src" "$target"
  echo "linked $name -> $src"
done < <(find "$REPO/skills" -mindepth 3 -maxdepth 3 -name SKILL.md -print0)
