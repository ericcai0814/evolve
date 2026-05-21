#!/usr/bin/env bash
# skill-static-test.sh — 靜態驗證所有 skill 的結構完整性
# 用途：獨立執行 or 被 skill-auditor agent 呼叫
# 零依賴、零 API 成本、零 build step
# 相容 macOS bash 3.2+（無 declare -A、無 GNU sed）
#
# 驗證項目：
#   1. Frontmatter 完整性（name, description）
#   2. Agent 引用驗證（agent: X → 對應檔案存在）
#   3. Skill 交叉引用驗證（引用的 skill 存在）
#   4. Reference 檔案驗證（ref-*.md 引用 → 檔案存在）
#   5. 大小限制（SKILL.md < 500 行，ref < 200 行）
#   6. Description 品質（非空、長度 > 20 字元）

set -o pipefail

SKILLS_DIR="${SKILLS_DIR:-$HOME/.claude/skills}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.claude/agents}"

# 內建 agent types（Claude Code 原生支援，不需要 .md 檔案）
BUILTIN_AGENTS="general-purpose Explore Plan"

# ANSI colors（若 stdout 是 terminal）
if [ -t 1 ]; then
  RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; DIM='\033[0;90m'; RST='\033[0m'
else
  RED=''; YEL=''; GRN=''; DIM=''; RST=''
fi

# Counters
HIGH=0; MED=0; LOW=0; PASS=0; TOTAL_SKILLS=0

# Temp file for known skill names（替代 declare -A，macOS bash 3.2 相容）
KNOWN_SKILLS_FILE=$(mktemp /tmp/skill-names.XXXXXX)
trap 'rm -f "$KNOWN_SKILLS_FILE"' EXIT

# ── Helpers ──

emit() {
  local sev="$1" skill="$2" msg="$3"
  case "$sev" in
    HIGH) printf "${RED}[HIGH]${RST} %-25s %s\n" "$skill" "$msg"; HIGH=$((HIGH + 1)) ;;
    MED)  printf "${YEL}[MED]${RST}  %-25s %s\n" "$skill" "$msg"; MED=$((MED + 1)) ;;
    LOW)  printf "${DIM}[LOW]${RST}  %-25s %s\n" "$skill" "$msg"; LOW=$((LOW + 1)) ;;
  esac
}

is_builtin_agent() {
  for b in $BUILTIN_AGENTS; do
    [ "$1" = "$b" ] && return 0
  done
  return 1
}

is_known_skill() {
  grep -qx "$1" "$KNOWN_SKILLS_FILE" 2>/dev/null
}

# awk-based frontmatter parser（BSD sed 相容問題太多，改用 awk）
get_fm_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    BEGIN { in_fm=0; found=0 }
    /^---$/ { in_fm++; next }
    in_fm == 1 {
      if ($0 ~ "^" field ":") {
        sub("^" field ":[[:space:]]*", "")
        print
        found=1
        exit
      }
    }
    in_fm >= 2 { exit }
  ' "$file"
}

# ── Collect all skills ──

# 用 -L 追蹤 symlink，去重（realpath 去除 symlink 重複）
SKILL_FILES=""
while IFS= read -r sf; do
  dir=$(dirname "$sf")
  # 排除 archive 和 plugins
  case "$dir" in
    */archive/*|*/plugins/*) continue ;;
  esac
  name=$(basename "$dir")
  echo "$name" >> "$KNOWN_SKILLS_FILE"
  SKILL_FILES="${SKILL_FILES}${sf}"$'\n'
done < <(find "$SKILLS_DIR" -follow -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort -u)

# 去重 skill names
sort -u "$KNOWN_SKILLS_FILE" -o "$KNOWN_SKILLS_FILE"

# ── Stopword list for cross-reference false positives ──

STOPWORDS="npm npx git bun bash node the and for not but all any run use see set get add api css env fix new src tmp dev pre may can let log try yet has its are was one two per how who why out off own top end put low mid key tag raw app url cli cmd err msg pkg bin cfg doc lib mod ref var val arr obj str num int len max min idx fmt typ fnc req res ret del tag pro con est ops sys sql xml csv dom svg json html http https yaml toml test file path name data code line sort grep find diff echo exec kill make move open read send stop text type wait work next only push pull each spec with from into just like more most much over once some such than that them then this very well what when will your also been both come does done each else even find first form four full gave give good have help here high hold home keep kind know land last left life line live long look made main many back cert well cert skip true false null"

is_stopword() {
  echo "$STOPWORDS" | tr ' ' '\n' | grep -qx "$1" 2>/dev/null
}

# ── Main validation loop ──

echo "Skill Static Test"
echo "============================================="
echo ""

while IFS= read -r sf; do
  [ -z "$sf" ] && continue
  dir=$(dirname "$sf")
  skill_name=$(basename "$dir")

  # 排除 archive / plugins
  case "$dir" in
    */archive/*|*/plugins/*) continue ;;
  esac

  TOTAL_SKILLS=$((TOTAL_SKILLS + 1))
  skill_errors=0

  # ── 1. Frontmatter 解析 ──

  fm_name=$(get_fm_field "$sf" "name")
  fm_desc=$(get_fm_field "$sf" "description")
  fm_agent=$(get_fm_field "$sf" "agent")
  fm_context=$(get_fm_field "$sf" "context")

  # 1a. name 必須存在
  if [ -z "$fm_name" ]; then
    emit HIGH "$skill_name" "frontmatter 缺少 name 欄位"
    skill_errors=$((skill_errors + 1))
  fi

  # 1b. description 必須存在且有意義長度
  if [ -z "$fm_desc" ]; then
    emit HIGH "$skill_name" "frontmatter 缺少 description 欄位"
    skill_errors=$((skill_errors + 1))
  else
    desc_len=${#fm_desc}
    # 多行 description 用 > 或 | 開頭
    if [ "$fm_desc" = ">" ] || [ "$fm_desc" = "|" ]; then
      # 計算整個 description block
      desc_block=$(awk '
        BEGIN { in_fm=0; in_desc=0 }
        /^---$/ { in_fm++; next }
        in_fm == 1 && /^description:/ { in_desc=1; next }
        in_fm == 1 && in_desc && /^[a-z]/ { exit }
        in_fm == 1 && in_desc { print }
        in_fm >= 2 { exit }
      ' "$sf")
      desc_len=${#desc_block}
    fi
    if [ "$desc_len" -lt 20 ] 2>/dev/null; then
      emit MED "$skill_name" "description 過短（${desc_len} 字元），CSO 觸發品質可能不足"
      skill_errors=$((skill_errors + 1))
    fi
  fi

  # ── 2. Agent 引用驗證 ──

  if [ -n "$fm_agent" ]; then
    if ! is_builtin_agent "$fm_agent"; then
      if [ ! -f "$AGENTS_DIR/${fm_agent}.md" ]; then
        emit HIGH "$skill_name" "agent: ${fm_agent} -> 找不到 ${AGENTS_DIR}/${fm_agent}.md"
        skill_errors=$((skill_errors + 1))
      fi
    fi
  fi

  # ── 3. Skill 交叉引用驗證 ──
  # 高信度模式：只檢查明確寫著「銜接到某 skill」的引用
  # 低信度的 /slash-refs 和 `code-example` 不檢查（誤報率太高）

  body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$sf")

  # 模式: 「銜接/invoke/委託/觸發 + `skill-name`」
  flow_refs=$(echo "$body" | grep -oE '(銜接|委託|呼叫|invoke|trigger)\s*`[a-z][-a-z0-9]+`' | grep -oE '`[a-z][-a-z0-9]+`' | tr -d '`' | sort -u)

  for ref in $flow_refs; do
    [ ${#ref} -lt 3 ] && continue
    is_known_skill "$ref" && continue
    emit MED "$skill_name" "銜接引用 '${ref}' 不在已知 skills 中"
    skill_errors=$((skill_errors + 1))
  done

  # ── 4. Reference 檔案驗證 ──

  ref_mentions=$(echo "$body" | grep -oE 'ref-[-a-z0-9]+\.md' | sort -u)
  for ref_file in $ref_mentions; do
    if [ ! -f "$dir/$ref_file" ]; then
      emit HIGH "$skill_name" "引用 ${ref_file} 但檔案不存在於 ${dir}/"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # 檢查目錄下的 ref-*.md 是否被 SKILL.md 引用（死檔案偵測）
  for ref_path in "$dir"/ref-*.md; do
    [ -f "$ref_path" ] || continue
    ref_basename=$(basename "$ref_path")
    if ! grep -q "$ref_basename" "$sf"; then
      emit LOW "$skill_name" "${ref_basename} 存在但未被 SKILL.md 引用（可能是死檔案）"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # ── 5. 大小限制 ──

  skill_lines=$(wc -l < "$sf" | tr -d ' ')
  if [ "$skill_lines" -gt 500 ] 2>/dev/null; then
    emit MED "$skill_name" "SKILL.md 超過 500 行（${skill_lines} 行），考慮拆分到 ref-*.md"
    skill_errors=$((skill_errors + 1))
  fi

  for ref_path in "$dir"/ref-*.md; do
    [ -f "$ref_path" ] || continue
    ref_lines=$(wc -l < "$ref_path" | tr -d ' ')
    ref_basename=$(basename "$ref_path")
    if [ "$ref_lines" -gt 200 ] 2>/dev/null; then
      emit MED "$skill_name" "${ref_basename} 超過 200 行（${ref_lines} 行）"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # ── 6. context 欄位驗證 ──

  if [ -n "$fm_context" ]; then
    case "$fm_context" in
      fork|inline) ;;
      *) emit MED "$skill_name" "context: '${fm_context}' 不是合法值（應為 fork 或 inline）"
         skill_errors=$((skill_errors + 1)) ;;
    esac
  fi

  # ── Pass ──

  if [ "$skill_errors" -eq 0 ]; then
    PASS=$((PASS + 1))
  fi

done <<< "$SKILL_FILES"

# ── Summary ──

echo ""
echo "---------------------------------------------"
TOTAL_ISSUES=$((HIGH + MED + LOW))
printf "Skills: %d | Pass: ${GRN}%d${RST} | Issues: %d (${RED}HIGH:%d${RST} ${YEL}MED:%d${RST} ${DIM}LOW:%d${RST})\n" \
  "$TOTAL_SKILLS" "$PASS" "$TOTAL_ISSUES" "$HIGH" "$MED" "$LOW"

if [ "$HIGH" -gt 0 ]; then
  echo ""
  echo "VERDICT: FAIL -- ${HIGH} HIGH issues"
  exit 1
elif [ "$MED" -gt 0 ]; then
  echo ""
  echo "VERDICT: WARN -- ${MED} MED issues"
  exit 0
else
  echo ""
  echo "VERDICT: PASS"
  exit 0
fi
