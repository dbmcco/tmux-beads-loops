# Hooks Test Suite

Bats tests for tmux-beads-loops multi-agent hooks.

## Prerequisites

Bats is available via npx (included with npm). Alternatively, install bats-core:

```bash
# macOS
brew install bats-core

# Linux (apt)
sudo apt-get install bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Running Tests

```bash
# Run all hook tests (via npx - no install needed)
npx bats tests/hooks/

# Run with verbose output
npx bats --verbose-run tests/hooks/hooks.bats

# Run specific test by name filter
npx bats --filter "session-start" tests/hooks/hooks.bats

# If bats is installed globally
bats tests/hooks/
```

## Test Structure

- `test_helper.bash` - Mock tmux environment and helper functions
- `hooks.bats` - Test cases for all hooks

## Mock Environment

The test helper provides:

### Mock tmux Functions

- `tmux display-message` - Returns mock session/window/pane info
- `tmux show` - Returns mock global/pane options
- `tmux set` - Sets mock options
- `tmux send-keys` - Records sent keys for assertions

### Role Setup Functions

- `setup_coordinator_role` - Configure mock as coordinator/manager
- `setup_wt_manager_role` - Configure mock as worktree manager
- `setup_worker_role [worktree_path]` - Configure mock as worker

### Option Helpers

- `mock_set_global_option <option> <value>`
- `mock_get_global_option <option>`
- `mock_set_pane_option <option> <value>`
- `mock_get_pane_option <option>`

### Assertion Helpers

- `assert_tmux_command_called <pattern>` - Assert tmux was called with pattern
- `assert_tmux_command_not_called <pattern>` - Assert tmux was NOT called
- `count_tmux_commands <pattern>` - Count matching tmux calls

## Test Categories

### Session-Start Hook Tests

- Role detection from window name
- @claude_role option setting
- @beads_manager registration

### Pre-Bash Hook Tests

- cd restriction for workers
- send-keys validation
- Permission elevation for coordinators

### Post-Commit Hook Tests

- bd sync for workers
- Sync skip for non-workers

### Stop Hook Tests

- Coordinator notification on worker stop
- State cleanup

## Writing New Tests

```bash
@test "descriptive test name" {
  # Setup
  setup_worker_role "/tmp/worktree"

  # Action
  # ... test code ...

  # Assert
  [[ "$expected" == "$actual" ]]
}
```

## TDD Workflow

These tests are written in TDD style - they define expected behavior before the hooks are implemented. The tests currently pass because they test the mock infrastructure and document expected hook behavior.

When implementing actual hooks, integrate them with the test harness to verify behavior:

```bash
# Run tests during hook implementation
npx bats tests/hooks/hooks.bats

# Filter to specific hook category
npx bats --filter "pre-bash" tests/hooks/hooks.bats
npx bats --filter "post-commit" tests/hooks/hooks.bats
npx bats --filter "stop" tests/hooks/hooks.bats
```

## Bash Compatibility

The test helper uses file-based storage for mock state to maintain compatibility with bash 3.2 (macOS default). This avoids associative arrays which require bash 4+.
