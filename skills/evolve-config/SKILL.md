---
name: evolve-config
description: Use when deciding what configuration artifact to create (agent, skill, hook, rule, memory) or when auditing the health of the existing config ecosystem. Provides the decision framework and quality gates.
---

# Configuration Ecosystem Evolution

## Three Modes

| Mode | Trigger | Action |
|------|---------|--------|
| **React** | Session reveals repeated friction, missing automation, or new pattern | Recommend specific artifact to create |
| **Evolve** | User wants to improve existing config | Analyze current state, suggest upgrades |
| **Audit** | Periodic health check (`/evolve`) | Spawn sub-agents, produce go/no-go report |

## Decision Framework: Signal → Artifact

| Signal | Artifact | Why |
|--------|----------|-----|
| Same correction given 3+ times | **feedback memory** | Stops repetition across sessions |
| Repeated multi-step workflow | **skill** | Encapsulates reusable process |
| Needs tool access + persona | **agent** | Skills can't use tools or hold persona |
| One-liner entry point that triggers an agent | **skill** with `context: fork` | User-facing entry point |
| Dangerous pattern to block before execution | **hook (PreToolUse)** | Prevents damage in real-time |
| Post-execution auto-check needed | **hook (PostToolUse)** | Catches issues after tool runs |
| Stable, always-needed guidance | **rule** | Loaded every session, no lookup cost |
| Context about user/project/reference | **memory** | Persists across sessions, read on demand |

## Artifact Quality Gates

| Artifact | Gate |
|----------|------|
| Memory | Passes "would future Claude decide differently?" test |
| Rule | Worth the always-on context cost (<20 lines ideal) |
| Skill | Description triggers CSO correctly; <500 lines main entry; three-tier progressive disclosure; has or plans Gotchas section |
| Entry-point skill | `context: fork` set; CSO-optimized description; under 500 lines; no inline agent logic |
| Agent | Has persona, tools declaration, clear trigger in description |
| Hook | Regex tested against 5+ positive and 5+ negative cases |

## Audit Protocol

1. Orchestrator scans inventory → determines mode
2. Spawns 5 sub-agents in parallel (memory, agent, skill, hook, rules)
3. Collects reports, applies severity (high/med/low)
4. Decision: GO / CONDITIONAL-GO / NO-GO per QA report standards

> **Opus 4.7 note**: Auditors should report all findings without pre-filtering — orchestrator applies severity weighting. Set effort to `xhigh` for thorough audits.

## References

Sub-agents preload domain-specific refs: `ref-memory-quality`, `ref-agent-design`, `ref-skill-authoring`, `ref-skill-patterns`, `ref-hook-design`, `ref-rules-optimization`, `ref-config-audit`
