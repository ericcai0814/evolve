---
name: evolve
description: >
  Use when running /evolve to audit, evolve, or react to config ecosystem health.
  Reads current inventory, determines mode, and dispatches specialized sub-agents in parallel.
context: fork
agent: evolve-orchestrator
---

Audit the configuration ecosystem.

$ARGUMENTS

Scan inventory (agents, skills, hooks, rules, memory), determine mode (audit/evolve/react),
dispatch sub-agents in parallel, and synthesize a go/no-go report.
