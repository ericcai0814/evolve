---
name: ref-rules-optimization
description: Reference for rules-auditor sub-agent. Memory-to-rule promotion path, context budget management, path-specific rules, and CLAUDE.md optimization.
---

# Rules Optimization Reference

## Promotion Path: Memory → Rule → CLAUDE.md

```
memory (read on demand, low cost)
  ↓ used in >80% of sessions
rule (always loaded, medium cost)
  ↓ critical to every task, universal
CLAUDE.md (always loaded, highest visibility)
  ↓ too expensive for always-on
back to memory (demote)
```

### When to Promote

| From | To | Signal |
|------|-----|--------|
| Memory → Rule | Same memory read in most sessions | Pattern is universally relevant |
| Rule → CLAUDE.md | Rule applies to every single task | Core workflow constraint |
| CLAUDE.md → Rule | Section only relevant to specific contexts | Reduce CLAUDE.md size |
| Rule → Memory | Rule rarely triggers | Not worth always-on cost |

## Context Budget Management

### Always-On Costs

Everything loaded every session:
- `CLAUDE.md` (global + project) — fully loaded
- `rules/common/*.md` — fully loaded
- `MEMORY.md` — first 200 lines only
- Agent/skill descriptions — indexed but not fully loaded

### Budget Guidelines

| Item | Target | Max |
|------|--------|-----|
| Global CLAUDE.md | <100 lines | 150 lines |
| Project CLAUDE.md | <80 lines | 120 lines |
| Single rule file | <20 lines | 40 lines |
| Total rules/common/ | <150 lines | 200 lines |
| MEMORY.md | <150 lines | 200 lines |

### Reducing Context Cost

1. **Merge overlapping rules** into one concise rule
2. **Extract examples** from rules (examples are expensive; put in skills instead)
3. **Use tables** over prose (more info per line)
4. **Remove obvious guidance** ("write clean code" — Claude already knows)
5. **Demote rare rules** to memory

## Path-Specific Rules

Rules in `rules/` can target specific directories:

```
rules/
├── common/          # Always loaded for all projects
│   ├── coding-style.md
│   └── testing.md
├── frontend/        # Only loaded when working in frontend/
│   └── react.md
└── backend/         # Only loaded when working in backend/
    └── api.md
```

### When to Use Path-Specific Rules

- Guidance only applies to a specific part of the codebase
- Different conventions for different languages/frameworks
- Team-specific rules for shared repos

## CLAUDE.md Optimization

### What Belongs in CLAUDE.md

- Workflow constraints (plan first, don't modify on analysis)
- Git conventions (commit message format, branch naming)
- Team process rules (QA report format, teammate rules)
- Infrastructure specifics the user has mandated

### What Does NOT Belong in CLAUDE.md

- Coding style details → `rules/common/coding-style.md`
- Testing requirements → `rules/common/testing.md`
- Tool-specific guidance → skill files
- Temporary project state → memory

### Optimization Checklist

- [ ] No section exceeds 30 lines
- [ ] No duplicated content with rule files
- [ ] No guidance that's obvious/default behavior
- [ ] Tables used where possible
- [ ] Each section has clear, unique purpose
- [ ] Total under 150 lines (global) or 120 lines (project)

## Common Anti-Patterns

| Anti-Pattern | Fix |
|------|-----|
| Same guidance in CLAUDE.md AND a rule file | Remove from one location |
| Rule file that restates language defaults | Delete — Claude already knows |
| Long prose blocks in rules | Convert to tables |
| Rules with examples longer than the rule | Move examples to skill ref |
| Path-specific content in common/ | Move to path-specific rule |
