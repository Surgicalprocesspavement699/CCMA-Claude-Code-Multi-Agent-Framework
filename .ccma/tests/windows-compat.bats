#!/usr/bin/env bats
# ============================================================================
# CCMA Windows Compatibility Tests
# ============================================================================
# Tests for CRLF handling, quoted Windows paths, and new whitelist commands.
# Run: bats tests/windows-compat.bats
# ============================================================================

SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"

# Helper: build correct JSON via jq to avoid shell escaping issues
guard_json() {
  jq -cn --arg cmd "$1" '{"tool_name":"Bash","tool_input":{"command":$cmd}}'
}

# ============================================================================
# CRLF TESTS (Bug 1)
# ============================================================================

@test "windows: CRLF in echo JSON argument is ALLOWED" {
  # JSON \\r\\n becomes literal \r\n after jq extraction — guard must strip it
  local cmd
  cmd=$(printf 'echo {"task_id": "test",\r\n  "timestamp": "2026-03-12"}')
  guard_json "$cmd" | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: CRLF in script argument is ALLOWED" {
  local cmd
  cmd=$(printf './scripts/ccma-log.sh coder SUCCESS "Subtask 5\r\n"')
  guard_json "$cmd" | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: multi-line JSON piped to retro-log is ALLOWED" {
  local cmd
  cmd=$(printf 'echo '\''{"task_id":"20260312-test","timestamp":"2026-03-12T20:00:00Z"}'\'' | ./scripts/ccma-retro-log.sh')
  guard_json "$cmd" | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: --adaptations argument with CRLF is ALLOWED" {
  local cmd
  cmd=$(printf './scripts/ccma-retro-log.sh --adaptations "## Proposals\r\n### 1. Process\r\nFix rule"')
  guard_json "$cmd" | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: CRLF strip does NOT affect legitimate command splitting" {
  local cmd="ls && rm -rf /"
  run bash -c "$(printf '%s' "$(guard_json "$cmd")") | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  [ "$status" -eq 2 ]
}

# ============================================================================
# QUOTED PATH TESTS (Bug 3)
# ============================================================================

@test "windows: double-quoted path with spaces to ccma-log.sh is ALLOWED" {
  guard_json '"D:/path with spaces/scripts/ccma-log.sh" coder SUCCESS "msg"' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: double-quoted Program Files path is ALLOWED" {
  guard_json '"/c/Program Files/project/scripts/ccma-log.sh" arg' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: quoted path to non-whitelisted script is BLOCKED" {
  local json
  json=$(guard_json '"D:/path/not-in-whitelist.sh" arg')
  run bash -c "echo '$json' | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  [ "$status" -eq 2 ]
}

@test "windows: single-quoted path with spaces to ccma-verify.sh is ALLOWED" {
  guard_json "'C:/path with spaces/scripts/ccma-verify.sh'" \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

# ============================================================================
# NEW WHITELIST COMMANDS (Bug 5)
# ============================================================================

@test "windows: test -f somefile.txt is ALLOWED" {
  guard_json 'test -f somefile.txt' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: find | xargs wc -l is ALLOWED" {
  guard_json 'find . -name "*.rs" | xargs wc -l' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "windows: echo | tr a-z A-Z is ALLOWED" {
  guard_json 'echo hello | tr a-z A-Z' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

# ============================================================================
# REGRESSION TESTS
# ============================================================================

@test "regression: rm -rf / is BLOCKED" {
  local json
  json=$(guard_json 'rm -rf /')
  run bash -c "echo '$json' | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  [ "$status" -eq 2 ]
}

@test "regression: bash evil.sh is BLOCKED" {
  local json
  json=$(guard_json 'bash evil.sh')
  run bash -c "echo '$json' | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  [ "$status" -eq 2 ]
}

@test "regression: python3 -c injection is BLOCKED" {
  local json
  json=$(guard_json 'python3 -c "import os; os.system(\"rm -rf /\")"')
  run bash -c "echo '$json' | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  [ "$status" -eq 2 ]
}

# ============================================================================
# ACCEPTANCE CRITERIA — Real-world commands from disruption logs
# ============================================================================

@test "acceptance: cd with quoted path + ccma-log.sh is ALLOWED" {
  local cmd='cd "D:/00_Coding/10.2_Lehrlingssoftware v2" && ./scripts/ccma-log.sh coder SUCCESS "Subtask 5: Wired ApprenticeImport GUI"'
  guard_json "$cmd" | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}
