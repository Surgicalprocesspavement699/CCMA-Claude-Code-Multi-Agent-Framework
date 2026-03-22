#!/usr/bin/env bash
# ============================================================================
# CCMA Pipeline Logger — Appends structured JSONL entries to audit log
# ============================================================================
# Usage: ./.ccma/scripts/ccma-log.sh <agent> <status> <description>
# Example: ./.ccma/scripts/ccma-log.sh coder SUCCESS "Implemented auth module"
# ============================================================================
# Note: -e is intentionally omitted. This script is called by agents as their
# last step — a logging failure should not mask the agent's actual exit status.
# -u (nounset) and -o pipefail still catch programming errors.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

AGENT="${1:-unknown}"
STATUS="${2:-UNKNOWN}"
DESCRIPTION="${3:-}"

# Read rework_count from scratchpad if it exists.
# Expected format: "- **rework_count**: <number>" (Markdown key-value).
# The regex is intentionally loose to tolerate minor formatting variations.
REWORK=0
if [[ -f "$CCMA_SCRATCHPAD" ]]; then
  RAW="$(grep -oE 'rework_count[^0-9]*([0-9]+)' "$CCMA_SCRATCHPAD" 2>/dev/null | grep -oE '[0-9]+$' || true)"
  if [[ -n "$RAW" && "$RAW" =~ ^[0-9]+$ ]]; then
    REWORK="$RAW"
  fi
fi

# Read task_id from scratchpad if it exists.
TASK_ID="unknown"
if [[ -f "$CCMA_SCRATCHPAD" ]]; then
  RAW_ID="$(grep -oE 'task_id[^:]*:[[:space:]]*([^[:space:]]+)' "$CCMA_SCRATCHPAD" 2>/dev/null | sed 's/.*:[[:space:]]*//' || true)"
  if [[ -n "$RAW_ID" && "$RAW_ID" != "(none)" ]]; then
    TASK_ID="$RAW_ID"
  fi
fi

# --- Scratchpad health check (warn-only) ---
if [[ -f "$CCMA_SCRATCHPAD" ]]; then
  if [[ "$TASK_ID" == "unknown" && "$AGENT" != "orchestrator" ]]; then
    echo "[CCMA Warning] Scratchpad has no task_id but agent '$AGENT' is logging. Pipeline state may be inconsistent." >&2
  fi
  if [[ "$REWORK" -eq 0 ]] && grep -q "rework_count" "$CCMA_SCRATCHPAD" 2>/dev/null; then
    # rework_count key exists but parsed as 0 — could be correct or could be parse failure
    # Only warn if the raw text doesn't literally say "0"
    RAW_LINE="$(grep 'rework_count' "$CCMA_SCRATCHPAD" 2>/dev/null || true)"
    if [[ -n "$RAW_LINE" && ! "$RAW_LINE" =~ [[:space:]]0[[:space:]]*$ && ! "$RAW_LINE" =~ [[:space:]]0$ ]]; then
      echo "[CCMA Warning] Scratchpad rework_count may have failed to parse. Raw: $RAW_LINE" >&2
    fi
  fi
else
  echo "[CCMA Warning] Scratchpad not found at $CCMA_SCRATCHPAD — pipeline state unknown." >&2
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build JSON entry (jq is a hard requirement — see README prerequisites)
if ! command -v jq &>/dev/null; then
  echo "CCMA Error: jq is required but not installed. See README prerequisites." >&2
  exit 1
fi

ENTRY="$(jq -cn \
  --arg ts "$TIMESTAMP" \
  --arg agent "$AGENT" \
  --arg desc "$DESCRIPTION" \
  --arg status "$STATUS" \
  --argjson rework "$REWORK" \
  --arg tid "$TASK_ID" \
  '{timestamp: $ts, task_id: $tid, agent: $agent, task_description: $desc, status: $status, rework_cycle: $rework}'
)"

# Ensure log directory exists
mkdir -p "$(dirname "$CCMA_PIPELINE_LOG")"

# Append to log file
echo "$ENTRY" >> "$CCMA_PIPELINE_LOG"

ccma_debug "Logged: $AGENT $STATUS"
