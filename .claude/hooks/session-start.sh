#!/bin/bash
# ABOUTME: Claude Code session-start hook for tmux-beads-loops multi-agent orchestration.
# ABOUTME: Detects agent role from tmux window name, sets tmux options, outputs cwd for workers.
#
# Window name patterns:
#   - "coordinator" -> coordinator role
#   - "wt-manager"  -> worktree manager role
#   - "beads-*"     -> worker role
#   - "wt-*"        -> worker role
#
# For workers: reads @worktree_path and outputs "cwd: <path>" to change working directory.

# Don't use set -e here - we want graceful handling of missing tmux

# Exit cleanly if not running inside tmux
if [ -z "${TMUX:-}" ]; then
    exit 0
fi

# Get window name from tmux
get_window_name() {
    local target="${TMUX_PANE:-}"
    if [ -n "$target" ]; then
        tmux display-message -p -t "$target" '#W' 2>/dev/null
    else
        tmux display-message -p '#W' 2>/dev/null
    fi
}

# Detect role based on window name
detect_role() {
    local window_name="$1"
    case "$window_name" in
        coordinator)
            echo "coordinator"
            ;;
        wt-manager)
            echo "wt-manager"
            ;;
        beads-*|wt-*)
            echo "worker"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get tmux option value
get_tmux_option() {
    local option="$1"
    tmux show -gqv "$option" 2>/dev/null || true
}

# Set tmux option
set_tmux_option() {
    local option="$1"
    local value="$2"
    tmux set -g "$option" "$value" 2>/dev/null || true
}

# Main logic
window_name="$(get_window_name)"
if [ -z "$window_name" ]; then
    exit 0
fi

role="$(detect_role "$window_name")"

# Set the role in tmux options
set_tmux_option "@claude_role" "$role"

# For workers, check for worktree path and output cwd directive
if [ "$role" = "worker" ]; then
    worktree_path="$(get_tmux_option "@worktree_path")"
    if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
        echo "cwd: $worktree_path"
    fi
fi

exit 0
