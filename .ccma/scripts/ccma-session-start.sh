#!/usr/bin/env bash
# ============================================================================
# CCMA Session Start — Injects pipeline state into session context
# ============================================================================
# Fires on: session start, resume, clear, compact
# Output goes to Claude's context automatically (stdout → additionalContext)
# MUST be fast — runs on every session start
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source config for paths
if [[ -f "$SCRIPT_DIR/ccma-config.sh" ]]; then
  source "$SCRIPT_DIR/ccma-config.sh"
else
  CCMA_SCRATCHPAD=".ccma/scratchpad.md"
  CCMA_PIPELINE_LOG=".claude/pipeline-log.jsonl"
  CCMA_DISRUPTION_LOG=".claude/disruption-log.jsonl"
fi

# Read hook input to determine source (startup, resume, compact, clear)
INPUT="$(cat 2>/dev/null || true)"
SOURCE="$(echo "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null || echo "unknown")"

echo "## CCMA Framework Active"
echo ""

# Always show scratchpad state
if [[ -f "$PROJECT_DIR/$CCMA_SCRATCHPAD" ]]; then
  echo "### Current Pipeline State"
  cat "$PROJECT_DIR/$CCMA_SCRATCHPAD"
  echo ""
fi

# Show recovery context after compaction
if [[ "$SOURCE" == "compact" ]]; then
  echo "### ⚠ Context was compacted — state restored from scratchpad"
  echo "Read .ccma/scratchpad.md carefully before continuing."
  echo ""

  # Show recovery file if it exists (from PreCompact hook)
  if [[ -f "$PROJECT_DIR/.claude/compact-recovery.md" ]]; then
    echo "### Recovery Context (saved before compaction)"
    cat "$PROJECT_DIR/.claude/compact-recovery.md"
    echo ""
    # Clean up — one-shot
    rm -f "$PROJECT_DIR/.claude/compact-recovery.md"
  fi
fi

# Git status (brief)
if command -v git &>/dev/null && [[ -d "$PROJECT_DIR/.git" ]]; then
  echo "### Git Status"
  echo "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo 'unknown')"
  git -C "$PROJECT_DIR" status --short 2>/dev/null | head -10
  echo ""
fi

# Memory file eviction
MEMORY_FILE="$PROJECT_DIR/.ccma/MEMORY.md"
if [[ -f "$MEMORY_FILE" ]]; then
  MEMORY_LINES=$(wc -l < "$MEMORY_FILE" 2>/dev/null || echo 0)
  MAX_LINES="${CCMA_MEMORY_MAX_LINES:-150}"
  if [[ "$MEMORY_LINES" -gt "$MAX_LINES" ]]; then
    ARCHIVE_DIR="${CCMA_MEMORY_ARCHIVE_DIR:-.ccma/memory-archive}"
    mkdir -p "$PROJECT_DIR/$ARCHIVE_DIR"
    TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    KEEP=$((MAX_LINES / 2))
    # Archive oldest half
    head -n "$((MEMORY_LINES - KEEP))" "$MEMORY_FILE" \
      > "$PROJECT_DIR/$ARCHIVE_DIR/MEMORY-$TIMESTAMP.md" 2>/dev/null
    # Keep newest half
    tail -n "$KEEP" "$MEMORY_FILE" > "$MEMORY_FILE.tmp" \
      && mv "$MEMORY_FILE.tmp" "$MEMORY_FILE"
    echo "### CCMA: MEMORY.md trimmed ($MEMORY_LINES → $KEEP lines, archived to $ARCHIVE_DIR/MEMORY-$TIMESTAMP.md)"
    echo ""
  fi
fi

# Log sizes (quick health check)
echo "### Log Status"
for log in "$CCMA_PIPELINE_LOG" "$CCMA_DISRUPTION_LOG"; do
  local_path="$PROJECT_DIR/$log"
  if [[ -f "$local_path" ]]; then
    count=$(wc -l < "$local_path" 2>/dev/null || echo 0)
    echo "- $(basename "$log"): $count entries"
  fi
done
echo ""

# Retrospective enforcement
if [[ -f "$PROJECT_DIR/$CCMA_SCRATCHPAD" ]]; then
  RETRO_STATUS="$(grep -oP 'retro_status[^:]*:\s*\K\S+' "$PROJECT_DIR/$CCMA_SCRATCHPAD" 2>/dev/null || echo "none")"
  if [[ "$RETRO_STATUS" == "pending" ]]; then
    echo "### ⚠ RETROSPECTIVE PENDING"
    echo "A retrospective is required before starting the next task."
    echo "Run /retro to execute, or /retro --skip to bypass (logged)."
    echo ""
  fi

  # Show open adaptation count
  if [[ -f "$PROJECT_DIR/${CCMA_PROCESS_ADAPTATIONS:-.ccma/process-adaptations.md}" ]]; then
    ADAPT_COUNT=$(grep -c '^### ' "$PROJECT_DIR/${CCMA_PROCESS_ADAPTATIONS:-.ccma/process-adaptations.md}" 2>/dev/null || echo 0)
    if [[ "$ADAPT_COUNT" -gt 0 ]]; then
      echo "### Open Adaptations: $ADAPT_COUNT proposals awaiting human review"
      echo "See .claude/process-adaptations.md"
      echo ""
    fi
  fi

  # Show open disruption proposals
  PROPOSALS_FILE="$PROJECT_DIR/${CCMA_DISRUPTION_PROPOSALS:-.ccma/disruption-proposals.md}"
  if [[ -f "$PROPOSALS_FILE" ]] && [[ -s "$PROPOSALS_FILE" ]]; then
    PROPOSAL_COUNT=$(grep -c '^## Proposal' "$PROPOSALS_FILE" 2>/dev/null; true)
    echo "### Open Disruption Proposals: $PROPOSAL_COUNT config-change suggestion(s) awaiting review"
    echo "See .ccma/disruption-proposals.md — apply manually to ccma-config.sh"
    echo ""
  fi
fi

echo "### Delegation Reminder"
echo "You are the ORCHESTRATOR. Delegate ALL code work to agents. Read CLAUDE.md for rules."
