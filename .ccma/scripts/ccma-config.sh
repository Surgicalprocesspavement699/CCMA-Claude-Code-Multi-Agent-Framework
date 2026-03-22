#!/usr/bin/env bash
# ============================================================================
# CCMA Framework — Central Configuration
# ============================================================================
# Version: 2.2.0
# All hook scripts source this file. Edit here to customize the entire
# framework for your project.
# ============================================================================

# ---------------------------------------------------------------------------
# 1. BASH GUARD — Command Whitelist
# ---------------------------------------------------------------------------
# Tier 1: Read-only commands (all agents, including planner/reviewer/auditor)
CCMA_TIER1_COMMANDS=(
  # Filesystem (read-only)
  ls find cat head tail wc
  # Directory change (needed on Windows where Claude Code prepends cd)
  cd
  # Version control (read-only; subcommands filtered separately)
  git
  # Text processing (sed without -i writes to stdout only; -i is blocked separately by redirect guard)
  grep awk sort uniq sed
  # Utilities
  echo pwd which date
  # Environment (needed for MSVC/toolchain PATH on Windows)
  export
  # Shell builtins / test utilities (read-only, no file modification)
  test "[" true false
  # Text processing (no file modification — output to stdout only)
  xargs tr paste cut bc
  # File comparison and metadata (read-only)
  diff comm basename dirname stat file realpath
)

# Tier 2: Build & test commands (write-capable agents: coder, tester)
CCMA_TIER2_COMMANDS=(
  # Node.js
  npm npx yarn pnpm bun node deno
  # Python
  python python3 pip pip3 uv
  # Rust
  cargo rustc
  # Go
  go
  # Build systems
  make cmake dotnet
  # Java / JVM
  mvn gradle javac
  # C / C++
  gcc g++
  # Web tooling
  tsc eslint
  # Test runners
  pytest jest vitest mocha bats
  # Other runtimes
  ruby php perl
  # Monorepo tools
  turbo nx
  # Containers (subcommands filtered separately)
  docker
  # Filesystem (write) — only mkdir/chmod. cp/mv/rm/ln are intentionally excluded:
  # agents use Write/Edit tools for file creation/modification (auditable via hooks),
  # and direct shell file operations would bypass the File Guard.
  mkdir chmod
  # CCMA framework scripts (called by agents for logging)
  ccma-log.sh ccma-verify.sh ccma-setup.sh
  ccma-retro-log.sh
  ccma-disruption-report.sh ccma-session-report.sh ccma-statusline.sh
  ccma-commit.sh
)

# Git subcommands allowed (read-only operations only).
# NOTE: git add/stash/checkout are intentionally excluded — staging and
# branch management are the orchestrator's or user's responsibility.
CCMA_GIT_ALLOWED_SUBCOMMANDS=(
  log diff status show
  ls-files ls-tree
  grep blame
  format-patch describe shortlog tag
)

# Docker subcommands allowed (safe operations only).
# NOTE: exec, rm, push, pull, login are intentionally excluded.
# WARNING: `docker run` with volume mounts (-v /:/host) can bypass all filesystem
# restrictions. If your threat model requires blocking this, remove `run` from
# this list and use `docker compose` exclusively (where volumes are declared in
# a committed docker-compose.yml that can be code-reviewed).
CCMA_DOCKER_ALLOWED_SUBCOMMANDS=(
  build run compose
  ps logs images
  inspect stop start restart
  version info
)

# Set to "true" to block shell redirects (>, >>, 2>, sed -i)
CCMA_BLOCK_REDIRECTS="true"

# Allowed source/dot-source patterns (regex).
# Python venvs often require sourcing. Add patterns as needed.
# Set to empty array to block ALL source commands.
CCMA_ALLOWED_SOURCE_PATTERNS=(
  '\.venv/bin/activate'
  'venv/bin/activate'
  'nvm\.sh'
)

# ---------------------------------------------------------------------------
# 2. SENSITIVE FILE GUARD — Protected file patterns
# ---------------------------------------------------------------------------
# Glob patterns matched against both full path and basename.
# Any file matching these patterns will be blocked from Edit/Write.
CCMA_SENSITIVE_PATTERNS=(
  ".env"
  ".env.*"
  "*.pem"
  "*.key"
  "*.p12"
  "*.pfx"
  "*secret*"
  "*credential*"
  "*password*"
  "*passwd*"
  "id_rsa"
  "id_ed25519"
  "CLAUDE.md"
  ".claude/agents/*.md"
  ".claude/settings.json"
  # Guard scripts — if an agent modifies these, it can bypass all enforcement.
  ".ccm./.ccma/scripts/ccma-*.sh"
  ".ccm./.ccma/scripts/ccma-config.sh"
  # Retrospective protection
  ".claude/agents/retrospector.md"
  ".ccm./.ccma/scripts/ccma-retro-log.sh"
)

# ---------------------------------------------------------------------------
# 2b. ORCHESTRATOR WRITE GUARD — Source paths the orchestrator should not touch
# ---------------------------------------------------------------------------
# These paths trigger a WARNING (not a block) when written outside of
# a recognized agent context. The guard cannot distinguish orchestrator
# from subagent calls, so exit code 0 is used (non-blocking). A disruption
# log entry is written for retrospective analysis.
# Add your project's source directories here.
# Leave empty to disable.
CCMA_ORCHESTRATOR_PROTECTED_PATHS=(
  "src/"
  "lib/"
  "app/"
  "pkg/"
)

# ---------------------------------------------------------------------------
# 3. AUTO-FORMAT — Formatter dispatch table
# ---------------------------------------------------------------------------
# Format: "extension:primary:primary_flags:fallback:fallback_flags"
# Use "-" for no fallback/no flags.
# IMPORTANT: Flags MUST include write/in-place mode flags (e.g., --write, -i, -w).
# The formatter is invoked generically as: <formatter> [flags] <file>
CCMA_FORMATTERS=(
  "rs:rustfmt:--edition 2021:-:-"
  "py:black:-q:autopep8:--in-place"
  "js:biome:format --write:prettier:--write"
  "ts:biome:format --write:prettier:--write"
  "jsx:biome:format --write:prettier:--write"
  "tsx:biome:format --write:prettier:--write"
  "mjs:biome:format --write:prettier:--write"
  "cjs:biome:format --write:prettier:--write"
  "json:prettier:--write:-:-"
  "yaml:prettier:--write:-:-"
  "yml:prettier:--write:-:-"
  "md:prettier:--write:-:-"
  "mdx:prettier:--write:-:-"
  "go:gofmt:-w:-:-"
  "c:clang-format:-i:-:-"
  "cpp:clang-format:-i:-:-"
  "cc:clang-format:-i:-:-"
  "cxx:clang-format:-i:-:-"
  "h:clang-format:-i:-:-"
  "hpp:clang-format:-i:-:-"
  "cs:clang-format:-i:-:-"
  "java:clang-format:-i:-:-"
  "sh:shfmt:-w:-:-"
  "bash:shfmt:-w:-:-"
)

# ---------------------------------------------------------------------------
# 4. MODEL SELECTION — DOCUMENTATION ONLY
# ---------------------------------------------------------------------------
# These variables are NOT read by any script or hook. They serve as a
# human-readable reference for which model each agent uses.
#
# The ACTUAL model is defined in each agent's frontmatter:
#   .claude/agents/<agent>.md → model: <value>
#
# To change an agent's model, edit the agent file directly.
# The upgrade recommendations below are suggestions for higher task classes.
# ---------------------------------------------------------------------------
# Valid values: sonnet, opus, haiku
CCMA_MODEL_PLANNER="sonnet"
CCMA_MODEL_CODER="opus"            # Always Opus: writes production code
CCMA_MODEL_TESTER="sonnet"
CCMA_MODEL_REVIEWER="opus"         # Always Opus: must catch what coder missed
CCMA_MODEL_SECURITY="opus"          # Always Opus: last line of defense

# Auto-upgrade rules: override model for higher task classes.
# Format: comma-separated "agent:model" pairs.
# These OVERRIDE the defaults above for the specified task class and higher.
# NOTE: security-auditor is already opus by default (no upgrade needed).
CCMA_MODEL_UPGRADE_COMPLEX="planner:opus"
CCMA_MODEL_UPGRADE_ARCHITECTURE="planner:opus"

# ---------------------------------------------------------------------------
# 5. PIPELINE SETTINGS
# ---------------------------------------------------------------------------
# Maximum rework cycles before escalation to human
CCMA_MAX_REWORK=3

# maxTurns overrides per task class (passed to Agent tool invocations)
# These override the agent frontmatter defaults for the coder agent.
# Adjust based on your project's typical complexity.
CCMA_CODER_MAX_TURNS_TRIVIAL=15
CCMA_CODER_MAX_TURNS_STANDARD=40
CCMA_CODER_MAX_TURNS_COMPLEX=60
CCMA_CODER_MAX_TURNS_ARCHITECTURE=80

# Task classes (for reference; used by orchestrator in CLAUDE.md)
# MICRO:         1 file, <=5 lines, no logic change   → Orchestrator directly
# TRIVIAL:       <=3 files, <=20 lines, non-security   → Coder + Tester
# STANDARD:      <=7 files, clear scope                → Planner + Coder + Tester + Reviewer
# COMPLEX:       >7 files or architectural decision     → Full pipeline + Security
# ARCHITECTURE:  Fundamental structural change          → Iterative Planner + Full pipeline

# Security-sensitive path patterns (elevate to minimum STANDARD)
CCMA_SECURITY_PATHS=(
  "auth"
  "crypto"
  "middleware"
  "*.pem"
  "*.key"
  ".env*"
  "package.json"
  "Cargo.toml"
  "requirements.txt"
  "go.mod"
  "pom.xml"
)

# Parallel execution (Linux only)
# Set to "true" to enable parallel coder dispatching.
# REQUIRES: Linux with native ext4/btrfs filesystem. NOT supported on Windows/WSL.
# When enabled: orchestrator dispatches multiple coder agents in one message
# for subtasks in the same Parallel-group. Each parallel coder skips
# scratchpad writes (step 9). Orchestrator consolidates after all complete.
CCMA_PARALLEL_ENABLED="false"

# Auto-commit after successful pipeline completion (default: false)
# When true: orchestrator calls ccma-commit.sh after SUCCESS.
# Commits with message: "CCMA: <task_id> [TASK_CLASS] <summary>"
# Requires: ccma-commit.sh in CCMA_TIER2_COMMANDS whitelist (already included above).
CCMA_AUTO_COMMIT="false"

# ---------------------------------------------------------------------------
# 6. LOGGING
# ---------------------------------------------------------------------------
# Pipeline audit log path (JSONL format)
# Use ${VAR:-default} so tests can override via environment variables.
CCMA_PIPELINE_LOG="${CCMA_PIPELINE_LOG:-.claude/pipeline-log.jsonl}"

# Scratchpad path (state persistence)
CCMA_SCRATCHPAD="${CCMA_SCRATCHPAD:-.ccma/scratchpad.md}"

# Disruption log: records every guard block for pattern analysis
# Format: JSONL — one entry per blocked action
CCMA_DISRUPTION_LOG="${CCMA_DISRUPTION_LOG:-.claude/disruption-log.jsonl}"

# Disruption proposals: orchestrator writes config change suggestions here
CCMA_DISRUPTION_PROPOSALS="${CCMA_DISRUPTION_PROPOSALS:-.ccma/disruption-proposals.md}"

# Activity log: records every tool call for behavior analysis
# Format: JSONL — one entry per tool invocation (PreToolUse)
# WARNING: This log grows fast in long sessions. Rotate or clear between tasks.
CCMA_ACTIVITY_LOG="${CCMA_ACTIVITY_LOG:-.claude/activity-log.jsonl}"

# Retrospective paths
CCMA_RETRO_LOG="${CCMA_RETRO_LOG:-.claude/retrospective-log.jsonl}"
CCMA_PROCESS_ADAPTATIONS="${CCMA_PROCESS_ADAPTATIONS:-.claude/process-adaptations.md}"

# Memory file management
# MEMORY.md is trimmed to this line count on session start.
# Oldest entries (top of file) are archived to .ccma/memory-archive/.
CCMA_MEMORY_MAX_LINES=150
CCMA_MEMORY_ARCHIVE_DIR="${CCMA_MEMORY_ARCHIVE_DIR:-.ccma/memory-archive}"

# Enable/disable activity logging (set "false" to reduce hook overhead)
CCMA_ACTIVITY_LOGGING="true"

# Enable verbose hook logging to stderr (set "true" for debugging)
CCMA_HOOK_DEBUG="false"

# ---------------------------------------------------------------------------
# Helper: debug log (used by all hook scripts)
# ---------------------------------------------------------------------------
ccma_debug() {
  if [[ "$CCMA_HOOK_DEBUG" == "true" ]]; then
    echo "[CCMA $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
  fi
}

# ---------------------------------------------------------------------------
# Helper: block with disruption logging (used by guard scripts)
# ---------------------------------------------------------------------------
# Usage: ccma_block <guard_name> <reason> <raw_command_or_path>
# - Prints the reason to stdout (Claude Code hook response)
# - Duplicates to stderr (fallback if stdout is swallowed)
# - Appends a JSONL entry to the disruption log
# - Exits with code 2 (block)
ccma_block() {
  local guard="$1"
  local reason="$2"
  local detail="${3:-}"

  # Message to agent (stdout + stderr for reliability)
  echo "$reason"
  echo "$reason" >&2

  # Append to disruption log (best-effort, never fatal)
  if command -v jq &>/dev/null; then
    local entry
    entry="$(jq -cn \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg g "$guard" \
      --arg r "$reason" \
      --arg d "$detail" \
      '{timestamp: $ts, guard: $g, reason: $r, detail: $d}'
    )" 2>/dev/null
    mkdir -p "$(dirname "$CCMA_DISRUPTION_LOG")" 2>/dev/null
    echo "$entry" >> "$CCMA_DISRUPTION_LOG" 2>/dev/null
  fi

  exit 2
}
