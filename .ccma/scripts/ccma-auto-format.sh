#!/usr/bin/env bash
# ============================================================================
# CCMA Auto-Format — PostToolUse hook for automatic code formatting
# ============================================================================
# Exit codes: always 0 (PostToolUse must never block)
# Input: JSON via stdin (tool_name, tool_input.file_path)
# ============================================================================
set -uo pipefail
# Note: no set -e — we must always exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

# --- Read hook input from stdin ---
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"

# Only process Edit, Write, and NotebookEdit tool calls
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "NotebookEdit" ]]; then
  exit 0
fi

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  ccma_debug "File not found or empty path: $FILE_PATH"
  exit 0
fi

# --- Extract file extension (lowercased) ---
EXTENSION="${FILE_PATH##*.}"
EXTENSION="$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')"

ccma_debug "Formatting file: $FILE_PATH (extension: $EXTENSION)"

# --- Find matching formatter from config ---
run_formatter() {
  local ext="$1"

  for entry in "${CCMA_FORMATTERS[@]}"; do
    IFS=':' read -r cfg_ext primary primary_flags fallback fallback_flags <<< "$entry"

    if [[ "$cfg_ext" != "$ext" ]]; then
      continue
    fi

    # Try primary formatter
    if [[ "$primary" != "-" ]] && command -v "$primary" &>/dev/null; then
      ccma_debug "Running primary formatter: $primary"
      format_file "$primary" "$primary_flags"
      return 0
    fi

    # Try fallback formatter
    if [[ "$fallback" != "-" ]] && command -v "$fallback" &>/dev/null; then
      echo "[CCMA Auto-Format] Primary '$primary' not found, using fallback '$fallback' for $FILE_PATH" >&2
      ccma_debug "Running fallback formatter: $fallback"
      format_file "$fallback" "$fallback_flags"
      return 0
    fi

    # Neither available
    if [[ "$primary" != "-" ]]; then
      echo "[CCMA Auto-Format] No formatter available for .$ext (tried: $primary, $fallback). File not formatted." >&2
    fi
    return 0
  done

  # No matching extension in config — silent no-op
  ccma_debug "No formatter configured for .$ext"
  return 0
}

# --- Execute formatter generically ---
# All formatters are invoked as: <formatter> [flags] <file>
# The flags in ccma-config.sh MUST include any write/in-place flags
# (e.g., "--write", "-i", "-w") since this function is fully generic.
format_file() {
  local formatter="$1"
  local flags="$2"

  if [[ "$flags" != "-" ]]; then
    # shellcheck disable=SC2086
    "$formatter" $flags "$FILE_PATH" 2>/dev/null || ccma_debug "$formatter warning (non-fatal)"
  else
    "$formatter" "$FILE_PATH" 2>/dev/null || ccma_debug "$formatter warning (non-fatal)"
  fi
}

run_formatter "$EXTENSION"

# PostToolUse: ALWAYS exit 0
exit 0
