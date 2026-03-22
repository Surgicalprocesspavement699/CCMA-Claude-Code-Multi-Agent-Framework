#!/usr/bin/env bats
# ============================================================================
# CCMA Auto-Commit Script Tests
# ============================================================================
# Tests for ccma-commit.sh behavior.
# Run: bats tests/ccma-commit.bats
# ============================================================================

SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/ccma-config.sh"

@test "ccma-commit.sh: CCMA_AUTO_COMMIT=false exits 0 without committing" {
  # Override config to ensure auto-commit is disabled
  CCMA_AUTO_COMMIT=false \
    "$SCRIPTS_DIR/ccma-commit.sh" "test-task-id" "STANDARD" "test summary" 2>/dev/null
  [ $? -eq 0 ]
}

@test "ccma-commit.sh: CCMA_AUTO_COMMIT=true in non-git dir exits 0" {
  # Run in a temp directory that is not a git repo
  local tmpdir
  tmpdir="$(mktemp -d)"
  # We need a minimal ccma-config.sh stub to source
  # Actually ccma-commit.sh sources the real config — override via env var
  (
    cd "$tmpdir"
    CCMA_AUTO_COMMIT=true \
      "$SCRIPTS_DIR/ccma-commit.sh" "test-task-id" "STANDARD" "test summary" 2>/dev/null
  )
  [ $? -eq 0 ]
  rm -rf "$tmpdir"
}

@test "ccma-commit.sh is listed in CCMA_TIER2_COMMANDS in ccma-config.sh" {
  grep -q 'ccma-commit\.sh' "$CONFIG_FILE"
}
