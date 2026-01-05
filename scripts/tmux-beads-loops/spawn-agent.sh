#!/usr/bin/env bash
# ABOUTME: Spawn a new agent window in the manager's tmux session.
# ABOUTME: Uses @beads_manager (or current session) and runs the chosen CLI.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: spawn-agent.sh <claude|codex|opencode|command> [--name <window-name>] [--worktree <path>] [--cmd <command>] [--shell <shell>]

Examples:
  spawn-agent.sh claude
  spawn-agent.sh codex --name codex-2
  spawn-agent.sh opencode --worktree .worktrees/agent-3
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
shell="${SHELL:-/bin/zsh}"

while [ "$#" -gt 0 ]; do
  case "$1" in
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

case "$kind" in
  claude)
    default_cmd="clauded"
    ;;
  codex)
    default_cmd="codexd"
    ;;
  opencode)
    default_cmd="opencode"
    ;;
  *)
    default_cmd="$kind"
    ;;
esac

if [ -z "$command" ]; then
  command="$default_cmd"
fi

manager="${BEADS_MANAGER_TARGET:-$(tmux show -gqv @beads_manager)}"
if [ -n "$manager" ]; then
  session="${manager%%:*}"
else
  session="$(tmux display-message -p '#S')"
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
  tmux new-window -t "$session" -n "$window_name" -c "$worktree" "$shell" -lc "$command"
else
  tmux new-window -t "$session" -n "$window_name" "$shell" -lc "$command"
fi

echo "tmux-beads-loops: spawned ${window_name} in ${session} (${command})"
