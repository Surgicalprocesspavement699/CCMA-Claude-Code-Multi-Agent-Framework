#!/usr/bin/env bash
# ============================================================================
# CCMA Bash Guard — PreToolUse hook for command whitelist enforcement
# ============================================================================
# Exit codes: 0 = allow, 2 = block, 1 = error
# Input: JSON via stdin (tool_name, tool_input.command)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

# --- Read hook input from stdin ---
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"

# Strip CRLF from command (Windows sends \r\n inside command strings).
# Also collapse embedded newlines to spaces — in JSON tool input, real command
# separators use &&/||/;/| (not raw newlines), so embedded \n are always
# inside quoted arguments and safe to flatten for validation purposes.
COMMAND="$(printf '%s' "$COMMAND" | tr -d '\r' | tr '\n' ' ')"

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

if [[ -z "$COMMAND" ]]; then
  ccma_block "bash-guard" "CCMA Bash Guard: empty command received." ""
fi

# --- Strip quoted strings to avoid false positives ---
# NOTE: Hooks are invoked directly by Claude Code (not via the Bash tool),
# so "source" in hook scripts does not trigger this guard.

strip_escaped_quotes() {
  # Neutralize escaped quotes (\' and \") before stripping quoted strings.
  # Without this, a \" inside a double-quoted string breaks the sed pattern.
  #
  # How it works:
  #   1. Replace literal \"  →  __ESC_DQ__   (escaped double quote)
  #   2. Replace literal \'  →  __ESC_SQ__   (escaped single quote)
  #
  # Sed delimiter is | to avoid conflicts with the backslash-heavy patterns.
  # In sed 's|PATTERN|REPLACE|g':
  #   - To match literal \", the regex needs \\", which in bash double-quotes
  #     requires escaping each \ → so \\\\" matches one backslash + one quote.
  local s="$1"
  s="$(echo "$s" | sed 's|\\"|__ESC_DQ__|g')"
  s="$(echo "$s" | sed "s|\\\\'|__ESC_SQ__|g")"
  echo "$s"
}

strip_single_quotes() {
  # Strip only single-quoted content (single quotes prevent ALL expansion in bash)
  # Use this for $() and backtick checks — double quotes do NOT prevent expansion
  local s
  s="$(strip_escaped_quotes "$1")"
  s="$(echo "$s" | sed "s/'[^']*'/__QUOTED__/g")"
  echo "$s"
}

strip_quotes() {
  # Strip both single and double-quoted content
  # Use this for redirect/write checks where ">" inside any quotes is safe
  local s
  s="$(strip_escaped_quotes "$1")"
  s="$(echo "$s" | sed 's/"[^"]*"/__QUOTED__/g')"
  s="$(echo "$s" | sed "s/'[^']*'/__QUOTED__/g")"
  echo "$s"
}

ccma_debug "Checking command: $COMMAND"

# --- Check for dangerous shell constructs (before whitelist, applies to full command) ---
# These bypass the per-segment whitelist check and must be caught globally.

# For $() and backtick checks: only strip single quotes (double quotes allow expansion)
COMMAND_SQ_STRIPPED="$(strip_single_quotes "$COMMAND")"
# For redirect/write checks: strip both quote types
COMMAND_STRIPPED="$(strip_quotes "$COMMAND")"

# Block command substitution: $(...) and backticks `...`
if echo "$COMMAND_SQ_STRIPPED" | grep -qE '\$\(|`'; then
  ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — command substitution (\$(...) or backticks) detected." "$COMMAND"
fi

# Block process substitution: <(...) and >(...)
if echo "$COMMAND_SQ_STRIPPED" | grep -qE '<\(|>\('; then
  ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — process substitution (<(...) or >(...)) detected." "$COMMAND"
fi

# Block eval (arbitrary code execution)
if echo "$COMMAND_STRIPPED" | grep -qE '(^|[;&|]\s*)\beval\b'; then
  ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — 'eval' is not allowed." "$COMMAND"
fi

# Block tee (can write to files, bypassing redirect check)
if echo "$COMMAND_STRIPPED" | grep -qE '\btee\b'; then
  ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — 'tee' is not allowed (can write to files)." "$COMMAND"
fi

# Block interpreter -c/-e injection (python -c, ruby -e, perl -e, node -e, etc.)
if echo "$COMMAND_STRIPPED" | grep -qE '\b(python3?|ruby|perl|node|php)\s+-(c|e)\b'; then
  ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — inline code execution via interpreter flag (-c/-e) not allowed." "$COMMAND"
fi

# Block exec (replaces current process)
if echo "$COMMAND_STRIPPED" | grep -qE '(^|[;&|]\s*)\bexec\b'; then
  ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — 'exec' is not allowed." "$COMMAND"
fi

# Block source/dot sourcing — except for explicitly allowed patterns
if echo "$COMMAND_STRIPPED" | grep -qE '(^|[;&|]\s*)(source\b|\.\s+/)'; then
  SOURCE_ALLOWED=false
  for pattern in "${CCMA_ALLOWED_SOURCE_PATTERNS[@]}"; do
    if echo "$COMMAND_STRIPPED" | grep -qE "$pattern"; then
      SOURCE_ALLOWED=true
      break
    fi
  done
  if [[ "$SOURCE_ALLOWED" != "true" ]]; then
    ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — 'source' / dot-sourcing is not allowed. To allow specific source commands, add patterns to CCMA_ALLOWED_SOURCE_PATTERNS in ccma-config.sh." "$COMMAND"
  else
    # Allowed source pattern — skip whitelist validation for this command
    ccma_debug "Source command allowed by pattern match: $COMMAND"
    exit 0
  fi
fi

# --- Build combined whitelist ---
declare -A ALLOWED_COMMANDS
for cmd in "${CCMA_TIER1_COMMANDS[@]}" "${CCMA_TIER2_COMMANDS[@]}"; do
  ALLOWED_COMMANDS["$cmd"]=1
done

# --- Build git subcommand set ---
declare -A GIT_ALLOWED
for sub in "${CCMA_GIT_ALLOWED_SUBCOMMANDS[@]}"; do
  GIT_ALLOWED["$sub"]=1
done

# --- Build docker subcommand set ---
declare -A DOCKER_ALLOWED
for sub in "${CCMA_DOCKER_ALLOWED_SUBCOMMANDS[@]}"; do
  DOCKER_ALLOWED["$sub"]=1
done

# --- Check for blocked redirects ---
check_redirects() {
  local segment="$1"
  if [[ "$CCMA_BLOCK_REDIRECTS" != "true" ]]; then
    return 0
  fi
  # Strip quoted content before checking for redirects
  local stripped
  stripped="$(strip_quotes "$segment")"

  # Block: > file, >> file — but allow safe stderr redirects
  # Step 1: Strip known-safe patterns before checking
  local redirect_check="$stripped"
  # Allow: 2>/dev/null (discard stderr — no file write)
  redirect_check="$(echo "$redirect_check" | sed 's/2>[[:space:]]*\/dev\/null//g')"
  # Allow: 2>&1 (merge stderr into stdout — no file write)
  redirect_check="$(echo "$redirect_check" | sed 's/2>[[:space:]]*&1//g')"
  # Allow: >/dev/null (discard stdout — no file write)
  redirect_check="$(echo "$redirect_check" | sed 's/>[[:space:]]*\/dev\/null//g')"

  # Step 2: Check remaining content for real file redirects
  if echo "$redirect_check" | grep -qE '(^|[[:space:]])[0-9]*>{1,2}[[:space:]]*[^&]'; then
    ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — shell redirect detected in: $segment" "$COMMAND"
  fi
  # Block: sed -i (in-place editing via sed)
  # Catches: sed -i, sed -i.bak, sed -ibak (GNU shorthand without space after -i)
  if echo "$stripped" | grep -qE '\bsed\b.*\s-i\b|\bsed\b.*\s-i[^[:space:]]'; then
    ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — sed -i (in-place edit) not allowed: $segment" "$COMMAND"
  fi
  # Block: sed w flag (writes matches to file) — check original, w is inside sed program
  if echo "$segment" | grep -qE '\bsed\b.*[/]w\s'; then
    ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — sed w (write to file) not allowed: $segment" "$COMMAND"
  fi
  # Block awk print-to-file redirect: awk '{ print > "file" }' or '{ print >> "file" }'
  # This checks for > or >> followed by a quoted filename inside the awk program.
  # Does NOT block numeric comparisons like: awk '$1 > 5'
  if echo "$segment" | grep -qE '\bawk\b.*print[[:space:]]*>{1,2}[[:space:]]*"'; then
    ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — awk with file output redirect not allowed: $segment" "$COMMAND"
  fi
  return 0
}

# --- Validate a single command segment ---
validate_segment() {
  local segment="$1"
  # Trim leading whitespace
  segment="$(echo "$segment" | sed 's/^[[:space:]]*//')"

  # Skip empty segments
  [[ -z "$segment" ]] && return 0

  # Extract first token (the command) — quote-aware for Windows paths with spaces
  # e.g. "D:/path with space./.ccma/scripts/ccma-log.sh" arg → D:/path with space./.ccma/scripts/ccma-log.sh
  local cmd
  cmd="$(echo "$segment" | awk '{
    # If first char is a quote, extract everything until the matching close quote
    c1 = substr($0, 1, 1)
    if (c1 == "\"" || c1 == "\047") {
      pos = index(substr($0, 2), c1)
      if (pos > 0) { print substr($0, 2, pos - 1) }
      else { print substr($0, 2) }
    } else {
      print $1
    }
  }')"

  # Strip path prefix (e.g., /usr/bin/git → git, d:/pat./.ccma/scripts/ccma-log.sh → ccma-log.sh)
  cmd="$(basename "$cmd")"
  # Fallback for paths that basename doesn't handle (e.g., Windows mixed separators)
  cmd="${cmd##*\\}"
  cmd="${cmd##*/}"

  ccma_debug "  Segment command: $cmd"

  # Check against whitelist
  if [[ -z "${ALLOWED_COMMANDS[$cmd]+_}" ]]; then
    ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — '$cmd' is not in the command whitelist. Allowed commands: ${!ALLOWED_COMMANDS[*]}" "$COMMAND"
  fi

  # Extract the first non-flag token after the command.
  # Handles quoted arguments with spaces (e.g., git -C "path with spaces" diff).
  extract_subcommand() {
    # Use awk for quote-aware tokenization
    echo "$1" | awk '
    BEGIN { found = 0; skip_next = 0; first = 1 }
    {
      n = length($0)
      token = ""
      in_dq = 0; in_sq = 0
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "\"" && !in_sq) { in_dq = !in_dq; continue }
        if (c == "\047" && !in_dq) { in_sq = !in_sq; continue }
        if ((c == " " || c == "\t") && !in_dq && !in_sq) {
          if (token != "") {
            if (first) { first = 0; token = ""; continue }  # skip command itself
            if (skip_next) { skip_next = 0; token = ""; continue }
            if (substr(token, 1, 1) == "-") {
              # Check if this flag takes a value argument
              if (token == "-C" || token == "-c" || token == "--git-dir" || \
                  token == "--work-tree" || token == "--namespace" || token == "--config" || \
                  token == "-H" || token == "--host" || token == "--context" || token == "--log-level") {
                skip_next = 1
              }
              token = ""
              continue
            }
            print token
            exit
          }
          continue
        }
        token = token c
      }
      # Handle last token (no trailing space)
      if (token != "" && !first) {
        if (!skip_next && substr(token, 1, 1) != "-") {
          print token
        }
      }
    }'
  }

  # Git subcommand validation
  if [[ "$cmd" == "git" ]]; then
    local subcmd
    subcmd="$(extract_subcommand "$segment")"
    if [[ -n "$subcmd" && -z "${GIT_ALLOWED[$subcmd]+_}" ]]; then
      ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — 'git $subcmd' is not allowed. Allowed git subcommands: ${!GIT_ALLOWED[*]}" "$COMMAND"
    fi
  fi

  # Docker subcommand validation
  if [[ "$cmd" == "docker" ]]; then
    local subcmd
    subcmd="$(extract_subcommand "$segment")"
    if [[ -n "$subcmd" && -z "${DOCKER_ALLOWED[$subcmd]+_}" ]]; then
      ccma_block "bash-guard" "CCMA Bash Guard: BLOCKED — 'docker $subcmd' is not allowed. Allowed docker subcommands: ${!DOCKER_ALLOWED[*]}" "$COMMAND"
    fi
  fi

  # Check for redirects in this segment
  check_redirects "$segment"

  return 0
}

# --- Quote-aware command splitting ---
# Splits on |, ||, &&, ; but ONLY outside of single/double quotes.
# Without this, commands like: echo "foo && bar" && ls
# would incorrectly split inside the quoted string.
quote_aware_split() {
  echo "$1" | awk '{
    in_sq = 0; in_dq = 0; esc = 0; seg = ""
    n = length($0)
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1)
      if (esc)           { seg = seg c; esc = 0; continue }
      if (c == "\\" && !in_sq) { seg = seg c; esc = 1; continue }
      if (c == "\"" && !in_sq) { in_dq = !in_dq; seg = seg c; continue }
      if (c == "\047" && !in_dq) { in_sq = !in_sq; seg = seg c; continue }
      if (!in_sq && !in_dq) {
        if (c == "|" && substr($0, i+1, 1) == "|") { if (seg != "") print seg; seg = ""; i++; continue }
        if (c == "&" && substr($0, i+1, 1) == "&") { if (seg != "") print seg; seg = ""; i++; continue }
        if (c == "|") { if (seg != "") print seg; seg = ""; continue }
        if (c == ";") { if (seg != "") print seg; seg = ""; continue }
      }
      seg = seg c
    }
    if (seg != "") print seg
  }'
}

# --- Split command and validate each segment ---
SEGMENTS="$(quote_aware_split "$COMMAND")"

while IFS= read -r segment; do
  validate_segment "$segment"
done <<< "$SEGMENTS"

ccma_debug "Command ALLOWED: $COMMAND"
exit 0
