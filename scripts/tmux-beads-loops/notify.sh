#!/usr/bin/env bash
# ABOUTME: Send a command to the beads manager tmux window.
# ABOUTME: Resolves manager target from tmux option or BEADS_MANAGER_TARGET.

set -euo pipefail

if [ -z "${TMUX:-}" ]; then
  echo "tmux-beads-loops: not running inside tmux" >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: notify.sh <command...>" >&2
  exit 1
fi

manager="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
if [ -z "$manager" ]; then
  echo "tmux-beads-loops: manager target not set. Run scripts/tmux-beads-loops/manager-init.sh in the manager window." >&2
  exit 1
fi

manager_pane_id="${BEADS_MANAGER_PANE_ID:-$(tmux show -gqv @beads_manager_pane)}"
manager_pane_target="${BEADS_MANAGER_PANE_TARGET:-$(tmux show -gqv @beads_manager_pane_target)}"
current_pane_id="$(tmux display-message -p '#{pane_id}')"

if [ -n "$manager_pane_id" ] && [ "$manager_pane_id" = "$current_pane_id" ]; then
  echo "tmux-beads-loops: refusing to notify from manager pane. Use delegate.sh to target workers." >&2
  exit 1
fi

if [ -n "$manager_pane_id" ]; then
  target="$manager_pane_id"
elif [ -n "$manager_pane_target" ]; then
  target="$manager_pane_target"
else
  target="$manager"
fi

command="$*"
tmux send-keys -t "$target" "$command"
tmux send-keys -t "$target" Enter
