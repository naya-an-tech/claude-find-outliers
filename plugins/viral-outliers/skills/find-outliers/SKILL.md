---
name: find-outliers
description: 니치(주제/키워드)를 받아 최근 7일 인스타그램 릴스·틱톡 영상 중 평소보다 비정상적으로 잘 터진 "바이럴 아웃라이어" 상위 10개를 Apify로 수집·점수화하고, Notion에 정리한다. "아웃라이어 찾아줘", "이번 주 바이럴 영상", "콘텐츠 리서치", "/find-outliers" 요청에 사용.
argument-hint: "<니치> [--platform instagram|tiktok|both] [--limit 30] [--no-notion]"
---

# find-outliers

니치 하나를 입력받아 **이번 주(최근 7일)** 인스타그램 릴스와 틱톡에서 같은 니치 대비 유독 잘 터진 영상 10개를 찾아 정리한다.

인자: `$ARGUMENTS`
- 첫 단어(들): 니치. 예) `홈카페`, `AI tools`, `personal branding`. 비어 있으면 사용자에게 묻는다.
- `--platform`: `instagram`, `tiktok`, `both`(기본)
- `--limit N`: 플랫폼별 수집 개수. 기본 30, 최대 100. 수집 개수만큼 Apify 비용이 든다.
- `--no-notion`: Notion 저장 없이 대화 + 로컬 파일로만 결과를 남긴다.

## 0. 준비 확인

이 스킬은 두 MCP 서버를 쓴다. 도구 목록에서 확인한다.
- **Apify** (`https://mcp.apify.com`): `call-actor`, `get-actor-run`, `get-dataset-items` 도구가 있어야 한다.
- **Notion** (`https://mcp.notion.com/mcp`): `notion-search`, `notion-create-pages` 도구. 없으면 Notion 단계만 건너뛴다.

Apify 도구가 없거나 인증 오류가 나면 멈추고 안내한다: "`/mcp` 에서 apify 서버를 선택해 Authenticate 를 진행해 주세요." Notion 도 같은 방법이다.

## 1. 수집 (Apify)

`call-actor` 로 아래 액터를 실행한다. 액터 입력과 실행 옵션은 분리한다. `maxItems` 는 `callOptions` 에 넣어 비용 상한을 건다.

### 인스타그램: `apify/instagram-hashtag-scraper`

```json
{
  "hashtags": ["<니치를 공백 없이 붙인 해시태그 또는 키워드>"],
  "keywordSearch": <니치가 여러 단어이거나 해시태그로 쓰기 어려우면 true, 아니면 false>,
  "resultsType": "reels",
  "resultsLimit": <limit>
}
```
- 니치가 한 단어면 그대로 해시태그로 쓴다(`#` 은 빼고). 여러 단어면 `keywordSearch: true` 로 원문을 넣는다.
- callOptions: `{ "maxItems": <limit> }`

### 틱톡: `clockworks/tiktok-scraper`

```json
{
  "searchQueries": ["<니치>"],
  "searchSection": "/video",
  "videoSearchDateFilter": "PAST_WEEK",
  "resultsPerPage": <limit>
}
```
- `videoSearchDateFilter` 는 액터의 유료 옵션($)이다. 사용자가 비용을 줄이길 원하면 이 키를 빼고, 아래 2단계의 날짜 필터로만 거른다.
- callOptions: `{ "maxItems": <limit> }`

### 결과 받기
`call-actor` 는 최대 45초만 기다리고 실행 상태와 `defaultDatasetId` 를 돌려준다. 데이터가 바로 오지 않을 수 있다.
1. 상태가 `SUCCEEDED` 가 아니면 `get-actor-run` 으로 끝날 때까지 상태를 다시 확인한다(최대 5분 정도).
2. `get-dataset-items` 로 데이터셋 항목을 가져온다.
3. `FAILED` / `ABORTED` 거나 항목이 0개면 그 플랫폼은 "수집 실패"로 기록하고 다른 플랫폼은 계속 진행한다.

## 2. 정규화

필드 이름은 각 액터의 데이터셋 스키마를 따른다. 값이 없으면 `null` 로 두고 꾸며내지 않는다.

| 공통 필드 | 인스타그램 | 틱톡 |
|-----------|-----------|------|
| url | `url` | `webVideoUrl` |
| creator | `ownerUsername` | `authorMeta.name` |
| followers | (제공 안 됨 → null) | `authorMeta.fans` |
| views | `videoPlayCount` → 없으면 `igPlayCount` → 없으면 `videoViewCount` | `playCount` |
| likes | `likesCount` | `diggCount` |
| comments | `commentsCount` | `commentCount` |
| shares | `sharesCount` | `shareCount` |
| posted_at | `timestamp` | `createTimeISO` |
| caption | `caption` | `text` |
| sponsored | `paidPartnership` | `isAd` 또는 `isSponsored` |

다음 항목은 제외한다.
- `error` 필드가 있는 항목
- `posted_at` 이 지금부터 7일보다 이전인 항목
- `views` 가 null 이거나 0 인 항목
- 같은 url 이 중복된 항목

## 3. 아웃라이어 점수

"아웃라이어"는 **같은 니치, 같은 주의 다른 영상보다 몇 배 더 봤는가**로 정의한다. 플랫폼마다 따로 계산한다.

- `median_views` = 해당 플랫폼에서 필터를 통과한 항목들의 views 중앙값
- **`outlier_score` = views / median_views** (소수 첫째 자리까지)
- 틱톡은 보조 지표로 `views_per_follower` = views / max(followers, 1) 도 계산한다. 팔로워에 비해 터진 영상을 찾는 데 쓴다. 인스타그램은 이 액터가 팔로워 수를 주지 않으므로 계산하지 않는다(추정 금지).
- `engagement_rate` = (likes + comments + shares) / views. 없는 값은 0으로 더한다.

순위:
1. 두 플랫폼 항목을 합쳐 `outlier_score` 내림차순으로 정렬한다.
2. `outlier_score < 1.5` 는 아웃라이어가 아니다. 남은 것이 10개보다 적으면 있는 만큼만 보여 주고, 그 사실을 말한다.
3. 상위 10개를 고른다.

## 4. 각 영상 분석

상위 10개 각각에 대해 수집된 caption, 해시태그, 지표**만** 근거로 짧게 적는다. 영상을 직접 보지 않았으므로 화면 내용은 추측하지 않는다.
- **왜 터졌나(가설)**: 후킹 문구, 형식(리스트/튜토리얼/비포애프터 등), 주제 각도 중 캡션에서 보이는 것
- **내 콘텐츠로 가져갈 아이디어**: 이 니치에서 바로 찍을 수 있는 변주 1개

## 5. 출력

### 대화창
```
## <니치> 바이럴 아웃라이어 TOP 10 (YYYY-MM-DD 기준 최근 7일)
수집: 인스타 N개 / 틱톡 M개 · 중앙값 조회수: 인스타 X / 틱톡 Y

| # | 플랫폼 | 크리에이터 | 조회수 | 아웃라이어 배수 | 참여율 | 게시일 | 링크 |
...
### 1. @creator — 12.4배
- 왜 터졌나: ...
- 가져갈 아이디어: ...
```
광고나 협찬 항목(`sponsored = true`)에는 표에 "(광고)"를 붙인다.

### Notion (`--no-notion` 이 아니고 Notion 도구가 있을 때)
1. 저장 위치를 정한다. 사용자가 이번 대화에서 지정한 페이지가 있으면 그곳을 쓴다. 없으면 `notion-search` 로 "Viral Outliers" 페이지를 찾는다. 그래도 없으면 어느 페이지 아래에 만들지 사용자에게 한 번 묻는다.
2. `notion-create-pages` 로 그 아래에 하위 페이지를 만든다.
   - 제목: `<니치> 아웃라이어 TOP 10 · YYYY-MM-DD`
   - 본문: 위 대화창 출력과 같은 내용(표 + 영상별 분석 + 수집 조건)
3. 만든 페이지 링크를 사용자에게 알려 준다.

### 로컬 파일 (항상)
작업 디렉터리에 `outliers/YYYY-MM-DD-<니치-slug>.md` 로 같은 내용을 저장한다. Notion 저장이 실패해도 결과는 남는다.

## 지켜야 할 것
- 숫자는 모두 Apify 응답에서 온 값만 쓴다. 비어 있는 값을 채우거나 반올림해 부풀리지 않는다.
- 비용이 드는 작업이다. 사용자가 `--limit` 를 100보다 크게 요청하면 비용이 늘어난다고 알리고 확인을 받는다.
- 수집한 영상과 캡션은 리서치 참고용이다. 결과에 "원본을 그대로 복제하지 말고 형식과 각도를 참고하라"는 한 줄을 붙인다.
