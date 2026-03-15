#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${HOME}/.claude/skills"

echo "Installing virtual-team skills..."

mkdir -p "$SKILLS_DIR"

# Remove old copies (files or dirs), then create symlinks
for skill in virtual-team virtual-team-init; do
  target="${SKILLS_DIR}/${skill}"
  source="${SCRIPT_DIR}/skills/${skill}"

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -d "$target" ]; then
    echo "Warning: ${target} is a regular directory, replacing with symlink"
    rm -rf "$target"
  fi

  ln -sf "$source" "$target"
  echo "  ✓ ${skill} -> ${source}"
done

echo ""
echo "Done. Restart Claude Code to use /virtual-team and /virtual-team-init."
