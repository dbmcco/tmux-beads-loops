#!/usr/bin/env bash
# ABOUTME: Session-start hook that bootstraps tmux-beads-loops in agent panes.
# ABOUTME: Auto-registers the manager if none is set (opt-out via TMUX_BEADS_AUTO_MANAGER=0).

set -euo pipefail

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

auto_manager="${TMUX_BEADS_AUTO_MANAGER:-1}"
manager_target="$(tmux show -gqv @beads_manager)"
tmux_target="${TMUX_PANE:-}"

if [ -z "$manager_target" ] && [ "$auto_manager" = "1" ]; then
  if [ -n "$tmux_target" ]; then
    session="$(tmux display-message -p -t "$tmux_target" '#S')"
    window="$(tmux display-message -p -t "$tmux_target" '#I')"
    window_name="$(tmux display-message -p -t "$tmux_target" '#W')"
  else
    session="$(tmux display-message -p '#S')"
    window="$(tmux display-message -p '#I')"
    window_name="$(tmux display-message -p '#W')"
  fi
  manager_target="${session}:${window}"

  tmux set -g @beads_manager "$manager_target"
  tmux set -g @beads_manager_name "$window_name"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${script_dir}/env.sh"

if [ -n "$tmux_target" ]; then
  current_target="$(tmux display-message -p -t "$tmux_target" '#S:#I')"
else
  current_target="$(tmux display-message -p '#S:#I')"
fi
if [ "${TMUX_BEADS_MANAGER_TARGET:-}" = "$current_target" ]; then
  export TMUX_BEADS_ROLE="manager"
else
  export TMUX_BEADS_ROLE="worker"
fi
