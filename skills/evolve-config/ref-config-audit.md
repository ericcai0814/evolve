---
name: ref-config-audit
description: Reference for cross-cutting config ecosystem audit. Health check checklists, severity grading, and cleanup templates for all artifact types.
---

# Configuration Audit Reference

## Inventory Check

Before auditing, collect current counts:

```
agents/       → count .md files (exclude subdirs for sub-agents)
skills/       → count SKILL.md files
rules/common/ → count .md files
hooks         → count hookify rules in settings.json
memory/       → count topic files + MEMORY.md line count
```

## Per-Type Health Checks

### Agents

| Check | Severity | Signal |
|-------|----------|--------|
| Missing `tools` in frontmatter | high | Agent can't function |
| `description` doesn't explain trigger | high | Never gets invoked |
| Wrong `model` for complexity | med | Cost waste or quality loss |
| No matching entry-point skill | low | Harder to discover |
| Body >200 lines | med | Context bloat when spawned |
| Duplicate functionality with another agent | med | Confusion in orchestration |

### Skills

| Check | Severity | Signal |
|-------|----------|--------|
| `description` doesn't start with "Use when" | high | CSO won't trigger |
| SKILL.md >500 lines (main entry) | med | Slow to load, dilutes focus |
| No SKILL.md in skill directory | high | Skill is broken |
| Reference files not used by any agent | low | Dead reference |
| Description describes workflow instead of trigger | med | CSO mismatch |

### Rules

| Check | Severity | Signal |
|-------|----------|--------|
| Rule >40 lines | med | Expensive always-on context |
| Duplicates content in CLAUDE.md | high | Wasted context budget |
| Duplicates content in another rule | high | Wasted context budget |
| Path-specific rule could be global | low | Missed optimization |
| Rule content derivable from code | med | Unnecessary memorization |

### Hooks

| Check | Severity | Signal |
|-------|----------|--------|
| Regex matches common false positives | high | Blocks legitimate work |
| Hook type wrong (Pre vs Post) | high | Doesn't catch what it should |
| Duplicate intent with another hook | med | Redundant processing |
| No test cases documented | low | Hard to maintain |
| `warn` when should `block` (or vice versa) | med | Wrong severity response |

### Memory

| Check | Severity | Signal |
|-------|----------|--------|
| MEMORY.md >200 lines | high | Truncated in sessions |
| Topic file >50 lines | med | Should be split |
| Orphan topic files | med | Not discoverable |
| Missing Why on feedback memories | med | Can't judge edge cases |
| Relative dates | med | Meaningless in future |
| Derivable information stored | low | Wasted budget |

## Severity Decision Table

| Condition | Decision |
|-----------|----------|
| Any `high` issue | **NO-GO** — must fix before proceeding |
| Only `med` issues | **CONDITIONAL-GO** — list required fixes |
| All `low` or clean | **GO** — ecosystem healthy |

## Report Template

```markdown
# Config Ecosystem Audit Report

**Date:** YYYY-MM-DD
**Decision:** GO / CONDITIONAL-GO / NO-GO

## Inventory
- Agents: X | Skills: Y | Rules: W | Hooks: V | Memory files: U

## Findings

### [HIGH] Issue title
- **Type:** agent / skill / rule / hook / memory
- **File:** path/to/file
- **Issue:** Description
- **Fix:** Recommended action

### [MED] Issue title
...

### [LOW] Issue title
...

## Recommendations
1. Priority fix list
2. Cleanup candidates
3. New artifacts to create
```

## Cleanup Actions

| Action | When |
|--------|------|
| Delete agent | No entry-point skill or workflow references it, no recent invocations |
| Delete skill | Description never triggers, no agent preloads it |
| Merge rules | Two rules cover overlapping guidance |
| Promote memory → rule | Same memory read in >80% of sessions |
| Demote rule → memory | Rule rarely relevant, high context cost |
| Split topic file | Over 50 lines, covers multiple concepts |
