#!/bin/bash
# scheduled-evolve.sh — Evolve scheduled audit script
#
# Purpose:
#   Lightweight mode (default, suitable for scheduling):
#     - Runs rule-driven static scan against ~/.claude/rules and CLAUDE.md
#     - Writes report to ~/.claude/evolve/log/YYYY-MM-DD.md
#
#   Full mode (--full, equivalent to manual /evolve):
#     - Builds on lightweight; full AI auditor agents must run inside a
#       Claude Code session — see notice section in the report.
#
# Usage:
#   ./scheduled-evolve.sh              # lightweight (default)
#   ./scheduled-evolve.sh --full       # full mode notice
#   ./scheduled-evolve.sh --dry-run    # report to stdout, no file writes
#
set -euo pipefail

# ── Constants ───────────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
EVOLVE_LOG_DIR="$HOME/.claude/evolve/log"
TODAY=$(date '+%Y-%m-%d')
REPORT_FILE="$EVOLVE_LOG_DIR/${TODAY}.md"
SKILL_USAGE_LOG="$CLAUDE_DIR/skill-usage.log"

# ── Argument parsing ────────────────────────────────────────
MODE="scheduled"    # scheduled | full
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --full)     MODE="full" ;;
        --dry-run)  DRY_RUN=true ;;
        *)          echo "[WARN] Unknown argument: $arg" ;;
    esac
done

# ── Counters ────────────────────────────────────────────────
high_issues=0

# ── Initialize report ───────────────────────────────────────
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

# Evolve Audit Report — ${TODAY}

**Mode:** ${MODE}
**Run at:** $(date '+%Y-%m-%d %H:%M:%S')

HEADER
}

# Append a line to the report (or stdout in dry-run)
append_report() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "$1"
        return
    fi
    echo "$1" >> "$REPORT_FILE"
}

# ── Step 1: Rules static scan (lightweight mode) ────────────
run_rules_audit() {
    append_report "## Rules Static Scan"
    append_report ""

    local rules_dir="$HOME/.claude/rules"
    local issues=0

    if [[ ! -d "$rules_dir" ]]; then
        append_report "[WARN] Rules directory not found: ${rules_dir}"
        append_report ""
        return
    fi

    # Rule 1: rule files exceeding 30 lines (over budget)
    while IFS= read -r -d '' rule_file; do
        local line_count
        line_count=$(wc -l < "$rule_file" | tr -d ' ')
        if [[ "$line_count" -gt 30 ]]; then
            append_report "- [MED] Rule file too long: \`$(basename "$rule_file")\` (${line_count} lines, recommended <= 30)"
            ((issues++)) || true
        fi
    done < <(find "$rules_dir" -name "*.md" -print0 2>/dev/null)

    # Rule 2: rule files containing TODO/FIXME markers
    while IFS= read -r -d '' rule_file; do
        if grep -qiE 'TODO|FIXME' "$rule_file" 2>/dev/null; then
            append_report "- [LOW] Rule contains unfinished marker: \`$(basename "$rule_file")\`"
            ((issues++)) || true
        fi
    done < <(find "$rules_dir" -name "*.md" -print0 2>/dev/null)

    # Rule 3: CLAUDE.md line count
    local claude_md="$HOME/.claude/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
        local claude_lines
        claude_lines=$(wc -l < "$claude_md" | tr -d ' ')
        if [[ "$claude_lines" -gt 200 ]]; then
            append_report "- [HIGH] CLAUDE.md too long: ${claude_lines} lines (recommended <= 200)"
            ((issues++)) || true
            ((high_issues++)) || true
        fi
    fi

    if [[ "$issues" -eq 0 ]]; then
        append_report "[OK] No issues."
    fi
    append_report ""
}

# ── Step 2: Full-mode notice ────────────────────────────────
run_full_mode_notice() {
    if [[ "$MODE" != "full" ]]; then
        return
    fi

    append_report "## Full Mode"
    append_report ""
    append_report "Full AI auditor agents must run inside a Claude Code session via \`/evolve\`."
    append_report "This scheduled script runs lightweight static checks only — AI agents"
    append_report "cannot execute in a scheduled / non-interactive environment."
    append_report ""
    append_report "**Recommendation:** run \`/evolve\` manually once a week for the full audit."
    append_report ""
}

# ── Step 3: Log execution to skill-usage.log ────────────────
log_execution() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') scheduled-evolve MODE=${MODE}" \
        >> "$SKILL_USAGE_LOG" 2>/dev/null || true
}

# ── Step 4: Write summary ───────────────────────────────────
write_summary() {
    local decision="GO"
    if [[ "$high_issues" -gt 0 ]]; then
        decision="CONDITIONAL-GO"
    elif grep -q '\[HIGH\]' "$REPORT_FILE" 2>/dev/null; then
        decision="CONDITIONAL-GO"
    fi

    append_report "---"
    append_report ""
    append_report "## Summary"
    append_report ""
    append_report "**Decision:** ${decision}"
    append_report ""
    if [[ "$DRY_RUN" == "false" ]]; then
        append_report "Report path: \`${REPORT_FILE}\`"
    fi
}

# ── Main ────────────────────────────────────────────────────
main() {
    # Once-per-day guard
    if [[ "$DRY_RUN" == "false" && -f "$REPORT_FILE" ]]; then
        echo "[scheduled-evolve] Already ran today, skipping (${REPORT_FILE})"
        exit 0
    fi

    init_report
    run_rules_audit
    run_full_mode_notice
    write_summary
    log_execution

    if [[ "$DRY_RUN" == "false" ]]; then
        echo "[scheduled-evolve] Done. Report: ${REPORT_FILE}"
    else
        echo "[scheduled-evolve] Dry-run complete, no files written."
    fi
}

main "$@"
