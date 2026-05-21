---
name: ref-agent-design
description: Reference for agent-auditor sub-agent. Agent vs Skill decision tree, agent anatomy, model selection strategy, and staleness signals.
---

# Agent Design Reference

## Agent vs Skill

```
Need tools (Read, Bash, etc.)?
├── Yes → Need a persona/role?
│   ├── Yes → AGENT
│   └── No → Consider skill with context: fork + tools
└── No → Need reusable process guidance?
    ├── Yes → SKILL
    └── No → Is it a one-line entry point?
        ├── Yes → SKILL with context: fork
        └── No → RULE or MEMORY
```

## Agent Anatomy

### Frontmatter (required fields)

```yaml
---
name: kebab-case-name          # Must match filename
description: >                  # Trigger-rich, explains WHEN to invoke
  Expert X specialist. Use PROACTIVELY when [trigger condition].
tools: ["Read", "Grep", "Glob"] # Minimal set — principle of least privilege
model: sonnet                   # haiku | sonnet | opus
---
```

Optional frontmatter:
- `skills: ["skill-name"]` — preloads skill content into agent context

### Body Structure

1. **Persona** (1 line): "You are a senior/expert [role]."
2. **When Invoked** section: Numbered steps for entry
3. **Checklist/Guidelines**: Priority-ordered (CRITICAL → HIGH → MEDIUM → LOW)
4. **Output Format**: Template showing expected report structure
5. **Rules/Constraints**: What NOT to do

### Body Size

- Target: 80-150 lines
- Max: 200 lines
- If over 200: extract reference content into a skill file

## Model Selection Strategy

| Model | Cost | Use When |
|-------|------|----------|
| `haiku` | Lowest | Simple checks, pattern matching, lightweight audits, frequent invocation |
| `sonnet` | Medium | Main development, complex analysis, code generation, orchestrating small teams |
| `opus` | Highest | Deep reasoning, architectural decisions, orchestrating large teams, ambiguous tasks |

### Decision Heuristic

- Does the agent just scan and report? → `haiku`
- Does the agent need to understand complex code? → `sonnet`
- Does the agent need to make judgment calls across domains? → `opus`

## Description Quality

The `description` field is the primary mechanism for agent discovery. It must:

1. **State the role**: "Expert X specialist" or "Y auditor"
2. **State the trigger**: "Use when..." or "Use PROACTIVELY when..."
3. **Be specific**: Distinguish from other agents

```markdown
# BAD — generic
description: Reviews code quality

# GOOD — specific trigger
description: Expert code review specialist. Use immediately after writing
or modifying code. MUST BE USED for all code changes.
```

## Tools Constraint

Only declare tools the agent actually needs:

| Tool | Grant when |
|------|------------|
| Read | Agent reads files |
| Grep | Agent searches file content |
| Glob | Agent searches file names |
| Bash | Agent runs shell commands |
| Write | Agent creates new files |
| Edit | Agent modifies existing files |
| Agent | Agent orchestrates sub-agents |

Never grant Write/Edit to read-only auditors.

## Staleness Signals

An agent may be stale or dead if:
- No entry-point skill or workflow references it
- Description uses outdated tool names or patterns
- Body references files/paths that no longer exist
- Another agent covers the same functionality
- Model is over-provisioned for actual complexity
