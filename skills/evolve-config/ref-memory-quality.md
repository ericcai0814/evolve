---
name: ref-memory-quality
description: Reference for memory-reviewer sub-agent. Quality principles, MEMORY.md structure, lifecycle, and common mistakes for auto memory entries.
---

# Memory Quality Reference

## The 200-Line Constraint

`MEMORY.md` is loaded into every session but **only the first 200 lines**. Topic files are **not** loaded at startup — Claude reads them on demand.

- `MEMORY.md` = concise index with one-line pointers to topic files
- Topic files = detailed content, read only when relevant
- Treat `MEMORY.md` like a table of contents, not a notebook

## Quality Principles

### 1. Actionable

Every memory must prescribe or inform a concrete action.

```markdown
# BAD — observation without action
The project uses TypeScript.

# GOOD — changes behavior
User prefers strict TypeScript: enable `noUncheckedIndexedAccess`,
avoid `any`, use discriminated unions over type assertions.
```

### 2. Specific

Concrete enough to apply without interpretation.

```markdown
# BAD — vague
User likes clean code.

# GOOD — precise
User wants functions under 50 lines, files under 800 lines,
no nested callbacks deeper than 3 levels.
```

### 3. Atomic

One concept per memory file. Combining unrelated facts makes updates fragile and retrieval noisy.

### 4. Contextual Why

Include **why** for feedback and project memories. Without why, future Claude can't judge edge cases.

```markdown
# BAD — rule without reason
Don't mock the database in tests.

# GOOD — rule with reason
Don't mock the database in tests.
**Why:** Last quarter, mocked tests passed but prod migration failed.
**How to apply:** Integration tests must hit real database.
```

### 5. Absolute Dates

Convert relative dates immediately. "Next Thursday" is meaningless in a future session.

## What NOT to Save

| Don't save | Instead |
|---|---|
| Code patterns, file paths, architecture | Read the code |
| Git history, who changed what | `git log` / `git blame` |
| Bug fix recipes | The fix is in the code |
| Anything in CLAUDE.md or rules | Already loaded every session |
| Ephemeral task state | Use TodoWrite for current session |

**Rule of thumb:** If you can `grep`, `git log`, or read a file to get it, don't memorize it.

## MEMORY.md Structure

```markdown
## User Profile
- [user_role.md](user_role.md) — Senior engineer, deep Go expertise

## Feedback
- [feedback_testing.md](feedback_testing.md) — No mocking DB in integration tests

## Project
- [project_deploy.md](project_deploy.md) — Deploy freeze schedule

## References
- [ref_linear.md](ref_linear.md) — Pipeline bugs in Linear "INGEST"
```

## Memory Lifecycle

| Phase | Action |
|-------|--------|
| Before creating | Check MEMORY.md for existing entry; update instead of duplicate |
| When to update | User corrects guidance, context changes, memory is inaccurate |
| When to delete | Promoted to CLAUDE.md/rules, deadline passed, memory was wrong |

## Audit Checklist

- [ ] MEMORY.md under 200 lines
- [ ] Each line is a pointer, not content
- [ ] No duplicate entries across topic files
- [ ] All topic files referenced in MEMORY.md
- [ ] No orphan topic files (exist but not indexed)
- [ ] Feedback memories have **Why** + **How to apply**
- [ ] No relative dates
- [ ] No derivable information (code paths, git history)
- [ ] Topic files under 50 lines each
