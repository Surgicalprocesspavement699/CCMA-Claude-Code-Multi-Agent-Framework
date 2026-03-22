---
name: disruptions
description: "Show disruption report — recurring guard blocks and config improvement candidates."
---

# /disruptions — Guard Block Analysis

Run the disruption report and present results:

1. Execute `./.ccma/scripts/ccma-disruption-report.sh`
2. Summarize:
   - Total blocks
   - Top 5 blocked commands with frequency
   - Config candidates (blocked 3+ times)
3. For each candidate, propose:
   - The blocked command
   - Risk assessment (safe to whitelist? needs wrapper? keep blocked?)
   - Exact config change in `ccma-config.sh`
4. Write proposals to `.claude/disruption-proposals.md`
5. Remind: "Config changes require human review. Do NOT modify ccma-config.sh directly."
