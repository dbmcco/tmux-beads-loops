#!/usr/bin/env bash
# ABOUTME: Send a command to the beads manager tmux window.
# ABOUTME: Resolves manager target from tmux option or BEADS_MANAGER_TARGET.

set -euo pipefail

if [ -z "${TMUX:-}" ]; then
  echo "tmux-beads: not running inside tmux" >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: notify.sh <command...>" >&2
  exit 1
fi

manager="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
if [ -z "$manager" ]; then
  echo "tmux-beads: manager target not set. Run scripts/tmux-beads/manager-init.sh in the manager window." >&2
  exit 1
fi

command="$*"
tmux send-keys -t "$manager" "$command" Enter
