---
name: retro
description: "Trigger a pipeline retrospective. Analyzes process quality: classification accuracy, rework causes, planner accuracy, and proposes adaptations."
command: /retro
usage: |
  /retro                              — Retrospective on last completed task
  /retro 20260308-1430-add-auth       — Retrospective on specific task
  /retro --force                      — Force retro even without trigger
  /retro --skip                       — Skip pending retro (human decision, logged)
---

# /retro — Pipeline Retrospective

## Behavior

1. **Determine task_id:**
   - If argument provided and not a flag: use as task_id.
   - If no argument: read task_id from `.claude/scratchpad.md`.
   - If scratchpad has no task_id: read last entry from `.claude/pipeline-log.jsonl`.

2. **Check retro trigger** (unless `--force`):
   - `rework_count >= 1` → trigger
   - Coder reported deviations → trigger
   - Task was reclassified during pipeline → trigger
   - Escalation to human occurred → trigger
   - `runs_since_retro >= 3` → trigger
   - `--force` → always trigger
   - No trigger → increment `runs_since_retro` in scratchpad, done.

3. **If `--skip`:**
   - Run `./.ccma/scripts/ccma-retro-log.sh --skip "<task_id>"`.
   - Set `retro_status: skipped` in scratchpad.
   - Set `runs_since_retro: 0` in scratchpad.
   - Done. The skip is permanently logged.

4. **Execute retrospective:**
   - Set `retro_status: pending` in scratchpad.
   - Invoke the `retrospector` agent with ONLY the task_id:
     ```
     Task ID: <task_id>
     ```
   - Do NOT pass summaries, analysis, or context. The retrospector reads logs independently.

5. **After retrospector returns:**
   - Set `retro_status: done` in scratchpad.
   - Set `runs_since_retro: 0` in scratchpad.
   - If adaptations were proposed: inform the human that `process-adaptations.md` has new entries.
   - Log: `./.ccma/scripts/ccma-log.sh retrospector <STATUS> "Retrospective for <task_id>"`
