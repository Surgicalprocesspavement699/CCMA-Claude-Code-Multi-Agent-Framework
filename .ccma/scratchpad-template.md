# CCMA Scratchpad — Orchestration State

<!-- CRITICAL: This file persists pipeline state across context compactions. -->
<!-- Both the orchestrator AND each write-capable agent update this file. -->
<!-- Read this file FIRST when resuming after compaction. -->
<!-- FORMAT: Markdown key-value ("- **key**: value"). Do NOT change the key names — -->
<!-- ccma-log.sh parses rework_count via regex: grep -oE 'rework_count[^0-9]*([0-9]+)' -->
<!-- The format "- **rework_count**: <number>" MUST be preserved exactly. -->
<!-- Extra whitespace, different markdown formatting, or restructuring will break parsing. -->
<!-- disruption_watermark is parsed by the orchestrator to detect new guard blocks during a pipeline. -->
<!-- Format: "- **disruption_watermark**: <number>" -->
<!-- retro_status is parsed by ccma-session-start.sh to enforce retrospective completion. -->
<!-- Format: "- **retro_status**: none | pending | done | skipped" -->
<!-- runs_since_retro is parsed by the orchestrator to trigger counter-based retrospectives. -->
<!-- Format: "- **runs_since_retro**: <number>" -->

## Current Task

- **task_id**: (none)
- **task_class**: (none)
- **rework_count**: 0
- **disruption_watermark**: 0
- **retro_status**: none
- **runs_since_retro**: 0
- **pipeline_stage**: (none)
- **last_agent_status**: (none)

## Pipeline Progress

| Stage | Agent | Status | Timestamp |
|-------|-------|--------|-----------|
| — | — | — | — |

## Modified Files

(none)

## Open Findings

(none)

## Test Baseline

- **pass**: 0
- **fail**: 0
- **skip**: 0

## Next Action

(none — classify task first)
