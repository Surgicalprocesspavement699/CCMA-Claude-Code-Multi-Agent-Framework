#!/usr/bin/env bash
# ============================================================================
# CCMA Disruption Report — Analyzes guard blocks for config improvement
# ============================================================================
# Usage: ./.ccma/scripts/ccma-disruption-report.sh [--since YYYY-MM-DD] [--top N]
# Output: Summary of blocked commands/files with frequency counts
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

# --- Parse arguments ---
SINCE=""
TOP=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --top)   TOP="$2"; shift 2 ;;
    *)       shift ;;
  esac
done

if [[ ! -f "$CCMA_DISRUPTION_LOG" ]]; then
  echo "No disruption log found at $CCMA_DISRUPTION_LOG"
  echo "This means no guard blocks have been recorded yet."
  exit 0
fi

TOTAL=$(wc -l < "$CCMA_DISRUPTION_LOG")
if [[ "$TOTAL" -eq 0 ]]; then
  echo "Disruption log is empty — no blocks recorded."
  exit 0
fi

echo "============================================"
echo "  CCMA Disruption Report"
echo "============================================"
echo ""
echo "Log: $CCMA_DISRUPTION_LOG"
echo "Total blocks recorded: $TOTAL"

# --- Filter by date if --since is given ---
if [[ -n "$SINCE" ]]; then
  FILTERED=$(jq -r --arg since "$SINCE" 'select(.timestamp >= $since)' "$CCMA_DISRUPTION_LOG" | wc -l)
  echo "Blocks since $SINCE: $FILTERED"
fi
echo ""

# --- Top blocked commands (bash-guard) ---
echo "--- Top $TOP Blocked Commands (Bash Guard) ---"
jq -r 'select(.guard == "bash-guard") | .detail' "$CCMA_DISRUPTION_LOG" 2>/dev/null \
  | sed 's/^ *//' \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -"$TOP" \
  | while read -r count cmd; do
      printf "  %4d×  %s\n" "$count" "$cmd"
    done
echo ""

# --- Top blocked files (file-guard) ---
echo "--- Top $TOP Blocked Files (File Guard) ---"
jq -r 'select(.guard == "file-guard") | .detail' "$CCMA_DISRUPTION_LOG" 2>/dev/null \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -"$TOP" \
  | while read -r count file; do
      printf "  %4d×  %s\n" "$count" "$file"
    done
echo ""

# --- Blocked command first-tokens (what the agent tried to run) ---
echo "--- Blocked Executables (first token) ---"
jq -r 'select(.guard == "bash-guard") | .detail' "$CCMA_DISRUPTION_LOG" 2>/dev/null \
  | awk '{print $1}' \
  | sed 's|.*/||' \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -"$TOP" \
  | while read -r count exe; do
      printf "  %4d×  %s\n" "$count" "$exe"
    done
echo ""

# --- Time distribution (blocks per day) ---
echo "--- Blocks Per Day ---"
jq -r '.timestamp' "$CCMA_DISRUPTION_LOG" 2>/dev/null \
  | cut -dT -f1 \
  | sort \
  | uniq -c \
  | while read -r count day; do
      printf "  %s  %4d blocks\n" "$day" "$count"
    done
echo ""

echo "============================================"
echo "  Recommendations"
echo "============================================"
echo ""
echo "Review the top blocked commands above."
echo "For each recurring block, decide:"
echo "  1. Add to whitelist (ccma-config.sh) — if the command is safe for agents"
echo "  2. Create a wrapper script (scripts/) — if the command needs restrictions"
echo "  3. Keep blocked — if the block is correct and agents should adapt"
echo ""
echo "To propose changes: ./.ccma/scripts/ccma-disruption-report.sh > .ccma/disruption-proposals.md"
echo ""
