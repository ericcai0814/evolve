---
name: ref-skill-authoring
description: Reference for skill-auditor sub-agent. Skill quality principles, CSO optimization, progressive disclosure, and description writing guide.
---

# Skill Authoring Reference

## Skill Quality Principles

### 1. Trigger-First Description (CSO)

The `description` field is how Claude discovers skills. It must describe **when to activate**, not what the skill does.

```markdown
# BAD — describes workflow
description: Analyzes code patterns, generates tests, runs coverage, and produces report

# GOOD — describes trigger condition
description: Use when writing, updating, or reviewing auto memory entries.
Ensures memories are actionable and well-structured.
```

### 2. Concise Main Entry (Prompt Caching)

SKILL.md should be under 500 lines. A shorter primary tier reduces model cognitive load and improves prompt cache hit rates.

- Lead with the decision framework or key guidelines
- Move detailed reference to separate files (ref-*.md)
- Use tables over prose for structured information
- Structure rules (what belongs in SKILL.md vs ref files) matter more than the size limit

### 3. No Persona Language

Skills provide **guidelines**, not **personas**. "You are..." belongs in agents.

```markdown
# BAD — persona in skill
You are an expert memory writer. When invoked, you should...

# GOOD — guideline in skill
## Quality Principles
Every memory must pass: "Would future Claude decide differently?"
```

### 4. Don't State the Obvious

Only write information that pushes Claude beyond its default thinking. If removing a section would not change Claude's behavior, delete it.

> Example: The frontend-design skill specifically steers Claude away from its default Inter font + purple gradient tendency — that is non-obvious knowledge worth including.

### 5. Build a Gotchas Section

The highest-signal content in any skill is the **Gotchas section**. Build it iteratively from real failure cases Claude encounters while using the skill. Every skill should include or progressively develop this section.

### 6. Avoid Railroading

Provide information and flexibility, not rigid step-by-step rails. Let Claude adapt to the situation rather than forcing a specific path.

```markdown
# BAD — railroading
Step 1: Run lint. Step 2: Run test. Step 3: If fail, fix line X.

# GOOD — information + flexibility
## Quality Checks
Run lint and test before commit. Fix failures based on error context.
Common pitfalls: [gotchas section]
```

## CSO Optimization

### Description Patterns That Work

```markdown
# Pattern: "Use when [specific condition]"
description: Use when deciding what configuration artifact to create

# Pattern: "Use when [action] + [constraint]"
description: Use when writing TypeScript code in monorepo projects

# Pattern: "Use when [trigger]. Ensures [outcome]."
description: Use when reviewing PRs. Ensures security and quality standards.
```

### Description Anti-Patterns

- Starting with "This skill..." (not a trigger)
- Listing all features (overloads CSO matching)
- Using jargon not in user's vocabulary
- Being so broad it matches everything

## Progressive Disclosure (Three-Tier Model)

Anthropic's **core design principle** for skills. Skills are folders, not just markdown files.

| Tier | Content | When Loaded |
|------|---------|-------------|
| **Metadata** | Frontmatter `name` + `description` | Preloaded at session start |
| **Primary** | Full SKILL.md (<500 lines) | Loaded when Claude determines relevance |
| **Referenced** | ref-*.md, assets/, scripts/ | Loaded only when Claude needs them |

```
skills/my-skill/
├── SKILL.md           # Primary tier (<500 lines)
├── ref-topic-a.md     # Referenced tier, preloaded by agents
├── ref-topic-b.md     # Referenced tier, per domain
├── scripts/           # Executable helpers Claude can invoke
├── assets/            # Templates, examples
└── config.json        # User-specific settings (see ref-skill-patterns)
```

### When to Split

- Main SKILL.md exceeds 500 lines → extract to ref files
- Different agents need different subsets → separate ref files
- Content is domain-specific → one ref per domain
- Mutually exclusive contexts → separate files to reduce token usage

### Naming Convention

- `ref-*.md` for reference documents preloaded by agents
- Keep each ref file under 200 lines

## Frontmatter Fields

```yaml
---
name: kebab-case-name     # Required: matches directory name
description: >            # Required: CSO-optimized trigger description
  Use when [condition]. Ensures [outcome].
origin: ECC               # Optional: who authored it
---
```

## Staleness Signals

A skill may be dead if:
- No agent declares it in `skills` frontmatter
- No agent preloads it and no entry-point or workflow skill links to it
- Description uses outdated terminology
- Content duplicates what's now in rules or CLAUDE.md
- Last modified date is very old relative to repo activity
