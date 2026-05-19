# SanDeVentura Presentation Update Proposal v3

Target file:

`C:\Users\kyung\OneDrive\01. Sosa\06. 개발(정리필요)\01. 개인 프로젝트\03. 등산로 트래킹 및 경로 찾기 어플리케이션\presentations\SanDeVentura_Presentation.pdf`

The current PDF has 18 pages. The business problem and product loop remain
valid, but the route inference section still describes the old H3/cell graph
algorithm. The presentation should be updated to explain the trajectory-first
pipeline.

---

## Keep Mostly As-Is

### Pages 1-5

These pages explain:

- problem definition
- product idea
- mobile/backend/operator architecture

They are still valid. Minor wording can be improved:

- "포인트 검증·누적" should become "포인트 검증·trajectory 집계"
- "Canonical Trail 생성" can stay, but describe it as representative trajectory
  generation.

### Pages 6-8

Mobile recording, offline workflow, upload validation are still valid.

Suggested small update:

- Add "처리 후 raw GPS 삭제" to upload/validation privacy message.

---

## Must Change

### Page 9: 경로 결정 파이프라인

Current message:

- High-level route decision pipeline.
- "사용자 기록이 누적될수록 Canonical Trail이 선명해짐" is still correct.

Update the figure to:

```text
Raw GPS
  -> Validation
  -> Refined trajectory
  -> Path-level route matching
  -> Canonical Trail or Candidate Trajectory
  -> Segment metrics
  -> Raw point purge
```

Speaker message:

> 사용자의 GPS는 H3 셀로 장기 보존하지 않고, 업로드 직후 정제된 trajectory로
> 변환해 기존 route와 전체 경로 단위로 비교합니다. 계산이 끝나면 raw point는
> 삭제하고 대표 경로와 집계 지표만 남깁니다.

### Page 10: GPS -> H3 셀 변환과 경로 매칭

This page should be replaced. H3 is no longer the route inference basis.

New title:

> GPS -> Refined Trajectory 변환과 경로 매칭

New visual:

```text
Raw noisy GPS dots
  -> noise filter / simplification
  -> 20m resampled trajectory
  -> Fréchet path comparison
  -> Route match or Candidate
```

Key bullets:

- GPS point를 sequence 순으로 정렬
- 5m 미만 중복 이동 제거
- 8m tolerance로 단순화
- 20m 등간격 resampling
- 기존 route와 weighted discrete Fréchet distance로 전체 path 비교

Remove:

- H3 cell
- 표준화된 셀 표현
- cell 기반 후보 경로

### Page 11-12: Canonical Trail 생성과 snap-position

Current message:

- "누적된 셀과 전이 그래프" is no longer correct.

New title:

> Canonical Trail 생성과 실시간 위치 판정

New wording:

> 누적된 refined trajectory를 weighted merge하여 대표 경로를 만들고,
> snap-position은 현재 위치와 canonical trail의 거리를 계산합니다.

New visual:

```text
Session trajectory A
Session trajectory B
Session trajectory C
  -> weighted merge + smoothing
  -> Canonical Trail
  -> snap-position distance judgment
```

Keep:

- snap-position concept
- 갈림길에서 즉시 판단 가능 message

### Page 14-15: 유즈케이스 2

Current wording:

- "후보 셀 누적 시작"

Replace with:

- "후보 trajectory 누적 시작"
- "반복 trajectory support 증가"
- "reference route 생성"
- "recommended route 승격"

If showing counts, avoid exact "cell" counts. Use:

- candidate trajectories
- supporting sessions
- point support
- confidence

### Page 16: 한계와 개선 방향

Add or modify issues:

1. Cold start: still valid.
2. GPS 한계: still valid.
3. 재계산 불가성: new v3 issue.

Suggested text:

> Raw GPS는 privacy를 위해 처리 후 폐기하므로, 알고리즘이 바뀌어도 과거
> session을 재계산할 수 없습니다. 따라서 algorithm version을 결과에 저장하고,
> 운영자 화면에서 어떤 버전으로 생성된 경로인지 표시해야 합니다.

Also update improvement:

- "H3 heatmap" should not be suggested.
- Suggest "aggregate corridor/support segment" or "trajectory support preview".

### Page 17: 결론

Current four steps:

1. 기록
2. 검증·누적
3. 경로 생성
4. 실시간 안내

Update step 2:

> 검증·정제·집계

Update step 3:

> 대표 경로 / 후보 경로 생성

New final loop:

```text
기록 -> 검증 -> trajectory 정제 -> 대표 경로 생성 -> 실시간 안내
```

---

## Optional New Slide

Add one slide after page 10:

### Title

왜 H3 셀이 아니라 Trajectory인가?

### Message

- 등산로는 좁고 굴곡이 많아 cell 중심 연결만으로는 지그재그가 생긴다.
- 인근 route에 너무 쉽게 흡수되면 잘못된 초기 route가 계속 강화된다.
- 전체 path similarity를 보면 사용자가 실제로 같은 길을 걸었는지 판단하기
  쉽다.
- raw GPS는 계산 후 폐기하고 대표 geometry만 저장해 privacy risk를 줄인다.

### Visual

Left:

- H3 cell centers connected in a zigzag.

Right:

- Refined GPS trajectories merged into a smooth canonical trail.

---

## Terms To Replace Globally

| Old | New |
|---|---|
| H3 셀 변환 | refined trajectory 변환 |
| 후보 셀 | candidate trajectory |
| 셀 누적 | trajectory support 누적 |
| 셀과 전이 그래프 | trajectory merge / segment metric |
| recompute canonical trail | match-and-aggregate 내 canonical update |
| 자동 split | operator candidate promotion |
| H3 heatmap | trajectory support preview / aggregate segment |

---

## Updated One-Sentence Algorithm Description

> SanDeVentura는 업로드된 raw GPS를 일시적으로 정제해 20m 간격 trajectory로
> 만들고, 기존 route와 전체 path 유사도를 비교해 canonical trail 또는
> candidate trajectory로 집계한 뒤 raw GPS를 삭제합니다.

