# CCMA — Claude Code Multi-Agent Framework

You've probably seen this: Claude Code writes 200 lines, they look plausible, you ship them — and later find a hardcoded secret, a missing error handler, or a function that was never tested. Not because Claude is bad. Because nothing in the pipeline enforced otherwise.

CCMA is a free, open-source framework that adds a structured pipeline and technical guardrails to Claude Code. It's slower than just asking Claude to code. That's the point — when it's done, you don't have to review the output yourself.

```
planner → coder → tester → reviewer → security-auditor
```

Every step is mandatory. Rework is automatic. The security auditor runs before you ship, not after. And if anything goes wrong, there's a structured log that tells you exactly what happened and why.

---

## Why CCMA?

Most Claude Code frameworks give you better prompts. CCMA gives you **technical enforcement**:

| | Prompt-based frameworks | CCMA |
|---|---|---|
| Prevent bad commands | Instruct the agent | Bash Guard blocks at the hook level |
| Protect sensitive files | Tell the agent | File Guard enforces regardless of instructions |
| Catch regressions | Hope the agent tests | Tester agent is mandatory, output verified |
| Security review | Optional, manual | Security Auditor in the pipeline for auth/crypto |
| Rework loops | Start over manually | Automatic rework up to 3 cycles, then human escalation |
| Audit trail | None | `pipeline-log.jsonl`, `disruption-log.jsonl`, `activity-log.jsonl` |

**CCMA is not for vibe coding. It's for when the output actually has to work.**

---

## Quickstart

```bash
# 1. Copy the template
cp -r ccma-template/ my-project/
cd my-project/

# 2. Fill in CLAUDE.md
#    → Project name, build/test/lint commands
#    → Architecture overview, conventions, security-sensitive paths

# 3. Verify framework is intact
bash .ccma/scripts/ccma-verify.sh

# 4. Init git
git init && git add -A && git commit -m "Initial commit with CCMA"

# 5. Start Claude Code
claude
```

**First task:**
```
/implement "your feature description here"
```

---

## Pipeline Classes

| Class | Criteria | Pipeline |
|-------|----------|----------|
| **MICRO** | 1 file, ≤5 lines, no logic change | Orchestrator fixes directly |
| **TRIVIAL** | ≤3 files, ≤20 lines, non-security | `coder → tester` |
| **STANDARD** | ≤7 files, clear scope | `planner → coder → tester → reviewer` |
| **COMPLEX** | >7 files or architectural | `planner → coder → tester → reviewer → security-auditor` |
| **ARCHITECTURE** | Fundamental structural change | Iterative planner + full pipeline |

Security-sensitive tasks (auth, crypto, middleware, env files) are elevated to minimum **STANDARD** automatically.

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/implement "..."` | Classify task and run the appropriate pipeline |
| `/status` | Show scratchpad + recent log entries |
| `/retro` | Run retrospective on last pipeline |
| `/retro --force` | Force retrospective even if not triggered |

---

## Structure

```
.ccma/                          Framework internals
├── scripts/
│   ├── ccma-config.sh          Central configuration (edit this)
│   ├── ccma-bash-guard.sh      Command whitelist enforcement (PreToolUse hook)
│   ├── ccma-sensitive-file-guard.sh  File write protection (PreToolUse hook)
│   ├── ccma-auto-format.sh     Auto-formatter dispatch (PostToolUse hook)
│   ├── ccma-session-start.sh   State injection on startup/resume/compact
│   ├── ccma-pre-compact.sh     Recovery snapshot before compaction
│   ├── ccma-log.sh             Pipeline event logger
│   ├── ccma-commit.sh          Optional auto-commit after SUCCESS
│   ├── ccma-verify.sh          Framework health check
│   └── ...                     (5 more utility scripts)
├── tests/                      bats test suite (220+ tests)
├── scratchpad.md               Live pipeline state
└── MEMORY.md                   Cross-task knowledge (auto-trimmed at 150 lines)

.claude/                        Claude Code native
├── agents/                     6 agent definitions
│   ├── planner.md              Read-only, sonnet, decomposes tasks
│   ├── coder.md                opus, writes production code
│   ├── tester.md               sonnet, writes + runs tests
│   ├── reviewer.md             opus, structured code review
│   ├── security-auditor.md     opus, auth/crypto/injection checks
│   └── retrospector.md         opus, process analysis
├── skills/                     Task checklists loaded by agents
├── delegation-rules.md         Orchestrator rules (imported in CLAUDE.md)
├── settings.json               Hook registrations + permissions
└── *.jsonl                     Audit logs

CLAUDE.md                       ← Fill this in for every project
```

---

## Configuration

All framework behaviour is controlled from `.ccma/scripts/ccma-config.sh`:

### Command Whitelist

```bash
# Tier 1: Read-only (all agents)
CCMA_TIER1_COMMANDS=(ls find cat head tail git grep awk ...)

# Tier 2: Build & test (coder, tester only)
CCMA_TIER2_COMMANDS=(npm npx python3 cargo go make pytest jest ...)
```

Any command not in the whitelist is **blocked** and logged to `disruption-log.jsonl`.

### Key Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `CCMA_AUTO_COMMIT` | `false` | Auto-commit after pipeline SUCCESS |
| `CCMA_MEMORY_MAX_LINES` | `150` | MEMORY.md trimmed above this |
| `CCMA_CODER_MAX_TURNS_*` | 15/40/60/80 | maxTurns per task class |
| `CCMA_BLOCK_REDIRECTS` | `true` | Block shell redirects (`>`, `>>`, `sed -i`) |
| `CCMA_PARALLEL_ENABLED` | `false` | Parallel coder dispatch (Linux only) |
| `CCMA_MAX_REWORK` | `3` | Max rework cycles before human escalation |

---

## Agents

### Planner
- **Model:** `sonnet` — **Tools:** Read, Glob, Grep (no Write/Edit/Bash)
- Decomposes tasks into ≤7 subtasks with dependencies and parallelization labels
- For COMPLEX/ARCHITECTURE: includes `### Security Pre-Analysis` — high-risk findings trigger security-auditor review of the plan **before** any code is written

### Coder
- **Model:** `opus` — **Tools:** Read, Write, Edit, Bash, Glob, Grep
- Implements exactly one subtask per invocation — no scope expansion
- Bash Guard enforced: blocked commands are logged, agent self-corrects

### Tester
- **Model:** `sonnet` — writes tests **and** runs them (both mandatory)
- Minimum coverage: 1 happy path, 1 edge case, 1 error case per changed public function
- Records baseline before and after — any regression returns PARTIAL

### Reviewer
- **Model:** `opus` — Read-only
- Returns exactly one of: `ACCEPTED`, `MINOR`, `MAJOR`, `REJECTED`
- MINOR → coder minor-fix mode; MAJOR → coder re-invoked; REJECTED → planner re-invoked

### Security Auditor
- **Model:** `opus` — Read-only, triggered for COMPLEX/ARCHITECTURE tasks
- Checks: injection, auth bypass, hardcoded secrets, insecure dependencies, IDOR
- `CRITICAL` finding → **pipeline halts**, human escalation required

### Retrospector
- **Model:** `opus` — independent of orchestrator context
- Reads only primary sources (logs, git diff) — ignores orchestrator's narrative
- Produces structured JSON: classification audit, rework causal analysis, adaptation proposals

---

## Rework Rules

| Trigger | Action |
|---------|--------|
| Tester `PARTIAL` | Re-invoke coder |
| Reviewer `MINOR` | Re-invoke coder (minor-fix mode) + tester |
| Reviewer `MAJOR` | Re-invoke coder |
| Reviewer `REJECTED` | Re-invoke planner |
| Security-auditor `CRITICAL` | **HALT** — escalate to human |
| Any agent `ERROR` | **STOP** — report infra issue to human |
| `rework_count >= 3` | **STOP** — escalate to human |

---

## Guards

### Bash Guard
Runs on every Bash tool call before execution. Splits the command into segments (quote-aware), validates each segment against the whitelist, checks for dangerous constructs:

- `$()` and backtick substitution
- `eval`, `exec`, `tee`
- `python -c`, `node -e` inline injection
- Shell redirects `>`, `>>`, `sed -i`
- Disallowed git subcommands (`push`, `commit`, `reset`, `checkout`)

Exit code `2` = blocked, entry written to `disruption-log.jsonl`.

### File Guard
Runs on every Write/Edit/NotebookEdit call. Blocks writes to:

- `.env`, `*.pem`, `*.key`, `*secret*`, `*password*`
- `CLAUDE.md`, `.claude/agents/*.md`, `.claude/settings.json`
- `.ccma/scripts/ccma-*.sh` (guards cannot be modified by agents)

### Orchestrator Write Guard
Non-blocking observability layer. Logs a warning to `disruption-log.jsonl` when the orchestrator writes directly to protected source paths (`src/`, `lib/`, `app/`). High counts = orchestrator is bypassing delegation. Not an error — a process signal.

---

## Context Recovery

CCMA preserves pipeline state across Claude Code's context window compaction:

1. **PreCompact hook** saves scratchpad + current plan + recent log entries to `.claude/compact-recovery.md`
2. **PostCompact hook** re-runs session-start, which injects recovery context
3. The orchestrator reads `.ccma/scratchpad.md` as the first step of every new session

Pending retrospectives are flagged on session start — the next task cannot begin until the retro runs (or is explicitly skipped with `/retro --skip`).

---

## Disruption Feedback Loop

Every blocked action is logged to `.claude/disruption-log.jsonl`. After each pipeline:

1. Orchestrator compares current log size against the watermark recorded at task start
2. Commands blocked 3+ times in a single pipeline → proposal written to `.ccma/disruption-proposals.md`
3. Human reviews proposals and applies changes to `ccma-config.sh`
4. Framework never auto-modifies its own configuration

---

## Parallel Execution

Enable on Linux with `CCMA_PARALLEL_ENABLED="true"` in `ccma-config.sh`.

When the planner assigns the same `Parallel-group` label to multiple subtasks with disjoint file sets, the orchestrator dispatches all coder agents **simultaneously** in a single message. Parallel coders skip scratchpad writes — the orchestrator consolidates after all complete. Atomic log appends are safe on Linux ext4 for entries under 4096 bytes.

Not supported on Windows/WSL.

---

## Prerequisites

```bash
# Required
bash >= 4.0
jq

# Recommended (for bats test suite)
bats-core

# Auto-detected per project
npm / npx / node    # JavaScript/TypeScript
python3 / pip3      # Python
cargo / rustc       # Rust
go                  # Go
# ... (see ccma-config.sh CCMA_TIER2_COMMANDS for full list)
```

---

## Running the Tests

```bash
# All suites
bats .ccma/tests/

# Individual suites
bats .ccma/tests/hooks.bats               # Bash Guard + File Guard
bats .ccma/tests/v2.2-fixes-validation.bats  # v2.2 fix regression suite
bats .ccma/tests/ccma-commit.bats         # Auto-commit script
bats .ccma/tests/windows-compat.bats      # Windows/Git Bash compatibility
```

---

## Important Notes

- **Fill in CLAUDE.md completely** — agents read it as their first source of truth
- **No `bash` prefix** on script calls **from Agent Tool Calls** — the Bash Guard blocks it. In your terminal (Quickstart step 3) `bash script.sh` is correct
- **Orchestrator Guard is observability, not enforcement** — high `orchestrator-guard` counts in `disruption-log.jsonl` mean the orchestrator wrote code directly instead of delegating. Process error, not a security incident
- **File deletion** — agents cannot delete files (`rm` is not in the whitelist). Workflow: coder returns `PARTIAL` with a list of files to delete → human deletes → coder re-invoked with `mode: continue`
- **Windows:** `defaultMode: acceptEdits` is set — permission prompts should not appear
- **Parallel execution** is disabled by default — do not enable on Windows or WSL

---

## Comparison

| | ECC / prompt-based frameworks | CCMA |
|---|---|---|
| **Approach** | Better prompts, richer skills | Technical hooks + enforcement |
| **Security** | Instruct the agent to be careful | Guard blocks the action |
| **Rework** | Manual retry | Automatic loop with rework_count limit |
| **Audit** | None | Three structured JSONL logs |
| **Best for** | Maximizing agent capability | Teams needing quality gates + accountability |

ECC and CCMA are complementary — use ECC's skills inside CCMA's pipeline for maximum coverage.

---

## License

MIT — see [LICENSE](LICENSE)
