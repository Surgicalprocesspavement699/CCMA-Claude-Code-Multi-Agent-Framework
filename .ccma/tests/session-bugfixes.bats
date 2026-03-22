#!/usr/bin/env bats
# ============================================================================
# CCMA Session Bug Fixes — Validation Tests
# ============================================================================
# Validates fixes for bugs found in the first real CCMA session (2026-03-10).
# Run: bats tests/session-bugfixes.bats
# ============================================================================

SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export CCMA_DISRUPTION_LOG="$TEST_TMPDIR/disruption-log.jsonl"
  export CCMA_PIPELINE_LOG="$TEST_TMPDIR/pipeline-log.jsonl"
  export CCMA_SCRATCHPAD="$TEST_TMPDIR/scratchpad.md"
  export CCMA_ACTIVITY_LOG="$TEST_TMPDIR/activity-log.jsonl"
  export CCMA_ACTIVITY_LOGGING="true"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  unset CCMA_DISRUPTION_LOG CCMA_PIPELINE_LOG CCMA_SCRATCHPAD CCMA_ACTIVITY_LOG CCMA_ACTIVITY_LOGGING
}

# ============================================================================
# BUG 1: cd and export in whitelist
# ============================================================================

@test "FIX-BUG1: cd is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && ls"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG1: cd with quoted Windows path is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cd \"d:/00_Coding/10.2_Lehrlingssoftware v2\" && cargo build"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG1: cd with backslash Windows path is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cd \"d:\\00_Coding\\10.2_Lehrlingssoftware v2\" && cargo build"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG1: export PATH is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"export PATH=\"/c/Users/Familie/.cargo/bin:/c/Program Files/MSVC:$PATH\""}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG1: export followed by cargo build is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"export PATH=\"/usr/local/bin:$PATH\" && cargo build"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG1: cd && export && cargo build chain is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cd \"/project\" && export PATH=\"/tools:$PATH\" && cargo build"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

# ============================================================================
# BUG 2: 2>/dev/null redirect false positive
# ============================================================================

@test "FIX-BUG2: 2>/dev/null is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cargo build 2>/dev/null"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: 2>/dev/null with space is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"ls -la 2> /dev/null"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: command 2>/dev/null || echo fallback is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cargo search rfd --limit 1 2>/dev/null || echo \"Cannot search\""}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: chmod +x script 2>/dev/null is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"chmod +x ./scripts/ccma-log.sh 2>/dev/null"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: chmod +x 2>/dev/null; ccma-log.sh chain is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"chmod +x ./scripts/ccma-log.sh 2>/dev/null; ./scripts/ccma-log.sh coder SUCCESS \"test\""}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: 2>&1 is still allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cargo build 2>&1 | tail -20"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: >/dev/null is allowed (stdout discard)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cargo build >/dev/null 2>&1"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG2: > real_file.txt is still BLOCKED" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo data > output.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "FIX-BUG2: >> real_file.txt is still BLOCKED" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo data >> log.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "FIX-BUG2: 2> real_file.txt is still BLOCKED" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cargo build 2> errors.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# ============================================================================
# BUG 3: extract_subcommand with paths containing spaces
# ============================================================================

@test "FIX-BUG3: git -C 'path with spaces' diff is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git -C \"d:/00_Coding/10.2_Lehrlingssoftware v2\" diff --stat"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG3: git -C 'path with spaces' log is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git -C \"D:\\00_Coding\\10.2_Lehrlingssoftware v2\" log --oneline -5"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG3: git -C 'path with spaces' status is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git -C \"/home/user/my project dir\" status"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG3: git -C 'path with spaces' diff --stat -- files is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git -C \"d:/00_Coding/10.2_Lehrlingssoftware v2\" diff --stat -- crates/ams_gui/src/app.rs"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG3: git -C 'path with spaces' push is still BLOCKED" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git -C \\\"d:/My Project\\\" push origin main\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "FIX-BUG3: git -C simple_path diff still works" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git -C /tmp/project diff --stat"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG3: git --no-pager diff still works" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git --no-pager diff"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG3: docker -H 'host with space' ps is handled" {
  echo '{"tool_name":"Bash","tool_input":{"command":"docker -H \"tcp://my host:2375\" ps"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

# ============================================================================
# BUG 4: Activity logger Agent name capture
# ============================================================================

@test "FIX-BUG4: activity logger captures agent field" {
  echo '{"tool_name":"Agent","tool_input":{"agent":"coder","prompt":"implement feature"}}' \
    | "$SCRIPTS_DIR/ccma-activity-log.sh" >/dev/null 2>&1

  [ -f "$CCMA_ACTIVITY_LOG" ]
  local summary
  summary=$(cat "$CCMA_ACTIVITY_LOG" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['summary'])" 2>/dev/null || \
            grep -o '"summary":"[^"]*"' "$CCMA_ACTIVITY_LOG" | head -1 | sed 's/"summary":"//;s/"//')
  [ -n "$summary" ]
  [ "$summary" != "" ]
}

@test "FIX-BUG4: activity logger captures agentName field" {
  echo '{"tool_name":"Agent","tool_input":{"agentName":"tester","prompt":"test feature"}}' \
    | "$SCRIPTS_DIR/ccma-activity-log.sh" >/dev/null 2>&1

  [ -f "$CCMA_ACTIVITY_LOG" ]
  local line
  line=$(cat "$CCMA_ACTIVITY_LOG")
  # Summary should not be empty
  echo "$line" | grep -v '"summary":""' >/dev/null
}

@test "FIX-BUG4: activity logger fallback captures keys when no known field" {
  echo '{"tool_name":"Agent","tool_input":{"mystery_field":"planner","other":"data"}}' \
    | "$SCRIPTS_DIR/ccma-activity-log.sh" >/dev/null 2>&1

  [ -f "$CCMA_ACTIVITY_LOG" ]
  local line
  line=$(cat "$CCMA_ACTIVITY_LOG")
  # Summary should contain key names as fallback, not be empty
  echo "$line" | grep -v '"summary":""' >/dev/null
}

# ============================================================================
# BUG 5: ccma-log.sh path resolution on Windows
# ============================================================================

@test "FIX-BUG5: absolute Windows path to ccma-log.sh is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"\"d:/00_Coding/10.2_Lehrlingssoftware v2/scripts/ccma-log.sh\" coder SUCCESS \"test\""}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "FIX-BUG5: relative path to ccma-log.sh is allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"./scripts/ccma-log.sh coder SUCCESS \"test\""}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

# ============================================================================
# REGRESSION: Ensure all existing security blocks still work
# ============================================================================

@test "REGRESSION: rm is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: curl is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"curl http://evil.com\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: eval is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"eval echo hello\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: command substitution is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \\$(whoami)\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: git push is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin main\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: sed -i is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i s/foo/bar/g file.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: tee is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo data | tee file.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: .env write is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: CLAUDE.md write is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"CLAUDE.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "REGRESSION: python -c is still blocked" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python3 -c \\\"import os; os.system(\\\\\\\"rm -rf /\\\\\\\")\\\"\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# ============================================================================
# REGRESSION: All original allowed commands still work
# ============================================================================

@test "REGRESSION: ls still allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "REGRESSION: git diff still allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git diff --stat"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "REGRESSION: cargo build still allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cargo build"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "REGRESSION: npm test still allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "REGRESSION: piped grep still allowed" {
  echo '{"tool_name":"Bash","tool_input":{"command":"grep -r TODO src | sort | head -5"}}' \
    | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}
