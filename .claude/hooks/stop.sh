#!/bin/bash
# ABOUTME: Claude Code stop hook shim for tmux-beads-loops multi-agent orchestration.
# ABOUTME: Delegates session-end wakeups to the shared manager-pane aware stop hook.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../scripts/tmux-beads-loops" && pwd)"

if [ -x "${script_dir}/stop.sh" ]; then
    export TMUX_BEADS_LOOPS_ROOT="${TMUX_BEADS_LOOPS_ROOT:-$script_dir}"
    exec "${script_dir}/stop.sh"
fi

exit 0
