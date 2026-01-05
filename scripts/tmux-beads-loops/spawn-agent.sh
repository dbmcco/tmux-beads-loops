#!/usr/bin/env bash
# ABOUTME: Spawn a new agent pane (or window) in the manager's tmux session.
# ABOUTME: Uses @beads_manager (or current session) and runs the chosen CLI.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: spawn-agent.sh <claude|codex|opencode|command> [options]

Options:
  --mode <pane|window>     Spawn a pane (default) or a new window
  --split <h|v>            Pane split direction (default: h)
  --base-pane <index>      Pane index to split from (default: manager or current)
  --name <label>           Window name (window mode) or pane title (pane mode)
  --worktree <path>        Working directory for the new pane/window
  --cmd <command>          Override the command to run
  --shell <shell>          Shell binary (default: $SHELL)
  --shell-flags <flags>    Shell flags (default: -lic)

Examples:
  spawn-agent.sh claude
  spawn-agent.sh codex --mode window --name codex-2
  spawn-agent.sh opencode --worktree .worktrees/agent-3
  spawn-agent.sh claude --split v --name claude-1
  spawn-agent.sh bash --cmd "htop"
EOF
}

if [ -z "${TMUX:-}" ]; then
  echo "tmux-beads-loops: spawn-agent must run inside tmux" >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

kind="$1"
shift

window_name=""
worktree=""
command=""
shell="${TMUX_BEADS_SHELL:-${SHELL:-/bin/zsh}}"
shell_flags="${TMUX_BEADS_SHELL_FLAGS:--lic}"
mode="${TMUX_BEADS_SPAWN_MODE:-pane}"
split="${TMUX_BEADS_SPAWN_SPLIT:-h}"
base_pane="${TMUX_BEADS_BASE_PANE:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      mode="$2"
      shift 2
      ;;
    --split)
      split="$2"
      shift 2
      ;;
    --base-pane)
      base_pane="$2"
      shift 2
      ;;
    --name)
      window_name="$2"
      shift 2
      ;;
    --worktree)
      worktree="$2"
      shift 2
      ;;
    --cmd)
      command="$2"
      shift 2
      ;;
    --shell)
      shell="$2"
      shift 2
      ;;
    --shell-flags)
      shell_flags="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

explicit_cmd=""
primary_cmd=""
fallback_cmd=""
case "$kind" in
  claude)
    explicit_cmd="${TMUX_BEADS_CLAUDE_CMD:-}"
    primary_cmd="clauded"
    fallback_cmd="claude"
    ;;
  codex)
    explicit_cmd="${TMUX_BEADS_CODEX_CMD:-}"
    primary_cmd="codexd"
    fallback_cmd="codex"
    ;;
  opencode)
    explicit_cmd="${TMUX_BEADS_OPENCODE_CMD:-}"
    primary_cmd="opencode"
    ;;
  *)
    primary_cmd="$kind"
    ;;
esac

if [ -z "$command" ]; then
  if [ -n "$explicit_cmd" ]; then
    command="$explicit_cmd"
  elif [ -n "$fallback_cmd" ]; then
    command="if command -v $primary_cmd >/dev/null 2>&1; then $primary_cmd; else $fallback_cmd; fi"
  else
    command="$primary_cmd"
  fi
fi

manager="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
if [ -n "$manager" ]; then
  session="${manager%%:*}"
  window="${manager##*:}"
else
  session="$(tmux display-message -p '#S')"
  window="$(tmux display-message -p '#I')"
fi

case "$mode" in
  pane|window)
    ;;
  *)
    echo "tmux-beads-loops: invalid --mode (use pane|window): $mode" >&2
    exit 1
    ;;
esac

if [ "$mode" = "pane" ]; then
  case "$split" in
    h|horizontal)
      split_flag="-h"
      ;;
    v|vertical)
      split_flag="-v"
      ;;
    *)
      echo "tmux-beads-loops: invalid --split (use h|v): $split" >&2
      exit 1
      ;;
  esac

  if [ -z "$base_pane" ]; then
    base_pane="$(tmux show -gqv @beads_manager_pane_index)"
    if [ -z "$base_pane" ]; then
      base_pane="$(tmux display-message -p '#P')"
    fi
  fi

  target="${session}:${window}.${base_pane}"
  if [ -n "$worktree" ]; then
    new_pane_id="$(tmux split-window $split_flag -t "$target" -c "$worktree" -P -F '#{pane_id}' "$shell" "$shell_flags" "$command")"
  else
    new_pane_id="$(tmux split-window $split_flag -t "$target" -P -F '#{pane_id}' "$shell" "$shell_flags" "$command")"
  fi

  if [ -n "$window_name" ]; then
    tmux select-pane -t "$new_pane_id" -T "$window_name"
  fi

  new_pane_index="$(tmux display-message -p -t "$new_pane_id" '#P')"
  echo "tmux-beads-loops: spawned pane ${new_pane_index} in ${session}:${window} (${command})"
  exit 0
fi

if [ -z "$window_name" ]; then
  base="$kind"
  if [ "$base" != "claude" ] && [ "$base" != "codex" ] && [ "$base" != "opencode" ]; then
    base="agent"
  fi
  existing="$(tmux list-windows -t "$session" -F '#W')"
  idx=1
  while echo "$existing" | grep -Fxq "${base}-${idx}"; do
    idx=$((idx + 1))
  done
  window_name="${base}-${idx}"
fi

if [ -n "$worktree" ]; then
  tmux new-window -t "$session" -n "$window_name" -c "$worktree" "$shell" "$shell_flags" "$command"
else
  tmux new-window -t "$session" -n "$window_name" "$shell" "$shell_flags" "$command"
fi

echo "tmux-beads-loops: spawned ${window_name} in ${session} (${command})"
