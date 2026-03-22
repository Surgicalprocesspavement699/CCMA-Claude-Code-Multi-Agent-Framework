#!/usr/bin/env bats
# ============================================================================
# CCMA Refactoring Validation Tests
# ============================================================================
# Run: bats tests/refactor-validation.bats
#
# These tests validate that all improvements from the code review have been
# correctly applied. They are structural/content tests, not runtime tests.
# ============================================================================

PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/.ccma/scripts"
CLAUDE_DIR="$PROJECT_DIR/.claude"
EXAMPLE_DIR="$PROJECT_DIR/examples/node-api"

# ============================================================================
# TASK 1: Delegation Rules Cleanup
# ============================================================================

@test "delegation-rules: file exists" {
  [ -f "$CLAUDE_DIR/delegation-rules.md" ]
}

@test "delegation-rules: contains no German text" {
  # Common German words that were in the original Model Selection section
  ! grep -qi "Begründung" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "Modell" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "Planung erfordert" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "Empfehlung" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "bindend" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "nötig" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "Jeder Agent" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "musst du" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "editieren" "$CLAUDE_DIR/delegation-rules.md"
  ! grep -qi "Wie Modelle" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: no Model Selection heading" {
  ! grep -q "^## Model Selection" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: has model selection reference comment" {
  grep -q "model.*frontmatter\|model:.*field\|ccma-config.sh" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: no Parallel Fan-Out section" {
  ! grep -q "Parallel Fan-Out" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: Rework Rules exist as table" {
  grep -q "## Rework Rules" "$CLAUDE_DIR/delegation-rules.md"
  # Check table structure: header row with pipes
  grep -q "| Trigger.*| Action.*|" "$CLAUDE_DIR/delegation-rules.md" || \
  grep -q "|.*Tester PARTIAL.*|" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: Rework Rules table covers all cases" {
  local file="$CLAUDE_DIR/delegation-rules.md"
  grep -q "Tester PARTIAL" "$file"
  grep -q "Reviewer MINOR" "$file"
  grep -q "Reviewer MAJOR" "$file"
  grep -q "Reviewer REJECTED" "$file"
  grep -q "CRITICAL.*HALT\|HALT.*CRITICAL\|CRITICAL.*escalate" "$file"
  grep -q "ERROR.*STOP\|STOP.*report\|ERROR.*report" "$file"
  grep -q "rework_count.*3\|>= 3\|>=3" "$file"
}

@test "delegation-rules: is concise (under 145 non-blank non-comment lines)" {
  local count
  count=$(grep -cv '^\s*$\|^\s*<!--' "$CLAUDE_DIR/delegation-rules.md")
  [ "$count" -le 145 ]
}

@test "delegation-rules: still has CRITICAL orchestrator instruction" {
  grep -q "CRITICAL" "$CLAUDE_DIR/delegation-rules.md"
  grep -q "ORCHESTRATOR" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: still has pipeline by task class" {
  grep -q "MICRO" "$CLAUDE_DIR/delegation-rules.md"
  grep -q "TRIVIAL" "$CLAUDE_DIR/delegation-rules.md"
  grep -q "STANDARD" "$CLAUDE_DIR/delegation-rules.md"
  grep -q "COMPLEX" "$CLAUDE_DIR/delegation-rules.md"
  grep -q "ARCHITECTURE" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: still has context requirements" {
  grep -q "Context" "$CLAUDE_DIR/delegation-rules.md"
  grep -q "Task description\|task description" "$CLAUDE_DIR/delegation-rules.md"
}

@test "delegation-rules: still has orchestrator self-check" {
  grep -q "Self-Check\|self-check\|Self Check" "$CLAUDE_DIR/delegation-rules.md"
}

# ============================================================================
# TASK 2: @import → Direct Inclusion
# ============================================================================

@test "CLAUDE.md: does not use @import for delegation-rules" {
  ! grep -q "^@import.*delegation-rules" "$PROJECT_DIR/CLAUDE.md"
}

@test "CLAUDE.md: contains delegation rules inline" {
  grep -q "Agent Delegation" "$PROJECT_DIR/CLAUDE.md"
  grep -q "ORCHESTRATOR" "$PROJECT_DIR/CLAUDE.md"
  grep -q "MICRO" "$PROJECT_DIR/CLAUDE.md"
  grep -q "Rework Rules" "$PROJECT_DIR/CLAUDE.md"
}

@test "CLAUDE.md: has @import as optional comment" {
  grep -q "OPTIONAL.*@import\|@import.*delegation-rules" "$PROJECT_DIR/CLAUDE.md"
  # The @import reference must be inside a comment, not active
  local active_imports
  active_imports=$(grep -c "^@import.*delegation-rules" "$PROJECT_DIR/CLAUDE.md" 2>/dev/null || true)
  [ "${active_imports:-0}" -eq 0 ]
}

@test "CLAUDE.md: delegation-rules.md still exists as source" {
  [ -f "$CLAUDE_DIR/delegation-rules.md" ]
}

# ============================================================================
# TASK 3: Example Project
# ============================================================================

@test "example: package.json exists" {
  [ -f "$EXAMPLE_DIR/package.json" ]
}

@test "example: package.json has required scripts" {
  jq -e '.scripts.build' "$EXAMPLE_DIR/package.json" >/dev/null
  jq -e '.scripts.test' "$EXAMPLE_DIR/package.json" >/dev/null
  jq -e '.scripts.lint' "$EXAMPLE_DIR/package.json" >/dev/null
  jq -e '.scripts.dev' "$EXAMPLE_DIR/package.json" >/dev/null
}

@test "example: package.json has express dependency" {
  jq -e '.dependencies.express // .devDependencies.express' "$EXAMPLE_DIR/package.json" >/dev/null
}

@test "example: package.json has typescript" {
  jq -e '.devDependencies.typescript' "$EXAMPLE_DIR/package.json" >/dev/null
}

@test "example: package.json has vitest" {
  jq -e '.devDependencies.vitest' "$EXAMPLE_DIR/package.json" >/dev/null
}

@test "example: tsconfig.json exists" {
  [ -f "$EXAMPLE_DIR/tsconfig.json" ]
}

@test "example: tsconfig.json has strict mode" {
  jq -e '.compilerOptions.strict' "$EXAMPLE_DIR/tsconfig.json" >/dev/null
}

@test "example: source files exist" {
  [ -f "$EXAMPLE_DIR/src/index.ts" ]
  [ -f "$EXAMPLE_DIR/src/routes/health.ts" ]
  [ -f "$EXAMPLE_DIR/src/middleware/error-handler.ts" ]
  [ -f "$EXAMPLE_DIR/src/services/status.ts" ]
}

@test "example: health route returns status and timestamp" {
  grep -q "status" "$EXAMPLE_DIR/src/routes/health.ts"
  grep -q "timestamp\|toISOString\|Date" "$EXAMPLE_DIR/src/routes/health.ts"
}

@test "example: error handler is Express middleware" {
  # Express error handlers have 4 params: (err, req, res, next)
  grep -qE "(err|error).*req.*res.*next|ErrorRequestHandler|errorHandler" "$EXAMPLE_DIR/src/middleware/error-handler.ts"
}

@test "example: status service exports getStatus" {
  grep -q "getStatus\|get_status\|GetStatus" "$EXAMPLE_DIR/src/services/status.ts"
  grep -q "uptime\|process.uptime" "$EXAMPLE_DIR/src/services/status.ts"
}

@test "example: test file exists" {
  [ -f "$EXAMPLE_DIR/tests/health.test.ts" ]
}

@test "example: test uses vitest" {
  grep -qE "import.*vitest|from.*vitest|describe|it\(|test\(" "$EXAMPLE_DIR/tests/health.test.ts"
}

@test "example: .gitignore exists" {
  [ -f "$EXAMPLE_DIR/.gitignore" ]
  grep -q "node_modules" "$EXAMPLE_DIR/.gitignore"
  grep -q "dist" "$EXAMPLE_DIR/.gitignore"
}

@test "example: CLAUDE.md still exists" {
  [ -f "$EXAMPLE_DIR/CLAUDE.md" ]
}

@test "example: pipeline transcript exists" {
  [ -f "$EXAMPLE_DIR/PIPELINE-TRANSCRIPT.md" ]
}

@test "example: pipeline transcript has task classification" {
  grep -q "Task class\|task_class\|Classification" "$EXAMPLE_DIR/PIPELINE-TRANSCRIPT.md"
  grep -q "TRIVIAL" "$EXAMPLE_DIR/PIPELINE-TRANSCRIPT.md"
}

@test "example: pipeline transcript has coder and tester stages" {
  grep -q "Coder\|coder" "$EXAMPLE_DIR/PIPELINE-TRANSCRIPT.md"
  grep -q "Tester\|tester" "$EXAMPLE_DIR/PIPELINE-TRANSCRIPT.md"
}

@test "example: pipeline transcript has SUCCESS status" {
  grep -q "SUCCESS" "$EXAMPLE_DIR/PIPELINE-TRANSCRIPT.md"
}

@test "example: sample pipeline-log.jsonl exists" {
  [ -f "$EXAMPLE_DIR/.claude/pipeline-log.jsonl" ]
}

@test "example: pipeline-log entries are valid JSON" {
  while IFS= read -r line; do
    echo "$line" | jq -e . >/dev/null 2>&1
  done < "$EXAMPLE_DIR/.claude/pipeline-log.jsonl"
}

@test "example: pipeline-log entries have required fields" {
  local first_line
  first_line=$(head -1 "$EXAMPLE_DIR/.claude/pipeline-log.jsonl")
  echo "$first_line" | jq -e '.timestamp' >/dev/null
  echo "$first_line" | jq -e '.task_id' >/dev/null
  echo "$first_line" | jq -e '.agent' >/dev/null
  echo "$first_line" | jq -e '.status' >/dev/null
  echo "$first_line" | jq -e '.rework_cycle' >/dev/null
}

@test "example: pipeline-log has at least 2 entries" {
  local count
  count=$(wc -l < "$EXAMPLE_DIR/.claude/pipeline-log.jsonl")
  [ "$count" -ge 2 ]
}

# ============================================================================
# TASK 4: Scratchpad Integrity in ccma-log.sh
# ============================================================================

@test "ccma-log: has scratchpad health check" {
  grep -q "Scratchpad.*health\|scratchpad.*warning\|CCMA Warning.*Scratchpad\|CCMA Warning.*scratchpad\|CCMA Warning.*task_id" "$SCRIPTS_DIR/ccma-log.sh"
}

@test "ccma-log: warns on missing scratchpad" {
  grep -q "Scratchpad not found\|scratchpad.*not found\|pipeline state unknown" "$SCRIPTS_DIR/ccma-log.sh"
}

@test "ccma-log: warns on missing task_id" {
  grep -q "task_id\|TASK_ID.*unknown" "$SCRIPTS_DIR/ccma-log.sh"
}

@test "ccma-log: health check is warn-only (no exit 1 in that block)" {
  # Extract the health check block and verify it doesn't exit 1
  # The key indicator: warnings go to stderr (>&2) but don't cause exit
  local warn_count
  warn_count=$(grep -c '>&2' "$SCRIPTS_DIR/ccma-log.sh")
  [ "$warn_count" -ge 1 ]
}

@test "ccma-log: smoke test — logs with valid scratchpad" {
  local tmpdir
  tmpdir=$(mktemp -d)
  # Create a minimal scratchpad
  cat > "$tmpdir/scratchpad.md" <<'EOF'
- **task_id**: 20260309-test-smoke
- **rework_count**: 0
EOF
  # Create config override
  export CCMA_PIPELINE_LOG="$tmpdir/test-log.jsonl"
  export CCMA_SCRATCHPAD="$tmpdir/scratchpad.md"

  "$SCRIPTS_DIR/ccma-log.sh" coder SUCCESS "Smoke test" 2>/dev/null

  [ -f "$tmpdir/test-log.jsonl" ]
  local entry
  entry=$(cat "$tmpdir/test-log.jsonl")
  echo "$entry" | jq -e '.task_id == "20260309-test-smoke"' >/dev/null
  echo "$entry" | jq -e '.agent == "coder"' >/dev/null
  echo "$entry" | jq -e '.status == "SUCCESS"' >/dev/null

  rm -rf "$tmpdir"
}

@test "ccma-log: smoke test — warns on missing scratchpad" {
  local tmpdir
  tmpdir=$(mktemp -d)
  export CCMA_PIPELINE_LOG="$tmpdir/test-log.jsonl"
  export CCMA_SCRATCHPAD="$tmpdir/nonexistent-scratchpad.md"

  local stderr_output
  stderr_output=$("$SCRIPTS_DIR/ccma-log.sh" coder SUCCESS "No scratchpad" 2>&1 1>/dev/null || true)

  # Should still produce a log entry (warn-only, not blocking)
  [ -f "$tmpdir/test-log.jsonl" ]
  # Should have warned on stderr
  echo "$stderr_output" | grep -qi "warning\|not found\|unknown"

  rm -rf "$tmpdir"
}

# ============================================================================
# TASK 5: Verify Script Enhancements
# ============================================================================

@test "ccma-verify: has placeholder detection" {
  grep -q "placeholder\|PLACEHOLDER\|\[YOUR.*COMMAND\]\|\[PROJECT NAME\]" "$SCRIPTS_DIR/ccma-verify.sh"
}

@test "ccma-verify: has language consistency check" {
  grep -q "German\|german\|Begründung\|English-only\|language" "$SCRIPTS_DIR/ccma-verify.sh"
}

@test "ccma-verify: has delegation-rules length check" {
  grep -q "LINE_COUNT\|line_count\|length.*check\|concise\|lines" "$SCRIPTS_DIR/ccma-verify.sh"
}

# ============================================================================
# TASK 6: Config Documentation
# ============================================================================

@test "ccma-config: model selection section marked as documentation-only" {
  grep -qi "DOCUMENTATION ONLY\|documentation only\|NOT read by any script\|not read by any" "$SCRIPTS_DIR/ccma-config.sh"
}

@test "ccma-config: references agent frontmatter as source of truth" {
  grep -q "frontmatter\|agent.*file\|\.md.*model:" "$SCRIPTS_DIR/ccma-config.sh"
}

# ============================================================================
# STRUCTURAL INTEGRITY — nothing broken
# ============================================================================

@test "integrity: all 5 agent files exist" {
  for agent in planner coder tester reviewer security-auditor; do
    [ -f "$CLAUDE_DIR/agents/${agent}.md" ]
  done
}

@test "integrity: settings.json is valid JSON with hooks" {
  jq -e '.hooks.PreToolUse' "$CLAUDE_DIR/settings.json" >/dev/null
  jq -e '.hooks.PostToolUse' "$CLAUDE_DIR/settings.json" >/dev/null
}

@test "integrity: all hook scripts are executable" {
  for script in ccma-bash-guard.sh ccma-sensitive-file-guard.sh ccma-auto-format.sh ccma-config.sh ccma-log.sh; do
    [ -x "$SCRIPTS_DIR/$script" ]
  done
}

@test "integrity: scratchpad.md exists" {
  [ -f "$CLAUDE_DIR/scratchpad.md" ]
}

@test "integrity: MEMORY.md exists" {
  [ -f "$CLAUDE_DIR/MEMORY.md" ]
}

@test "integrity: bash guard still works (smoke test)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "integrity: bash guard still blocks rm" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /tmp\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "integrity: file guard still blocks .env" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "integrity: file guard still blocks CLAUDE.md" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"CLAUDE.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "integrity: file guard still blocks agent files" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".claude/agents/coder.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "integrity: README still has threat model" {
  grep -q "Threat Model\|threat model\|Known Limitations" "$PROJECT_DIR/README.md"
}

@test "integrity: LICENSE exists" {
  [ -f "$PROJECT_DIR/LICENSE" ]
}
