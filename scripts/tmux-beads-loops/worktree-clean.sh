#!/usr/bin/env bash
# ABOUTME: Remove an agent worktree with safety checks.
# ABOUTME: Optionally deletes the associated agent branch after cleanup.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: worktree-clean.sh <name> [--path <dir>] [--branch-prefix <prefix>] [--force] [--delete-branch]

Examples:
  worktree-clean.sh agent-1
  worktree-clean.sh lfw-2 --force
  worktree-clean.sh pane-4 --delete-branch
EOF
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

name="$1"
shift

worktree_dir=""
branch_prefix="agent"
force_remove=0
delete_branch=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      worktree_dir="$2"
      shift 2
      ;;
    --branch-prefix)
      branch_prefix="$2"
      shift 2
      ;;
    --force)
      force_remove=1
      shift 1
      ;;
    --delete-branch)
      delete_branch=1
      shift 1
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

repo_root="$(git rev-parse --show-toplevel)"

if [ -z "$worktree_dir" ]; then
  worktree_dir="${repo_root}/.worktrees/${name}"
fi

branch="${branch_prefix}/${name}"

if [ ! -d "$worktree_dir" ]; then
  echo "tmux-beads-loops: worktree not found: $worktree_dir" >&2
  exit 1
fi

dirty_status="$(git -C "$worktree_dir" status --porcelain)"
if [ -n "$dirty_status" ] && [ "$force_remove" -ne 1 ]; then
  echo "tmux-beads-loops: worktree has uncommitted changes. Use --force to remove anyway." >&2
  exit 1
fi

if [ "$force_remove" -eq 1 ]; then
  git -C "$repo_root" worktree remove --force "$worktree_dir"
else
  git -C "$repo_root" worktree remove "$worktree_dir"
fi

if [ "$delete_branch" -eq 1 ] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}"; then
  git -C "$repo_root" branch -D "$branch"
fi

git -C "$repo_root" worktree prune

echo "tmux-beads-loops: removed $worktree_dir"
