#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"

usage() {
  echo "Usage: ./install.sh <platform>"
  echo ""
  echo "Platforms:"
  echo "  claude-code   Install skills to ~/.claude/skills/"
  echo "  openclaw      Install skills to ~/.openclaw/skills/"
  echo "  codex         Show Codex CLI setup instructions"
  echo "  all           Install for all platforms"
  echo ""
  echo "Example: ./install.sh claude-code"
}

install_skill_dir() {
  local target_dir="$1"
  local adapter_dir="$2"
  local skill_name="$3"

  # Remove old target
  if [ -L "$target_dir" ]; then
    rm "$target_dir"
  elif [ -d "$target_dir" ]; then
    rm -rf "$target_dir"
  fi

  # Create skill directory with SKILL.md + core symlink
  mkdir -p "$target_dir"
  cp "$adapter_dir/SKILL.md" "$target_dir/SKILL.md"
  ln -sf "$CORE_DIR" "$target_dir/core"

  echo "  ✓ ${skill_name} -> ${target_dir}"
}

install_claude_code() {
  local skills_dir="${HOME}/.claude/skills"
  echo "Installing for Claude Code..."
  mkdir -p "$skills_dir"

  # virtual-team
  install_skill_dir "$skills_dir/virtual-team" "$SCRIPT_DIR/adapters/claude-code" "virtual-team"

  # virtual-team-init
  install_skill_dir "$skills_dir/virtual-team-init" "$SCRIPT_DIR/adapters/claude-code/init" "virtual-team-init"

  echo "  Done. Restart Claude Code to use /virtual-team and /virtual-team-init."
}

install_openclaw() {
  local skills_dir="${HOME}/.openclaw/skills"
  echo "Installing for OpenClaw..."
  mkdir -p "$skills_dir"

  # virtual-team
  install_skill_dir "$skills_dir/virtual-team" "$SCRIPT_DIR/adapters/openclaw" "virtual-team"

  # virtual-team-init
  install_skill_dir "$skills_dir/virtual-team-init" "$SCRIPT_DIR/adapters/openclaw/init" "virtual-team-init"

  echo "  Done. Restart OpenClaw to use the skills."
}

install_codex() {
  echo "Codex CLI setup:"
  echo ""
  echo "  Codex uses TOML config, not skill directories."
  echo "  Copy the config to your project:"
  echo ""
  echo "    cp -r ${SCRIPT_DIR}/adapters/codex/ .codex/"
  echo ""
  echo "  Or reference it in your codex.toml:"
  echo ""
  echo "    config_file = \"${SCRIPT_DIR}/adapters/codex/config.toml\""
  echo ""
  echo "  The agent TOML files reference role prompts from:"
  echo "    ${CORE_DIR}/roles/"
}

# --- Main ---

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

PLATFORM="$1"

case "$PLATFORM" in
  claude-code)
    install_claude_code
    ;;
  openclaw)
    install_openclaw
    ;;
  codex)
    install_codex
    ;;
  all)
    install_claude_code
    echo ""
    install_openclaw
    echo ""
    install_codex
    ;;
  *)
    echo "Error: Unknown platform '$PLATFORM'"
    echo ""
    usage
    exit 1
    ;;
esac
