#!/usr/bin/env bash
# ABOUTME: Create an agent worktree and branch under .worktrees/.
# ABOUTME: Handles safe defaults for base branch and branch reuse.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: worktree-create.sh <name> [--base <branch>] [--path <dir>] [--branch-prefix <prefix>]

Examples:
  worktree-create.sh agent-1
  worktree-create.sh lfw-2 --base main
  worktree-create.sh pane-4 --path /tmp/pane-4 --branch-prefix agent
EOF
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

name="$1"
shift

base_branch=""
worktree_dir=""
branch_prefix="agent"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      base_branch="$2"
      shift 2
      ;;
    --path)
      worktree_dir="$2"
      shift 2
      ;;
    --branch-prefix)
      branch_prefix="$2"
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

repo_root="$(git rev-parse --show-toplevel)"

default_base_branch() {
  if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
    echo "main"
    return
  fi
  if git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
    echo "master"
    return
  fi
  if git -C "$repo_root" show-ref --verify --quiet refs/remotes/origin/HEAD; then
    git -C "$repo_root" symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@'
    return
  fi
  echo "main"
}

if [ -z "$worktree_dir" ]; then
  worktree_dir="${repo_root}/.worktrees/${name}"
fi

if [ -z "$base_branch" ]; then
  base_branch="$(default_base_branch)"
fi

branch="${branch_prefix}/${name}"

mkdir -p "$(dirname "$worktree_dir")"

if [ -e "$worktree_dir" ]; then
  echo "tmux-beads: worktree path already exists: $worktree_dir" >&2
  exit 1
fi

if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}"; then
  git -C "$repo_root" worktree add "$worktree_dir" "$branch"
else
  git -C "$repo_root" worktree add -b "$branch" "$worktree_dir" "$base_branch"
fi

echo "tmux-beads: worktree ready at $worktree_dir (branch $branch, base $base_branch)"
