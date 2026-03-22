#!/usr/bin/env bash
# ============================================================================
# CCMA Framework — Verification Script
# ============================================================================
# Quick health check: verifies all components are in place and functional.
# Run anytime to confirm the framework is correctly installed.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [[ "$result" == "0" ]]; then
    echo "  [PASS] $desc"
    ((PASS++))
  else
    echo "  [FAIL] $desc"
    ((FAIL++))
  fi
}

echo "============================================"
echo "  CCMA Framework Verification"
echo "============================================"
echo ""

# --- jq ---
command -v jq &>/dev/null
check "jq is installed" "$?"

# --- bash version ---
[[ "${BASH_VERSINFO[0]}" -ge 4 ]]
check "bash >= 4.0" "$?"

# --- 6 Agent files ---
AGENTS=(planner coder tester reviewer security-auditor retrospector)
for agent in "${AGENTS[@]}"; do
  [[ -f "$PROJECT_DIR/.claude/agents/${agent}.md" ]]
  check "Agent: ${agent}.md exists" "$?"
done

# --- 4 Hook scripts (config + 3 hooks) ---
SCRIPTS=(ccma-config.sh ccma-bash-guard.sh ccma-sensitive-file-guard.sh ccma-auto-format.sh ccma-log.sh ccma-disruption-report.sh ccma-activity-log.sh ccma-session-report.sh ccma-session-start.sh ccma-pre-compact.sh ccma-retro-log.sh)
for script in "${SCRIPTS[@]}"; do
  [[ -f "$SCRIPT_DIR/$script" && -x "$SCRIPT_DIR/$script" ]]
  check "Script: $script (exists + executable)" "$?"
done

# --- settings.json with hooks ---
SETTINGS="$PROJECT_DIR/.claude/settings.json"
[[ -f "$SETTINGS" ]] && jq -e '.hooks.PreToolUse' "$SETTINGS" &>/dev/null
check "settings.json has PreToolUse hooks" "$?"

[[ -f "$SETTINGS" ]] && jq -e '.hooks.PostToolUse' "$SETTINGS" &>/dev/null
check "settings.json has PostToolUse hooks" "$?"

# Check activity logger is registered (matcher ".*" with ccma-activity-log.sh)
ACTIVITY_HOOK_FOUND=1
if [[ -f "$SETTINGS" ]] && jq -e '.hooks.PreToolUse[] | select(.hooks[]?.command | test("ccma-activity-log"))' "$SETTINGS" &>/dev/null; then
  ACTIVITY_HOOK_FOUND=0
fi
check "Activity logger hook registered in settings.json" "$ACTIVITY_HOOK_FOUND"

# Check SessionStart hook
if [[ -f "$SETTINGS" ]]; then
  jq -e '.hooks.SessionStart' "$SETTINGS" &>/dev/null
  check "settings.json has SessionStart hook" "$?"
fi

# Check PreCompact hook
if [[ -f "$SETTINGS" ]]; then
  jq -e '.hooks.PreCompact' "$SETTINGS" &>/dev/null
  check "settings.json has PreCompact hook" "$?"
fi

# --- Skills ---
SKILL_COUNT=$(find "$PROJECT_DIR/.claude/skills" -name "*.md" ! -name "README.md" 2>/dev/null | wc -l)
[[ "$SKILL_COUNT" -ge 1 ]]
check "At least 1 skill file in .claude/skills/ (found: $SKILL_COUNT)" "$?"

# Check for at least 1 command skill
CMD_SKILL_FOUND=1
for cmd in implement review test status; do
  if [[ -f "$PROJECT_DIR/.claude/skills/${cmd}.md" ]]; then
    CMD_SKILL_FOUND=0
    break
  fi
done
check "At least 1 command skill exists (implement/review/test/status)" "$CMD_SKILL_FOUND"

# --- CLAUDE.md ---
[[ -f "$PROJECT_DIR/CLAUDE.md" ]]
check "CLAUDE.md exists" "$?"

# Agent Delegation may be in CLAUDE.md directly or via @import delegation-rules.md
DELEG_FOUND=1
if grep -q "Agent Delegation" "$PROJECT_DIR/CLAUDE.md" 2>/dev/null; then
  DELEG_FOUND=0
elif grep -q "@import.*delegation-rules" "$PROJECT_DIR/CLAUDE.md" 2>/dev/null && \
     [[ -f "$PROJECT_DIR/.claude/delegation-rules.md" ]]; then
  DELEG_FOUND=0
fi
check "Agent Delegation rules configured" "$DELEG_FOUND"

# Model selection is now in agent frontmatter + ccma-config.sh comments
MODEL_FOUND=1
if grep -q "model:" "$PROJECT_DIR/.claude/agents/coder.md" 2>/dev/null; then
  MODEL_FOUND=0
fi
check "Model selection defined in agent frontmatter" "$MODEL_FOUND"

# disallowedTools enforcement for read-only agents (Claude Code 2.1+)
for agent in planner reviewer security-auditor retrospector; do
  if [[ -f "$PROJECT_DIR/.claude/agents/${agent}.md" ]]; then
    if grep -q "disallowedTools:" "$PROJECT_DIR/.claude/agents/${agent}.md" 2>/dev/null; then
      check "Agent ${agent}.md has disallowedTools (read-only enforcement)" "0"
    else
      check "Agent ${agent}.md has disallowedTools (read-only enforcement)" "1"
    fi
  fi
done

# maxTurns defined for at least one agent
MAXTURNS_FOUND=1
if grep -rq "maxTurns:" "$PROJECT_DIR/.claude/agents/" 2>/dev/null; then
  MAXTURNS_FOUND=0
fi
check "maxTurns defined in at least one agent" "$MAXTURNS_FOUND"

# --- Placeholder detection ---
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"

# --- Windows path compatibility (settings.json) ---
if [[ -f "$SETTINGS" ]]; then
  WIN_COMPAT=0
  if jq -r '.permissions.allow[]' "$SETTINGS" 2>/dev/null | grep -q '\*\*/'; then
    WIN_COMPAT=0
  else
    # Check if any Edit/Write patterns lack **/ prefix
    NON_GLOB=$(jq -r '.permissions.allow[]' "$SETTINGS" 2>/dev/null | grep -E '^(Edit|Write)\(' | grep -v '\*\*/' | wc -l)
    if [[ "$NON_GLOB" -gt 0 ]]; then
      WIN_COMPAT=1
    fi
  fi
  check "Permission patterns use **/ prefix (Windows compat)" "$WIN_COMPAT"
fi
if [[ -f "$CLAUDE_MD" ]]; then
  PLACEHOLDERS_FOUND=0
  for ph in "[YOUR BUILD COMMAND]" "[YOUR TEST COMMAND]" "[YOUR LINT COMMAND]" "[YOUR START COMMAND]" "[PROJECT NAME]"; do
    if grep -qF "$ph" "$CLAUDE_MD" 2>/dev/null; then
      ((PLACEHOLDERS_FOUND++))
    fi
  done
  [[ "$PLACEHOLDERS_FOUND" -eq 0 ]]
  check "CLAUDE.md has no unfilled placeholders" "$?"
fi

# --- Language consistency (delegation rules should be English-only) ---
DELEG_FILE="$PROJECT_DIR/.claude/delegation-rules.md"
if [[ -f "$DELEG_FILE" ]]; then
  GERMAN_FOUND=0
  for word in "Begründung" "Modell" "Planung" "erfordert" "Empfehlung" "bindend" "nötig" "Jeder" "musst" "editieren"; do
    if grep -qi "$word" "$DELEG_FILE" 2>/dev/null; then
      GERMAN_FOUND=1
      break
    fi
  done
  [[ "$GERMAN_FOUND" -eq 0 ]]
  check "Delegation rules are English-only (no German detected)" "$?"
fi

# --- Delegation rules length check ---
if [[ -f "$DELEG_FILE" ]]; then
  LINE_COUNT=$(grep -cv '^\s*$\|^\s*<!--' "$DELEG_FILE" 2>/dev/null || echo 999)
  [[ "$LINE_COUNT" -le 145 ]]
  check "Delegation rules are concise (<= 145 non-blank/non-comment lines, actual: $LINE_COUNT)" "$?"
fi

# --- Disruption proposals check ---
PROPOSALS_FILE="$PROJECT_DIR/${CCMA_DISRUPTION_PROPOSALS:-.ccma/disruption-proposals.md}"
if [[ -f "$PROPOSALS_FILE" ]] && [[ -s "$PROPOSALS_FILE" ]]; then
  PROPOSAL_COUNT=$(grep -c '^## Proposal' "$PROPOSALS_FILE" 2>/dev/null; true)
  echo "  [WARN] disruption-proposals.md has $PROPOSAL_COUNT unreviewed proposal(s)"
  echo "         Review and apply to ccma-config.sh, then clear the file."
  # NOTE: This is a warning, not a FAIL — proposals don't block framework usage.
fi

# --- Scratchpad ---
[[ -f "$PROJECT_DIR/.ccma/scratchpad.md" ]]
check "scratchpad.md exists" "$?"

# --- Bash guard smoke test ---
if command -v jq &>/dev/null; then
  # Test: allowed command
  echo '{"tool_name":"Bash","tool_input":{"command":"git diff"}}' | "$SCRIPT_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  check "Bash guard allows 'git diff'" "$?"

  # Test: blocked command (expect exit 2 = blocked)
  echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | "$SCRIPT_DIR/ccma-bash-guard.sh" >/dev/null 2>&1
  RC_BLOCK=$?
  [[ "$RC_BLOCK" -eq 2 ]]
  check "Bash guard blocks 'rm -rf /'" "$?"

  # Test: file guard allows normal file
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts"}}' | "$SCRIPT_DIR/ccma-sensitive-file-guard.sh" >/dev/null 2>&1
  check "File guard allows 'src/app.ts'" "$?"

  # Test: file guard blocks .env (expect exit 2 = blocked)
  echo '{"tool_name":"Write","tool_input":{"file_path":".env"}}' | "$SCRIPT_DIR/ccma-sensitive-file-guard.sh" >/dev/null 2>&1
  RC_FILE=$?
  [[ "$RC_FILE" -eq 2 ]]
  check "File guard blocks '.env'" "$?"
fi

# --- Summary ---
echo ""
echo "============================================"
TOTAL=$((PASS + FAIL))
echo "  Results: $PASS/$TOTAL passed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo "  All checks passed! Framework is ready."
else
  echo "  $FAIL check(s) failed. Fix issues and re-run."
fi
echo ""
exit $FAIL
