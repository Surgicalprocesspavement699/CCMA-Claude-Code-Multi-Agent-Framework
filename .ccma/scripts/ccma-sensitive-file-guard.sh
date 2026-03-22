#!/usr/bin/env bash
# ============================================================================
# CCMA Sensitive File Guard — PreToolUse hook for file write protection
# ============================================================================
# Exit codes: 0 = allow, 2 = block, 1 = error
# Input: JSON via stdin (tool_name, tool_input.file_path)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

# --- Read hook input from stdin ---
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"

# Strip CRLF (Windows sends \r\n in JSON strings)
FILE_PATH="$(printf '%s' "$FILE_PATH" | tr -d '\r')"

# Only process Edit, Write, and NotebookEdit tool calls
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "NotebookEdit" ]]; then
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  echo "CCMA File Guard: no file_path in tool input."
  exit 0
fi

ccma_debug "Checking file: $FILE_PATH"

# --- Normalize path ---
# Windows sends absolute paths with backslashes (C:\Users\...\project\.claude\agents\coder.md).
# We need to match these against relative patterns like ".claude/agents/*.md".

# Step 1: Convert backslashes to forward slashes (Windows → Unix)
NORMALIZED="$(printf '%s' "$FILE_PATH" | sed 's|\\|/|g')"

# Step 2: Try realpath for relative path (works on Linux/Mac, often fails on Windows)
if command -v realpath &>/dev/null && [[ -e "$FILE_PATH" || -L "$FILE_PATH" ]]; then
  REL="$(realpath --relative-to=. "$FILE_PATH" 2>/dev/null || echo "")"
  if [[ -n "$REL" ]]; then
    NORMALIZED="$REL"
  fi
fi

# Step 3: Extract project-relative portion from absolute paths
# If the path contains .claude/ or scripts/ccma-, extract from that point
# This handles: C:/Users/Familie/Desktop/project/.claude/agents/coder.md → .claude/agents/coder.md
if [[ "$NORMALIZED" == /* || "$NORMALIZED" == ?:/* ]]; then
  # Absolute path (Unix /... or Windows C:/...)
  # Try to extract from known framework paths
  for anchor in ".claude/" "scripts/ccma-"; do
    if [[ "$NORMALIZED" == *"$anchor"* ]]; then
      NORMALIZED="${NORMALIZED##*/$anchor}"
      NORMALIZED="${anchor}${NORMALIZED}"
      break
    fi
  done
fi

# Step 4: Strip leading ./ repeatedly
while [[ "$NORMALIZED" == ./* ]]; do
  NORMALIZED="${NORMALIZED#./}"
done

# Step 5: Collapse // → /
while [[ "$NORMALIZED" == *//* ]]; do
  NORMALIZED="${NORMALIZED//\/\//\/}"
done

# Remove trailing /
NORMALIZED="${NORMALIZED%/}"

BASENAME="$(basename "$NORMALIZED")"

ccma_debug "Normalized: $NORMALIZED (basename: $BASENAME)"

# --- Match against sensitive patterns ---
match_pattern() {
  local value="$1"
  local pattern="$2"

  # Use bash extended globbing for matching
  # shellcheck disable=SC2254
  case "$value" in
    $pattern) return 0 ;;
  esac
  return 1
}

for pattern in "${CCMA_SENSITIVE_PATTERNS[@]}"; do
  # Check full normalized path
  if match_pattern "$NORMALIZED" "$pattern"; then
    ccma_block "file-guard" \
      "CCMA File Guard: BLOCKED — '$FILE_PATH' matches protected pattern '$pattern'. To allow: remove '$pattern' from CCMA_SENSITIVE_PATTERNS in scripts/ccma-config.sh." \
      "$FILE_PATH"
  fi
  # Check basename only
  if match_pattern "$BASENAME" "$pattern"; then
    ccma_block "file-guard" \
      "CCMA File Guard: BLOCKED — '$FILE_PATH' (basename '$BASENAME') matches protected pattern '$pattern'. To allow: remove '$pattern' from CCMA_SENSITIVE_PATTERNS in scripts/ccma-config.sh." \
      "$FILE_PATH"
  fi
done

ccma_debug "File ALLOWED: $FILE_PATH"

# --- Orchestrator write guard (observability, non-blocking) ---
if [[ "${#CCMA_ORCHESTRATOR_PROTECTED_PATHS[@]}" -gt 0 ]]; then
  for protected in "${CCMA_ORCHESTRATOR_PROTECTED_PATHS[@]}"; do
    if [[ "$FILE_PATH" == *"$protected"* ]]; then
      WARNING="CCMA Orchestrator Guard: Writing to protected path '$FILE_PATH'. Ensure this write originates from the coder/tester agent, not the orchestrator directly."
      echo "$WARNING" >&2
      # Log to disruption log (non-fatal)
      if command -v jq &>/dev/null; then
        entry="$(jq -cn \
          --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          --arg g "orchestrator-guard" \
          --arg r "$WARNING" \
          --arg d "$FILE_PATH" \
          '{timestamp: $ts, guard: $g, reason: $r, detail: $d}'
        )" 2>/dev/null
        mkdir -p "$(dirname "$CCMA_DISRUPTION_LOG")" 2>/dev/null
        echo "$entry" >> "$CCMA_DISRUPTION_LOG" 2>/dev/null
      fi
      break
    fi
  done
fi

exit 0
