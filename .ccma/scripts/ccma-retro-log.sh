#!/usr/bin/env bash
# ============================================================================
# CCMA Retrospective Logger — Writes structured retro data
# ============================================================================
# Usage:
#   echo '<JSON>' | ./.ccma/scripts/ccma-retro-log.sh
#   ./.ccma/scripts/ccma-retro-log.sh --adaptations "<markdown>"
#   ./.ccma/scripts/ccma-retro-log.sh --skip "<task_id>"
#
# Called by: retrospector agent (via Bash tool)
# Outputs to: .claude/retrospective-log.jsonl, .claude/process-adaptations.md
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config if available
if [[ -f "$SCRIPT_DIR/ccma-config.sh" ]]; then
  source "$SCRIPT_DIR/ccma-config.sh"
fi

# Paths (can be overridden by config)
RETRO_LOG="${CCMA_RETRO_LOG:-.claude/retrospective-log.jsonl}"
ADAPTATIONS="${CCMA_PROCESS_ADAPTATIONS:-.ccma/process-adaptations.md}"
PROJECT_DIR="${SCRIPT_DIR}/../.."

# --- Mode: --adaptations ---
if [[ "${1:-}" == "--adaptations" ]]; then
  shift
  CONTENT="${1:-}"

  if [[ -z "$CONTENT" ]]; then
    echo "[CCMA-RETRO] ERROR: --adaptations requires content argument" >&2
    exit 1
  fi

  # Append to adaptations file (create with header if new)
  if [[ ! -f "$PROJECT_DIR/$ADAPTATIONS" ]]; then
    {
      echo "# CCMA Process Adaptations"
      echo ""
      echo "<!-- Proposals from retrospective analysis. Requires HUMAN review. -->"
      echo "<!-- Do NOT apply these automatically. Review, discuss, then implement manually. -->"
      echo ""
    } > "$PROJECT_DIR/$ADAPTATIONS"
  fi

  {
    echo ""
    echo "---"
    echo ""
    echo "$CONTENT"
  } >> "$PROJECT_DIR/$ADAPTATIONS"

  echo "[CCMA-RETRO] Adaptations written to $ADAPTATIONS" >&2
  exit 0
fi

# --- Mode: --skip ---
if [[ "${1:-}" == "--skip" ]]; then
  TASK_ID="${2:-unknown}"
  TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  ENTRY=$(jq -nc \
    --arg ts "$TIMESTAMP" \
    --arg tid "$TASK_ID" \
    '{
      task_id: $tid,
      timestamp: $ts,
      trigger: "human_skip",
      classification_audit: null,
      rework_analysis: [],
      planner_accuracy: null,
      agent_signals: {},
      adaptations: []
    }')

  echo "$ENTRY" >> "$PROJECT_DIR/$RETRO_LOG"
  echo "[CCMA-RETRO] Skip recorded for task $TASK_ID" >&2
  exit 0
fi

# --- Mode: stdin (structured JSON from retrospector) ---
INPUT="$(cat 2>/dev/null || true)"

if [[ -z "$INPUT" ]]; then
  echo "[CCMA-RETRO] ERROR: No input received on stdin" >&2
  echo "Usage: echo '<JSON>' | ./.ccma/scripts/ccma-retro-log.sh" >&2
  exit 1
fi

# Validate JSON
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo "[CCMA-RETRO] ERROR: Invalid JSON received" >&2
  echo "$INPUT" | head -5 >&2
  exit 1
fi

# Ensure required fields exist
TASK_ID="$(echo "$INPUT" | jq -r '.task_id // empty')"
if [[ -z "$TASK_ID" ]]; then
  echo "[CCMA-RETRO] ERROR: JSON missing required field 'task_id'" >&2
  exit 1
fi

# Ensure timestamp exists (add if missing)
HAS_TS="$(echo "$INPUT" | jq -r '.timestamp // empty')"
if [[ -z "$HAS_TS" ]]; then
  INPUT="$(echo "$INPUT" | jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {timestamp: $ts}')"
fi

# Compact to single line and append
echo "$INPUT" | jq -c '.' >> "$PROJECT_DIR/$RETRO_LOG"

# Count adaptations
ADAPT_COUNT="$(echo "$INPUT" | jq '.adaptations | length')"

echo "[CCMA-RETRO] Retrospective logged for task $TASK_ID ($ADAPT_COUNT adaptations)" >&2
exit 0
