<!-- ABOUTME: Tmux-based multi-agent workflow using beads and git worktrees. -->
<!-- ABOUTME: Documents manager/agent setup, notifications, and cleanup. -->

# TMUX Beads Loops Workflow

This repo repurposes beads for tmux-coordinated coding agents. Each agent runs in
its own git worktree and uses beads as the shared task graph. The manager can be
any tmux window; the manager window registers itself and workers discover it.

## One-Time Setup

1) Initialize beads metadata on a dedicated branch:

```bash
bd init --branch beads-metadata
```

2) For worktrees, disable the beads daemon (shared DB + daemon can cross-commit):

```bash
export BEADS_NO_DAEMON=1
```

3) Install global scripts (for all repos):

```bash
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ]; then
  ln -s "$repo_root/scripts/tmux-beads-loops" "$HOME/.local/share/tmux-beads-loops"
fi
```

Optional PATH helpers:

```bash
for script in bootstrap delegate env manager-init notify session-start spawn-agent worktree-create worktree-clean; do
  ln -sf "$HOME/.local/share/tmux-beads-loops/${script}.sh" "$HOME/.local/bin/tmux-beads-loops-${script}"
done
```

4) Claude hook (wired in `.claude/settings.json`):

```bash
~/.claude/hooks/session-start.sh
```

5) Codex hook (ensure your `~/.codex/hooks/session-start.sh` sources the global hook):

```bash
global_hook="$HOME/.local/share/tmux-beads-loops/session-start.sh"
if [ -f "$global_hook" ]; then
  source "$global_hook"
fi
```

6) OpenCode wrapper (auto-runs the same session-start hooks):

```bash
~/.local/bin/opencode
```

This wrapper sources `~/.claude/hooks/session-start.sh` (or the Codex hook
fallback) and then runs the real binary at `~/.opencode/bin/opencode`. Override
with `OPENCODE_REAL_BINARY` if needed.

## Manager Initialization (Any Window)

Run this in the manager window (HM0). It records the current session+window+pane
as the manager target:

```bash
scripts/tmux-beads-loops/manager-init.sh
```

If you want the first pane to auto-claim manager, keep the default
`TMUX_BEADS_AUTO_MANAGER=1`. Set `TMUX_BEADS_AUTO_MANAGER=0` to disable
auto-registration and require explicit `manager-init.sh`.

Verify the manager target and pane:

```bash
tmux show -gqv @beads_manager
tmux show -gqv @beads_manager_pane
```

## Bootstrap Agents (Same Window)

Bootstrap spawns balanced Claude/Codex panes in the manager window:

```bash
scripts/tmux-beads-loops/bootstrap.sh --total 4
```

Auto-bootstrap via hooks (set before starting codexd/clauded):

```bash
TMUX_BEADS_BOOTSTRAP_TOTAL=4 \
TMUX_BEADS_CLAUDE_CMD=clauded TMUX_BEADS_CODEX_CMD=codexd \
codexd
```

Note: tmux panes require splits, but this keeps everything in the same window (no new windows).

## Create Worktrees Per Agent

```bash
scripts/tmux-beads-loops/worktree-create.sh agent-1
scripts/tmux-beads-loops/worktree-create.sh agent-2 --base main
```

Each worktree lands in `.worktrees/<name>` and uses `agent/<name>` as the branch
name by default.

## Agent Startup (Per Pane)

1) Enter the worktree:

```bash
cd .worktrees/agent-1
```

2) Bootstrap Codex + tmux/beads env:

```bash
source .codex/hooks/session-start.sh && codex_session_start
source scripts/tmux-beads-loops/env.sh
```

If you use the hooks above, `session-start.sh` runs automatically and you do not
need to source `env.sh` manually.

`env.sh` exports:

- `TMUX_BEADS_SESSION`, `TMUX_BEADS_WINDOW`, `TMUX_BEADS_WINDOW_NAME`
- `TMUX_BEADS_PANE_INDEX`, `TMUX_BEADS_PANE_ID`, `TMUX_BEADS_PANE_TARGET`
- `TMUX_BEADS_TARGET`, `TMUX_BEADS_MANAGER_TARGET`
- `TMUX_BEADS_MANAGER_PANE_ID`, `TMUX_BEADS_MANAGER_PANE_INDEX`, `TMUX_BEADS_MANAGER_PANE_TARGET`
- `BEADS_NO_DAEMON=1` (if not already set)

## Notify the Manager

Send commands back to the manager pane:

```bash
scripts/tmux-beads-loops/notify.sh "bd show bd-123"
scripts/tmux-beads-loops/notify.sh "bd ready"
```

If you run this in the manager pane, it refuses and asks you to use
`delegate.sh` for worker targets.

## Delegate to Workers

Use the delegate helper from the manager pane to send commands to worker panes.
It resolves window names within the manager's tmux session and sends Enter
separately for reliability.

```bash
scripts/tmux-beads-loops/delegate.sh --window claude-1 -- "bd ready"
scripts/tmux-beads-loops/delegate.sh --target hm:3.0 -- "git status"
```

## Spawn Agents in the Same Session

Use the spawn helper to keep new agents in the manager's tmux session. It
defaults to **pane** mode (same window), and supports `--mode window` if you
prefer separate windows:

```bash
scripts/tmux-beads-loops/spawn-agent.sh claude
scripts/tmux-beads-loops/spawn-agent.sh codex --worktree .worktrees/agent-2
scripts/tmux-beads-loops/spawn-agent.sh opencode --name opencode-1
scripts/tmux-beads-loops/spawn-agent.sh claude --split v --name claude-1
scripts/tmux-beads-loops/spawn-agent.sh codex --mode window --name codex-2
```

This reads `@beads_manager` (or the current session) and creates new panes in
that tmux session by default. Pass `--mode window` for new windows, and use
`--cmd` if you do not use `clauded`/`codexd` aliases.

Alias-aware defaults:

```bash
export TMUX_BEADS_CLAUDE_CMD=clauded
export TMUX_BEADS_CODEX_CMD=codexd
export TMUX_BEADS_SHELL_FLAGS=-lic
export TMUX_BEADS_BOOTSTRAP_TOTAL=4
```

## Worktree Cleanup

Safely remove worktrees when agents are done:

```bash
scripts/tmux-beads-loops/worktree-clean.sh agent-1
scripts/tmux-beads-loops/worktree-clean.sh agent-2 --force --delete-branch
```

`--force` removes dirty worktrees, `--delete-branch` removes the agent branch.

## Notes

- Manager window can be any index (example: `LFW:4`). Workers rely on the
  `@beads_manager` tmux option, not window names.
- If `@beads_manager` is not set, re-run `manager-init.sh` in the manager pane.
- If you split panes in the manager window, re-run `manager-init.sh` so the
  manager pane ID stays correct.
- Prefer `bd --no-daemon` when running one-off beads commands in worktrees.
