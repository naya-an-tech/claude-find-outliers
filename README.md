# claude-find-outliers

니치(주제)를 입력하면 **최근 7일 인스타그램 릴스·틱톡에서 유독 잘 터진 "바이럴 아웃라이어" TOP 10**을 찾아 Notion에 정리하는 Claude Code 스킬입니다.

```
/find-outliers 홈카페
```

- 데이터 수집: [Apify](https://apify.com) MCP. 인스타그램은 `apify/instagram-hashtag-scraper`, 틱톡은 `clockworks/tiktok-scraper`를 씁니다.
- 결과 정리: [Notion](https://www.notion.so) MCP로 페이지를 만들고, 작업 폴더의 `outliers/` 아래에 마크다운 파일로도 저장합니다.
- 지원 OS: macOS, Linux(Ubuntu), Windows. Claude Code가 돌아가는 곳이면 됩니다.

> 이 저장소는 Claude Code(CLI·데스크톱·IDE)용입니다. 영상 원작자의 스킬은 공개되어 있지 않아, 공개 문서로 확인된 Apify·Notion MCP와 액터 스키마만으로 직접 구현했습니다.

---

## 설치

### 방법 A. 플러그인 (Claude Code 안에서)

```
/plugin marketplace add naya-an-tech/claude-find-outliers
/plugin install viral-outliers@claude-find-outliers
```

Apify·Notion MCP 서버가 플러그인에 함께 들어 있습니다. 실행 명령은 `/viral-outliers:find-outliers <니치>` 입니다.

### 방법 B. 설치 스크립트 (`/find-outliers`로 바로 쓰기)

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main/install.ps1 | iex
```

스크립트가 하는 일은 두 가지뿐입니다.
1. `~/.claude/skills/find-outliers/SKILL.md`를 설치합니다.
2. `claude mcp add --scope user --transport http`로 `apify`(`https://mcp.apify.com`)와 `notion`(`https://mcp.notion.com/mcp`)을 등록합니다. 같은 이름의 서버가 이미 있으면 덮어쓰지 않습니다.

Notion 없이 쓰려면 `bash -s -- --no-notion`(macOS/Linux) 또는 `-NoNotion`(Windows)을 붙이세요.

### 공통: 로그인 (최초 1회)

1. Claude Code를 다시 시작합니다.
2. `/mcp`를 입력해 `apify`를 선택한 뒤 **Authenticate**를 누르고 브라우저에서 Apify에 로그인합니다.
3. `notion`도 같은 방법으로 인증합니다. 인증할 때 Claude가 접근할 페이지를 고릅니다.

두 서비스 모두 OAuth 방식이라 API 토큰을 직접 넣을 필요가 없습니다.

---

## 사용법

```
/find-outliers <니치> [--platform instagram|tiktok|both] [--limit 30] [--no-notion]
```

| 예시 | 설명 |
|------|------|
| `/find-outliers 홈카페` | 두 플랫폼에서 각 30개를 수집해 TOP 10을 뽑음 |
| `/find-outliers "AI tools" --platform tiktok` | 틱톡만 |
| `/find-outliers 러닝 --limit 50 --no-notion` | 플랫폼당 50개, Notion 저장 없이 |

플러그인으로 설치했다면 `/viral-outliers:find-outliers`로 실행합니다. 슬래시 명령 대신 "홈카페 니치로 이번 주 바이럴 아웃라이어 찾아줘"처럼 말해도 됩니다.

### 결과 예시 형식

```
## 홈카페 바이럴 아웃라이어 TOP 10 (2026-10-29 기준 최근 7일)
수집: 인스타 28개 / 틱톡 30개 · 중앙값 조회수: 인스타 4,100 / 틱톡 9,800

| # | 플랫폼 | 크리에이터 | 조회수 | 아웃라이어 배수 | 참여율 | 게시일 | 링크 |
| 1 | TikTok | @... | 412,000 | 42.0배 | 8.1% | 10-25 | ... |
...
### 1. @... — 42.0배
- 왜 터졌나(캡션 기준 가설): ...
- 가져갈 아이디어: ...
```
위 숫자는 형식을 보여 주기 위한 예시입니다.

---

## 아웃라이어를 고르는 방법

| 단계 | 내용 |
|------|------|
| 수집 | 인스타: 해시태그(여러 단어면 키워드 검색)로 릴스를 수집합니다. 틱톡: 영상 검색에 `PAST_WEEK` 필터를 겁니다. |
| 필터 | 게시일이 7일 이내이고, 조회수가 있으며, 오류가 없는 항목만 남기고 중복은 지웁니다. |
| 점수 | **아웃라이어 배수 = 조회수 ÷ 같은 플랫폼 수집 결과의 조회수 중앙값** |
| 선정 | 배수 1.5 이상인 항목 중 상위 10개를 고릅니다. 10개가 안 되면 있는 만큼만 보여 줍니다. |
| 보조 지표 | 참여율 = (좋아요+댓글+공유) ÷ 조회수. 틱톡은 조회수 ÷ 팔로워도 함께 보여 줍니다. |

- 인스타그램 해시태그 액터는 **팔로워 수를 주지 않습니다.** 그래서 인스타는 "같은 니치의 다른 영상 대비" 배수만 계산하고, 팔로워 수를 추정하지 않습니다.
- "왜 터졌나"는 **캡션·해시태그·지표만** 보고 세운 가설입니다. 영상 화면은 분석하지 않습니다.

---

## 비용

- Apify 액터는 **결과 1건당 과금**(pay-per-event)됩니다. 비용은 `--limit` × 플랫폼 수에 비례하고, 스킬은 실행할 때마다 `maxItems`로 상한을 겁니다.
- 틱톡의 `PAST_WEEK` 날짜 필터는 액터의 **유료 옵션($)** 입니다. 비용을 줄이고 싶다고 말하면 이 옵션을 빼고 수집한 뒤 게시일로 직접 거릅니다.
- 정확한 단가와 무료 크레딧은 바뀔 수 있으니 실행 전에 Apify 콘솔에서 확인하세요.
  - https://apify.com/apify/instagram-hashtag-scraper
  - https://apify.com/clockworks/tiktok-scraper

---

## 구성

```
.claude-plugin/marketplace.json           # 플러그인 마켓플레이스
plugins/viral-outliers/
  .claude-plugin/plugin.json
  .mcp.json                               # apify, notion (HTTP + OAuth)
  skills/find-outliers/SKILL.md           # 스킬 본체 (수집 → 정규화 → 점수 → Notion)
install.sh / install.ps1                  # 플러그인 없이 사용자 전역 설치
```

## 제거

```bash
# 플러그인으로 설치한 경우
claude plugin uninstall viral-outliers@claude-find-outliers

# 스크립트로 설치한 경우
rm -rf ~/.claude/skills/find-outliers
claude mcp remove apify --scope user
claude mcp remove notion --scope user
```

## 문제 해결

- **Apify 도구가 안 보이거나 인증 오류가 날 때**: `/mcp`에서 `apify`를 다시 Authenticate 하세요. 플러그인으로 설치했다면 서버 이름이 `plugin:viral-outliers:apify`로 보입니다.
- **결과가 0개일 때**: 니치를 더 일반적인 단어나 영어 해시태그로 바꿔 보세요(예: `홈카페` → `homecafe`).
- **Notion 저장 위치**: 처음 실행할 때 "Viral Outliers" 페이지를 찾고, 없으면 어느 페이지 아래에 저장할지 묻습니다. Notion 인증 단계에서 해당 페이지에 접근 권한을 줘야 합니다.

## 출처

Facebook 릴스 "Want to grow faster as a creator?"의 내용(Claude 스킬 + Apify + Notion으로 주간 바이럴 아웃라이어 찾기)을 바탕으로 만들었습니다. 액터 입출력 필드와 MCP 엔드포인트는 2026-10-29 기준 Apify·Notion 공식 문서와 Apify API의 액터 스키마로 확인했습니다.
