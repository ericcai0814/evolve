---
name: ref-skill-patterns
description: Reference for skill-auditor sub-agent. Advanced skill patterns including taxonomy, setup, data persistence, scripts, on-demand hooks, and iteration methodology.
---

# Skill Patterns Reference

## Skill Taxonomy (9 Types)

Use this to classify skills and identify gaps in coverage.

| Type | Purpose | Examples |
|------|---------|---------|
| **Library & API Reference** | Proper usage of libraries, CLIs, SDKs | Billing library edge cases, design system guidance |
| **Product Verification** | Test/verify functionality, often with Playwright/tmux | Signup flow driver, checkout verifier |
| **Data Fetching & Analysis** | Connect to data and monitoring stacks | Funnel query tool, Grafana datasource mapping |
| **Business Process & Team Automation** | Automate repetitive workflows | Standup aggregator, ticket creation with schema enforcement |
| **Code Scaffolding & Templates** | Generate framework boilerplate | Migration templates, new app creation with auth pre-configured |
| **Code Quality & Review** | Enforce organizational code quality standards | Adversarial review via fresh-eyes subagent, style enforcement |
| **CI/CD & Deployment** | Fetch, push, deploy code | PR babysitting with flaky CI retry, gradual traffic rollout |
| **Runbooks** | Multi-tool investigation from symptoms to structured report | Service-specific debugging, oncall runner |
| **Infrastructure Operations** | Routine maintenance with guardrails for destructive actions | Orphaned resource cleanup, dependency approval |

## Setup Pattern (config.json)

Skills may need user-specific context (e.g., which Slack channel to post standups to).

### How It Works

1. Skill checks for `config.json` in its directory on activation
2. If missing or incomplete, agent uses `AskUserQuestion` to prompt the user
3. User responses are saved to `config.json`
4. Subsequent invocations read config automatically — no repeated questions

```json
// skills/my-skill/config.json
{
  "slackChannel": "#team-standup",
  "reviewers": ["alice", "bob"],
  "timezone": "Asia/Taipei"
}
```

### Guidelines

- Keep config minimal — only store what cannot be inferred
- Provide sensible defaults where possible
- Use `AskUserQuestion` for structured choices (multiple-choice)
- Document expected config keys in SKILL.md

## Data Persistence

Skills can maintain state across invocations using stored data.

### Storage Options

| Format | Use Case | Example |
|--------|----------|---------|
| **Append-only .log** | Execution history, audit trail | `standups.log` tracking every post written |
| **JSON** | Structured state, counters | `metrics.json` with usage statistics |
| **SQLite** | Queryable datasets, complex relations | Historical analysis data |

### Critical Rule: Use ${CLAUDE_PLUGIN_DATA}

Data stored in the skill directory **may be deleted when the skill is upgraded**. Long-term stable data must be stored in `${CLAUDE_PLUGIN_DATA}`.

```
# Ephemeral (OK to lose on upgrade)
skills/my-skill/cache.json

# Persistent (survives upgrades)
${CLAUDE_PLUGIN_DATA}/my-skill/history.log
```

## Store Scripts & Generate Code

Provide helper functions and libraries so Claude spends its turns on **composition and decision-making**, not reconstructing boilerplate.

### Why This Matters

Token generation is far more expensive than running code. A sorting algorithm via code execution is cheaper and more reliable than sorting via token generation.

### Pattern

```
skills/my-skill/
├── SKILL.md
├── scripts/
│   ├── fetch-metrics.py    # Reusable data fetcher
│   ├── validate-schema.sh  # Schema validator
│   └── helpers.ts          # Composable utility functions
└── templates/
    └── migration.ts.tmpl   # Code template
```

Claude invokes scripts via tools and composes them into complex workflows without rebuilding basic functionality each time.

## On-Demand Hooks

Hooks that activate **only when a specific skill is called**, providing opinionated guardrails scoped to a workflow.

| Example | Behavior |
|---------|----------|
| `/careful` | Blocks destructive commands (rm -rf, DROP TABLE) in production |
| `/freeze` | Blocks edits outside a specific directory during debugging |

This pattern bridges skills and hooks — the skill sets the mode, the hook enforces it.

## Iteration Methodology

### Start with Evaluation

Before building a skill, test with representative tasks to identify **capability gaps**. Don't guess what Claude needs — measure it.

### Iterate with Claude

Use the agent itself to capture successful approaches into the skill. Most skills begin simply and improve as Claude encounters edge cases. The Gotchas section is built this way.

### Measure Usage

A PreToolUse hook on `Skill` logs every invocation to `~/.claude/skill-usage.log` in format: `timestamp user skill args`.

**Analysis queries** (for skill-auditor sub-agent during `/evolve` audit):

```bash
# Top 10 most used skills
awk '{print $3}' ~/.claude/skill-usage.log | sort | uniq -c | sort -rn | head -10

# Never-triggered skills (compare against installed)
awk '{print $3}' ~/.claude/skill-usage.log | sort -u > /tmp/used.txt
ls ~/.claude/skills/ | sort > /tmp/all.txt
comm -23 /tmp/all.txt /tmp/used.txt

# Daily usage trend
awk '{print $1}' ~/.claude/skill-usage.log | sort | uniq -c
```

**Audit signals from usage data:**
- High frequency → invest in improving (add Gotchas, refine content)
- Zero triggers → candidate for archive (check CSO description first)
- Lower than expected → CSO description may need optimization
