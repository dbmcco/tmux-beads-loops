# Skills: Tmux Multi-Agent Orchestration

This directory contains Claude Code skills for a three-role multi-agent architecture using tmux.

## Architecture Overview

Three Claude instances communicate via natural language through tmux send-keys:

```
┌─────────────────────────────────────────────────────────────┐
│                      tmux session                           │
├─────────────┬─────────────────────┬─────────────────────────┤
│ coordinator │     wt-manager      │   worker-N (dynamic)    │
│             │                     │                         │
│ - Manages   │ - Creates worktrees │ - Implements tasks      │
│   beads     │ - Spawns windows    │ - Full tool access      │
│ - Assigns   │ - Sets tmux options │ - Reports completion    │
│   work      │ - Cleans up         │ - Waits for assignment  │
└─────────────┴─────────────────────┴─────────────────────────┘
```

## Roles

### coordinator
**Location:** `coordinator/SKILL.md`

The orchestrator. Manages work items (beads), delegates to workers, and tracks overall progress. Never implements code directly.

Key commands:
- `bd create`, `bd ready`, `bd list`, `bd close`
- `tmux send-keys -t <window>` for communication

### wt-manager
**Location:** `wt-manager/SKILL.md`

Infrastructure manager. Creates git worktrees for isolation, spawns tmux windows for workers, sets window options, and handles cleanup.

Key commands:
- `git worktree add/remove`
- `tmux new-window`, `tmux set-option`, `tmux kill-window`

### worker
**Location:** `worker/SKILL.md`

Implementation agent. Receives assignments, implements tasks with full tool access, closes beads when done, and notifies coordinator.

Key commands:
- `bd show`, `bd close`
- All standard Claude tools for implementation

## Communication Flow

1. **coordinator** finds work: `bd ready`
2. **coordinator** requests worktree from **wt-manager**
3. **wt-manager** creates worktree, spawns window, reports ready
4. **coordinator** sends assignment to **worker** window
5. **worker** implements, closes bead, notifies **coordinator**
6. **coordinator** syncs changes, assigns next task or idles worker

## Key Principles

- **Natural language communication** via tmux - no special protocols
- **Workers wait** for assignments - they don't self-assign
- **Completion signals** require both `bd close` AND notifying coordinator
- **One bead per worker** at a time for isolation
- **Worktree isolation** ensures workers don't interfere with each other
