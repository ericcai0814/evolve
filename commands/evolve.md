---
description: "Audit the Claude Code configuration ecosystem (agents, skills, hooks, rules, memory)"
argument-hint: "[audit|evolve|react]"
allowed-tools: ["Task", "Read", "Grep", "Glob"]
---

Use the **evolve-orchestrator** agent to handle this audit request: $ARGUMENTS

The orchestrator will:
1. Scan inventory at `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/hooks/`, `~/.claude/rules/`, `~/.claude/projects/*/memory/`, and `~/.claude/settings.json`
2. Determine mode (audit / evolve / react)
3. Dispatch specialized sub-agents in parallel (agent-auditor, hook-auditor, memory-reviewer, rules-auditor, skill-auditor, standards-drift-checker)
4. Synthesize a GO / CONDITIONAL-GO / NO-GO report
