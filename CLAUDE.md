# [PROJECT NAME]

[One-line description of what this project does.]

## Build & Run

```bash
# Build
[YOUR BUILD COMMAND]

# Test
[YOUR TEST COMMAND]

# Lint
[YOUR LINT COMMAND]

# Start (if applicable)
[YOUR START COMMAND]
```

## Architecture Overview

```
[YOUR PROJECT STRUCTURE]
```

[Brief description of architecture: layers, data flow, key modules.]

## Conventions

- [Language-specific naming convention, e.g. snake_case / camelCase]
- [Type system rules, e.g. type hints, generics]
- [Error handling pattern, e.g. Result type, exceptions, error codes]
- [Import ordering, e.g. stdlib → third-party → local]
- [Docstring style, e.g. Google, JSDoc, rustdoc]

## Known Pitfalls

- [Gotcha 1: e.g. floating point precision in comparisons]
- [Gotcha 2: e.g. async code requires tokio runtime]

## Security-Sensitive Paths

- `**/auth/**`, `**/middleware/**`
- `**/*.pem`, `**/*.key`, `**/.env*`
- [Add project-specific sensitive paths here]

# Agent Delegation — MANDATORY

@import .claude/delegation-rules.md

<!-- Model selection is defined in each agent's frontmatter. -->
<!-- Agent tool restrictions (disallowedTools) are enforced at the platform level. -->
