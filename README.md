# tmux-beads-loops

Credit: This project is a fork of Beads by Steve Yegge (https://github.com/steveyegge/beads).

tmux-beads-loops is a tmux-first orchestration layer on top of Beads for multi-agent coding loops.

## Purpose

Coordinate multiple coding agents in tmux panes with a shared task graph and isolated git worktrees.

## What It Does

- Registers a manager pane, exports tmux-aware env vars, and routes worker notifications back to the manager.
- Creates and cleans per-agent worktrees with predictable branch naming.
- Bootstraps Claude, Codex, and OpenCode sessions to share the same hook behavior.

## Loop Flow

1) Start a single tmux agent in a manager window.
2) Use that agent to define steps and decide which additional agents to spawn.
3) Spawn new windows for Claude/Codex/OpenCode in the same tmux session.
4) Workers claim tasks in Beads and notify the manager via tmux.

Note: If you use `clauded`/`codexd` aliases, ensure they point to the CLI you expect.

Suggested command (same session):

```bash
scripts/tmux-beads-loops/spawn-agent.sh claude
```

## How It Works

- Uses tmux global options (like `@beads_manager`) to track the manager window.
- Uses per-agent git worktrees and disables the beads daemon for safety (`BEADS_NO_DAEMON=1`).
- Tracks tasks with the `bd` CLI, optionally on a dedicated metadata branch.

## Works With

tmux, git worktrees, Beads (`bd`), Claude CLI, Codex CLI, and OpenCode (via wrapper).

## Value

Durable task coordination, fewer context handoff mistakes, and a predictable manager/worker loop.

## Status

Beta at best. Scripts and hooks may change; review before use and avoid critical production workflows.

## Docs

See `docs/TMUX_BEADS_LOOPS.md` for the tmux workflow, hooks, and scripts.

Below is the upstream Beads README for reference.

# bd - Beads

**Distributed, git-backed graph issue tracker for AI agents.**

[![License](https://img.shields.io/github/license/steveyegge/beads)](LICENSE)
[![Go Report Card](https://goreportcard.com/badge/github.com/steveyegge/beads)](https://goreportcard.com/report/github.com/steveyegge/beads)
[![Release](https://img.shields.io/github/v/release/steveyegge/beads)](https://github.com/steveyegge/beads/releases)
[![npm version](https://img.shields.io/npm/v/@beads/bd)](https://www.npmjs.com/package/@beads/bd)
[![PyPI](https://img.shields.io/pypi/v/beads-mcp)](https://pypi.org/project/beads-mcp/)

Beads provides a persistent, structured memory for coding agents. It replaces messy markdown plans with a dependency-aware graph, allowing agents to handle long-horizon tasks without losing context.

## ⚡ Quick Start

```bash
# Install (macOS/Linux)
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Initialize (Humans run this once)
bd init

# Tell your agent
echo "Use 'bd' for task tracking" >> AGENTS.md

```

## 🛠 Features

* **Git as Database:** Issues stored as JSONL in `.beads/`. Versioned, branched, and merged like code.
* **Agent-Optimized:** JSON output, dependency tracking, and auto-ready task detection.
* **Zero Conflict:** Hash-based IDs (`bd-a1b2`) prevent merge collisions in multi-agent/multi-branch workflows.
* **Invisible Infrastructure:** SQLite local cache for speed; background daemon for auto-sync.
* **Compaction:** Semantic "memory decay" summarizes old closed tasks to save context window.

## 📖 Essential Commands

| Command | Action |
| --- | --- |
| `bd ready` | List tasks with no open blockers. |
| `bd create "Title" -p 0` | Create a P0 task. |
| `bd dep add <child> <parent>` | Link tasks (blocks, related, parent-child). |
| `bd show <id>` | View task details and audit trail. |

## 🔗 Hierarchy & Workflow

Beads supports hierarchical IDs for epics:

* `bd-a3f8` (Epic)
* `bd-a3f8.1` (Task)
* `bd-a3f8.1.1` (Sub-task)

**Stealth Mode:** Run `bd init --stealth` to use Beads locally without committing files to the main repo. Perfect for personal use on shared projects.

## 📦 Installation

* **npm:** `npm install -g @beads/bd`
* **Homebrew:** `brew install steveyegge/beads/bd`
* **Go:** `go install github.com/steveyegge/beads/cmd/bd@latest`

**Requirements:** Linux (glibc 2.32+), macOS, or Windows.

## 🌐 Community Tools

See [docs/COMMUNITY_TOOLS.md](docs/COMMUNITY_TOOLS.md) for a curated list of community-built UIs, extensions, and integrations—including terminal interfaces, web UIs, editor extensions, and native apps.

## 📝 Documentation

* [Installing](docs/INSTALLING.md) | [Agent Workflow](AGENT_INSTRUCTIONS.md) | [Sync Branch Mode](docs/PROTECTED_BRANCHES.md) | [Troubleshooting](docs/TROUBLESHOOTING.md) | [FAQ](docs/FAQ.md)
* [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/steveyegge/beads)
