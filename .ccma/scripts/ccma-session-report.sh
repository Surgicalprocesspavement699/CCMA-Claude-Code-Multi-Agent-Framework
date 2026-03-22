#!/usr/bin/env bash
# ============================================================================
# CCMA Session Report — Combines all logs into a pipeline run summary
# ============================================================================
# Usage: ./.ccma/scripts/ccma-session-report.sh [--task-id ID] [--since TIMESTAMP]
# Without flags: reports on the most recent task_id found in the logs.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

# --- Parse arguments ---
TASK_ID=""
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --since)   SINCE="$2"; shift 2 ;;
    *)         shift ;;
  esac
done

# --- Auto-detect task ID from pipeline log if not given ---
if [[ -z "$TASK_ID" && -f "$CCMA_PIPELINE_LOG" ]]; then
  TASK_ID="$(tail -1 "$CCMA_PIPELINE_LOG" 2>/dev/null | jq -r '.task_id // empty' 2>/dev/null)"
fi

echo "============================================"
echo "  CCMA Session Report"
echo "============================================"
echo ""
if [[ -n "$TASK_ID" && "$TASK_ID" != "unknown" ]]; then
  echo "  Task ID: $TASK_ID"
fi
if [[ -n "$SINCE" ]]; then
  echo "  Since:   $SINCE"
fi
echo ""

# -----------------------------------------------
# 1. Pipeline Events (agent-level)
# -----------------------------------------------
echo "--- Pipeline Events ---"
if [[ -f "$CCMA_PIPELINE_LOG" ]]; then
  local_filter=""
  if [[ -n "$TASK_ID" && "$TASK_ID" != "unknown" ]]; then
    local_filter="select(.task_id == \"$TASK_ID\")"
  elif [[ -n "$SINCE" ]]; then
    local_filter="select(.timestamp >= \"$SINCE\")"
  fi

  if [[ -n "$local_filter" ]]; then
    jq -r "$local_filter | \"  \\(.timestamp)  \\(.agent | (. + \"            \")[:16])  \\(.status | (. + \"        \")[:10])  \\(.task_description)\"" "$CCMA_PIPELINE_LOG" 2>/dev/null
  else
    tail -20 "$CCMA_PIPELINE_LOG" | jq -r '"  \(.timestamp)  \(.agent | (. + "            ")[:16])  \(.status | (. + "        ")[:10])  \(.task_description)"' 2>/dev/null
  fi
else
  echo "  (no pipeline log found)"
fi
echo ""

# -----------------------------------------------
# 2. Activity Summary (tool-level)
# -----------------------------------------------
echo "--- Activity Summary ---"
if [[ -f "$CCMA_ACTIVITY_LOG" ]]; then
  # Filter by task_id or since
  ACTIVITY_FILTER="."
  if [[ -n "$TASK_ID" && "$TASK_ID" != "unknown" ]]; then
    ACTIVITY_FILTER="select(.task_id == \"$TASK_ID\")"
  elif [[ -n "$SINCE" ]]; then
    ACTIVITY_FILTER="select(.timestamp >= \"$SINCE\")"
  fi

  TOTAL_CALLS=$(jq -r "$ACTIVITY_FILTER" "$CCMA_ACTIVITY_LOG" 2>/dev/null | wc -l)
  echo "  Total tool calls: $TOTAL_CALLS"
  echo ""

  echo "  Calls by tool:"
  jq -r "$ACTIVITY_FILTER | .tool" "$CCMA_ACTIVITY_LOG" 2>/dev/null \
    | sort | uniq -c | sort -rn \
    | while read -r count tool; do
        printf "    %4d×  %s\n" "$count" "$tool"
      done
  echo ""

  # Agent invocations (the most interesting part)
  AGENT_CALLS=$(jq -r "$ACTIVITY_FILTER | select(.tool == \"Agent\") | .summary" "$CCMA_ACTIVITY_LOG" 2>/dev/null)
  if [[ -n "$AGENT_CALLS" ]]; then
    echo "  Agent invocations (in order):"
    echo "$AGENT_CALLS" | nl -ba | while read -r num agent; do
      printf "    %2d. %s\n" "$num" "$agent"
    done
    echo ""
  fi

  # Files touched (Write/Edit)
  echo "  Files written/edited:"
  jq -r "$ACTIVITY_FILTER | select(.tool == \"Write\" or .tool == \"Edit\") | .summary" "$CCMA_ACTIVITY_LOG" 2>/dev/null \
    | sort -u \
    | while read -r file; do
        echo "    - $file"
      done
  echo ""

  # Delegation check: did the orchestrator call Write/Edit directly?
  DIRECT_WRITES=$(jq -r "$ACTIVITY_FILTER | select((.tool == \"Write\" or .tool == \"Edit\") and (.task_id != \"unknown\"))" "$CCMA_ACTIVITY_LOG" 2>/dev/null | wc -l)
  AGENT_COUNT=$(jq -r "$ACTIVITY_FILTER | select(.tool == \"Agent\")" "$CCMA_ACTIVITY_LOG" 2>/dev/null | wc -l)
  if [[ "$DIRECT_WRITES" -gt 0 && "$AGENT_COUNT" -gt 0 ]]; then
    echo "  WARNING: $DIRECT_WRITES direct Write/Edit calls detected alongside $AGENT_COUNT agent invocations."
    echo "    This may indicate the orchestrator wrote code directly instead of delegating."
    echo "    Review the activity log for details."
    echo ""
  fi
else
  echo "  (no activity log found — is ccma-activity-log.sh registered in settings.json?)"
fi

# -----------------------------------------------
# 3. Disruption Summary
# -----------------------------------------------
echo "--- Disruptions ---"
if [[ -f "$CCMA_DISRUPTION_LOG" ]]; then
  DISRUPTION_FILTER="."
  if [[ -n "$SINCE" ]]; then
    DISRUPTION_FILTER="select(.timestamp >= \"$SINCE\")"
  fi

  DISRUPTION_COUNT=$(jq -r "$DISRUPTION_FILTER" "$CCMA_DISRUPTION_LOG" 2>/dev/null | wc -l)
  echo "  Guard blocks: $DISRUPTION_COUNT"

  if [[ "$DISRUPTION_COUNT" -gt 0 ]]; then
    echo "  Top blocked:"
    jq -r "$DISRUPTION_FILTER | .detail" "$CCMA_DISRUPTION_LOG" 2>/dev/null \
      | awk '{print $1}' | sed 's|.*/||' \
      | sort | uniq -c | sort -rn | head -5 \
      | while read -r count cmd; do
          printf "    %4d×  %s\n" "$count" "$cmd"
        done
  fi
else
  echo "  (no disruption log found)"
fi
echo ""

# -----------------------------------------------
# 4. Session Health Assessment
# -----------------------------------------------
echo "--- Session Health ---"

HEALTH="GOOD"
ISSUES=()

# Check: pipeline log exists and has entries
if [[ ! -f "$CCMA_PIPELINE_LOG" ]] || [[ $(wc -l < "$CCMA_PIPELINE_LOG") -eq 0 ]]; then
  ISSUES+=("No pipeline events logged — orchestrator may not be following logging rules")
  HEALTH="DEGRADED"
fi

# Check: high disruption rate
if [[ -f "$CCMA_DISRUPTION_LOG" ]]; then
  D_COUNT=$(wc -l < "$CCMA_DISRUPTION_LOG")
  if [[ "$D_COUNT" -gt 10 ]]; then
    ISSUES+=("$D_COUNT guard blocks — config may need tuning (run ccma-disruption-report.sh)")
    HEALTH="DEGRADED"
  fi
fi

# Check: no agent invocations but file writes exist (delegation violation indicator)
if [[ -f "$CCMA_ACTIVITY_LOG" ]]; then
  A_AGENTS=$(jq -r 'select(.tool == "Agent")' "$CCMA_ACTIVITY_LOG" 2>/dev/null | wc -l)
  A_WRITES=$(jq -r 'select(.tool == "Write" or .tool == "Edit")' "$CCMA_ACTIVITY_LOG" 2>/dev/null | wc -l)
  if [[ "$A_AGENTS" -eq 0 && "$A_WRITES" -gt 3 ]]; then
    ISSUES+=("$A_WRITES file writes but 0 agent invocations — possible delegation bypass")
    HEALTH="WARNING"
  fi
fi

echo "  Status: $HEALTH"
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  for issue in "${ISSUES[@]}"; do
    echo "  ! $issue"
  done
fi
echo ""

echo "============================================"
echo "  Log files:"
echo "    Pipeline:   $CCMA_PIPELINE_LOG"
echo "    Activity:   $CCMA_ACTIVITY_LOG"
echo "    Disruption: $CCMA_DISRUPTION_LOG"
echo "============================================"
