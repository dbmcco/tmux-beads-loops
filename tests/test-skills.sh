#!/bin/bash
# Test script to validate skill file structure for tmux multi-agent orchestration
# TDD: Run this before and after implementing skills

SKILLS_DIR="/Users/braydon/projects/experiments/tmux-beads-loops/.claude/skills"
PASS=0
FAIL=0

check_skill() {
    local skill_name="$1"
    local skill_file="$SKILLS_DIR/$skill_name/SKILL.md"

    if [[ -f "$skill_file" ]]; then
        # Check file is not empty
        if [[ -s "$skill_file" ]]; then
            echo "✓ $skill_name/SKILL.md exists and is not empty"
            ((PASS++))
        else
            echo "✗ $skill_name/SKILL.md exists but is empty"
            ((FAIL++))
        fi
    else
        echo "✗ $skill_name/SKILL.md does not exist"
        ((FAIL++))
    fi
}

check_content() {
    local skill_name="$1"
    local required_text="$2"
    local skill_file="$SKILLS_DIR/$skill_name/SKILL.md"

    if grep -E -q "$required_text" "$skill_file" 2>/dev/null; then
        echo "  ✓ Contains: $required_text"
        ((PASS++))
    else
        echo "  ✗ Missing: $required_text"
        ((FAIL++))
    fi
}

echo "=== Skill Structure Tests ==="
echo ""

# Test coordinator skill
echo "Testing coordinator skill..."
check_skill "coordinator"
if [[ -f "$SKILLS_DIR/coordinator/SKILL.md" ]]; then
    check_content "coordinator" "Coordinator"
    check_content "coordinator" "bd ready"
    check_content "coordinator" "tmux send-keys"
    check_content "coordinator" "wt-manager"
fi

echo ""

# Test wt-manager skill
echo "Testing wt-manager skill..."
check_skill "wt-manager"
if [[ -f "$SKILLS_DIR/wt-manager/SKILL.md" ]]; then
    check_content "wt-manager" "Worktree Manager"
    check_content "wt-manager" "git worktree"
    check_content "wt-manager" "tmux new-window"
    check_content "wt-manager" "@worktree_path"
fi

echo ""

# Test worker skill
echo "Testing worker skill..."
check_skill "worker"
if [[ -f "$SKILLS_DIR/worker/SKILL.md" ]]; then
    check_content "worker" "Worker"
    check_content "worker" "bd show"
    check_content "worker" "bd close"
    check_content "worker" "Wait for"
fi

echo ""

# Test README
echo "Testing README..."
if [[ -f "$SKILLS_DIR/README.md" ]]; then
    echo "✓ README.md exists"
    ((PASS++))
    if grep -q "coordinator" "$SKILLS_DIR/README.md" && \
       grep -q "wt-manager" "$SKILLS_DIR/README.md" && \
       grep -q "worker" "$SKILLS_DIR/README.md"; then
        echo "  ✓ Documents all three roles"
        ((PASS++))
    else
        echo "  ✗ Missing role documentation"
        ((FAIL++))
    fi
else
    echo "✗ README.md does not exist"
    ((FAIL++))
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
