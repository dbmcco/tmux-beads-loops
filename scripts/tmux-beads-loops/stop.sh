#!/usr/bin/env bash
# ABOUTME: Notify the tmux-beads-loops manager pane when a worker session exits.
# ABOUTME: Wakes the coordinator with bead/worktree context and clears stale pane state.

set -uo pipefail

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

script_path="${BASH_SOURCE[0]:-$0}"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"

if [ -z "${TMUX_BEADS_LOOPS_ROOT:-}" ]; then
  export TMUX_BEADS_LOOPS_ROOT="$script_dir"
fi

if [ -f "${script_dir}/env.sh" ]; then
  # shellcheck source=/dev/null
  source "${script_dir}/env.sh" 2>/dev/null || true
fi

current_pane_id="${TMUX_BEADS_PANE_ID:-$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)}"
manager_pane_id="${TMUX_BEADS_MANAGER_PANE_ID:-$(tmux show -gqv @beads_manager_pane 2>/dev/null || true)}"

if [ -n "$manager_pane_id" ] && [ -n "$current_pane_id" ] && [ "$current_pane_id" = "$manager_pane_id" ]; then
  exit 0
fi

role="${TMUX_BEADS_ROLE:-${CLAUDE_ROLE:-}}"
if [ -z "$role" ]; then
  role="$(tmux show -gqv @claude_role 2>/dev/null || true)"
fi

if [ -z "$role" ] || [ "$role" = "unknown" ] || [ "$role" = "coordinator" ]; then
  if [ -n "$manager_pane_id" ] && [ -n "$current_pane_id" ] && [ "$current_pane_id" = "$manager_pane_id" ]; then
    role="manager"
  else
    role="worker"
  fi
fi

case "$role" in
  worker|wt-manager)
    ;;
  *)
    exit 0
    ;;
esac

assigned_bead="${TMUX_BEADS_ASSIGNED_BEAD:-${ASSIGNED_BEAD:-}}"
if [ -z "$assigned_bead" ]; then
  assigned_bead="$(tmux show -qv @assigned_bead 2>/dev/null || true)"
fi
if [ -z "$assigned_bead" ] && [ -n "${TMUX_PANE:-}" ]; then
  assigned_bead="$(tmux show-options -pqv -t "${TMUX_PANE}" @assigned_bead 2>/dev/null || true)"
fi
if [ -z "$assigned_bead" ]; then
  assigned_bead="none"
fi

worktree_path="${TMUX_BEADS_WORKTREE_PATH:-${WORKTREE_PATH:-}}"
if [ -z "$worktree_path" ]; then
  worktree_path="$(tmux show -qv @worktree_path 2>/dev/null || true)"
fi
if [ -z "$worktree_path" ] && [ -n "${TMUX_PANE:-}" ]; then
  worktree_path="$(tmux show-options -pqv -t "${TMUX_PANE}" @worktree_path 2>/dev/null || true)"
fi
if [ -z "$worktree_path" ]; then
  worktree_path="$(pwd 2>/dev/null || true)"
fi
if [ -z "$worktree_path" ]; then
  worktree_path="unknown"
fi

pane_target="${TMUX_BEADS_PANE_TARGET:-$(tmux display-message -p '#S:#I.#P' 2>/dev/null || true)}"
if [ -z "$pane_target" ]; then
  pane_target="${current_pane_id:-unknown}"
fi

agent_kind="${TMUX_BEADS_AGENT_KIND:-agent}"
message="Sub-agent finished. Resume orchestration now. Role: ${role}. Agent: ${agent_kind}. Pane: ${pane_target}. Bead: ${assigned_bead}. Worktree: ${worktree_path}. Review that pane's output, update task state, and delegate the next step."

tmux set -pt "${TMUX_PANE:-}" @assigned_bead "" 2>/dev/null || tmux set @assigned_bead "" 2>/dev/null || true
tmux set -pt "${TMUX_PANE:-}" @worktree_path "" 2>/dev/null || tmux set @worktree_path "" 2>/dev/null || true

if [ -x "${script_dir}/notify.sh" ]; then
  "${script_dir}/notify.sh" "$message" 2>/dev/null || true
fi

exit 0
