#!/usr/bin/env bash
# ============================================================================
# CCMA Framework — Post-Copy Setup Script
# ============================================================================
# Run this after copying the CCMA framework into a new project.
# It checks prerequisites, sets permissions, and detects project type.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
WARN=0

ok()   { echo "  [OK]   $1"; ((PASS++)); }
fail() { echo "  [FAIL] $1"; ((FAIL++)); }
warn() { echo "  [WARN] $1"; ((WARN++)); }
info() { echo "  [INFO] $1"; }

echo "============================================"
echo "  CCMA Framework Setup"
echo "============================================"
echo ""
echo "Project directory: $PROJECT_DIR"
echo ""

# --- 0. Create .ccma state directory ---
mkdir -p "$PROJECT_DIR/.ccma"
if [[ ! -f "$PROJECT_DIR/.ccma/scratchpad.md" && -f "$PROJECT_DIR/.ccma/scratchpad-template.md" ]]; then
  cp "$PROJECT_DIR/.ccma/scratchpad-template.md" "$PROJECT_DIR/.ccma/scratchpad.md"
  ok ".ccma/scratchpad.md created from template"
else
  ok ".ccma/ directory exists"
fi
echo ""

# --- 1. Prerequisites ---
echo "--- Prerequisites ---"

if command -v jq &>/dev/null; then
  ok "jq installed ($(jq --version 2>&1))"
else
  fail "jq not found — install with: brew install jq / apt install jq / choco install jq"
fi

BASH_MAJOR="${BASH_VERSINFO[0]}"
if [[ "$BASH_MAJOR" -ge 4 ]]; then
  ok "bash >= 4.0 ($BASH_VERSION)"
else
  fail "bash >= 4.0 required (found $BASH_VERSION)"
fi

if command -v git &>/dev/null; then
  ok "git installed ($(git --version 2>&1 | head -1))"
else
  warn "git not found — version control features will not work"
fi

echo ""

# --- 2. Hook Scripts ---
echo "--- Hook Scripts ---"

HOOKS=(ccma-bash-guard.sh ccma-sensitive-file-guard.sh ccma-auto-format.sh ccma-config.sh ccma-log.sh ccma-disruption-report.sh ccma-activity-log.sh ccma-session-report.sh ccma-session-start.sh ccma-pre-compact.sh ccma-retro-log.sh ccma-statusline.sh ccma-setup.sh ccma-verify.sh)
for hook in "${HOOKS[@]}"; do
  if [[ -f "$SCRIPT_DIR/$hook" ]]; then
    if [[ -x "$SCRIPT_DIR/$hook" ]]; then
      ok "$hook (executable)"
    else
      chmod +x "$SCRIPT_DIR/$hook"
      ok "$hook (made executable)"
    fi
  else
    fail "$hook not found in scripts/"
  fi
done

# --- Windows/WSL Note ---
if grep -qi microsoft /proc/version 2>/dev/null; then
  warn "WSL detected — chmod +x may not persist on NTFS-mounted directories. Consider cloning into a native Linux filesystem path (e.g., ~/projects/)."
fi

echo ""

# --- 3. Agent Definitions ---
echo "--- Agent Definitions ---"

AGENTS=(planner.md coder.md tester.md reviewer.md security-auditor.md retrospector.md)
AGENTS_DIR="$PROJECT_DIR/.claude/agents"
for agent in "${AGENTS[@]}"; do
  if [[ -f "$AGENTS_DIR/$agent" ]]; then
    ok "$agent"
  else
    fail "$agent not found in .claude/agents/"
  fi
done

echo ""

# --- 4. Configuration Files ---
echo "--- Configuration ---"

SETTINGS="$PROJECT_DIR/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
  if jq -e '.hooks' "$SETTINGS" &>/dev/null; then
    ok "settings.json (hooks configured)"
  else
    warn "settings.json exists but has no hooks section"
  fi
else
  fail "settings.json not found in .claude/"
fi

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]]; then
  if grep -q "Agent Delegation" "$CLAUDE_MD" || \
     (grep -q "@import.*delegation-rules" "$CLAUDE_MD" && [[ -f "$PROJECT_DIR/.claude/delegation-rules.md" ]]); then
    ok "CLAUDE.md (has Agent Delegation — direct or via @import)"
  else
    warn "CLAUDE.md exists but missing Agent Delegation section"
  fi
else
  fail "CLAUDE.md not found — create from template"
fi

echo ""

# --- 5. Initialize Pipeline Log ---
echo "--- Pipeline Log ---"

PIPELINE_LOG="$PROJECT_DIR/.claude/pipeline-log.jsonl"
if [[ ! -f "$PIPELINE_LOG" ]]; then
  touch "$PIPELINE_LOG"
  ok "pipeline-log.jsonl created"
else
  ok "pipeline-log.jsonl exists"
fi

DISRUPTION_LOG="$PROJECT_DIR/.claude/disruption-log.jsonl"
if [[ ! -f "$DISRUPTION_LOG" ]]; then
  touch "$DISRUPTION_LOG"
  ok "disruption-log.jsonl created"
else
  ok "disruption-log.jsonl exists"
fi

ACTIVITY_LOG="$PROJECT_DIR/.claude/activity-log.jsonl"
if [[ ! -f "$ACTIVITY_LOG" ]]; then
  touch "$ACTIVITY_LOG"
  ok "activity-log.jsonl created"
else
  ok "activity-log.jsonl exists"
fi

echo ""

# --- 6. Project Type Detection ---
echo "--- Project Detection ---"

detect_project() {
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    info "Node.js project detected (package.json)"
    info "  Suggested build: npm run build"
    info "  Suggested test:  npm test"
  fi
  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    info "Rust project detected (Cargo.toml)"
    info "  Suggested build: cargo build"
    info "  Suggested test:  cargo test"
  fi
  if [[ -f "$PROJECT_DIR/requirements.txt" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    info "Python project detected"
    info "  Suggested test: pytest"
  fi
  if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    info "Go project detected (go.mod)"
    info "  Suggested build: go build ./..."
    info "  Suggested test:  go test ./..."
  fi
  if [[ -f "$PROJECT_DIR/pom.xml" ]]; then
    info "Java/Maven project detected (pom.xml)"
    info "  Suggested build: mvn compile"
    info "  Suggested test:  mvn test"
  fi
  if [[ -f "$PROJECT_DIR/build.gradle" ]] || [[ -f "$PROJECT_DIR/build.gradle.kts" ]]; then
    info "Java/Gradle project detected"
    info "  Suggested build: gradle build"
    info "  Suggested test:  gradle test"
  fi
}

detect_project

echo ""

# --- 7. Check for placeholder CLAUDE.md ---
if [[ -f "$CLAUDE_MD" ]]; then
  if grep -q '\[YOUR BUILD COMMAND\]' "$CLAUDE_MD"; then
    warn "CLAUDE.md still has placeholder values — update Build & Run commands!"
  fi
  if grep -q '\[PROJECT NAME\]' "$CLAUDE_MD"; then
    warn "CLAUDE.md still has [PROJECT NAME] placeholder — update it!"
  fi
fi

# --- Summary ---
echo "============================================"
echo "  Setup Summary"
echo "============================================"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "  Framework is ready! Next steps:"
  echo "  1. Update CLAUDE.md with your project's build/test commands"
  echo "  2. Optionally adjust scripts/ccma-config.sh"
  echo "  3. Run: ./.ccma/scripts/ccma-verify.sh for a full check"
  echo "  4. Start Claude Code and try a task"
else
  echo "  Fix the failures above before using the framework."
fi
echo ""
