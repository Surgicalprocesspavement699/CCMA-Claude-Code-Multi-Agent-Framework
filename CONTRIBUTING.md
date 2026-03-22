# Contributing to CCMA

Thank you for your interest in contributing.

## What belongs in CCMA

CCMA is a **framework** — not a collection of skills or prompts. Contributions that add technical enforcement (new guards, hook improvements, pipeline logic) are the best fit. Contributions that are purely prompt improvements belong in ECC or similar projects.

**Good contributions:**
- New guard scripts or improvements to existing guards
- bats tests for uncovered behaviour
- Bug fixes with a failing test that demonstrates the bug
- Platform compatibility fixes (Windows, WSL, alternative shells)
- Documentation clarifications

**Not a fit:**
- New agent skill files / prompt improvements without a guard or hook component
- Dependencies on external services or non-standard tools
- Changes to the Bash Guard whitelist without strong justification (this is a security boundary)

## Development Setup
```bash
git clone https://github.com/skydreamer18/CCMA-Claude-Code-Multi-Agent-Framework.git
cd CCMA-Claude-Code-Multi-Agent-Framework
bash .ccma/scripts/ccma-verify.sh
bats .ccma/tests/
```

Prerequisites: `bash >= 4.0`, `jq`, `bats-core`

## Making Changes

1. Fork the repository
2. Create a branch: `git checkout -b fix/your-description`
3. Make your change
4. Add or update tests in `.ccma/tests/`
5. Run: `bash .ccma/scripts/ccma-verify.sh && bats .ccma/tests/`
6. Submit a pull request

## Pull Request Requirements

- All existing tests must pass
- New behaviour must have bats tests
- Changes to guards must include both allow and block test cases
- CLAUDE.md placeholder check must pass

## Reporting Issues

Please include:
- Your OS and bash version (`bash --version`)
- Whether jq is installed (`jq --version`)
- The full output of `bash .ccma/scripts/ccma-verify.sh`
- The relevant lines from `.claude/disruption-log.jsonl` if a guard is misbehaving
