#!/usr/bin/env bash
# ABOUTME: Session-start hook that bootstraps tmux-beads-loops in agent panes.
# ABOUTME: Auto-registers the manager if none is set (opt-out via TMUX_BEADS_AUTO_MANAGER=0).

set -euo pipefail

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

auto_manager="${TMUX_BEADS_AUTO_MANAGER:-1}"
manager_target="$(tmux show -gqv @beads_manager)"
manager_pane_id="$(tmux show -gqv @beads_manager_pane)"
tmux_target="${TMUX_PANE:-}"

if [ -z "$manager_target" ] && [ "$auto_manager" = "1" ]; then
  if [ -n "$tmux_target" ]; then
    session="$(tmux display-message -p -t "$tmux_target" '#S')"
    window="$(tmux display-message -p -t "$tmux_target" '#I')"
    window_name="$(tmux display-message -p -t "$tmux_target" '#W')"
    pane_index="$(tmux display-message -p -t "$tmux_target" '#P')"
    pane_id="$(tmux display-message -p -t "$tmux_target" '#{pane_id}')"
  else
    session="$(tmux display-message -p '#S')"
    window="$(tmux display-message -p '#I')"
    window_name="$(tmux display-message -p '#W')"
    pane_index="$(tmux display-message -p '#P')"
    pane_id="$(tmux display-message -p '#{pane_id}')"
  fi
  manager_target="${session}:${window}"
  manager_pane_id="$pane_id"
  manager_pane_target="${session}:${window}.${pane_index}"

  tmux set -g @beads_manager "$manager_target"
  tmux set -g @beads_manager_name "$window_name"
  tmux set -g @beads_manager_pane "$manager_pane_id"
  tmux set -g @beads_manager_pane_index "$pane_index"
  tmux set -g @beads_manager_pane_target "$manager_pane_target"
fi

script_dir="${TMUX_BEADS_LOOPS_ROOT:-}"
if [ -z "$script_dir" ]; then
  script_path=""
  if [ -n "${BASH_SOURCE:-}" ]; then
    script_path="${BASH_SOURCE[0]}"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    script_path="$(eval 'echo ${(%):-%N}')"
  else
    script_path="$0"
  fi
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
fi
# shellcheck source=/dev/null
source "${script_dir}/env.sh"

if [ -n "${TMUX_BEADS_MANAGER_PANE_ID:-}" ] && [ -n "${TMUX_BEADS_PANE_ID:-}" ]; then
  if [ "$TMUX_BEADS_PANE_ID" = "$TMUX_BEADS_MANAGER_PANE_ID" ]; then
    export TMUX_BEADS_ROLE="manager"
  else
    export TMUX_BEADS_ROLE="worker"
  fi
elif [ -n "$tmux_target" ]; then
  current_target="$(tmux display-message -p -t "$tmux_target" '#S:#I')"
  if [ "${TMUX_BEADS_MANAGER_TARGET:-}" = "$current_target" ]; then
    export TMUX_BEADS_ROLE="manager"
  else
    export TMUX_BEADS_ROLE="worker"
  fi
else
  current_target="$(tmux display-message -p '#S:#I')"
  if [ "${TMUX_BEADS_MANAGER_TARGET:-}" = "$current_target" ]; then
    export TMUX_BEADS_ROLE="manager"
  else
    export TMUX_BEADS_ROLE="worker"
  fi
fi
