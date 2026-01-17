#!/bin/bash
# ABOUTME: Claude Code post-commit hook for tmux-beads-loops multi-agent orchestration.
# ABOUTME: After git commit, auto-runs `bd sync --from-main` for workers to pull bead updates.
#
# Claude Code PostToolUse hooks receive JSON via stdin with tool_input.command
# Silent for non-workers (coordinator, wt-manager).

# Don't use set -e - we want graceful failure

# Read JSON from stdin
input="$(cat)"

# Parse command from JSON (requires jq)
if command -v jq &>/dev/null; then
    bash_command="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"

    # Only proceed if this was a git commit
    if ! echo "$bash_command" | grep -q "git commit"; then
        exit 0
    fi
fi

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

role="$(get_role)"

# Only run bd sync for workers
if [ "$role" != "worker" ]; then
    exit 0
fi

# Check if bd command exists
if ! command -v bd &>/dev/null; then
    # Silent exit - bd not available
    exit 0
fi

# Run bd sync --from-main to pull updates from main beads db
# This ensures worker beads stay in sync after commits
bd sync --from-main 2>/dev/null || true

exit 0
