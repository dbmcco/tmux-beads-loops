#!/usr/bin/env bash
# ABOUTME: Run a spawned agent command with tmux-beads-loops bootstrap and exit notification.
# ABOUTME: Ensures Codex/Claude/OpenCode workers all share the same session-start and stop path.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-run.sh --kind <name> --shell <path> --shell-flags <flags> --command <command>
EOF
}

kind=""
shell_bin="${SHELL:-/bin/zsh}"
shell_flags="-lic"
command=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --kind)
      kind="$2"
      shift 2
      ;;
    --shell)
      shell_bin="$2"
      shift 2
      ;;
    --shell-flags)
      shell_flags="$2"
      shift 2
      ;;
    --command)
      command="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "tmux-beads-loops: unknown option for agent-run.sh: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$command" ]; then
  usage
  exit 1
fi

script_path="${BASH_SOURCE[0]:-$0}"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
export TMUX_BEADS_LOOPS_ROOT="${TMUX_BEADS_LOOPS_ROOT:-$script_dir}"
export TMUX_BEADS_AGENT_KIND="${TMUX_BEADS_AGENT_KIND:-${kind:-agent}}"

if [ -f "${script_dir}/session-start.sh" ]; then
  # shellcheck source=/dev/null
  source "${script_dir}/session-start.sh"
fi

cleanup() {
  if [ -x "${script_dir}/stop.sh" ]; then
    "${script_dir}/stop.sh" || true
  fi
}

trap cleanup EXIT

"$shell_bin" "$shell_flags" "$command"
