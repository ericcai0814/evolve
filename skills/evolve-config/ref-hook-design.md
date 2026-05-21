---
name: ref-hook-design
description: Reference for hook-auditor sub-agent. Hook vs hookify rule selection, block vs warn decisions, regex precision, and settings.json integration.
---

# Hook Design Reference

## Hook vs Hookify Rule

| Mechanism | What It Is | When to Use |
|-----------|------------|-------------|
| **Hook** (settings.json) | Shell command that runs on tool events | Complex validation, external checks, multi-step logic |
| **Hookify rule** (settings.json) | Regex-based pattern match with block/warn | Simple pattern detection, string matching |

### Decision Tree

```
Is the check a simple string/regex match?
├── Yes → Hookify rule
└── No → Does it need external tools or complex logic?
    ├── Yes → Hook script (shell)
    └── No → Can it be a rule in CLAUDE.md instead?
        ├── Yes → Rule (always-on guidance)
        └── No → Hookify rule with warn
```

## Block vs Warn Decision

| Action | When |
|--------|------|
| **block** | Irreversible damage: deleting production data, force-pushing to main, committing secrets |
| **warn** | Suspicious but potentially legitimate: large file writes, unusual tool combinations, deprecated patterns |

### Decision Heuristic

- "If this fires on a false positive, would blocking break the workflow?" → `warn`
- "If this fires on a true positive, would allowing it cause real damage?" → `block`
- When in doubt → `warn` (less disruptive)

## Regex Precision

### Good Regex Patterns

```regex
# Specific: matches only force-push to main/master
git\s+push\s+.*--force.*\s+(main|master)

# Specific: matches hardcoded API keys (common prefixes)
(sk-|pk_|AKIA)[A-Za-z0-9]{20,}
```

### Bad Regex Patterns

```regex
# Too broad: blocks ANY push
git\s+push

# Too broad: matches any string with "key" in it
key\s*=\s*".*"

# Too narrow: misses variations
git push --force main    # misses: git push -f main
```

### Testing Methodology

For every regex, mentally validate against:

**Must match (true positives):**
1. The exact dangerous command
2. Common variations (flags in different order)
3. With extra whitespace or quoting

**Must NOT match (true negatives):**
1. Safe versions of similar commands
2. The pattern appearing in comments or strings
3. Legitimate use cases that look similar

## Hook Event Types

### PreToolUse

Runs BEFORE the tool executes. Use for:
- Preventing dangerous commands
- Validating parameters
- Checking preconditions

### PostToolUse

Runs AFTER the tool executes. Use for:
- Auto-formatting generated code
- Verifying output quality
- Triggering follow-up actions

### Stop

Runs when Claude session ends. Use for:
- Final verification checks
- Cleanup tasks

## Settings.json Integration

Hooks live in `settings.json` under the `hooks` key:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": "~/.claude/hooks/bash-pre-check.sh"
      }
    ]
  }
}
```

Hookify rules live under a separate key and use regex matching.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Blocking legitimate tool use | Narrow the regex, use warn instead |
| Overlapping rules (two rules catch same thing) | Merge into one rule |
| Missing variations (--force but not -f) | Test both long and short flags |
| Hook script not executable | `chmod +x` the script |
| Warn when should block (secrets) | Secrets = always block |
