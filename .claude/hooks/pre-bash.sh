#!/bin/bash
# ABOUTME: Claude Code pre-bash hook for tmux-beads-loops multi-agent orchestration.
# ABOUTME: Guards worker agents from escaping worktree, blocks unsafe tmux commands.
#
# Rules enforced:
#   - For workers: block cd outside worktree
#   - For workers: block git checkout to other branches (allow checkout -- files)
#   - For all: block tmux send-keys without trailing "Enter"
#
# Claude Code PreToolUse hooks receive JSON via stdin with tool_input.command
# Exit 0 = allow, Exit 2 = block (with stderr message)

set -uo pipefail

# Read JSON from stdin
input="$(cat)"

# Parse command from JSON (requires jq)
if ! command -v jq &>/dev/null; then
    # No jq, can't parse - allow by default
    exit 0
fi

command="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"

# If no command provided, allow
if [ -z "$command" ]; then
    exit 0
fi

# Get role from tmux (or env fallback)
get_role() {
    if [ -z "${TMUX:-}" ]; then
        echo "unknown"
        return
    fi

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

# Get worktree path from tmux
get_worktree_path() {
    if [ -z "${TMUX:-}" ]; then
        echo ""
        return
    fi

    # First check environment variable
    if [ -n "${WORKTREE_PATH:-}" ]; then
        echo "$WORKTREE_PATH"
        return
    fi

    # Then check tmux option
    tmux show -gqv "@worktree_path" 2>/dev/null || true
}

# Check if command is tmux send-keys without Enter
check_tmux_send_keys() {
    local cmd="$1"

    # Match tmux send-keys without "Enter" at end
    if echo "$cmd" | grep -qE '^tmux\s+send-keys'; then
        # Check if it ends with "Enter" (case insensitive for safety)
        if ! echo "$cmd" | grep -qEi '\s+Enter\s*$'; then
            echo "ERROR: tmux send-keys must end with 'Enter' to complete the command."
            echo "Use: tmux send-keys -t <target> \"<message>\" Enter"
            return 1
        fi
    fi
    return 0
}

# Check if cd command goes outside worktree
check_cd_command() {
    local cmd="$1"
    local worktree="$2"

    # Only check actual cd commands
    if ! echo "$cmd" | grep -qE '^\s*cd\s'; then
        return 0
    fi

    # If no worktree defined, allow all
    if [ -z "$worktree" ]; then
        return 0
    fi

    # Extract the target path from cd command
    local target_path
    target_path="$(echo "$cmd" | sed -E 's/^\s*cd\s+//' | sed -E 's/\s*[;&|].*$//' | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//")"

    # Handle relative paths - if it starts with . or doesn't start with /, it's relative
    if [[ "$target_path" != /* ]]; then
        # Relative paths within worktree are OK
        return 0
    fi

    # Absolute path - check if it's within worktree
    # Normalize paths by removing trailing slashes
    local normalized_worktree="${worktree%/}"
    local normalized_target="${target_path%/}"

    # Check if target starts with worktree path
    if [[ "$normalized_target" == "$normalized_worktree"* ]]; then
        return 0
    fi

    echo "ERROR: Workers cannot cd outside their worktree."
    echo "Worktree: $worktree"
    echo "Blocked path: $target_path"
    return 1
}

# Check if git checkout is trying to switch branches
check_git_checkout() {
    local cmd="$1"

    # Only check git checkout commands
    if ! echo "$cmd" | grep -qE '^\s*git\s+checkout'; then
        return 0
    fi

    # Allow git checkout -- (file checkout)
    if echo "$cmd" | grep -qE '^\s*git\s+checkout\s+(--\s|.*\s--)'; then
        return 0
    fi

    # Allow git checkout with file paths (containing / or .)
    # This is a heuristic - branch names typically don't have / at start or .
    local args
    args="$(echo "$cmd" | sed -E 's/^\s*git\s+checkout\s+//')"

    # If first non-flag arg looks like a file path, allow
    if echo "$args" | grep -qE '^(-[a-zA-Z]+\s+)*[./]'; then
        return 0
    fi

    # Block branch checkout
    echo "ERROR: Workers should not checkout other branches."
    echo "Use 'git checkout -- <file>' to restore files."
    echo "Branch management is handled by the worktree manager."
    return 1
}

# Main logic
role="$(get_role)"

# Rule: tmux send-keys must have Enter (applies to all roles)
if ! check_tmux_send_keys "$command"; then
    exit 2  # Exit 2 = blocking error in Claude Code hooks
fi

# Worker-specific rules
if [ "$role" = "worker" ]; then
    worktree_path="$(get_worktree_path)"

    # Rule: no cd outside worktree
    if ! check_cd_command "$command" "$worktree_path"; then
        exit 2
    fi

    # Rule: no git checkout to other branches
    if ! check_git_checkout "$command"; then
        exit 2
    fi
fi

# Command allowed
exit 0
