---
name: test-patterns
description: "Test writing patterns and standards: coverage requirements, determinism rules, naming conventions, mock strategy, baseline management."
---

# Test Writing Patterns

## Coverage Rules
- Functions with branching logic or error paths: **1 happy path**, **1 edge case**, **1 error case**.
- Simple functions (getters, formatters, pure mappers): **1 happy path** is sufficient.
- Goal is meaningful coverage, not boilerplate.

## Quality Standards
- Tests MUST be **deterministic** (no unseeded random data, no time-dependent assertions without mocking).
- Tests MUST be **independent** (no shared mutable state between tests, no execution-order dependency).
- Test names MUST be descriptive: `should_return_error_when_input_is_empty`, not `test_1`.
- Mock external dependencies (network, filesystem, clock, database).

## Baseline Management
- Run existing test suite BEFORE writing new tests → record baseline.
- After writing new tests, run full suite → compare against baseline.
- A regression = a previously passing test now fails (not a new test failing).

## Greenfield Projects
If no test framework exists:
1. Check project manifest for language/ecosystem
2. Choose standard framework (vitest for Node, pytest for Python, cargo test for Rust)
3. Install if needed
4. Create initial config
5. Record decision in MEMORY.md
6. Baseline: Pass 0 | Fail 0 | Skip 0
