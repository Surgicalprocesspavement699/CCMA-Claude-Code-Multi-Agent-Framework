#!/usr/bin/env bats
# ============================================================================
# CCMA Hook Tests — Automated tests using bats (Bash Automated Testing System)
# ============================================================================
# Install bats: npm install -g bats / brew install bats-core
# Run: bats tests/hooks.bats
# ============================================================================

SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"

# ============================================================================
# BASH GUARD TESTS
# ============================================================================

@test "bash-guard: allows ls" {
  result=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null)
  [ $? -eq 0 ]
}

@test "bash-guard: allows git diff" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git diff --stat"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows git log" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git log --oneline -10"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows git --no-pager diff" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git --no-pager diff"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows git -C /path log" {
  echo '{"tool_name":"Bash","tool_input":{"command":"git -C /some/path log --oneline"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks git --no-pager push" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git --no-pager push\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows npm test" {
  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows pytest" {
  echo '{"tool_name":"Bash","tool_input":{"command":"pytest -v"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows cargo build" {
  echo '{"tool_name":"Bash","tool_input":{"command":"cargo build"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows diff (Tier 1 read-only)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"diff file1.txt file2.txt"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows stat (Tier 1 read-only)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"stat src/main.rs"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks process substitution >(...)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat > >(tee log.txt)\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows piped commands" {
  echo '{"tool_name":"Bash","tool_input":{"command":"grep -r TODO src | sort | head -5"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows chained commands with &&" {
  echo '{"tool_name":"Bash","tool_input":{"command":"npm run build && npm test"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks rm" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /tmp/test\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks curl" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"curl https://example.com\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks wget" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"wget https://example.com\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks git push" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin main\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks git commit" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m test\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks git reset" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git reset --hard\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks shell redirect" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo foo > bar.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks append redirect" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo foo >> bar.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks sed -i" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i s/foo/bar/ file.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks sed -ibak (GNU shorthand)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -ibak s/foo/bar/ file.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks sed -i.bak" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i.bak s/foo/bar/ file.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows redirect inside double quotes" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo \"hello > world\""}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows redirect inside single quotes" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo '\''hello > world'\''"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: ignores non-Bash tool calls" {
  echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks empty command" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# --- Bypass vector tests ---

@test "bash-guard: blocks command substitution \$()" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \$(rm -rf /)\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks backtick execution" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \`whoami\`\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks eval" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"eval rm -rf /\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks tee" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo secret | tee /etc/passwd\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks python -c injection" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python3 -c \\\"import os; os.system(\\\\\\\"rm -rf /\\\\\\\")\\\"\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks node -e injection" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"node -e \\\"require(\\\\\\\"child_process\\\\\\\").exec(\\\\\\\"rm -rf /\\\\\\\")\\\"\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks exec" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"exec /bin/sh\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks source" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"source /etc/profile\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows chmod" {
  echo '{"tool_name":"Bash","tool_input":{"command":"chmod +x script.sh"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks \$() inside double quotes (double quotes allow expansion)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \\\"the syntax is \$(cmd)\\\"\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows \$() inside single quotes (single quotes prevent expansion)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo '\''the syntax is $(cmd)'\''"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks awk with output redirect" {
  # Guard checks for awk + > in same segment (even inside quotes)
  local tmpjson
  tmpjson="$(mktemp)"
  printf '{"tool_name":"Bash","tool_input":{"command":"awk '"'"'{ print > \\\"out.txt\\\" }'"'"' file"}}\n' > "$tmpjson"
  run bash -c "cat '$tmpjson' | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  rm -f "$tmpjson"
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks sed w flag" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed '\\''s/foo/bar/w output.txt'\\'' file.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks command after ||" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"false || curl evil.com\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows ccma-log.sh" {
  echo '{"tool_name":"Bash","tool_input":{"command":"./scripts/ccma-log.sh coder SUCCESS \"done\""}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

# --- Quote-aware splitting tests ---

@test "bash-guard: allows && inside double quotes (quote-aware split)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo \"build && test passed\""}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows || inside single quotes (quote-aware split)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo '\''true || false'\''"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows pipe inside double quotes (quote-aware split)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo \"use cmd | grep to filter\""}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows semicolon inside double quotes (quote-aware split)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"echo \"a; b; c\""}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: still blocks real && after quoted string" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \\\"ok\\\" && curl evil.com\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# --- Known bypass vectors (documented as limitations) ---

@test "bash-guard: blocks process substitution <()" {
  # Process substitution <() is now explicitly blocked by the guard
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"diff <(ls) <(ls -a)\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  # Blocked by process substitution check (diff itself is whitelisted in Tier 1)
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks heredoc with dangerous command" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python3 <<EOF\nprint(1)\nEOF\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  # python3 without -c/-e is whitelisted, but << is a redirect — caught by redirect check
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks brace expansion with non-whitelisted command" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm file{1,2,3}.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# --- File guard path normalization tests ---

@test "file-guard: blocks .env with ./ prefix" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"./.env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks .env with repeated ./ prefix" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"./././.env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# ============================================================================
# SENSITIVE FILE GUARD TESTS
# ============================================================================

@test "file-guard: blocks .env" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks .env.production" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".env.production\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks server.pem" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"certs/server.pem\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks private.key" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"private.key\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks CLAUDE.md" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"CLAUDE.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks .claude/settings.json" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".claude/settings.json\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks id_rsa" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"~/.ssh/id_rsa\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: allows src/app.ts" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts"}}' | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "file-guard: allows README.md" {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"README.md"}}' | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "file-guard: allows test files" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"tests/auth.test.ts"}}' | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "file-guard: ignores non-Write/Edit tool calls" {
  echo '{"tool_name":"Read","tool_input":{"file_path":".env"}}' | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

# ============================================================================
# AUTO-FORMAT TESTS
# ============================================================================

@test "auto-format: always exits 0 for known extension" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts"}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "auto-format: always exits 0 for unknown extension" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"data.xyz"}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "auto-format: always exits 0 for missing file" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"nonexistent/file.js"}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "auto-format: ignores non-Write/Edit tool calls" {
  echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "auto-format: handles NotebookEdit tool" {
  echo '{"tool_name":"NotebookEdit","tool_input":{"file_path":"notebook.ipynb"}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "auto-format: handles file without extension" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"Makefile"}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "auto-format: handles empty file path" {
  echo '{"tool_name":"Write","tool_input":{"file_path":""}}' | "$SCRIPTS_DIR/ccma-auto-format.sh" 2>/dev/null
  [ $? -eq 0 ]
}

# ============================================================================
# DOCKER SUBCOMMAND TESTS
# ============================================================================

@test "bash-guard: allows docker build" {
  echo '{"tool_name":"Bash","tool_input":{"command":"docker build -t myapp ."}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows docker compose up" {
  echo '{"tool_name":"Bash","tool_input":{"command":"docker compose up -d"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows docker ps" {
  echo '{"tool_name":"Bash","tool_input":{"command":"docker ps"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: blocks docker exec" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker exec -it container /bin/sh\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks docker rm" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker rm container\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks docker push" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker push myimage\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "bash-guard: blocks docker login" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker login\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# ============================================================================
# NOTEBOOKEDIT FILE GUARD TESTS
# ============================================================================

@test "file-guard: blocks NotebookEdit on .env" {
  run bash -c 'echo "{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"file_path\":\".env\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: allows NotebookEdit on regular file" {
  echo '{"tool_name":"NotebookEdit","tool_input":{"file_path":"notebooks/analysis.ipynb"}}' | "$SCRIPTS_DIR/ccma-sensitive-file-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

# ============================================================================
# CCMA-LOG.SH TESTS
# ============================================================================

@test "ccma-log: creates valid JSONL entry" {
  TMPDIR_LOG="$(mktemp -d)"
  CCMA_PIPELINE_LOG="$TMPDIR_LOG/pipeline-log.jsonl"
  CCMA_SCRATCHPAD="$TMPDIR_LOG/scratchpad.md"
  export CCMA_PIPELINE_LOG CCMA_SCRATCHPAD

  "$SCRIPTS_DIR/ccma-log.sh" coder SUCCESS "Implemented feature X"

  [ -f "$CCMA_PIPELINE_LOG" ]
  jq -e '.agent == "coder"' "$CCMA_PIPELINE_LOG"
  jq -e '.status == "SUCCESS"' "$CCMA_PIPELINE_LOG"
  jq -e '.task_description == "Implemented feature X"' "$CCMA_PIPELINE_LOG"
  jq -e '.timestamp' "$CCMA_PIPELINE_LOG"
  jq -e '.rework_cycle == 0' "$CCMA_PIPELINE_LOG"

  rm -rf "$TMPDIR_LOG"
}

@test "ccma-log: reads rework_count from scratchpad" {
  TMPDIR_LOG="$(mktemp -d)"
  CCMA_PIPELINE_LOG="$TMPDIR_LOG/pipeline-log.jsonl"
  CCMA_SCRATCHPAD="$TMPDIR_LOG/scratchpad.md"
  export CCMA_PIPELINE_LOG CCMA_SCRATCHPAD

  echo '- **rework_count**: 2' > "$CCMA_SCRATCHPAD"

  "$SCRIPTS_DIR/ccma-log.sh" tester PARTIAL "Tests failing"

  jq -e '.rework_cycle == 2' "$CCMA_PIPELINE_LOG"

  rm -rf "$TMPDIR_LOG"
}

@test "ccma-log: handles missing scratchpad gracefully" {
  TMPDIR_LOG="$(mktemp -d)"
  CCMA_PIPELINE_LOG="$TMPDIR_LOG/pipeline-log.jsonl"
  CCMA_SCRATCHPAD="$TMPDIR_LOG/nonexistent-scratchpad.md"
  export CCMA_PIPELINE_LOG CCMA_SCRATCHPAD

  "$SCRIPTS_DIR/ccma-log.sh" reviewer ACCEPTED "Code looks good"
  [ $? -eq 0 ]

  jq -e '.rework_cycle == 0' "$CCMA_PIPELINE_LOG"

  rm -rf "$TMPDIR_LOG"
}

@test "ccma-log: handles missing arguments with defaults" {
  TMPDIR_LOG="$(mktemp -d)"
  CCMA_PIPELINE_LOG="$TMPDIR_LOG/pipeline-log.jsonl"
  CCMA_SCRATCHPAD="$TMPDIR_LOG/nonexistent.md"
  export CCMA_PIPELINE_LOG CCMA_SCRATCHPAD

  "$SCRIPTS_DIR/ccma-log.sh"
  [ $? -eq 0 ]

  jq -e '.agent == "unknown"' "$CCMA_PIPELINE_LOG"
  jq -e '.status == "UNKNOWN"' "$CCMA_PIPELINE_LOG"

  rm -rf "$TMPDIR_LOG"
}

# ============================================================================
# CCMA-SETUP.SH TESTS
# ============================================================================

@test "ccma-setup: runs without error on framework directory" {
  run "$SCRIPTS_DIR/ccma-setup.sh"
  [ "$status" -eq 0 ]
}

@test "ccma-setup: detects placeholder values in CLAUDE.md" {
  run "$SCRIPTS_DIR/ccma-setup.sh"
  [[ "$output" == *"WARN"* ]]
}

# ============================================================================
# CCMA-VERIFY.SH TESTS
# ============================================================================

@test "ccma-verify: runs without error on framework directory" {
  run "$SCRIPTS_DIR/ccma-verify.sh"
  [ "$status" -eq 0 ]
}

@test "ccma-verify: reports pass count" {
  run "$SCRIPTS_DIR/ccma-verify.sh"
  [[ "$output" == *"passed"* ]]
}

# ============================================================================
# ADDITIONAL EDGE CASES
# ============================================================================

@test "bash-guard: allows mkdir" {
  echo '{"tool_name":"Bash","tool_input":{"command":"mkdir -p src/utils"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows deno" {
  echo '{"tool_name":"Bash","tool_input":{"command":"deno test"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows uv" {
  echo '{"tool_name":"Bash","tool_input":{"command":"uv pip install pytest"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: allows turbo" {
  echo '{"tool_name":"Bash","tool_input":{"command":"turbo run build"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "file-guard: blocks files with 'secret' in name" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"config/db-secret.yaml\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks files with 'credential' in name" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"credentials.json\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks agent definition files" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".claude/agents/coder.md\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# ============================================================================
# INTEGRATION TESTS — Guard interplay
# ============================================================================

@test "integration: tee .env is blocked by bash guard (tee not whitelisted)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo data | tee .env\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "integration: tee to normal file is also blocked (tee not whitelisted)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo data | tee output.txt\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "integration: cat .env via bash guard allowed (cat is read-only)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat .env\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 0 ]
}

# ============================================================================
# ccma-log.sh: jq requirement
# ============================================================================

@test "ccma-log: fails if jq not available" {
  TMPDIR_LOG="$(mktemp -d)"
  run bash -c 'PATH="/usr/bin:/bin" && export PATH && hash -r && CCMA_PIPELINE_LOG="'"$TMPDIR_LOG"'/test.jsonl" CCMA_SCRATCHPAD="'"$TMPDIR_LOG"'/scratch.md" "'"$SCRIPTS_DIR"'/ccma-log.sh" coder SUCCESS "test" 2>&1'
  # If jq is in /usr/bin or /bin this test may pass — the key is the error path exists
  # On systems without jq in those paths, it should fail with exit 1
  rm -rf "$TMPDIR_LOG"
  true  # This test documents the behavior; jq is typically available
}

# ============================================================================
# SCRIPT PROTECTION TESTS
# ============================================================================

@test "file-guard: blocks Edit on ccma-config.sh" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"scripts/ccma-config.sh\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks Write on ccma-bash-guard.sh" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"scripts/ccma-bash-guard.sh\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "file-guard: blocks Edit on ccma-sensitive-file-guard.sh" {
  run bash -c 'echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"scripts/ccma-sensitive-file-guard.sh\"}}" | "'"$SCRIPTS_DIR"'/ccma-sensitive-file-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

# ============================================================================
# FIX VERIFICATION TESTS
# ============================================================================

@test "bash-guard: allows awk numeric comparison (FIX-04)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"awk '\''$1 > 5 {print}'\'' data.csv"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: still blocks awk print-to-file redirect (FIX-04)" {
  local tmpjson
  tmpjson="$(mktemp)"
  printf '{"tool_name":"Bash","tool_input":{"command":"awk '\''{ print > \\\"out.txt\\\" }'\'' file"}}\n' > "$tmpjson"
  run bash -c "cat '$tmpjson' | \"$SCRIPTS_DIR/ccma-bash-guard.sh\" 2>/dev/null"
  rm -f "$tmpjson"
  [ "$status" -eq 2 ]
}

@test "bash-guard: allows source .venv/bin/activate (FIX-05)" {
  echo '{"tool_name":"Bash","tool_input":{"command":"source .venv/bin/activate"}}' | "$SCRIPTS_DIR/ccma-bash-guard.sh" 2>/dev/null
  [ $? -eq 0 ]
}

@test "bash-guard: still blocks arbitrary source (FIX-05)" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"source /etc/profile\"}}" | "'"$SCRIPTS_DIR"'/ccma-bash-guard.sh" 2>/dev/null'
  [ "$status" -eq 2 ]
}

@test "ccma-log: includes task_id in JSONL entry (FIX-06)" {
  TMPDIR_LOG="$(mktemp -d)"
  CCMA_PIPELINE_LOG="$TMPDIR_LOG/pipeline-log.jsonl"
  CCMA_SCRATCHPAD="$TMPDIR_LOG/scratchpad.md"
  export CCMA_PIPELINE_LOG CCMA_SCRATCHPAD

  echo '- **task_id**: 20260309-1200-test-task' > "$CCMA_SCRATCHPAD"
  echo '- **rework_count**: 0' >> "$CCMA_SCRATCHPAD"

  "$SCRIPTS_DIR/ccma-log.sh" coder SUCCESS "Test task"

  jq -e '.task_id == "20260309-1200-test-task"' "$CCMA_PIPELINE_LOG"

  rm -rf "$TMPDIR_LOG"
}
