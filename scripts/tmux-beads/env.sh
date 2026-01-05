#!/usr/bin/env bash
# ABOUTME: Export tmux/beads environment variables for agents in tmux panes.
# ABOUTME: Resolves manager target and disables beads daemon for worktrees by default.

_tmux_beads_fail() {
  echo "tmux-beads: $1" >&2
  return 1 2>/dev/null || exit 1
}

if [ -z "${TMUX:-}" ]; then
  _tmux_beads_fail "not running inside tmux"
fi

tmux_target="${TMUX_PANE:-}"
if [ -n "$tmux_target" ]; then
  TMUX_BEADS_SESSION="$(tmux display-message -p -t "$tmux_target" '#S')"
  TMUX_BEADS_WINDOW="$(tmux display-message -p -t "$tmux_target" '#I')"
  TMUX_BEADS_WINDOW_NAME="$(tmux display-message -p -t "$tmux_target" '#W')"
  TMUX_BEADS_PANE_ID="$(tmux display-message -p -t "$tmux_target" '#{pane_id}')"
else
  TMUX_BEADS_SESSION="$(tmux display-message -p '#S')"
  TMUX_BEADS_WINDOW="$(tmux display-message -p '#I')"
  TMUX_BEADS_WINDOW_NAME="$(tmux display-message -p '#W')"
  TMUX_BEADS_PANE_ID="$(tmux display-message -p '#{pane_id}')"
fi
TMUX_BEADS_TARGET="${TMUX_BEADS_SESSION}:${TMUX_BEADS_WINDOW}"

TMUX_BEADS_MANAGER_TARGET="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
if [ -z "$TMUX_BEADS_MANAGER_TARGET" ] && [ "${BEADS_ASSUME_MANAGER:-}" = "1" ]; then
  TMUX_BEADS_MANAGER_TARGET="$TMUX_BEADS_TARGET"
  tmux set -g @beads_manager "$TMUX_BEADS_MANAGER_TARGET"
fi

if [ -z "${BEADS_NO_DAEMON:-}" ]; then
  export BEADS_NO_DAEMON=1
fi

export TMUX_BEADS_SESSION
export TMUX_BEADS_WINDOW
export TMUX_BEADS_WINDOW_NAME
export TMUX_BEADS_PANE_ID
export TMUX_BEADS_TARGET
export TMUX_BEADS_MANAGER_TARGET
