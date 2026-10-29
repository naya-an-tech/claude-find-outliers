#!/usr/bin/env bash
# claude-find-outliers — macOS / Linux installer
#
# 플러그인 없이 사용자 전역에 설치합니다.
#   - 스킬:  ~/.claude/skills/find-outliers/SKILL.md   → Claude Code 에서 /find-outliers
#   - MCP:   apify (https://mcp.apify.com), notion (https://mcp.notion.com/mcp)  — user scope
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --no-notion

set -u

REPO_RAW="https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main"
SKILL_REL="plugins/viral-outliers/skills/find-outliers/SKILL.md"
SKILL_DIR="$HOME/.claude/skills/find-outliers"
WITH_NOTION=1

for arg in "$@"; do
  case "$arg" in
    --no-notion) WITH_NOTION=0 ;;
    -h|--help) echo "Usage: install.sh [--no-notion]"; exit 0 ;;
    *) echo "알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

ok()   { printf '  \033[32m✔\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✖\033[0m %s\n' "$1"; exit 1; }

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
command -v claude >/dev/null 2>&1 || fail "Claude Code CLI(claude)가 없습니다 → curl -fsSL https://claude.ai/install.sh | bash"

echo "claude-find-outliers 설치"

# 1) 스킬 — 저장소를 clone 해서 실행했으면 로컬 파일을, 아니면 GitHub 에서 받는다.
mkdir -p "$SKILL_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$SKILL_REL" ]; then
  cp "$SCRIPT_DIR/$SKILL_REL" "$SKILL_DIR/SKILL.md"
else
  curl -fsSL "$REPO_RAW/$SKILL_REL" -o "$SKILL_DIR/SKILL.md" || fail "스킬 다운로드 실패"
fi
ok "스킬 설치: $SKILL_DIR/SKILL.md"

# 2) MCP 서버 — 같은 이름이 이미 있으면 사용자의 설정을 덮어쓰지 않는다.
add_mcp() {
  local name="$1" url="$2"
  if claude mcp get "$name" >/dev/null 2>&1; then
    warn "MCP '$name' 이미 등록되어 있어 그대로 둡니다"
  elif claude mcp add --scope user --transport http "$name" "$url" >/dev/null; then
    ok "MCP '$name' 등록: $url"
  else
    fail "MCP '$name' 등록 실패"
  fi
}
add_mcp apify https://mcp.apify.com
if [ "$WITH_NOTION" -eq 1 ]; then add_mcp notion https://mcp.notion.com/mcp; fi

cat <<'EOF'

다음 단계
  1. Claude Code 를 다시 시작합니다.
  2. /mcp 에서 apify, notion 을 각각 선택해 Authenticate (브라우저 로그인) 합니다.
  3. /find-outliers 홈카페
EOF
