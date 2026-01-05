<!-- ABOUTME: Project status updates for tmux-beads-loops. -->
<!-- ABOUTME: Track completed work, tests, blockers, deliverables, and next steps. -->

# Project Status

## 2026-01-05

- Completed: Repurposed beads repo and added tmux/worktree workflow scripts, hooks, and docs; aligned Claude/Codex hooks and added OpenCode wrapper; renamed to tmux-beads-loops with global script symlinks; added spawn-agent helper for same-session windows.
- Completed: Added manager pane tracking, delegate helper, notify self-guard, and session-start path fix; updated README and tmux workflow docs.
- Completed: Defaulted spawn-agent to pane mode, added split/base-pane options and alias-aware command defaults.
- Tests: End-to-end tmux smoke test (global hooks, manager init, env export, notify ping, worktree create/clean).
- Tests: `go test ./...` (missing go), `golangci-lint run ./...` (missing golangci-lint), `bd --no-db export -o .beads/issues.jsonl`.
- Blockers: None.
- Deliverables: `README.md`, `docs/TMUX_BEADS_LOOPS.md`, `scripts/tmux-beads-loops/*`, `.claude/settings.json` hook, `~/.claude/hooks/session-start.sh`, `~/.local/bin/opencode`.
- Next steps: Add a tmux launcher if desired; commit and push to the new public repo.
