# evolve

**Language:** 繁體中文 | [English](README.en.md)

---

Claude Code 配置生態系健檢工具。`/evolve` 觸發 orchestrator 平行 dispatch 六個 specialized auditor sub-agents，稽核 `~/.claude/` 的 agents / skills / hooks / rules / memory 健康度，產出 **GO** / **CONDITIONAL-GO** / **NO-GO** 報告。

## 做什麼

執行 `/evolve` 後，`evolve-orchestrator` agent 會：

1. **掃描盤點**：列出 `~/.claude/` 下 user-global 的所有配置 artifact
2. **判定模式**：`audit`（定期健檢）/ `evolve`（建議升級）/ `react`（依當前 session 訊號建議該補哪類 artifact）
3. **平行派遣**：spawn 六個 sub-agent，每個專責單一配置領域
4. **彙整**：套 severity 權重，產出單一決策報告

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

另外註冊一個 `SessionStart` hook，每天背景跑一次輕量靜態檢查（rule 行數、TODO 標記、CLAUDE.md 長度）— 見下方〈[排程稽核](#排程稽核)〉。

## 安裝

```
/plugin marketplace add ericcai0814/claude-plugins
/plugin install evolve
```

本機開發 / 本地安裝：

```
git clone https://github.com/ericcai0814/evolve.git
/plugin install file:///絕對路徑/evolve
```

## 使用方式

| 指令 | 行為 |
|---|---|
| `/evolve` | 完整稽核，預設模式（由 orchestrator 自行決定 audit 或 react） |
| `/evolve audit` | 強制走定期健檢模式 |
| `/evolve evolve` | 針對現有配置建議升級方向 |
| `/evolve react` | 依當前 session 訊號建議該新增什麼 artifact |

完整稽核約耗時 1-2 分鐘（六個 sub-agent 平行跑）。

## 稽核範圍

evolve 是 **user-global** 工具：永遠稽核 `~/.claude/`，不看當下 CWD。在任何專案下執行 `/evolve` 都會產生同一份報告。

目前不支援 per-project `.claude/` 的稽核（未來可能透過 `--scope=project` 參數加上）。

## 排程稽核

Plugin 會註冊一個 `SessionStart` hook，每次開新 session 時背景跑輕量靜態檢查。報告寫到：

```
~/.claude/evolve/log/YYYY-MM-DD.md
```

腳本內建「每日只跑一次」保護 — 同一天重開多次 session 不會重複產生報告。要強制重跑：

```bash
rm ~/.claude/evolve/log/$(date +%Y-%m-%d).md
bash ${CLAUDE_PLUGIN_ROOT}/hooks/scheduled-evolve.sh
```

## Optional 整合

- **hookify plugin** — 若有安裝，`hook-auditor` 會 defer 給 `hookify:writing-rules` skill 拿規則品質慣例。沒裝就 fallback 到 `evolve-config/ref-hook-design.md` 的通用標準。**沒有硬相依**。

## Plugin 結構

```
evolve/
├── .claude-plugin/plugin.json
├── commands/evolve.md                     # /evolve 入口
├── agents/
│   ├── evolve-orchestrator.md             # Opus，主控
│   └── evolve/                            # 六個 sub-agent auditor
│       ├── agent-auditor.md
│       ├── hook-auditor.md
│       ├── memory-reviewer.md
│       ├── rules-auditor.md
│       ├── skill-auditor.md
│       └── standards-drift-checker.md
├── skills/
│   └── evolve-config/                     # 決策框架 + reference 文件
│       ├── SKILL.md
│       └── ref-{agent-design, config-audit, hook-design,
│            memory-quality, official-standards, rules-optimization,
│            skill-authoring, skill-patterns}.md
├── hooks/
│   ├── hooks.json                         # SessionStart -> scheduled-evolve.sh
│   └── scheduled-evolve.sh                # 輕量 bash 靜態掃描
└── scripts/
    └── skill-static-test.sh               # 零相依 skill validator
```

## License

MIT — see [LICENSE](LICENSE).
