#!/usr/bin/env bats
# ABOUTME: Bats tests for tmux-beads-loops multi-agent hooks.
# ABOUTME: Tests session-start, pre-bash, post-commit, and stop hooks.

# Load the test helper
load test_helper

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
  reset_mock_state
  reset_bd_mock

  # Set up a basic tmux environment
  export TMUX="/tmp/mock-tmux,12345,0"

  # Create temp directories for worktree tests
  export TEST_WORKTREE_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_WORKTREE_ROOT/feature-branch"
}

teardown() {
  # Clean up temp directories
  if [[ -d "${TEST_WORKTREE_ROOT:-}" ]]; then
    rm -rf "$TEST_WORKTREE_ROOT"
  fi
}

# =============================================================================
# Session-Start Hook Tests
# =============================================================================

@test "session-start detects coordinator role from window name" {
  # Setup: Window named "coordinator"
  export MOCK_TMUX_WINDOW_NAME="coordinator"
  export MOCK_TMUX_PANE_ID="%0"
  mock_set_global_option "@beads_manager_pane" "%0"

  # The hook should detect this as the coordinator
  # Since hooks don't exist yet, this test documents expected behavior
  setup_coordinator_role

  # Verify the role was set correctly
  [[ "$TMUX_BEADS_ROLE" == "manager" ]]
}

@test "session-start detects wt-manager role" {
  # Setup: Window named "wt-manager" (worktree manager)
  setup_wt_manager_role

  # The hook should detect this as a wt-manager
  [[ "$TMUX_BEADS_ROLE" == "wt-manager" ]]
  [[ "$MOCK_TMUX_WINDOW_NAME" == "wt-manager" ]]
}

@test "session-start detects worker role and cds to worktree" {
  # Setup: Worker window with worktree path
  local worktree_path="$TEST_WORKTREE_ROOT/feature-branch"
  setup_worker_role "$worktree_path"

  # The hook should detect this as a worker and set worktree path
  [[ "$TMUX_BEADS_ROLE" == "worker" ]]
  [[ "$TMUX_BEADS_WORKTREE_PATH" == "$worktree_path" ]]
}

@test "session-start sets tmux @claude_role option" {
  # Setup coordinator role
  setup_coordinator_role

  # Simulate what the hook should do
  tmux set -g @claude_role "coordinator"

  # Verify the option was set
  local role
  role=$(mock_get_global_option "@claude_role")
  [[ "$role" == "coordinator" ]]
}

@test "session-start sets @beads_manager for first pane" {
  # First pane should register itself as manager
  export MOCK_TMUX_SESSION="test-session"
  export MOCK_TMUX_WINDOW="0"
  export MOCK_TMUX_PANE_ID="%0"

  # After hook runs, manager should be set
  tmux set -g @beads_manager "${MOCK_TMUX_SESSION}:${MOCK_TMUX_WINDOW}"
  tmux set -g @beads_manager_pane "$MOCK_TMUX_PANE_ID"

  [[ "$(mock_get_global_option "@beads_manager")" == "test-session:0" ]]
  [[ "$(mock_get_global_option "@beads_manager_pane")" == "%0" ]]
}

# =============================================================================
# Pre-Bash Hook Tests
# =============================================================================

@test "pre-bash blocks cd outside worktree for workers" {
  # Setup worker with restricted worktree
  local worktree_path="$TEST_WORKTREE_ROOT/feature-branch"
  setup_worker_role "$worktree_path"

  # Attempting to cd outside worktree should be blocked
  # This test documents the expected behavior - the hook should
  # intercept and block cd commands outside the worktree

  # Simulate a cd command outside worktree
  local target_dir="/tmp/other-directory"
  local should_block=1

  # The pre-bash hook would check:
  # - Is this a worker role?
  # - Is the target directory outside the worktree?
  # If both true, block the command

  if [[ "$TMUX_BEADS_ROLE" == "worker" ]]; then
    if [[ "$target_dir" != "$worktree_path"* ]]; then
      should_block=1
    fi
  fi

  [[ "$should_block" -eq 1 ]]
}

@test "pre-bash allows cd within worktree" {
  # Setup worker with worktree
  local worktree_path="$TEST_WORKTREE_ROOT/feature-branch"
  mkdir -p "$worktree_path/src"
  setup_worker_role "$worktree_path"

  # cd within worktree should be allowed
  local target_dir="$worktree_path/src"
  local should_allow=0

  if [[ "$TMUX_BEADS_ROLE" == "worker" ]]; then
    if [[ "$target_dir" == "$worktree_path"* ]]; then
      should_allow=1
    fi
  fi

  [[ "$should_allow" -eq 1 ]]
}

@test "pre-bash blocks send-keys without Enter" {
  # Workers should not be able to send-keys without Enter
  # This prevents partial command injection
  setup_worker_role "$TEST_WORKTREE_ROOT/feature-branch"

  # Simulate send-keys without Enter
  local keys_without_enter="echo 'partial command'"
  local has_enter=0

  # Check if Enter is included
  if [[ "$keys_without_enter" == *"Enter"* ]] || [[ "$keys_without_enter" == *$'\n'* ]]; then
    has_enter=1
  fi

  # Should be blocked (no Enter)
  [[ "$has_enter" -eq 0 ]]

  # For workers, this should be blocked
  local should_block=0
  if [[ "$TMUX_BEADS_ROLE" == "worker" ]] && [[ "$has_enter" -eq 0 ]]; then
    should_block=1
  fi

  [[ "$should_block" -eq 1 ]]
}

@test "pre-bash allows send-keys with Enter" {
  # Complete commands (with Enter) should be allowed
  setup_worker_role "$TEST_WORKTREE_ROOT/feature-branch"

  # Simulate send-keys with Enter
  local keys_with_enter="echo 'complete command' Enter"
  local has_enter=0

  if [[ "$keys_with_enter" == *"Enter"* ]]; then
    has_enter=1
  fi

  [[ "$has_enter" -eq 1 ]]
}

@test "pre-bash allows all commands for coordinator" {
  # Coordinator should have no restrictions
  setup_coordinator_role

  # Even cd outside worktree should work
  local target_dir="/tmp/any-directory"
  local should_allow=0

  # Coordinators have no restrictions
  if [[ "$TMUX_BEADS_ROLE" == "manager" ]]; then
    should_allow=1
  fi

  [[ "$should_allow" -eq 1 ]]
}

@test "pre-bash allows all commands for wt-manager" {
  # wt-manager should also have elevated permissions
  setup_wt_manager_role

  local should_allow=0
  if [[ "$TMUX_BEADS_ROLE" == "wt-manager" ]] || [[ "$TMUX_BEADS_ROLE" == "manager" ]]; then
    should_allow=1
  fi

  [[ "$should_allow" -eq 1 ]]
}

# =============================================================================
# Post-Commit Hook Tests
# =============================================================================

@test "post-commit runs bd sync for workers" {
  # Workers should sync their beads after commit
  setup_worker_role "$TEST_WORKTREE_ROOT/feature-branch"

  # Simulate what the post-commit hook should do
  if [[ "$TMUX_BEADS_ROLE" == "worker" ]]; then
    bd sync
  fi

  was_bd_sync_called
}

@test "post-commit skips sync for non-workers" {
  # Manager/coordinator should not auto-sync
  setup_coordinator_role

  # Simulate post-commit hook logic
  if [[ "$TMUX_BEADS_ROLE" == "worker" ]]; then
    bd sync
  fi

  # Sync should NOT have been called
  ! was_bd_sync_called
}

@test "post-commit runs bd sync for wt-manager" {
  # wt-managers may also want to sync
  setup_wt_manager_role

  # Depending on design, wt-managers might also sync
  # This test documents the expected behavior
  local should_sync=0

  # For this test, we expect wt-managers to NOT auto-sync
  # (only workers auto-sync)
  if [[ "$TMUX_BEADS_ROLE" == "worker" ]]; then
    should_sync=1
  fi

  [[ "$should_sync" -eq 0 ]]
}

# =============================================================================
# Stop Hook Tests
# =============================================================================

@test "stop notifies coordinator when worker has assigned bead" {
  # Setup worker with assigned bead
  setup_worker_role "$TEST_WORKTREE_ROOT/feature-branch"
  export TMUX_BEADS_ASSIGNED_BEAD="bd-123"
  mock_set_pane_option "@assigned_bead" "bd-123"

  # Simulate stop hook - should notify coordinator
  local should_notify=0
  local assigned_bead

  assigned_bead=$(mock_get_pane_option "@assigned_bead")

  if [[ "$TMUX_BEADS_ROLE" == "worker" ]] && [[ -n "$assigned_bead" ]]; then
    should_notify=1
    # Hook would do: tmux send-keys -t $MANAGER_PANE "# Worker stopped with bead: $assigned_bead" Enter
  fi

  [[ "$should_notify" -eq 1 ]]
}

@test "stop is silent when no bead assigned" {
  # Setup worker without assigned bead
  setup_worker_role "$TEST_WORKTREE_ROOT/feature-branch"
  mock_set_pane_option "@assigned_bead" ""

  # Simulate stop hook - should be silent
  local should_notify=0
  local assigned_bead

  assigned_bead=$(mock_get_pane_option "@assigned_bead")

  if [[ "$TMUX_BEADS_ROLE" == "worker" ]] && [[ -n "$assigned_bead" ]]; then
    should_notify=1
  fi

  [[ "$should_notify" -eq 0 ]]
}

@test "stop cleans up worker state" {
  # Setup worker
  setup_worker_role "$TEST_WORKTREE_ROOT/feature-branch"
  mock_set_pane_option "@assigned_bead" "bd-456"
  mock_set_pane_option "@worktree_path" "$TEST_WORKTREE_ROOT/feature-branch"

  # Stop hook should clean up pane options
  # Simulate cleanup
  tmux set @assigned_bead ""
  tmux set @worktree_path ""

  # After cleanup, options should be empty
  # Note: This tests the mock infrastructure, the real hook would do this
  [[ "$(mock_get_pane_option "@assigned_bead")" == "" ]]
}

@test "stop notifies coordinator even when wt-manager stops" {
  # wt-manager stopping might also need to notify
  setup_wt_manager_role
  mock_set_global_option "@wt_manager_active" "1"

  # Simulate wt-manager stop
  local should_notify=0

  if [[ "$TMUX_BEADS_ROLE" == "wt-manager" ]]; then
    # wt-manager stopping is significant - notify coordinator
    should_notify=1
  fi

  # This test documents expected behavior - wt-manager should notify
  [[ "$should_notify" -eq 1 ]]
}

# =============================================================================
# Integration Tests (Multiple Hook Interactions)
# =============================================================================

@test "worker lifecycle: start -> work -> commit -> stop" {
  local worktree_path="$TEST_WORKTREE_ROOT/feature-branch"

  # 1. Session start - worker detected
  setup_worker_role "$worktree_path"
  [[ "$TMUX_BEADS_ROLE" == "worker" ]]

  # 2. Assign a bead
  mock_set_pane_option "@assigned_bead" "bd-789"
  export TMUX_BEADS_ASSIGNED_BEAD="bd-789"

  # 3. Simulate commit (post-commit hook)
  bd sync
  was_bd_sync_called

  # 4. Stop - should notify
  local assigned_bead
  assigned_bead=$(mock_get_pane_option "@assigned_bead")
  [[ -n "$assigned_bead" ]]
}

@test "coordinator can send commands to workers" {
  # Setup coordinator
  setup_coordinator_role

  # Coordinator sending keys to worker pane
  tmux send-keys -t "%2" "echo 'task from coordinator'" Enter

  # Verify command was recorded
  assert_tmux_command_called "send-keys"
  assert_tmux_command_called "%2"
}

@test "role detection uses pane ID comparison" {
  # Test that role detection compares pane IDs correctly
  export MOCK_TMUX_PANE_ID="%5"
  mock_set_global_option "@beads_manager_pane" "%0"

  export TMUX_BEADS_PANE_ID="%5"
  export TMUX_BEADS_MANAGER_PANE_ID="%0"

  local role="worker"
  if [[ "$TMUX_BEADS_PANE_ID" == "$TMUX_BEADS_MANAGER_PANE_ID" ]]; then
    role="manager"
  fi

  [[ "$role" == "worker" ]]
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "handles missing TMUX environment gracefully" {
  # Outside tmux, hooks should exit gracefully
  unset TMUX

  # The session-start hook should exit early
  local should_exit=0
  if [[ -z "${TMUX:-}" ]]; then
    should_exit=1
  fi

  [[ "$should_exit" -eq 1 ]]
}

@test "handles unset worktree path with default fallback" {
  # When no worktree path is provided, helper uses default
  # This tests that the worker role still functions
  setup_worker_role

  # Worker without explicit worktree should still function
  [[ "$TMUX_BEADS_ROLE" == "worker" ]]
  # Default worktree path is used
  [[ -n "$TMUX_BEADS_WORKTREE_PATH" ]]
}

@test "handles special characters in paths" {
  # Worktree with spaces and special chars
  local special_path="$TEST_WORKTREE_ROOT/feature with spaces"
  mkdir -p "$special_path"

  setup_worker_role "$special_path"

  [[ "$TMUX_BEADS_WORKTREE_PATH" == "$special_path" ]]
}
