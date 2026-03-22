#!/usr/bin/env bash
# ============================================================================
# CCMA Status Line — Live pipeline state display in terminal
# ============================================================================
# Outputs JSON for Claude Code's statusLine feature.
# Parses .ccma/scratchpad.md for current pipeline state.
# MUST be fast (<100ms) — runs on every prompt render.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRATCHPAD="$PROJECT_DIR/.ccma/scratchpad.md"

# Default values
TASK_ID=""
TASK_CLASS=""
STAGE=""
REWORK="0"
STATUS=""
TESTS_PASS="0"

# Parse scratchpad (fast grep, no jq needed)
if [[ -f "$SCRATCHPAD" ]]; then
  TASK_ID="$(grep -oP 'task_id\*\*:\s*\K\S+' "$SCRATCHPAD" 2>/dev/null || echo "")"
  TASK_CLASS="$(grep -oP 'task_class\*\*:\s*\K\S+' "$SCRATCHPAD" 2>/dev/null || echo "")"
  STAGE="$(grep -oP 'pipeline_stage\*\*:\s*\K\S+' "$SCRATCHPAD" 2>/dev/null || echo "")"
  REWORK="$(grep -oP 'rework_count\*\*:\s*\K[0-9]+' "$SCRATCHPAD" 2>/dev/null || echo "0")"
  STATUS="$(grep -oP 'last_agent_status\*\*:\s*\K\S+' "$SCRATCHPAD" 2>/dev/null || echo "")"
  TESTS_PASS="$(grep -oP '\*\*pass\*\*:\s*\K[0-9]+' "$SCRATCHPAD" 2>/dev/null || echo "0")"
fi

# Build display string
if [[ -z "$TASK_ID" || "$TASK_ID" == "(none)" ]]; then
  DISPLAY="CCMA idle"
else
  # Short task slug (last part of task_id)
  SLUG="${TASK_ID##*-}"
  
  # Rework indicator
  RW_INDICATOR=""
  if [[ "$REWORK" -gt 0 ]]; then
    RW_INDICATOR=" rw:${REWORK}"
  fi
  
  # Status emoji
  case "$STATUS" in
    SUCCESS)  S_ICON="✓" ;;
    PARTIAL)  S_ICON="△" ;;
    ERROR)    S_ICON="✗" ;;
    *)        S_ICON="…" ;;
  esac
  
  DISPLAY="CCMA ${TASK_CLASS:-?} → ${STAGE:-?} ${S_ICON}${RW_INDICATOR} [${TESTS_PASS}t]"
fi

# Output JSON for Claude Code statusLine
# Format: { "statusLine": "text" } or just plain text
echo "$DISPLAY"
