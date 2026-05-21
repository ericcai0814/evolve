#!/usr/bin/env bash
# skill-static-test.sh — static structural validation for all skills
# Purpose: standalone execution, or called by the skill-auditor agent
# Zero dependencies, zero API cost, zero build step
# Compatible with macOS bash 3.2+ (no declare -A, no GNU sed)
#
# Checks:
#   1. Frontmatter completeness (name, description)
#   2. Agent reference validation (agent: X -> file exists)
#   3. Skill cross-reference validation (referenced skill exists)
#   4. Reference file validation (ref-*.md mentions -> file exists)
#   5. Size limits (SKILL.md < 500 lines, ref < 200 lines)
#   6. Description quality (non-empty, length > 20 chars)

set -o pipefail

SKILLS_DIR="${SKILLS_DIR:-$HOME/.claude/skills}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.claude/agents}"

# Built-in agent types (natively supported by Claude Code, no .md file required)
BUILTIN_AGENTS="general-purpose Explore Plan"

# ANSI colors (only when stdout is a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; DIM='\033[0;90m'; RST='\033[0m'
else
  RED=''; YEL=''; GRN=''; DIM=''; RST=''
fi

# Counters
HIGH=0; MED=0; LOW=0; PASS=0; TOTAL_SKILLS=0

# Temp file for known skill names (replaces declare -A for macOS bash 3.2 compat)
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

# awk-based frontmatter parser (BSD sed has too many compat quirks, awk is portable)
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

# Follow symlinks (-L) and de-duplicate via sort -u
SKILL_FILES=""
while IFS= read -r sf; do
  dir=$(dirname "$sf")
  # Exclude archive and plugins
  case "$dir" in
    */archive/*|*/plugins/*) continue ;;
  esac
  name=$(basename "$dir")
  echo "$name" >> "$KNOWN_SKILLS_FILE"
  SKILL_FILES="${SKILL_FILES}${sf}"$'\n'
done < <(find "$SKILLS_DIR" -follow -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort -u)

# De-duplicate skill names
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

  # Exclude archive / plugins
  case "$dir" in
    */archive/*|*/plugins/*) continue ;;
  esac

  TOTAL_SKILLS=$((TOTAL_SKILLS + 1))
  skill_errors=0

  # ── 1. Frontmatter parsing ──

  fm_name=$(get_fm_field "$sf" "name")
  fm_desc=$(get_fm_field "$sf" "description")
  fm_agent=$(get_fm_field "$sf" "agent")
  fm_context=$(get_fm_field "$sf" "context")

  # 1a. name must exist
  if [ -z "$fm_name" ]; then
    emit HIGH "$skill_name" "frontmatter missing 'name' field"
    skill_errors=$((skill_errors + 1))
  fi

  # 1b. description must exist and have meaningful length
  if [ -z "$fm_desc" ]; then
    emit HIGH "$skill_name" "frontmatter missing 'description' field"
    skill_errors=$((skill_errors + 1))
  else
    desc_len=${#fm_desc}
    # Multiline description marked with > or |
    if [ "$fm_desc" = ">" ] || [ "$fm_desc" = "|" ]; then
      # Measure entire description block
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
      emit MED "$skill_name" "description too short (${desc_len} chars), CSO trigger quality may be insufficient"
      skill_errors=$((skill_errors + 1))
    fi
  fi

  # ── 2. Agent reference validation ──

  if [ -n "$fm_agent" ]; then
    if ! is_builtin_agent "$fm_agent"; then
      if [ ! -f "$AGENTS_DIR/${fm_agent}.md" ]; then
        emit HIGH "$skill_name" "agent: ${fm_agent} -> not found at ${AGENTS_DIR}/${fm_agent}.md"
        skill_errors=$((skill_errors + 1))
      fi
    fi
  fi

  # ── 3. Skill cross-reference validation ──
  # High-confidence patterns only: explicitly stated "chains to skill X" references.
  # Low-confidence /slash-refs and `code-examples` are skipped (high false-positive rate).

  body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$sf")

  # Pattern: "chain/invoke/delegate/trigger + `skill-name`"
  flow_refs=$(echo "$body" | grep -oE '(chain|delegate|invoke|trigger|hand off)\s*`[a-z][-a-z0-9]+`' | grep -oE '`[a-z][-a-z0-9]+`' | tr -d '`' | sort -u)

  for ref in $flow_refs; do
    [ ${#ref} -lt 3 ] && continue
    is_known_skill "$ref" && continue
    emit MED "$skill_name" "chain reference '${ref}' not found in known skills"
    skill_errors=$((skill_errors + 1))
  done

  # ── 4. Reference file validation ──

  ref_mentions=$(echo "$body" | grep -oE 'ref-[-a-z0-9]+\.md' | sort -u)
  for ref_file in $ref_mentions; do
    if [ ! -f "$dir/$ref_file" ]; then
      emit HIGH "$skill_name" "references ${ref_file} but file does not exist in ${dir}/"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # Check whether ref-*.md files in the directory are actually referenced by SKILL.md (dead-file detection)
  for ref_path in "$dir"/ref-*.md; do
    [ -f "$ref_path" ] || continue
    ref_basename=$(basename "$ref_path")
    if ! grep -q "$ref_basename" "$sf"; then
      emit LOW "$skill_name" "${ref_basename} exists but is not referenced by SKILL.md (possibly dead file)"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # ── 5. Size limits ──

  skill_lines=$(wc -l < "$sf" | tr -d ' ')
  if [ "$skill_lines" -gt 500 ] 2>/dev/null; then
    emit MED "$skill_name" "SKILL.md exceeds 500 lines (${skill_lines}), consider splitting to ref-*.md"
    skill_errors=$((skill_errors + 1))
  fi

  for ref_path in "$dir"/ref-*.md; do
    [ -f "$ref_path" ] || continue
    ref_lines=$(wc -l < "$ref_path" | tr -d ' ')
    ref_basename=$(basename "$ref_path")
    if [ "$ref_lines" -gt 200 ] 2>/dev/null; then
      emit MED "$skill_name" "${ref_basename} exceeds 200 lines (${ref_lines})"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # ── 6. context field validation ──

  if [ -n "$fm_context" ]; then
    case "$fm_context" in
      fork|inline) ;;
      *) emit MED "$skill_name" "context: '${fm_context}' is not valid (expected fork or inline)"
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
