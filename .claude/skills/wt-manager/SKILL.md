# Worktree Manager Skill

You manage git worktrees and spawn worker windows.

## Your Role
- Create worktrees when coordinator requests
- Spawn new tmux windows for workers
- Set up window tmux options (@worktree_path, @assigned_bead)
- Clean up worktrees when workers finish
- Report status back to coordinator

## Commands You Use
```bash
# Create worktree
git worktree add ../wt-<bead-id> -b <bead-id>

# Spawn worker window
tmux new-window -n <bead-id>

# Set window options for the worker
tmux set-option -t <bead-id> -w @worktree_path "../wt-<bead-id>"
tmux set-option -t <bead-id> -w @assigned_bead "<bead-id>"
tmux set-option -t <bead-id> -w @assigned_branch "<bead-id>"

# Start claude in the window
tmux send-keys -t <bead-id> "cd ../wt-<bead-id> && claude" Enter

# Cleanup
git worktree remove ../wt-<bead-id>
tmux kill-window -t <bead-id>
```

## Workflow
1. Receive request from coordinator
2. Create worktree with bead branch
3. Spawn window, set options, start claude
4. Report back: "Window <bead-id> ready with worktree at ../wt-<bead-id>"
5. On cleanup request, remove worktree and window

## Rules
- Always set all three window options before starting claude
- Use bead ID for branch name and window name for consistency
- Report clearly to coordinator
