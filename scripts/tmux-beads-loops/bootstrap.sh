#!/usr/bin/env bash
# ABOUTME: Bootstrap a manager pane by spawning balanced agent panes in-session.
# ABOUTME: Uses tmux-beads-loops spawn-agent and marks the session as bootstrapped.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--total N] [--claude N] [--codex N] [--split h|v] [--base-pane N] [--layout NAME] [--force]

Examples:
  bootstrap.sh --total 4
  bootstrap.sh --claude 2 --codex 2 --split v
EOF
}

if [ -z "${TMUX:-}" ]; then
  echo "tmux-beads-loops: bootstrap must run inside tmux" >&2
  exit 1
fi

script_dir="${TMUX_BEADS_LOOPS_ROOT:-}"
if [ -z "$script_dir" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

total="${TMUX_BEADS_BOOTSTRAP_TOTAL:-}"
claude="${TMUX_BEADS_BOOTSTRAP_CLAUDE:-}"
codex="${TMUX_BEADS_BOOTSTRAP_CODEX:-}"
split="${TMUX_BEADS_SPAWN_SPLIT:-h}"
base_pane="${TMUX_BEADS_BASE_PANE:-}"
layout="${TMUX_BEADS_BOOTSTRAP_LAYOUT:-}"
force=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --total)
      total="$2"
      shift 2
      ;;
    --claude)
      claude="$2"
      shift 2
      ;;
    --codex)
      codex="$2"
      shift 2
      ;;
    --split)
      split="$2"
      shift 2
      ;;
    --base-pane)
      base_pane="$2"
      shift 2
      ;;
    --layout)
      layout="$2"
      shift 2
      ;;
    --force)
      force=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "tmux-beads-loops: unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

is_number() {
  printf '%s' "$1" | grep -Eq '^[0-9]+$'
}

if [ -z "$claude" ] && [ -z "$codex" ]; then
  if [ -z "$total" ]; then
    total="2"
  fi
  if ! is_number "$total"; then
    echo "tmux-beads-loops: --total must be numeric" >&2
    exit 1
  fi
  claude=$(( (total + 1) / 2 ))
  codex=$(( total - claude ))
else
  claude="${claude:-0}"
  codex="${codex:-0}"
  if ! is_number "$claude" || ! is_number "$codex"; then
    echo "tmux-beads-loops: --claude/--codex must be numeric" >&2
    exit 1
  fi
  total=$((claude + codex))
fi

if [ "$total" -lt 1 ]; then
  echo "tmux-beads-loops: total agent count must be >= 1" >&2
  exit 1
fi

bootstrapped="$(tmux show -gqv @beads_bootstrapped)"
if [ -n "$bootstrapped" ] && [ "$force" -ne 1 ]; then
  echo "tmux-beads-loops: already bootstrapped (${bootstrapped}). Use --force to re-run."
  exit 0
fi

manager="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
if [ -z "$manager" ] && [ -x "${script_dir}/manager-init.sh" ]; then
  "${script_dir}/manager-init.sh" >/dev/null
  manager="$(tmux show -gqv @beads_manager)"
fi

if [ -n "$manager" ]; then
  session="${manager%%:*}"
  window="${manager##*:}"
else
  session="$(tmux display-message -p '#S')"
  window="$(tmux display-message -p '#I')"
fi

if [ -z "$base_pane" ]; then
  base_pane="$(tmux show -gqv @beads_manager_pane_index)"
  if [ -z "$base_pane" ]; then
    base_pane="$(tmux display-message -p '#P')"
  fi
fi

spawn="${script_dir}/spawn-agent.sh"
if [ ! -x "$spawn" ]; then
  echo "tmux-beads-loops: spawn-agent.sh not found at ${spawn}" >&2
  exit 1
fi

for i in $(seq 1 "$claude"); do
  "$spawn" claude --split "$split" --base-pane "$base_pane" --name "claude-${i}"
done

for i in $(seq 1 "$codex"); do
  "$spawn" codex --split "$split" --base-pane "$base_pane" --name "codex-${i}"
done

if [ -n "$layout" ]; then
  tmux select-layout -t "${session}:${window}" "$layout"
fi

tmux set -g @beads_bootstrapped "${session}:${window}:$(date +%s)"
tmux set -g @beads_bootstrapped_total "$total"

echo "tmux-beads-loops: bootstrapped ${total} panes in ${session}:${window} (claude=${claude}, codex=${codex})"
