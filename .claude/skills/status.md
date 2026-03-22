---
name: status
description: "Show current CCMA pipeline status: task, stage, logs, health assessment."
---

# /status — Pipeline Status

Show the current state of the CCMA framework:

1. Read `.claude/scratchpad.md` and display:
   - Current task_id and class
   - Pipeline stage and last agent status
   - Rework count
   - Modified files
   - Open findings

2. Log statistics:
   - `wc -l .claude/activity-log.jsonl` — total tool calls
   - `wc -l .claude/disruption-log.jsonl` — guard blocks
   - `wc -l .claude/pipeline-log.jsonl` — pipeline events

3. Health check:
   - If pipeline-log is empty but activity-log has entries → "⚠ Pipeline logging may not be working"
   - If disruption-log has >10 entries → "⚠ Config may need tuning — run /disruptions"
   - If no agent invocations in activity-log but writes exist → "⚠ Possible delegation bypass"

4. Git status: branch, uncommitted changes count
