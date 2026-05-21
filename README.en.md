# evolve

Configuration ecosystem auditor for Claude Code. Audits the health of your `~/.claude/` setup — agents, skills, hooks, rules, and memory — via an orchestrator that dispatches six specialized auditor sub-agents in parallel and synthesizes a GO / CONDITIONAL-GO / NO-GO report.

## What it does

Running `/evolve` triggers the `evolve-orchestrator` agent, which:

1. **Inventories** the user-global Claude Code config under `~/.claude/`
2. **Determines mode** — `audit` (periodic health check) / `evolve` (recommend upgrades) / `react` (one-off recommendation based on session signals)
3. **Spawns six sub-agents in parallel** — each focused on a single config domain
4. **Synthesizes** their findings into a single report with severity weighting

```
              /evolve
                 │
                 ▼
        evolve-orchestrator    (opus)
                 │
   ┌────┬───────┼───────┬────┐
   ▼    ▼       ▼       ▼    ▼   ▼
 agent  hook  memory  rules  skill  standards-drift
auditor auditor reviewer auditor auditor checker
(sonnet, sonnet, sonnet, haiku, sonnet, sonnet)
```

A lightweight bash version of the rules check also runs once-per-day in the background via the SessionStart hook — see [Scheduled audit](#scheduled-audit) below.

## Install

```
/plugin marketplace add ericcai0814/claude-plugins
/plugin install evolve
```

Or for development / local install:

```
git clone https://github.com/ericcai0814/evolve.git
/plugin install file:///absolute/path/to/evolve
```

## Use

| Invocation | What happens |
|---|---|
| `/evolve` | Full audit, default mode (orchestrator decides between audit / react) |
| `/evolve audit` | Force periodic-health-check mode |
| `/evolve evolve` | Recommend upgrades to existing config |
| `/evolve react` | Recommend new config artifact based on session signals |

The full audit takes ~1-2 min (six sub-agents run in parallel).

## Scope

evolve is **user-global**: it audits `~/.claude/` regardless of which project you are in. Running `/evolve` from any project produces the same report.

Per-project `.claude/` auditing is not currently supported (may be added via `--scope=project` flag in a future version).

## Scheduled audit

The plugin registers a `SessionStart` hook that runs a lightweight static scan (rule file line counts, TODO markers, CLAUDE.md size) in the background. Report is written to:

```
~/.claude/evolve/log/YYYY-MM-DD.md
```

Once-per-day guard built into the script — re-opening sessions throughout the day does not duplicate work. To force re-run:

```bash
rm ~/.claude/evolve/log/$(date +%Y-%m-%d).md
bash ${CLAUDE_PLUGIN_ROOT}/hooks/scheduled-evolve.sh
```

## Optional integrations

- **hookify plugin** — if installed, `hook-auditor` defers to `hookify:writing-rules` for rule-quality conventions. If not installed, falls back to general hook-quality criteria from `evolve-config/ref-hook-design.md`. No hard dependency.

## Plugin structure

```
evolve/
├── .claude-plugin/plugin.json
├── commands/evolve.md                     # /evolve entry
├── agents/
│   ├── evolve-orchestrator.md             # Opus, orchestrates audit
│   └── evolve/                            # Sub-agent auditors
│       ├── agent-auditor.md
│       ├── hook-auditor.md
│       ├── memory-reviewer.md
│       ├── rules-auditor.md
│       ├── skill-auditor.md
│       └── standards-drift-checker.md
├── skills/
│   └── evolve-config/                     # Decision framework + reference docs
│       ├── SKILL.md
│       └── ref-{agent-design, config-audit, hook-design,
│            memory-quality, official-standards, rules-optimization,
│            skill-authoring, skill-patterns}.md
├── hooks/
│   ├── hooks.json                         # SessionStart -> scheduled-evolve.sh
│   └── scheduled-evolve.sh                # Lightweight bash static scan
└── scripts/
    └── skill-static-test.sh               # Zero-dependency skill validator
```

## 中文

繁體中文版見 [README.md](README.md)。

## License

MIT — see [LICENSE](LICENSE).
