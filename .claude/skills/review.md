---
name: review
description: "Run a code review on recent changes or specific files. Invokes the reviewer agent with the code-review-checklist skill."
---

# /review — Code Review

## Usage
- `/review` — Review all uncommitted changes
- `/review src/auth/` — Review specific path

## Process
1. Run `git diff --stat` to identify changed files
2. If no changes: inform user, stop
3. Invoke the **reviewer** agent with:
   - Task: "Code review of recent changes"
   - Modified files: from git diff
   - Plan: (not applicable — direct review)
4. Report the reviewer's assessment (ACCEPTED / MINOR / MAJOR / REJECTED)
5. If MINOR or MAJOR: ask user if they want to invoke coder for fixes
