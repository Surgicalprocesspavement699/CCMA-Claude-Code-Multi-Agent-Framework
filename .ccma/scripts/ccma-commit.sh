#!/usr/bin/env bash
# ============================================================================
# CCMA Auto-Commit — Optional checkpoint after successful pipeline
# ============================================================================
# Called by orchestrator when CCMA_AUTO_COMMIT=true and pipeline=SUCCESS
# Usage: ccma-commit.sh <task_id> <task_class> "<summary>"
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ccma-config.sh"

if [[ "$CCMA_AUTO_COMMIT" != "true" ]]; then
  echo "[CCMA] Auto-commit disabled (CCMA_AUTO_COMMIT=false). Skipping." >&2
  exit 0
fi

TASK_ID="${1:-unknown}"
TASK_CLASS="${2:-STANDARD}"
SUMMARY="${3:-pipeline completed}"

PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR"

if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
  echo "[CCMA] Git not available or not a git repo. Skipping auto-commit." >&2
  exit 0
fi

# Check if there is anything to commit
if git diff --quiet && git diff --staged --quiet; then
  echo "[CCMA] Nothing to commit. Working tree clean." >&2
  exit 0
fi

git add -A
git commit -m "CCMA: $TASK_ID [$TASK_CLASS] $SUMMARY"

echo "[CCMA] Auto-commit: CCMA: $TASK_ID [$TASK_CLASS] $SUMMARY" >&2
