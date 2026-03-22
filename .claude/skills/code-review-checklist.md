---
name: code-review-checklist
description: "Structured code review checklist covering correctness, scope, error handling, input validation, code quality, dependencies, security first-pass, and conventions compliance."
---

# Code Review Checklist

Apply each category to every changed file. Report findings with file and line number.

## Categories

- **CORRECTNESS**: Logic errors, off-by-one, wrong return values, unhandled error paths, boundary conditions (empty input, max values, null/None).
- **SCOPE**: Only files assigned in the subtask are modified. No scope creep. No drive-by fixes.
- **ERROR HANDLING**: Structured errors (Result/Either/custom types), no silent failures, no empty catch/rescue blocks, no unwrap()/expect() without justification.
- **INPUT VALIDATION**: All external input validated at entry points. Boundary conditions handled. Numeric ranges checked. String lengths bounded.
- **CODE QUALITY**: Naming consistency (matches CLAUDE.md conventions), no commented-out code, no unjustified TODOs, single responsibility per function, no magic numbers.
- **DEPENDENCIES**: Version pinning, no duplication of functionality already in the project, no unnecessary new dependencies.
- **SECURITY (first pass)**: No hardcoded secrets, no direct user input concatenated into shell commands/SQL/file paths, no logging of sensitive data.
- **CONVENTIONS**: Follows CLAUDE.md, consistent with existing codebase patterns, import ordering respected.
