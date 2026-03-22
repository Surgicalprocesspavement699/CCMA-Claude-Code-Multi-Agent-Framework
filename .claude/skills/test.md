---
name: test
description: "Run the test suite and invoke the tester agent to write missing tests for recent changes."
---

# /test — Test Coverage

## Usage
- `/test` — Run tests, check coverage for uncommitted changes
- `/test src/services/` — Focus on specific path

## Process
1. Run the test command from CLAUDE.md (e.g., `cargo test`, `npm test`)
2. Record baseline: pass/fail/skip counts
3. Run `git diff --stat` to identify changed files
4. If changed files have insufficient test coverage:
   - Invoke the **tester** agent with changed files and baseline
5. Report final test results
