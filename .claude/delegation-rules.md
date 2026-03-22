# Agent Delegation — MANDATORY

**CRITICAL: You are the ORCHESTRATOR. You MUST delegate ALL implementation work to subagents. You MUST NOT write, edit, or delete code yourself. Every code-related action MUST go through the appropriate CCMA agent.**

## Rules

1. **NEVER** write, edit, or refactor code directly — always delegate to `coder`.
2. **NEVER** write tests directly — always delegate to `tester`.
3. **NEVER** skip pipeline stages for the given task class.
4. **ALWAYS** invoke agents via the Agent tool (each agent runs in its own isolated context via `.claude/agents/*.md` definitions).
5. **ALWAYS** pass complete context in the agent's prompt (see Context Template below).
6. **ALWAYS** evaluate each agent's returned Status before proceeding to the next stage.
7. **ALWAYS** update `.ccma/scratchpad.md` after each pipeline stage.

## Context to Pass to Agents

Every agent invocation MUST include:
1. **Task description**: The original user request (verbatim or paraphrased).
2. **Plan/subtask**: For coder — the specific subtask from the planner. For tester — which files changed and what was implemented.
3. **Prior agent output**: The full Status + Summary from the immediately preceding agent.
4. **Modified files list**: Paths of all files changed so far in this pipeline run.
5. **Test baseline**: Current pass/fail counts. **Mandatory for subtask N>1** (read from
   prior tester output). For subtask 1 (no prior tests): state "No baseline (first subtask)".
6. **Reviewer findings**: For coder in minor-fix mode — the exact findings list from the reviewer.
7. **Cross-agent findings**: If a prior agent wrote memory (`.claude/agent-memory/<agent>/`),
   include relevant findings in the next agent's prompt. Agents have per-agent memory —
   they do NOT automatically see each other's findings.

## Pipeline by Task Class

| Task Class | Criteria | Pipeline | Coder maxTurns |
|-----------|----------|----------|----------------|
| MICRO | 1 file, <=5 lines, no logic change (typo, comment, rename) | orchestrator may fix directly | — |
| TRIVIAL | <=3 files, <=20 lines, non-security | coder -> tester | 15 |
| STANDARD | <=7 files, clear scope | planner -> coder -> tester -> reviewer | 40 |
| COMPLEX | >7 files or architectural decision | planner -> coder -> tester -> reviewer -> security-auditor | 60 |
| ARCHITECTURE | fundamental structural change | planner (iterative) -> full pipeline | 80 |

MICRO is the **only** class where the orchestrator may act directly. For all others, delegation is mandatory.

**maxTurns override:** When invoking the `coder` agent, pass the `max_turns` parameter according
to the task class (see table above). This overrides the frontmatter default of 50.

## Security Pre-Check (COMPLEX/ARCHITECTURE only)

After the planner returns for COMPLEX or ARCHITECTURE tasks:
1. Read the planner's `### Security Pre-Analysis` section.
2. If any finding is rated HIGH or CRITICAL:
   a. Invoke the `security-auditor` agent in plan-review mode.
   b. Pass the full planner output (not code — no code exists yet).
   c. Instruct the auditor: "Review this implementation plan for security design flaws. No code has been written. Output: risk assessment of the plan only."
   d. If auditor returns CRITICAL → **HALT**, escalate to human.
   e. If auditor returns HIGH → re-invoke planner with auditor findings.
   f. If auditor returns MEDIUM or lower → proceed to coder, include findings in coder prompt.
3. If Security Pre-Analysis is N/A or all findings are LOW → proceed directly to coder.

## Orchestrator Self-Check

Before ANY action, verify:
1. **Have I classified the task?** If not, classify first. Generate a task_id using format: `YYYYMMDD-HHMM-<short-slug>` (e.g., `20260308-1430-add-auth-endpoint`).
2. **Am I about to write/edit code?** If task class is not MICRO → STOP and delegate to the correct agent.
3. **Did the previous agent return SUCCESS?** If not → apply rework rules below.
4. **Is .ccma/scratchpad.md up to date?** If not → update it now.

## Rework Rules

| Trigger | Action | Counter |
|---------|--------|---------|
| Tester PARTIAL | Re-invoke coder | rework_count +1 |
| Reviewer MINOR | Re-invoke coder (minor-fix mode), then tester | rework_count +1 |
| Reviewer MAJOR | Re-invoke coder | rework_count +1 |
| Reviewer REJECTED | Re-invoke planner | rework_count +1 |
| Security-auditor CRITICAL | **HALT** — escalate to human | — |
| Any agent ERROR | **STOP** — report to human (infra issue) | — |
| rework_count >= 3 | **STOP** — escalate to human | — |

## Known Limitation: File Deletion

Agents cannot delete files. `rm` is not in the Bash Guard whitelist; `Write`/`Edit`
only create or modify. When a plan requires file deletion:
1. Coder returns `PARTIAL` and lists files to delete in Findings.
2. Orchestrator reports to human: "Manual deletion required: [list]"
3. Human deletes the files.
4. Orchestrator re-invokes coder with: `mode: continue — files deleted, finalize`.

## Pipeline Logging

After each agent completes, log the result: `./.ccma/scripts/ccma-log.sh <agent> <STATUS> "<description>"`. Agents do this automatically as their last step. The orchestrator should also log classification and escalation events.

Security-sensitive tasks (auth, crypto, validation, middleware, dependencies) are elevated to minimum STANDARD.

## Post-Pipeline: Plan Persistence

After the planner returns, persist the plan to `.ccma/current-plan.md` using the Write tool. This provides a recovery point if context is compacted and a version-controlled record of architectural decisions.

## Post-Pipeline: Disruption Review

After a pipeline completes (SUCCESS or ESCALATION):

1. Compare current disruption log size against the watermark in the scratchpad:
   ```
   CURRENT=$(wc -l < .claude/disruption-log.jsonl 2>/dev/null || echo 0)
   WATERMARK=<disruption_watermark from scratchpad>
   ```
2. If CURRENT > WATERMARK (new disruptions occurred during this pipeline):
   a. Run `./.ccma/scripts/ccma-disruption-report.sh --since <task start timestamp>`
   b. For each command blocked 3+ times: write a proposal to `.ccma/disruption-proposals.md`
   c. Each proposal MUST include: the blocked command, frequency, proposed config change (exact line), and risk assessment
3. If CURRENT == WATERMARK: skip — no new disruptions.
4. Do NOT modify `ccma-config.sh` — proposals require human review.

**Orchestrator Self-Check addition:** When classifying a new task, record the disruption watermark:
```
disruption_watermark: $(wc -l < .claude/disruption-log.jsonl 2>/dev/null || echo 0)
```

<!-- Model selection is defined in each agent's frontmatter (model:, effort:, maxTurns:, disallowedTools: fields). -->
<!-- See scripts/ccma-config.sh for recommended upgrades per task class. -->
<!-- Agent tool restrictions (disallowedTools) are enforced at the platform level since Claude Code 2.1. -->

## Script Invocation — CRITICAL

**Agents MUST invoke CCMA scripts directly using relative paths. NEVER prefix with `bash`.**

```
CORRECT:  ./.ccma/scripts/ccma-log.sh coder SUCCESS "summary"
WRONG:    bash ./.ccma/scripts/ccma-log.sh coder SUCCESS "summary"
```

The `bash` command is NOT in the guard whitelist. Using it wastes a turn while the guard blocks and the agent self-corrects. This applies to ALL scripts: `ccma-log.sh`, `ccma-retro-log.sh`, `ccma-verify.sh`, etc.

## Parallel Execution (Linux only)

**Prerequisite:** `CCMA_PARALLEL_ENABLED="true"` in `.ccma/scripts/ccma-config.sh`.
Default is `false`. Do NOT enable on Windows or WSL.

### When to parallelize

Dispatch multiple coder agents **in a single message** (parallel Agent tool calls) when ALL of the following are true:

1. Two or more subtasks carry the same `Parallel-group` label (set by planner).
2. All subtasks in the group have `Depends on: none` (or all dependencies are already complete).
3. The subtasks modify **disjoint file sets** — no file appears in more than one subtask.
4. `CCMA_PARALLEL_ENABLED="true"` is confirmed in the config.

If any condition is not met, fall back to sequential execution.

### Orchestrator behavior for a parallel group

1. Read the planner output and identify all subtasks sharing the same `Parallel-group` label.
2. Verify the file disjointness condition. If two subtasks share a file, execute sequentially.
3. Dispatch all subtasks in the group as **simultaneous Agent tool calls in one message**.
   Each call includes `mode: parallel` in the prompt.
4. **Wait** for all parallel agents to return before proceeding.
5. After all parallel coders return:
   a. Collect all `modified_files` lists from each coder's output.
   b. Determine combined status (SUCCESS only if ALL returned SUCCESS).
   c. Write scratchpad **once** with consolidated result:
      - `pipeline_stage: coder`
      - `modified_files`: merged list from all parallel coders
      - `last_agent_status`: combined status
6. Log each coder individually (O_APPEND on Linux ext4 is atomic for entries under 4096 bytes):
   `./.ccma/scripts/ccma-log.sh coder <STATUS> "<subtask-summary>"` — one call per coder.
7. Proceed to tester with the full merged `modified_files` list.

### Scratchpad safety rule

**Parallel coders MUST NOT write to `.ccma/scratchpad.md`.** This is enforced via `mode: parallel`
in the coder prompt. The orchestrator is the sole writer after a parallel group completes.
This eliminates the last-write-wins race condition.

### Rework with parallel coders

If one parallel coder returns PARTIAL or ERROR:
- Treat the entire group as needing rework (increment `rework_count` once for the group).
- Re-invoke only the failing coder(s) **sequentially** (no parallel retry).
- Apply normal Rework Rules from the table above.

### Windows/WSL compatibility

This section is ignored when `CCMA_PARALLEL_ENABLED="false"`.
All sequential behavior defined above remains the default and only supported mode on Windows.
