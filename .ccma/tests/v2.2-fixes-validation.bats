#!/usr/bin/env bats
# ============================================================================
# CCMA v2.2 Fixes Validation Tests
# ============================================================================
# Validates that all three documentation and config fixes are correctly applied.
# Run: bats .ccma/tests/v2.2-fixes-validation.bats
# Requires: jq, bash >= 4
# ============================================================================

PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/.ccma/scripts"
CONFIG_FILE="$SCRIPTS_DIR/ccma-config.sh"
README="$PROJECT_DIR/README.md"

# ============================================================================
# Fix A — bats file itself
# ============================================================================

@test "fix-a: this bats file exists" {
  [ -f "$PROJECT_DIR/.ccma/tests/v2.2-fixes-validation.bats" ]
}

@test "fix-a: this bats file is executable" {
  [ -x "$PROJECT_DIR/.ccma/tests/v2.2-fixes-validation.bats" ]
}

# ============================================================================
# Fix B — ccma-commit.sh listed in structure
# ============================================================================

@test "fix-b: ccma-commit.sh script exists" {
  [ -f "$SCRIPTS_DIR/ccma-commit.sh" ]
}

@test "fix-b: ccma-commit.sh is executable" {
  [ -x "$SCRIPTS_DIR/ccma-commit.sh" ]
}

@test "fix-b: README mentions ccma-commit.sh in structure section" {
  grep -q "ccma-commit\.sh" "$README"
}

@test "fix-b: README ccma-commit.sh entry has description" {
  grep -q "ccma-commit\.sh.*Auto-Commit\|ccma-commit\.sh.*auto-commit\|ccma-commit\.sh.*Pipeline-SUCCESS" "$README"
}

# ============================================================================
# Fix B — Konfiguration section in README
# ============================================================================

@test "fix-b: README has Konfiguration section header" {
  grep -q "Konfiguration\|ccma-config\.sh" "$README"
}

@test "fix-b: README documents CCMA_AUTO_COMMIT variable" {
  grep -q "CCMA_AUTO_COMMIT" "$README"
}

@test "fix-b: README documents CCMA_MEMORY_MAX_LINES variable" {
  grep -q "CCMA_MEMORY_MAX_LINES" "$README"
}

@test "fix-b: README documents CCMA_CODER_MAX_TURNS variable" {
  grep -q "CCMA_CODER_MAX_TURNS" "$README"
}

@test "fix-b: CCMA_AUTO_COMMIT default is false in README" {
  grep -A2 "CCMA_AUTO_COMMIT" "$README" | grep -q "false\|False"
}

@test "fix-b: CCMA_MEMORY_MAX_LINES default is 150 in README" {
  grep -A2 "CCMA_MEMORY_MAX_LINES" "$README" | grep -q "150"
}

@test "fix-b: ccma-config.sh actually defines CCMA_AUTO_COMMIT" {
  grep -q 'CCMA_AUTO_COMMIT' "$CONFIG_FILE"
}

@test "fix-b: ccma-config.sh actually defines CCMA_MEMORY_MAX_LINES" {
  grep -q 'CCMA_MEMORY_MAX_LINES' "$CONFIG_FILE"
}

@test "fix-b: ccma-config.sh actually defines CCMA_CODER_MAX_TURNS_TRIVIAL" {
  grep -q 'CCMA_CODER_MAX_TURNS_TRIVIAL' "$CONFIG_FILE"
}

@test "fix-b: ccma-config.sh actually defines CCMA_CODER_MAX_TURNS_STANDARD" {
  grep -q 'CCMA_CODER_MAX_TURNS_STANDARD' "$CONFIG_FILE"
}

@test "fix-b: ccma-config.sh actually defines CCMA_CODER_MAX_TURNS_COMPLEX" {
  grep -q 'CCMA_CODER_MAX_TURNS_COMPLEX' "$CONFIG_FILE"
}

@test "fix-b: README documents Orchestrator-Guard as Observability" {
  grep -qi "Orchestrator-Guard.*Observability\|orchestrator-guard.*observability" "$README"
}

@test "fix-b: README Orchestrator-Guard bullet mentions disruption-log.jsonl" {
  grep -q "disruption-log\.jsonl" "$README"
}

@test "fix-b: README Orchestrator-Guard bullet mentions Prozessfehler" {
  grep -qi "Prozessfehler\|prozessfehler" "$README"
}

# ============================================================================
# Fix C — Security Pre-Check in COMPLEX pipeline class
# ============================================================================

@test "fix-c: README COMPLEX row mentions security-auditor" {
  grep -q "COMPLEX.*security-auditor\|security-auditor.*COMPLEX" "$README"
}

@test "fix-c: README COMPLEX row mentions Security Pre-Check" {
  grep -qi "Security Pre-Check\|security pre-check" "$README"
}

# ============================================================================
# Structural integrity — no logic changes
# ============================================================================

@test "integrity: ccma-config.sh is still sourceable (no syntax errors)" {
  bash -n "$CONFIG_FILE"
}

@test "integrity: settings.json is valid JSON" {
  jq -e . "$PROJECT_DIR/.claude/settings.json" >/dev/null
}

@test "integrity: all 5 agent files still exist" {
  for agent in planner coder tester reviewer security-auditor; do
    [ -f "$PROJECT_DIR/.claude/agents/${agent}.md" ]
  done
}

@test "integrity: README still has Schnellstart section" {
  grep -q "## Schnellstart" "$README"
}

@test "integrity: README still has Pipeline-Klassen section" {
  grep -q "## Pipeline-Klassen" "$README"
}

@test "integrity: README still has Wichtig section" {
  grep -q "## Wichtig" "$README"
}
