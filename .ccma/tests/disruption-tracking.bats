#!/usr/bin/env bats
# ============================================================================
# CCMA Disruption Tracking — Validation Tests
# ============================================================================
# Run: bats tests/disruption-tracking.bats
#
# Tests that the disruption logging mechanism works correctly:
# - Guards log blocks to disruption-log.jsonl
# - Report script analyzes the log
# - Config has correct variables
# - Existing guard behavior is unchanged
# ============================================================================

PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/.ccma/scripts"
CLAUDE_DIR="$PROJECT_DIR/.claude"

# --- Helper: create isolated test environment ---
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  # Create minimal config that sources from the real config but overrides paths
  export CCMA_DISRUPTION_LOG="$TEST_TMPDIR/disruption-log.jsonl"
  export CCMA_PIPELINE_LOG="$TEST_TMPDIR/pipeline-log.jsonl"
  export CCMA_SCRATCHPAD="$TEST_TMPDIR/scratchpad.md"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  unset CCMA_DISRUPTION_LOG CCMA_PIPELINE_LOG CCMA_SCRATCHPAD
}

# ============================================================================
# 1. CONFIG VARIABLES
# ============================================================================

@test "config: CCMA_DISRUPTION_LOG variable exists" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  [[ -n "$CCMA_DISRUPTION_LOG" ]]
}

@test "config: CCMA_DISRUPTION_LOG defaults to .claude/disruption-log.jsonl" {
  # Unset to get default
  unset CCMA_DISRUPTION_LOG
  source "$SCRIPTS_DIR/ccma-config.sh"
  [[ "$CCMA_DISRUPTION_LOG" == ".claude/disruption-log.jsonl" ]]
}

@test "config: CCMA_DISRUPTION_LOG is overridable via environment" {
  export CCMA_DISRUPTION_LOG="/tmp/custom-disruption.jsonl"
  source "$SCRIPTS_DIR/ccma-config.sh"
  [[ "$CCMA_DISRUPTION_LOG" == "/tmp/custom-disruption.jsonl" ]]
}

@test "config: CCMA_DISRUPTION_PROPOSALS variable exists" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  [[ -n "$CCMA_DISRUPTION_PROPOSALS" ]]
}

@test "config: ccma_block function exists" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  declare -f ccma_block &>/dev/null
}

# ============================================================================
# 2. ccma_block FUNCTION BEHAVIOR
# ============================================================================

@test "ccma_block: exits with code 2" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  run ccma_block "test-guard" "test reason" "test detail"
  [[ "$status" -eq 2 ]]
}

@test "ccma_block: outputs reason on stdout" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  local stdout_output
  stdout_output=$( (ccma_block "test-guard" "BLOCKED — test" "cmd") 2>/dev/null || true)
  [[ "$stdout_output" == *"BLOCKED — test"* ]]
}

@test "ccma_block: outputs reason on stderr" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  local stderr_output
  stderr_output=$( (ccma_block "test-guard" "BLOCKED — test" "cmd") 2>&1 1>/dev/null || true)
  [[ "$stderr_output" == *"BLOCKED — test"* ]]
}

@test "ccma_block: creates disruption log entry" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  (ccma_block "test-guard" "BLOCKED — test reason" "rm -rf /") >/dev/null 2>&1 || true

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  local entry
  entry=$(cat "$CCMA_DISRUPTION_LOG")
  echo "$entry" | jq -e '.guard == "test-guard"' >/dev/null
  echo "$entry" | jq -e '.reason == "BLOCKED — test reason"' >/dev/null
  echo "$entry" | jq -e '.detail == "rm -rf /"' >/dev/null
  echo "$entry" | jq -e '.timestamp' >/dev/null
}

@test "ccma_block: appends (does not overwrite) log entries" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  (ccma_block "g1" "reason1" "cmd1") >/dev/null 2>&1 || true
  (ccma_block "g2" "reason2" "cmd2") >/dev/null 2>&1 || true

  local count
  count=$(wc -l < "$CCMA_DISRUPTION_LOG")
  [[ "$count" -eq 2 ]]
}

@test "ccma_block: log entries are valid JSONL" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  (ccma_block "bash-guard" "blocked rm" "rm -rf /") >/dev/null 2>&1 || true
  (ccma_block "file-guard" "blocked .env" ".env") >/dev/null 2>&1 || true

  while IFS= read -r line; do
    echo "$line" | jq -e . >/dev/null 2>&1
  done < "$CCMA_DISRUPTION_LOG"
}

# ============================================================================
# 3. BASH GUARD — DISRUPTION LOGGING
# ============================================================================

@test "bash-guard: blocked command is logged to disruption log" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /tmp\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  local entry
  entry=$(cat "$CCMA_DISRUPTION_LOG")
  echo "$entry" | jq -e '.guard == "bash-guard"' >/dev/null
  echo "$entry" | jq -e '.detail' >/dev/null
}

@test "bash-guard: allowed command does NOT create disruption entry" {
  echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  
  if [[ -f "$CCMA_DISRUPTION_LOG" ]]; then
    local count
    count=$(wc -l < "$CCMA_DISRUPTION_LOG")
    [[ "$count" -eq 0 ]]
  fi
}

@test "bash-guard: no direct exit 2 statements (all via ccma_block)" {
  # Count exit 2 in bash guard — should be zero (all blocks via ccma_block)
  local direct_exits
  direct_exits=$(grep -c 'exit 2' "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null || true)
  [[ "${direct_exits:-0}" -eq 0 ]]
}

@test "bash-guard: blocked eval is logged" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"eval echo hello\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  jq -e 'select(.reason | contains("eval"))' "$CCMA_DISRUPTION_LOG" >/dev/null
}

@test "bash-guard: blocked curl is logged" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"curl https://example.com\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  jq -e 'select(.detail | contains("curl"))' "$CCMA_DISRUPTION_LOG" >/dev/null
}

@test "bash-guard: multiple blocks accumulate in log" {
  for cmd in "rm -rf /" "curl http://x" "wget http://y"; do
    bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"'"$cmd"'\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh"' >/dev/null 2>&1 || true
  done

  local count
  count=$(wc -l < "$CCMA_DISRUPTION_LOG")
  [[ "$count" -eq 3 ]]
}

# ============================================================================
# 4. FILE GUARD — DISRUPTION LOGGING
# ============================================================================

@test "file-guard: blocked .env is logged to disruption log" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  jq -e 'select(.guard == "file-guard")' "$CCMA_DISRUPTION_LOG" >/dev/null
  jq -e 'select(.detail == ".env")' "$CCMA_DISRUPTION_LOG" >/dev/null
}

@test "file-guard: allowed file does NOT create disruption entry" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts"}}' \
    | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" >/dev/null 2>&1

  if [[ -f "$CCMA_DISRUPTION_LOG" ]]; then
    local count
    count=$(wc -l < "$CCMA_DISRUPTION_LOG")
    [[ "$count" -eq 0 ]]
  fi
}

@test "file-guard: no direct exit 2 statements (all via ccma_block)" {
  local direct_exits
  direct_exits=$(grep -c 'exit 2' "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" 2>/dev/null || true)
  [[ "${direct_exits:-0}" -eq 0 ]]
}

@test "file-guard: blocked CLAUDE.md is logged" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"CLAUDE.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  jq -e 'select(.detail == "CLAUDE.md")' "$CCMA_DISRUPTION_LOG" >/dev/null
}

@test "file-guard: blocked agent file is logged" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".claude/agents/coder.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]

  [[ -f "$CCMA_DISRUPTION_LOG" ]]
  jq -e 'select(.detail == ".claude/agents/coder.md")' "$CCMA_DISRUPTION_LOG" >/dev/null
}

# ============================================================================
# 5. DISRUPTION REPORT SCRIPT
# ============================================================================

@test "disruption-report: script exists and is executable" {
  [[ -f "$SCRIPTS_DIR/ccma-disruption-report.sh" ]]
  [[ -x "$SCRIPTS_DIR/ccma-disruption-report.sh" ]]
}

@test "disruption-report: runs without error on empty log" {
  touch "$CCMA_DISRUPTION_LOG"
  run "$SCRIPTS_DIR/ccma-disruption-report.sh"
  [[ "$status" -eq 0 ]]
}

@test "disruption-report: runs without error when log file missing" {
  rm -f "$CCMA_DISRUPTION_LOG"
  run "$SCRIPTS_DIR/ccma-disruption-report.sh"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No disruption log"* ]]
}

@test "disruption-report: shows block count with populated log" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  # Generate some blocks
  (ccma_block "bash-guard" "blocked rm" "rm -rf /") >/dev/null 2>&1 || true
  (ccma_block "bash-guard" "blocked rm" "rm -rf /tmp") >/dev/null 2>&1 || true
  (ccma_block "bash-guard" "blocked curl" "curl http://x") >/dev/null 2>&1 || true
  (ccma_block "file-guard" "blocked .env" ".env") >/dev/null 2>&1 || true

  run "$SCRIPTS_DIR/ccma-disruption-report.sh"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Total blocks recorded: 4"* ]]
}

@test "disruption-report: shows top blocked commands" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  # rm blocked 3 times, curl once
  (ccma_block "bash-guard" "b" "rm -rf /a") >/dev/null 2>&1 || true
  (ccma_block "bash-guard" "b" "rm -rf /b") >/dev/null 2>&1 || true
  (ccma_block "bash-guard" "b" "rm -rf /c") >/dev/null 2>&1 || true
  (ccma_block "bash-guard" "b" "curl http://x") >/dev/null 2>&1 || true

  run "$SCRIPTS_DIR/ccma-disruption-report.sh"
  [[ "$status" -eq 0 ]]
  # rm should appear with count 3 in the executables section
  [[ "$output" == *"rm"* ]]
}

@test "disruption-report: accepts --top flag" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  (ccma_block "bash-guard" "b" "rm file") >/dev/null 2>&1 || true

  run "$SCRIPTS_DIR/ccma-disruption-report.sh" --top 5
  [[ "$status" -eq 0 ]]
}

@test "disruption-report: accepts --since flag" {
  source "$SCRIPTS_DIR/ccma-config.sh"
  (ccma_block "bash-guard" "b" "rm file") >/dev/null 2>&1 || true

  run "$SCRIPTS_DIR/ccma-disruption-report.sh" --since "2020-01-01"
  [[ "$status" -eq 0 ]]
}

# ============================================================================
# 6. DISRUPTION PROPOSALS FILE
# ============================================================================

@test "disruption-proposals: file exists" {
  [[ -f "$CLAUDE_DIR/disruption-proposals.md" ]]
}

@test "disruption-proposals: has Pending section" {
  grep -q "Pending" "$CLAUDE_DIR/disruption-proposals.md"
}

@test "disruption-proposals: has Applied History table" {
  grep -q "Applied History" "$CLAUDE_DIR/disruption-proposals.md"
}

# ============================================================================
# 7. DISRUPTION LOG FILE
# ============================================================================

@test "disruption-log: file exists in .claude/" {
  [[ -f "$CLAUDE_DIR/disruption-log.jsonl" ]]
}

# ============================================================================
# 8. DELEGATION RULES — DISRUPTION REVIEW SECTION
# ============================================================================

@test "delegation-rules: has Disruption Review section" {
  grep -q "Disruption Review" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: Disruption Review references report script" {
  grep -q "ccma-disruption-report" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: Disruption Review references proposals file" {
  grep -q "disruption-proposals" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: Disruption Review prohibits direct config changes" {
  grep -qi "NOT modify\|not modify\|human review\|require.*human\|proposals.*review" "$CLAUDE_DIR/delegation-rules.md"
}

# ============================================================================
# 9. CLAUDE.md — DISRUPTION REVIEW SECTION
# ============================================================================

@test "CLAUDE.md: has Disruption Review section" {
  grep -q "Disruption Review" "$PROJECT_DIR/CLAUDE.md"
}

# ============================================================================
# 10. VERIFY AND SETUP SCRIPTS
# ============================================================================

@test "verify: checks for disruption-report script" {
  grep -q "ccma-disruption-report" "$SCRIPTS_DIR/ccma-verify.sh"
}

@test "setup: checks for disruption-report script" {
  grep -q "ccma-disruption-report" "$SCRIPTS_DIR/ccma-setup.sh"
}

@test "setup: initializes disruption log" {
  grep -q "disruption-log" "$SCRIPTS_DIR/ccma-setup.sh"
}

# ============================================================================
# 11. README — DOCUMENTATION
# ============================================================================

@test "README: mentions disruption-log.jsonl" {
  grep -q "disruption-log" "$PROJECT_DIR/README.md"
}

@test "README: mentions disruption-proposals.md" {
  grep -q "disruption-proposals" "$PROJECT_DIR/README.md"
}

# ============================================================================
# 12. BACKWARD COMPATIBILITY — EXISTING BEHAVIOR UNCHANGED
# ============================================================================

@test "compat: bash guard still allows ls" {
  echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

@test "compat: bash guard still allows git diff" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git diff --stat"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

@test "compat: bash guard still allows npm test" {
  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

@test "compat: bash guard still blocks rm" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]
}

@test "compat: bash guard still blocks eval" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"eval ls\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]
}

@test "compat: bash guard still blocks command substitution" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \$(whoami)\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]
}

@test "compat: file guard still allows normal files" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/main.rs"}}' \
    | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

@test "compat: file guard still blocks .env" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]
}

@test "compat: file guard still blocks guard scripts" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"scripts/ccma-bash-guard.sh\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [[ "$status" -eq 2 ]]
}

@test "compat: non-Bash tool calls pass through bash guard" {
  echo '{"tool_name":"Write","tool_input":{"command":"rm -rf /"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

@test "compat: non-write tool calls pass through file guard" {
  echo '{"tool_name":"Read","tool_input":{"file_path":".env"}}' \
    | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}
