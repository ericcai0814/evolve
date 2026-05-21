#!/bin/bash
# scheduled-evolve.sh — Evolve 系統排程腳本
#
# 用途：
#   輕量模式（預設，適合排程）：
#     - 執行規則驅動的 rules-auditor 靜態掃描
#     - 產出 evolve-log/YYYY-MM-DD.md 執行報告
#
#   完整模式（--full，等同手動 /evolve）：
#     - 在輕量模式基礎上，額外呼叫 Claude 執行全套 auditor agents
#
# 用法：
#   ./scheduled-evolve.sh              # 輕量模式
#   ./scheduled-evolve.sh --full       # 完整模式（手動觸發）
#   ./scheduled-evolve.sh --dry-run    # 只報告，不寫入任何檔案
#
set -euo pipefail

# ── 常數定義 ──────────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
EVOLVE_LOG_DIR="$HOME/.claude/homunculus/evolve-log"
TODAY=$(date '+%Y-%m-%d')
REPORT_FILE="$EVOLVE_LOG_DIR/${TODAY}.md"
SKILL_USAGE_LOG="$CLAUDE_DIR/skill-usage.log"

# ── 引數解析 ──────────────────────────────────────────────
MODE="scheduled"    # scheduled | full
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --full)     MODE="full" ;;
        --dry-run)  DRY_RUN=true ;;
        *)          echo "[WARN] 不認識的引數: $arg" ;;
    esac
done

# ── 計數器 ──────────────────────────────────────────────
high_issues=0

# ── 輔助函式 ──────────────────────────────────────────────

# ── 初始化報告 ──────────────────────────────────────────────
init_report() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    mkdir -p "$EVOLVE_LOG_DIR"
    cat > "$REPORT_FILE" <<HEADER
---
date: ${TODAY}
mode: ${MODE}
dry_run: false
---

# Evolve 執行報告 — ${TODAY}

**模式：** ${MODE}
**執行時間：** $(date '+%Y-%m-%d %H:%M:%S')

HEADER
}

# 追加內容到報告
append_report() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "$1"
        return
    fi
    echo "$1" >> "$REPORT_FILE"
}

# ── 步驟 1：Rules 靜態掃描（輕量模式）──────────────────────
run_rules_audit() {
    append_report "## Rules 靜態掃描"
    append_report ""

    local rules_dir="$HOME/dotfiles/claude/rules"
    local issues=0

    if [[ ! -d "$rules_dir" ]]; then
        append_report "⚠️ rules 目錄不存在：${rules_dir}"
        append_report ""
        return
    fi

    # 規則 1：rule 檔案超過 30 行（超出預算）
    while IFS= read -r -d '' rule_file; do
        local line_count
        line_count=$(wc -l < "$rule_file" | tr -d ' ')
        if [[ "$line_count" -gt 30 ]]; then
            append_report "- [MED] Rule 檔案過長：\`$(basename "$rule_file")\`（${line_count} 行，建議 ≤30）"
            ((issues++)) || true
        fi
    done < <(find "$rules_dir" -name "*.md" -print0 2>/dev/null)

    # 規則 2：rule 檔案中含 TODO/FIXME
    while IFS= read -r -d '' rule_file; do
        if grep -qiE 'TODO|FIXME' "$rule_file" 2>/dev/null; then
            append_report "- [LOW] Rule 含未完成標記：\`$(basename "$rule_file")\`"
            ((issues++)) || true
        fi
    done < <(find "$rules_dir" -name "*.md" -print0 2>/dev/null)

    # 規則 3：CLAUDE.md 行數
    local claude_md="$HOME/dotfiles/claude/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
        local claude_lines
        claude_lines=$(wc -l < "$claude_md" | tr -d ' ')
        if [[ "$claude_lines" -gt 200 ]]; then
            append_report "- [HIGH] CLAUDE.md 過長：${claude_lines} 行（建議 ≤200）"
            ((issues++)) || true
            ((high_issues++)) || true
        fi
    fi

    if [[ "$issues" -eq 0 ]]; then
        append_report "✅ 無問題。"
    fi
    append_report ""
}

# ── 步驟 2：完整模式提示 ──────────────────────────────────
run_full_mode_notice() {
    if [[ "$MODE" != "full" ]]; then
        return
    fi

    append_report "## 完整模式（Full）"
    append_report ""
    append_report "完整的 AI auditor 需在 Claude Code session 中執行 \`/evolve\`。"
    append_report "排程腳本僅執行輕量靜態檢查，AI agents 無法在排程環境中運行。"
    append_report ""
    append_report "**建議：** 每週手動執行一次 \`/evolve\` 完整審計。"
    append_report ""
}

# ── 步驟 3：記錄 skill-usage.log ──────────────────────────
log_execution() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') scheduled-evolve MODE=${MODE}" \
        >> "$SKILL_USAGE_LOG" 2>/dev/null || true
}

# ── 步驟 4：最終摘要 ──────────────────────────────────────
write_summary() {
    local decision="GO"
    if [[ "$high_issues" -gt 0 ]]; then
        decision="CONDITIONAL-GO"
    elif grep -q '\[HIGH\]' "$REPORT_FILE" 2>/dev/null; then
        decision="CONDITIONAL-GO"
    fi

    append_report "---"
    append_report ""
    append_report "## 摘要"
    append_report ""
    append_report "**決策：** ${decision}"
    append_report ""
    if [[ "$DRY_RUN" == "false" ]]; then
        append_report "報告路徑：\`${REPORT_FILE}\`"
    fi
}

# ── 主程式 ──────────────────────────────────────────────
main() {
    # ── 每日執行一次防護 ──
    if [[ "$DRY_RUN" == "false" && -f "$REPORT_FILE" ]]; then
        echo "[scheduled-evolve] 今日已執行，略過（${REPORT_FILE}）"
        exit 0
    fi

    init_report
    run_rules_audit
    run_full_mode_notice
    write_summary
    log_execution

    if [[ "$DRY_RUN" == "false" ]]; then
        echo "[scheduled-evolve] 完成。報告：${REPORT_FILE}"
    else
        echo "[scheduled-evolve] dry-run 完成，無檔案寫入。"
    fi
}

main "$@"
