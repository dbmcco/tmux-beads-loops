# Orchestrate Skill

Activate tmux multi-agent orchestration mode.

## When User Says
- "lets use tmux and get some work done"
- "orchestrate"
- "start orchestration"
- "multi-agent mode"

## What You Do

### 1. Bootstrap Current Window as Coordinator

```bash
# Rename current window to coordinator
tmux rename-window coordinator

# Register as beads manager
SESSION=$(tmux display-message -p '#S')
WINDOW=$(tmux display-message -p '#I')
PANE=$(tmux display-message -p '#P')
PANE_ID=$(tmux display-message -p '#{pane_id}')

tmux set -g @beads_manager "${SESSION}:${WINDOW}"
tmux set -g @beads_manager_pane "$PANE_ID"
tmux set -g @claude_role "coordinator"
```

### 2. Create Worktree Manager Window (Same Session)

```bash
# Get current session name
SESSION=$(tmux display-message -p '#S')

# Create new window in THIS session
tmux new-window -t "$SESSION" -n wt-manager
tmux send-keys -t "${SESSION}:wt-manager" "claude" Enter
```

### 3. Confirm Setup

Tell user:
- You are now the **coordinator** in window `coordinator`
- Worktree manager is starting in window `wt-manager`
- Use `bd ready` to find work
- Ask wt-manager to create worktrees for beads
- Workers spawn as `beads-*` windows

## Your Role as Coordinator

You manage work via beads and delegate to workers:

1. `bd ready` - find available work
2. Ask wt-manager: "Create a worktree for beads-XXX"
3. Wait for wt-manager to confirm window is ready
4. Send work: `tmux send-keys -t beads-XXX "Work on beads-XXX: <description>" Enter`
5. Wait for worker to report completion
6. `bd sync --from-main` to pull updates
7. Repeat

## Rules
- Never implement code yourself - delegate to workers
- One bead per worker at a time
- Natural language communication via tmux send-keys
- Always end send-keys with `Enter`
