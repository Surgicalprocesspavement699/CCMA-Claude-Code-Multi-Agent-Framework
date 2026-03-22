#!/usr/bin/env bash
# ============================================================================
# CCMA Pre-Compact — Saves recovery state before context compaction
# ============================================================================
# Fires on: manual /compact or automatic compaction
# Saves: scratchpad, current-plan, recent log entries, transcript backup
# The SessionStart hook loads this after compaction completes.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$SCRIPT_DIR/ccma-config.sh" ]]; then
  source "$SCRIPT_DIR/ccma-config.sh"
fi

RECOVERY_FILE="$PROJECT_DIR/.claude/compact-recovery.md"
ARCHIVE_DIR="$PROJECT_DIR/.claude/archives/compactions"

# Read hook input
INPUT="$(cat 2>/dev/null || true)"
TRIGGER="$(echo "$INPUT" | jq -r '.trigger // "unknown"' 2>/dev/null || echo "unknown")"
TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")"

mkdir -p "$ARCHIVE_DIR"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

# --- 1. Save recovery context ---
{
  echo "# CCMA Recovery Context"
  echo "Saved at: $TIMESTAMP (trigger: $TRIGGER)"
  echo ""

  # Scratchpad (the most critical piece)
  if [[ -f "$PROJECT_DIR/.ccma/scratchpad.md" ]]; then
    echo "## Pipeline State (Scratchpad)"
    cat "$PROJECT_DIR/.ccma/scratchpad.md"
    echo ""
  fi

  # Current plan
  if [[ -f "$PROJECT_DIR/.ccma/current-plan.md" ]]; then
    echo "## Current Plan"
    cat "$PROJECT_DIR/.ccma/current-plan.md"
    echo ""
  fi

  # Last 10 pipeline events
  if [[ -f "$PROJECT_DIR/$CCMA_PIPELINE_LOG" ]] && [[ -s "$PROJECT_DIR/$CCMA_PIPELINE_LOG" ]]; then
    echo "## Recent Pipeline Events (last 10)"
    echo '```'
    tail -10 "$PROJECT_DIR/$CCMA_PIPELINE_LOG"
    echo '```'
    echo ""
  fi

  # Last 5 activity events (agent calls only)
  if [[ -f "$PROJECT_DIR/$CCMA_ACTIVITY_LOG" ]] && [[ -s "$PROJECT_DIR/$CCMA_ACTIVITY_LOG" ]]; then
    echo "## Recent Agent Invocations"
    echo '```'
    grep '"Agent"' "$PROJECT_DIR/$CCMA_ACTIVITY_LOG" 2>/dev/null | tail -5
    echo '```'
    echo ""
  fi

  # Disruption count since watermark
  if [[ -f "$PROJECT_DIR/$CCMA_DISRUPTION_LOG" ]]; then
    local_count=$(wc -l < "$PROJECT_DIR/$CCMA_DISRUPTION_LOG" 2>/dev/null || echo 0)
    echo "## Disruptions: $local_count total blocks this session"
    echo ""
  fi

} > "$RECOVERY_FILE"

echo "[CCMA] Recovery context saved to $RECOVERY_FILE" >&2

# --- 2. Archive transcript (if available) ---
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  cp "$TRANSCRIPT" "$ARCHIVE_DIR/transcript-$TIMESTAMP.jsonl" 2>/dev/null
  echo "[CCMA] Transcript archived: transcript-$TIMESTAMP.jsonl" >&2
fi

# Always exit 0 — PreCompact must not block compaction
exit 0
