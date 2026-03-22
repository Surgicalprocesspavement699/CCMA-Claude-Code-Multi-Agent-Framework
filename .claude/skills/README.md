# CCMA Skills

Skills package domain knowledge (coding conventions, framework patterns, API references) for progressive disclosure. Unlike agents, only the skill name and description are loaded initially (~50 tokens), with the full body loaded only when relevant.

## When to Create a Skill

- Domain-specific instructions that apply to only one type of task
- Framework-specific patterns (e.g., React hooks conventions, Django ORM patterns)
- API references that agents need only occasionally

## How to Create a Skill

Create a `.md` file in this directory with YAML frontmatter:

```yaml
---
name: my-skill
description: "Short description of what this skill provides"
---

# Skill content here
...
```

Agents can auto-load skills via the `skills` frontmatter field in their agent definition.

## See Also

- CCMA Spec, Chapter "Skills Integration" for full details
- Claude Code Docs: https://code.claude.com/docs/en/skills
