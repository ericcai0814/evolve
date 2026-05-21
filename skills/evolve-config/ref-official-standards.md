# Official Standards Reference

## Version Marker

```yaml
last_verified: "2026-05-04"
ttl_days: 3
sources:
  - https://code.claude.com/docs/en/skills
  - https://code.claude.com/docs/en/sub-agents
  - https://code.claude.com/docs/en/hooks
  - https://code.claude.com/docs/en/memory
  - https://agentskills.io/specification
context7_library: /ericbuess/claude-code-docs
```

---

## Skill Constraints

### Name (agentskills.io spec — stable)
- 1-64 characters
- Lowercase letters, numbers, hyphens only
- No starting/ending with hyphen
- No consecutive hyphens (`--`)
- Must match parent directory name

### Description
- 1-1024 characters (agentskills.io spec)
- First 250 chars shown in skill list; beyond truncated (Claude Code)
- Should describe **what** AND **when to use**
- Good: includes trigger keywords for agent matching
- Bad: vague ("helps with PDFs") or describes workflow steps

### Size
- SKILL.md < 500 lines (official tip)
- Instructions < 5000 tokens recommended (agentskills.io progressive disclosure)
- Reference files loaded on demand, keep focused

### Frontmatter Fields (evolving — query context7 for latest)
| Field | Required | Stable? | Notes |
|-------|----------|---------|-------|
| `name` | Yes (agentskills.io) / No (Claude Code) | Stable | Max 64 chars; lowercase + digits + hyphens |
| `description` | Recommended | Stable | First 250 chars shown in skill list |
| `argument-hint` | No | Stable | Autocomplete hint, e.g. `[issue-number]` |
| `disable-model-invocation` | No | Stable | `true` = user-only invocation |
| `user-invocable` | No | Stable | `false` = hide from `/` menu |
| `allowed-tools` | No | Stable | Space-separated or YAML list |
| `model` | No | Stable | |
| `effort` | No | Stable | Values: `low`/`medium`/`high`/`xhigh`/`max` — `xhigh` recommended for coding/agentic on Opus 4.7; `max` available but may overthink |
| `context` | No | Stable | `fork` = run in subagent |
| `agent` | No | Stable | Built-in or custom subagent type |
| `hooks` | No | Stable | Skill-scoped lifecycle hooks |
| `paths` | No | Stable | Glob patterns for conditional activation |
| `shell` | No | Stable | `bash` (default) or `powershell` |

### String Substitutions (available in skill body)

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill |
| `$ARGUMENTS[N]` / `$N` | Nth positional argument (0-indexed, shell-style quoting) |
| `${CLAUDE_SESSION_ID}` | Current session ID — useful for logging |
| `${CLAUDE_SKILL_DIR}` | Directory containing the skill's SKILL.md (for referencing bundled scripts/files) |

### Progressive Disclosure
1. **Metadata** (~100 tokens): name + description, loaded at session start
2. **Instructions** (<5000 tokens): full SKILL.md, loaded when activated
3. **Resources** (on demand): scripts/, references/, assets/

### Compaction Behavior
When auto-compaction fires, Claude Code re-attaches each invoked skill's most-recent content after the summary, keeping the **first 5,000 tokens** of each. All re-attached skills share a combined budget of **25,000 tokens**. Older skills are dropped if the budget is exhausted. Implication: skills longer than 5K tokens lose their tail after compaction — keep critical instructions near the top.

### Built-in Agents (evolving — query context7 for latest)

Skills can reference these in `agent:` field without a corresponding file in `~/.claude/agents/`:

| Agent | Model | Purpose |
|-------|-------|---------|
| `general-purpose` | inherit | Complex multi-step tasks, all tools |
| `Explore` | haiku | Read-only codebase search and analysis |
| `Plan` | inherit | Research for plan mode |
| `statusline-setup` | sonnet | Status line configuration |
| `claude-code-guide` | haiku | Claude Code feature questions |

When auditing `agent:` references in skills, check against this list BEFORE flagging as missing.

## Opus 4.7 Behavioral Notes

These behaviors differ from Opus 4.6 and inform how prompts/agents should be tuned. Source: official migration guide.

- **Adaptive thinking off by default**: Requests without explicit `thinking: {type: "adaptive"}` run without thinking. Set explicitly when reasoning quality matters.
- **Strict effort calibration**: At `low`/`medium`, the model scopes work to what was asked — no above-and-beyond. Raise to `high`/`xhigh` for thorough audits.
- **Fewer subagents by default**: Steerable through prompting. Orchestrators must give explicit guidance on when subagents are desirable (evolve-orchestrator already does this).
- **Fewer tool calls by default**: Reasons more, tools less. For coverage-heavy tasks (audits), prompts should explicitly direct tool usage.
- **More literal instruction following**: Will not silently generalize an instruction. State scope explicitly ("for every file matched, including subdirectories").
- **Anti-laziness language overtriggers**: `CRITICAL`/`MUST`/`if in doubt use X` causes overtriggering on 4.5+, more so on 4.7. Prefer plain instructions.
- **Code-review harness anti-pattern**: Filters like "only report high-severity" or "be conservative" cause 4.7 to suppress real findings. For auditor-style work, instruct the model to report every finding and let downstream logic filter.
- **`xhigh` is the recommended effort for coding/agentic work**; `max` is available but prone to overthinking.
- **Tokenization**: 4.7 uses ~1.0–1.35x tokens vs 4.6 for the same text. Line-count budgets (200/500 lines) unaffected; token budgets need re-baseline.
- **Built-in progress updates**: Scaffolding like "summarize after every N tool calls" should be removed.

## Operational Context

When auditing, account for these facts:

- **Hookify rules intercept Claude's tool use, not human terminal commands.** Claude generates lowercase CLI flags (`rm -rf`, not `rm -Rf`). Missing uppercase variants in regex is near-zero real-world impact.
- **Hookify supports two schema formats**: simple (`pattern:` field) AND advanced (`conditions:` block with `field:`/`operator:`/`pattern:` sub-keys). Both are valid. See hookify:writing-rules skill for full schema.
- **Built-in agents exist without files.** `general-purpose`, `Explore`, `Plan`, `statusline-setup`, `claude-code-guide` are provided by Claude Code itself. Skills referencing these via `agent:` field are valid.
- **`event: file` + `pattern:` matches file content, not file path.** To match file paths, use `conditions:` with `field: file_path`.
- **Config thresholds may intentionally differ across contexts.** A lightweight scheduled script and a full auditor can have different thresholds for the same metric — evaluate whether each value serves its own context before flagging inconsistency.

---

### Structural Rules
- `context: fork` without task content = meaningless (official warning)
- `disable-model-invocation: true` removes skill from Claude's context entirely
- `user-invocable: false` hides from / menu but still available to model

---

## Agent Constraints

### Required Frontmatter
- `name`: lowercase + hyphens
- `description`: when Claude should delegate

### Optional Frontmatter (evolving — query context7 for latest)
| Field | Purpose | Stable? |
|-------|---------|---------|
| `tools` | Tool allowlist | Stable |
| `disallowedTools` | Tool denylist (applied before `tools`) | Stable |
| `model` | sonnet/opus/haiku/inherit/full ID | Stable |
| `permissionMode` | default/acceptEdits/auto/dontAsk/bypassPermissions/plan | Stable |
| `maxTurns` | Max agentic turns | Stable |
| `skills` | Preloaded skills (full content injected) | Stable |
| `mcpServers` | MCP server configs | Stable |
| `hooks` | Lifecycle hooks | Stable |
| `memory` | user/project/local | Stable |
| `background` | true/false | Stable |
| `effort` | low/medium/high/xhigh/max — `xhigh` recommended for coding/agentic on Opus 4.7; `max` available but may overthink | Stable |
| `isolation` | worktree | Stable |
| `color` | red/blue/green/yellow/purple/orange/pink/cyan | Stable |
| `initialPrompt` | Auto-submitted first prompt | Stable |

### Plugin Subagent Field Restrictions
Subagents loaded from plugins **cannot use** the following frontmatter fields (silently ignored): `hooks`, `mcpServers`, `permissionMode`. If these are required, the agent file must live in `.claude/agents/` or `~/.claude/agents/` instead of inside a plugin.

### Subagent-Scoped Hook Events
Hooks declared inside a subagent's frontmatter support only 3 events (not the full hook-event list): `PreToolUse`, `PostToolUse`, `Stop`. The `Stop` event is auto-converted to `SubagentStop` at runtime.

### Body Content
- Acts as system prompt for the subagent
- "You are..." persona language is correct for agents (official examples use this)
- Subagents receive ONLY this prompt + environment details, not full Claude Code system prompt

### Model Resolution Order
1. `CLAUDE_CODE_SUBAGENT_MODEL` env var
2. Per-invocation `model` parameter
3. Frontmatter `model` field
4. Main conversation model

### Quality Guidelines (official best practices)
- Design focused subagents: one specific task each
- Write detailed descriptions for delegation matching
- Limit tool access: principle of least privilege
- `tools` + `disallowedTools` conflict: disallowed applied first

### Custom Standards (our additions, not official)
- Completion protocol (DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT)
- Escalation rules (3 failed attempts → STOP)
- Severity definitions in auditor agents

---

## Hook Constraints

### Event Types (evolving — query context7 for latest)

**Can block (exit code 2):**
PreToolUse, UserPromptSubmit, PermissionRequest, Stop, SubagentStop, TeammateIdle, TaskCreated, TaskCompleted, ConfigChange, Elicitation, ElicitationResult, WorktreeCreate

**Cannot block:**
SessionStart, SessionEnd, PostToolUse, PostToolUseFailure, PermissionDenied, Notification, SubagentStart, StopFailure, CwdChanged, FileChanged, PreCompact, PostCompact, InstructionsLoaded, WorktreeRemove

### Matcher Support
**Events WITHOUT matcher support:**
UserPromptSubmit, Stop, TeammateIdle, CwdChanged, TaskCreated, TaskCompleted, WorktreeCreate, WorktreeRemove

### Handler Types
- `command`: shell script
- `http`: HTTP endpoint
- `prompt`: AI evaluation
- `agent`: agent evaluation

**Command-only events** (other handler types are rejected): `SessionStart`, `InstructionsLoaded`. All other events support all 4 handler types.

### Exit Codes
- 0: success, parse JSON from stdout
- 2: blocking error (events that support blocking only)
- Other: non-blocking error, continue

### `if` Field
- Only works on tool events: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, PermissionDenied
- Uses permission rule syntax: `Bash(git *)`, `Edit(*.ts)`

---

## Memory/CLAUDE.md Constraints

### CLAUDE.md
- Target under 200 lines per file
- Use markdown headers and bullets
- Specific > vague ("2-space indent" not "format properly")
- No conflicting instructions across files
- `@path` imports supported (max 5 hops depth)
- HTML comments stripped before injection

### .claude/rules/
- `paths` frontmatter for conditional activation (glob patterns)
- Rules without `paths` loaded unconditionally
- Symlinks supported in rules directory

### Auto Memory (MEMORY.md)
- First 200 lines or 25KB loaded at session start
- Topic files loaded on demand
- Per git repository (worktrees share one memory dir)

---

## Drift Check Queries

When `last_verified` is older than `ttl_days`, run these context7 queries:

```
library: /ericbuess/claude-code-docs
queries:
  1. "skills SKILL.md frontmatter fields specification"
  2. "sub-agents subagent frontmatter fields supported configuration"
  3. "hooks events list PreToolUse PostToolUse all event types"
  4. "built-in subagents Explore Plan general-purpose"
```

Compare results against the field tables and Built-in Agents list above. New fields/agents = update this file + flag as finding.
