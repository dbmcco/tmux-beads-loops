#!/usr/bin/env bash
# ABOUTME: Register the current tmux window as the beads manager target.
# ABOUTME: Stores session:window in the tmux global @beads_manager option.

set -euo pipefail

if [ -z "${TMUX:-}" ]; then
  echo "tmux-beads: manager init must run inside tmux" >&2
  exit 1
fi

tmux_target="${TMUX_PANE:-}"
if [ -n "$tmux_target" ]; then
  session="$(tmux display-message -p -t "$tmux_target" '#S')"
  window="$(tmux display-message -p -t "$tmux_target" '#I')"
  window_name="$(tmux display-message -p -t "$tmux_target" '#W')"
else
  session="$(tmux display-message -p '#S')"
  window="$(tmux display-message -p '#I')"
  window_name="$(tmux display-message -p '#W')"
fi
target="${session}:${window}"

tmux set -g @beads_manager "$target"
tmux set -g @beads_manager_name "$window_name"

echo "tmux-beads: manager set to ${target} (${window_name})"
