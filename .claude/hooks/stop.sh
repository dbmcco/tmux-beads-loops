#!/bin/bash
# ABOUTME: Claude Code stop hook for tmux-beads-loops multi-agent orchestration.
# ABOUTME: On session end, if worker has assigned bead, notify coordinator.
#
# Sends: tmux send-keys -t coordinator "Worker stopping, was on $BEAD" Enter
# Silent for non-workers or workers without assigned beads.

# Don't use set -e - we want graceful failure

# Exit cleanly if not running inside tmux
if [ -z "${TMUX:-}" ]; then
    exit 0
fi

# Get role from tmux (or env fallback)
get_role() {
    # First check environment variable (faster)
    if [ -n "${CLAUDE_ROLE:-}" ]; then
        echo "$CLAUDE_ROLE"
        return
    fi

    # Then check tmux option
    local role
    role="$(tmux show -gqv "@claude_role" 2>/dev/null || true)"
    if [ -n "$role" ]; then
        echo "$role"
        return
    fi

    # Fallback: detect from window name
    local window_name
    local target="${TMUX_PANE:-}"
    if [ -n "$target" ]; then
        window_name="$(tmux display-message -p -t "$target" '#W' 2>/dev/null || true)"
    else
        window_name="$(tmux display-message -p '#W' 2>/dev/null || true)"
    fi

    case "$window_name" in
        coordinator) echo "coordinator" ;;
        wt-manager) echo "wt-manager" ;;
        beads-*|wt-*) echo "worker" ;;
        *) echo "unknown" ;;
    esac
}

# Get assigned bead from tmux option
get_assigned_bead() {
    # First check environment variable
    if [ -n "${ASSIGNED_BEAD:-}" ]; then
        echo "$ASSIGNED_BEAD"
        return
    fi

    # Then check tmux option
    tmux show -gqv "@assigned_bead" 2>/dev/null || true
}

# Get coordinator target (window name to send notification to)
get_coordinator_target() {
    # First check if explicitly set
    local target
    target="$(tmux show -gqv "@coordinator_target" 2>/dev/null || true)"
    if [ -n "$target" ]; then
        echo "$target"
        return
    fi

    # Default to "coordinator" window name
    echo "coordinator"
}

role="$(get_role)"

# Only notify for workers
if [ "$role" != "worker" ]; then
    exit 0
fi

# Get assigned bead
bead="$(get_assigned_bead)"

# If no bead assigned, exit silently
if [ -z "$bead" ]; then
    exit 0
fi

# Get coordinator target
coordinator="$(get_coordinator_target)"

# Notify coordinator
# Use send-keys with Enter to ensure the message is submitted
tmux send-keys -t "$coordinator" "Worker stopping, was on $bead" Enter 2>/dev/null || true

exit 0
