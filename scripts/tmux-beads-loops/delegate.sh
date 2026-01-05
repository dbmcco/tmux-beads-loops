#!/usr/bin/env bash
# ABOUTME: Safely delegate commands to another tmux pane with Enter sent separately.
# ABOUTME: Prevents accidental self-targeting and resolves window names in manager session.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: delegate.sh [--target <target>] [--window <name|index>] [--pane <index>] [--allow-self] -- <command...>

Examples:
  delegate.sh --window claude-1 -- "bd ready"
  delegate.sh --window 2 --pane 0 -- "git status"
  delegate.sh --target hm:3.1 -- "echo hi"
EOF
}

if [ -z "${TMUX:-}" ]; then
  echo "tmux-beads-loops: delegate must run inside tmux" >&2
  exit 1
fi

target=""
window=""
pane=""
allow_self=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      target="$2"
      shift 2
      ;;
    --window)
      window="$2"
      shift 2
      ;;
    --pane)
      pane="$2"
      shift 2
      ;;
    --allow-self)
      allow_self=1
      shift 1
      ;;
    --)
      shift
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

command="$*"

if [ -z "$target" ]; then
  if [ -z "$window" ]; then
    echo "tmux-beads-loops: specify --window or --target" >&2
    exit 1
  fi

  manager="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
  if [ -n "$manager" ]; then
    session="${manager%%:*}"
  else
    session="$(tmux display-message -p '#S')"
  fi

  if echo "$window" | grep -Eq '^[0-9]+$'; then
    window_index="$window"
  else
    window_index="$(tmux list-windows -t "$session" -F '#I:#W' | awk -F: -v name="$window" '$2 == name {print $1; exit}')"
  fi

  if [ -z "${window_index:-}" ]; then
    echo "tmux-beads-loops: window not found in session $session: $window" >&2
    exit 1
  fi

  if [ -z "$pane" ]; then
    pane="0"
  fi

  target="${session}:${window_index}.${pane}"
fi

target_pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
current_pane_id="$(tmux display-message -p '#{pane_id}')"
manager_pane_id="$(tmux show -gqv @beads_manager_pane)"

if [ "$allow_self" -ne 1 ]; then
  if [ "$target_pane_id" = "$current_pane_id" ]; then
    echo "tmux-beads-loops: refusing to target current pane ($target)" >&2
    exit 1
  fi
  if [ -n "$manager_pane_id" ] && [ "$target_pane_id" = "$manager_pane_id" ]; then
    echo "tmux-beads-loops: refusing to target manager pane ($target)" >&2
    exit 1
  fi
fi

tmux send-keys -t "$target" "$command"
tmux send-keys -t "$target" Enter
