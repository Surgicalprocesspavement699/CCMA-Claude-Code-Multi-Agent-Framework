---
name: implement
description: "Start a CCMA pipeline to implement a feature or fix. Classifies the task, runs the appropriate agent pipeline (TRIVIAL through ARCHITECTURE), and tracks progress in the scratchpad."
---

# /implement — Start Implementation Pipeline

When the user invokes this command, follow these steps:

## Step 1: Classify the Task
Read the user's request and classify:
- **MICRO** (1 file, ≤5 lines, no logic change) → Fix directly
- **TRIVIAL** (≤3 files, ≤20 lines, non-security) → coder → tester
- **STANDARD** (≤7 files, clear scope) → planner → coder → tester → reviewer
- **COMPLEX** (>7 files or architectural) → planner → coder → tester → reviewer → security-auditor

If security-sensitive paths are touched, elevate to minimum STANDARD.

## Step 2: Initialize Pipeline
1. Generate task_id: `YYYYMMDD-HHMM-<short-slug>`
2. Update `.claude/scratchpad.md` with task_id, task_class, rework_count: 0
3. Record disruption_watermark: `$(wc -l < .claude/disruption-log.jsonl 2>/dev/null || echo 0)`

## Step 3: Execute Pipeline
Follow the delegation rules in CLAUDE.md. Delegate to agents in order. Pass full context to each agent. Update scratchpad after each stage.

When invoking the coder agent, pass `max_turns` based on task class:
- TRIVIAL: 15 | STANDARD: 40 | COMPLEX: 60 | ARCHITECTURE: 80

## Step 4: Post-Pipeline
After completion, run disruption review if new blocks occurred.
