#!/usr/bin/env bash
# ============================================================================
# CCMA Activity Logger — PreToolUse hook for behavior tracking
# ============================================================================
# Logs every tool call to activity-log.jsonl for session analysis.
# MUST always exit 0 — this hook observes, never blocks.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

# Skip if activity logging is disabled
if [[ "$CCMA_ACTIVITY_LOGGING" != "true" ]]; then
  exit 0
fi

# --- Read hook input from stdin ---
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Strip CRLF (Windows sends \r\n in JSON strings)
TOOL_NAME="$(printf '%s' "$TOOL_NAME" | tr -d '\r')"

# Skip if we couldn't parse the input
if [[ -z "$TOOL_NAME" ]]; then
  exit 0
fi

# --- Extract a short summary based on tool type ---
SUMMARY=""
case "$TOOL_NAME" in
  Bash)
    SUMMARY="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    # Truncate long commands to 200 chars
    if [[ ${#SUMMARY} -gt 200 ]]; then
      SUMMARY="${SUMMARY:0:200}…"
    fi
    ;;
  Edit|Write|NotebookEdit)
    SUMMARY="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    ;;
  Read)
    SUMMARY="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    ;;
  Glob)
    SUMMARY="$(echo "$INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null)"
    ;;
  Grep)
    SUMMARY="$(echo "$INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null)"
    ;;
  Agent)
    # Agent invocations — try multiple possible field names
    # Claude Code's Agent tool structure may vary; try common patterns
    SUMMARY="$(echo "$INPUT" | jq -r '
      .tool_input.agent //
      .tool_input.name //
      .tool_input.agentName //
      .tool_input.agent_name //
      .tool_input.prompt[0:80] //
      (if .tool_input | keys | length > 0
       then (.tool_input | to_entries | map(.key + "=" + (.value | tostring)[0:30]) | join(", "))[0:100]
       else "unknown"
       end)
    ' 2>/dev/null)"
    # If still empty, dump the raw tool_input keys for debugging
    if [[ -z "$SUMMARY" ]]; then
      SUMMARY="$(echo "$INPUT" | jq -r '.tool_input | keys | join(",")' 2>/dev/null || echo 'unknown')"
    fi
    ;;
  *)
    # Unknown tool — log raw input keys
    SUMMARY="$(echo "$INPUT" | jq -r '.tool_input | keys | join(",")' 2>/dev/null)"
    ;;
esac

# --- Read task_id from scratchpad (best-effort) ---
TASK_ID="unknown"
if [[ -f "$CCMA_SCRATCHPAD" ]]; then
  RAW_ID="$(grep -oE 'task_id[^:]*:[[:space:]]*([^[:space:]]+)' "$CCMA_SCRATCHPAD" 2>/dev/null | sed 's/.*:[[:space:]]*//' || true)"
  if [[ -n "$RAW_ID" && "$RAW_ID" != "(none)" ]]; then
    TASK_ID="$RAW_ID"
  fi
fi

# --- Append to activity log ---
if command -v jq &>/dev/null; then
  ENTRY="$(jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg tool "$TOOL_NAME" \
    --arg summary "$SUMMARY" \
    --arg tid "$TASK_ID" \
    '{timestamp: $ts, task_id: $tid, tool: $tool, summary: $summary}'
  )" 2>/dev/null
  mkdir -p "$(dirname "$CCMA_ACTIVITY_LOG")" 2>/dev/null
  echo "$ENTRY" >> "$CCMA_ACTIVITY_LOG" 2>/dev/null
fi

# MUST always exit 0
exit 0
