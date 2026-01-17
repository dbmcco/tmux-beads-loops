#!/usr/bin/env bash
# ABOUTME: Test helper for bats tests - provides mock tmux environment and utilities.
# ABOUTME: Used to test tmux-beads-loops hooks without requiring actual tmux.
# ABOUTME: Compatible with bash 3.2+ (macOS default)

# =============================================================================
# Mock tmux state storage (file-based for bash 3.2 compatibility)
# =============================================================================

# Create temp directory for mock state
MOCK_STATE_DIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}/mock_tmux_state"
mkdir -p "$MOCK_STATE_DIR"

# Mock tmux display values (simulate window/pane info)
MOCK_TMUX_SESSION="test-session"
MOCK_TMUX_WINDOW="0"
MOCK_TMUX_WINDOW_NAME="main"
MOCK_TMUX_PANE_INDEX="0"
MOCK_TMUX_PANE_ID="%0"

# Track tmux commands for assertions (file-based)
MOCK_TMUX_COMMANDS_FILE="$MOCK_STATE_DIR/commands.log"
MOCK_TMUX_SENT_KEYS_FILE="$MOCK_STATE_DIR/sent_keys.log"

# Global options storage
MOCK_TMUX_GLOBAL_OPTIONS_DIR="$MOCK_STATE_DIR/global_options"
MOCK_TMUX_PANE_OPTIONS_DIR="$MOCK_STATE_DIR/pane_options"

# BD mock state
MOCK_BD_COMMANDS_FILE="$MOCK_STATE_DIR/bd_commands.log"
MOCK_BD_SYNC_CALLED_FILE="$MOCK_STATE_DIR/bd_sync_called"

# =============================================================================
# Option storage helpers (file-based)
# =============================================================================

_safe_option_name() {
  # Convert option name to safe filename
  echo "$1" | sed 's/@/_at_/g; s/\//_slash_/g'
}

_set_global_option() {
  local option="$1"
  local value="$2"
  local safe_name
  safe_name=$(_safe_option_name "$option")
  mkdir -p "$MOCK_TMUX_GLOBAL_OPTIONS_DIR"
  echo "$value" > "$MOCK_TMUX_GLOBAL_OPTIONS_DIR/$safe_name"
}

_get_global_option() {
  local option="$1"
  local safe_name
  safe_name=$(_safe_option_name "$option")
  if [[ -f "$MOCK_TMUX_GLOBAL_OPTIONS_DIR/$safe_name" ]]; then
    cat "$MOCK_TMUX_GLOBAL_OPTIONS_DIR/$safe_name"
  fi
}

_set_pane_option() {
  local option="$1"
  local value="$2"
  local safe_name
  safe_name=$(_safe_option_name "$option")
  mkdir -p "$MOCK_TMUX_PANE_OPTIONS_DIR"
  echo "$value" > "$MOCK_TMUX_PANE_OPTIONS_DIR/$safe_name"
}

_get_pane_option() {
  local option="$1"
  local safe_name
  safe_name=$(_safe_option_name "$option")
  if [[ -f "$MOCK_TMUX_PANE_OPTIONS_DIR/$safe_name" ]]; then
    cat "$MOCK_TMUX_PANE_OPTIONS_DIR/$safe_name"
  fi
}

# =============================================================================
# Mock tmux command
# =============================================================================

tmux() {
  # Record the full command for later assertions
  echo "$*" >> "$MOCK_TMUX_COMMANDS_FILE"

  case "$1" in
    display-message)
      _mock_tmux_display_message "$@"
      ;;
    show)
      _mock_tmux_show "$@"
      ;;
    show-options)
      _mock_tmux_show_options "$@"
      ;;
    set|set-option)
      _mock_tmux_set "$@"
      ;;
    send-keys)
      _mock_tmux_send_keys "$@"
      ;;
    *)
      # Record unknown command, return success
      return 0
      ;;
  esac
}

# Export the mock function
export -f tmux

# =============================================================================
# Mock tmux subcommand implementations
# =============================================================================

_mock_tmux_display_message() {
  local target=""
  local format=""

  shift # remove "display-message"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p)
        # Print to stdout (normal mode)
        shift
        ;;
      -t)
        target="$2"
        shift 2
        ;;
      *)
        format="$1"
        shift
        ;;
    esac
  done

  # Handle format strings
  case "$format" in
    '#S')
      echo "$MOCK_TMUX_SESSION"
      ;;
    '#I')
      echo "$MOCK_TMUX_WINDOW"
      ;;
    '#W')
      echo "$MOCK_TMUX_WINDOW_NAME"
      ;;
    '#P')
      echo "$MOCK_TMUX_PANE_INDEX"
      ;;
    '#{pane_id}')
      echo "$MOCK_TMUX_PANE_ID"
      ;;
    '#S:#I')
      echo "${MOCK_TMUX_SESSION}:${MOCK_TMUX_WINDOW}"
      ;;
    *)
      echo "$format"
      ;;
  esac
}

_mock_tmux_show() {
  local scope=""
  local quiet=""
  local value_only=""
  local option_name=""

  shift # remove "show"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -g)
        scope="global"
        shift
        ;;
      -q)
        quiet="1"
        shift
        ;;
      -v)
        value_only="1"
        shift
        ;;
      -gq|-qg)
        scope="global"
        quiet="1"
        shift
        ;;
      -gqv|-gvq|-qgv|-qvg|-vgq|-vqg)
        scope="global"
        quiet="1"
        value_only="1"
        shift
        ;;
      *)
        option_name="$1"
        shift
        ;;
    esac
  done

  if [[ -n "$option_name" ]]; then
    local value=""
    if [[ "$scope" == "global" ]]; then
      value=$(_get_global_option "$option_name")
    else
      value=$(_get_pane_option "$option_name")
    fi

    if [[ -n "$value_only" ]]; then
      echo "$value"
    elif [[ -n "$value" ]]; then
      echo "$option_name $value"
    fi
  fi
}

_mock_tmux_show_options() {
  _mock_tmux_show "$@"
}

_mock_tmux_set() {
  local scope=""
  local option_name=""
  local option_value=""

  shift # remove "set" or "set-option"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -g)
        scope="global"
        shift
        ;;
      *)
        if [[ -z "$option_name" ]]; then
          option_name="$1"
        else
          option_value="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -n "$option_name" ]]; then
    if [[ "$scope" == "global" ]]; then
      _set_global_option "$option_name" "$option_value"
    else
      _set_pane_option "$option_name" "$option_value"
    fi
  fi
}

_mock_tmux_send_keys() {
  shift # remove "send-keys"
  echo "$*" >> "$MOCK_TMUX_SENT_KEYS_FILE"
}

# Export helper functions
export -f _mock_tmux_display_message
export -f _mock_tmux_show
export -f _mock_tmux_show_options
export -f _mock_tmux_set
export -f _mock_tmux_send_keys
export -f _safe_option_name
export -f _set_global_option
export -f _get_global_option
export -f _set_pane_option
export -f _get_pane_option

# =============================================================================
# Role simulation helpers
# =============================================================================

# Set up mock environment for a coordinator/manager role
setup_coordinator_role() {
  MOCK_TMUX_SESSION="test-session"
  MOCK_TMUX_WINDOW="0"
  MOCK_TMUX_WINDOW_NAME="coordinator"
  MOCK_TMUX_PANE_INDEX="0"
  MOCK_TMUX_PANE_ID="%0"

  _set_global_option "@beads_manager" "${MOCK_TMUX_SESSION}:${MOCK_TMUX_WINDOW}"
  _set_global_option "@beads_manager_pane" "%0"
  _set_global_option "@beads_manager_name" "coordinator"

  export TMUX="/tmp/mock-tmux,12345,0"
  export TMUX_PANE="%0"
  export TMUX_BEADS_ROLE="manager"
  export TMUX_BEADS_MANAGER_TARGET="${MOCK_TMUX_SESSION}:${MOCK_TMUX_WINDOW}"
  export TMUX_BEADS_MANAGER_PANE_ID="%0"
  export TMUX_BEADS_PANE_ID="%0"
}

# Set up mock environment for a wt-manager role (worktree manager)
setup_wt_manager_role() {
  MOCK_TMUX_SESSION="test-session"
  MOCK_TMUX_WINDOW="1"
  MOCK_TMUX_WINDOW_NAME="wt-manager"
  MOCK_TMUX_PANE_INDEX="0"
  MOCK_TMUX_PANE_ID="%1"

  _set_global_option "@beads_manager" "${MOCK_TMUX_SESSION}:0"
  _set_global_option "@beads_manager_pane" "%0"
  _set_global_option "@claude_role" "wt-manager"

  export TMUX="/tmp/mock-tmux,12345,0"
  export TMUX_PANE="%1"
  export TMUX_BEADS_ROLE="wt-manager"
  export TMUX_BEADS_MANAGER_TARGET="${MOCK_TMUX_SESSION}:0"
  export TMUX_BEADS_MANAGER_PANE_ID="%0"
  export TMUX_BEADS_PANE_ID="%1"
}

# Set up mock environment for a worker role
# Args: $1 = worktree path (optional)
setup_worker_role() {
  local worktree_path="${1:-/tmp/test-worktree}"

  MOCK_TMUX_SESSION="test-session"
  MOCK_TMUX_WINDOW="2"
  MOCK_TMUX_WINDOW_NAME="worker-1"
  MOCK_TMUX_PANE_INDEX="0"
  MOCK_TMUX_PANE_ID="%2"

  _set_global_option "@beads_manager" "${MOCK_TMUX_SESSION}:0"
  _set_global_option "@beads_manager_pane" "%0"
  _set_global_option "@claude_role" "worker"
  _set_pane_option "@worktree_path" "$worktree_path"
  _set_pane_option "@assigned_bead" ""

  export TMUX="/tmp/mock-tmux,12345,0"
  export TMUX_PANE="%2"
  export TMUX_BEADS_ROLE="worker"
  export TMUX_BEADS_WORKTREE_PATH="$worktree_path"
  export TMUX_BEADS_MANAGER_TARGET="${MOCK_TMUX_SESSION}:0"
  export TMUX_BEADS_MANAGER_PANE_ID="%0"
  export TMUX_BEADS_PANE_ID="%2"
}

# Export role setup functions
export -f setup_coordinator_role
export -f setup_wt_manager_role
export -f setup_worker_role

# =============================================================================
# Tmux option helpers for tests (public API)
# =============================================================================

# Set a mock global tmux option
mock_set_global_option() {
  _set_global_option "$1" "$2"
}

# Get a mock global tmux option
mock_get_global_option() {
  _get_global_option "$1"
}

# Set a mock pane-specific tmux option
mock_set_pane_option() {
  _set_pane_option "$1" "$2"
}

# Get a mock pane-specific tmux option
mock_get_pane_option() {
  _get_pane_option "$1"
}

# Export option helpers
export -f mock_set_global_option
export -f mock_get_global_option
export -f mock_set_pane_option
export -f mock_get_pane_option

# =============================================================================
# Assertion helpers
# =============================================================================

# Assert that a tmux command was called
assert_tmux_command_called() {
  local expected="$1"

  if [[ ! -f "$MOCK_TMUX_COMMANDS_FILE" ]]; then
    echo "No tmux commands were called"
    return 1
  fi

  if grep -q "$expected" "$MOCK_TMUX_COMMANDS_FILE"; then
    return 0
  else
    echo "Expected tmux command containing '$expected' was not called"
    echo "Commands called:"
    cat "$MOCK_TMUX_COMMANDS_FILE"
    return 1
  fi
}

# Assert that a tmux command was NOT called
assert_tmux_command_not_called() {
  local unexpected="$1"

  if [[ ! -f "$MOCK_TMUX_COMMANDS_FILE" ]]; then
    return 0
  fi

  if grep -q "$unexpected" "$MOCK_TMUX_COMMANDS_FILE"; then
    echo "Unexpected tmux command containing '$unexpected' was called"
    echo "Commands called:"
    cat "$MOCK_TMUX_COMMANDS_FILE"
    return 1
  fi
}

# Get the number of times a command pattern was called
count_tmux_commands() {
  local pattern="$1"

  if [[ ! -f "$MOCK_TMUX_COMMANDS_FILE" ]]; then
    echo "0"
    return
  fi

  grep -c "$pattern" "$MOCK_TMUX_COMMANDS_FILE" || echo "0"
}

# Export assertion helpers
export -f assert_tmux_command_called
export -f assert_tmux_command_not_called
export -f count_tmux_commands

# =============================================================================
# Test setup and teardown
# =============================================================================

# Reset all mock state (call in setup())
reset_mock_state() {
  # Clean up state directories
  rm -rf "$MOCK_STATE_DIR"
  mkdir -p "$MOCK_STATE_DIR"
  mkdir -p "$MOCK_TMUX_GLOBAL_OPTIONS_DIR"
  mkdir -p "$MOCK_TMUX_PANE_OPTIONS_DIR"

  # Reset display values
  MOCK_TMUX_SESSION="test-session"
  MOCK_TMUX_WINDOW="0"
  MOCK_TMUX_WINDOW_NAME="main"
  MOCK_TMUX_PANE_INDEX="0"
  MOCK_TMUX_PANE_ID="%0"

  # Clear exported environment
  unset TMUX_BEADS_ROLE
  unset TMUX_BEADS_WORKTREE_PATH
  unset TMUX_BEADS_MANAGER_TARGET
  unset TMUX_BEADS_MANAGER_PANE_ID
  unset TMUX_BEADS_PANE_ID
  unset TMUX_BEADS_ASSIGNED_BEAD
}

export -f reset_mock_state

# =============================================================================
# Mock bd (beads) command
# =============================================================================

MOCK_BD_SYNC_CALLED=0

bd() {
  echo "$*" >> "$MOCK_BD_COMMANDS_FILE"

  case "$1" in
    sync)
      MOCK_BD_SYNC_CALLED=1
      echo "1" > "$MOCK_BD_SYNC_CALLED_FILE"
      ;;
  esac

  return 0
}

export -f bd

reset_bd_mock() {
  rm -f "$MOCK_BD_COMMANDS_FILE"
  rm -f "$MOCK_BD_SYNC_CALLED_FILE"
  MOCK_BD_SYNC_CALLED=0
}

# Check if bd sync was called
was_bd_sync_called() {
  if [[ -f "$MOCK_BD_SYNC_CALLED_FILE" ]]; then
    return 0
  fi
  return 1
}

export -f reset_bd_mock
export -f was_bd_sync_called

# =============================================================================
# Path for hooks under test
# =============================================================================

# Get the project root (assuming tests are in tests/hooks/)
get_project_root() {
  local script_dir
  if [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
    script_dir="$BATS_TEST_DIRNAME"
  else
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  cd "$script_dir/../.." && pwd
}

# Get the path to the hooks directory
get_hooks_dir() {
  echo "$(get_project_root)/scripts/tmux-beads-loops"
}

export -f get_project_root
export -f get_hooks_dir

# Export state directory variables
export MOCK_STATE_DIR
export MOCK_TMUX_COMMANDS_FILE
export MOCK_TMUX_SENT_KEYS_FILE
export MOCK_TMUX_GLOBAL_OPTIONS_DIR
export MOCK_TMUX_PANE_OPTIONS_DIR
export MOCK_BD_COMMANDS_FILE
export MOCK_BD_SYNC_CALLED_FILE
export MOCK_TMUX_SESSION
export MOCK_TMUX_WINDOW
export MOCK_TMUX_WINDOW_NAME
export MOCK_TMUX_PANE_INDEX
export MOCK_TMUX_PANE_ID
