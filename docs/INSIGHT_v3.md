# SanDeVentura Insight v3

## Why v3 Exists

v2의 H3 cell 기반 route inference는 privacy와 aggregation 측면에서는
단순했지만, 실제 route geometry 품질에서 한계가 드러났다.

관찰된 문제:

- 신뢰도 높은 cell 중심을 연결하면 canonical line이 지그재그로 보인다.
- 멀리 길게 쌓인 candidate cell support에 비해 최종 route가 짧게 생성된다.
- bootstrap route가 조금 잘못되면 이후 정확한 path도 기존 route confidence만
  높이는 방향으로 흡수될 수 있다.
- Dobongsan test처럼 candidate 위치가 직관과 다르게 결정될 수 있다.
- H3 cell graph는 사람의 실제 이동 trajectory보다 격자 topology에 크게
  영향을 받는다.

따라서 v3는 route inference와 candidate generation에서 H3를 제거하고,
정제된 raw GPS trajectory를 직접 비교하는 방식으로 전환했다.

---

## Key Product Insight

SanDeVentura의 핵심 가치는 "기록이 곧 안내가 되는 학습 루프"다.
이 루프에서 가장 중요한 것은 cell count 자체가 아니라 **사용자가 실제로
걸은 path의 반복성**이다.

v3는 다음 질문에 직접 답한다.

- 이 session의 전체 path가 기존 route와 같은 길인가?
- 아니라면 새로운 candidate route로 볼 만큼 반복되고 있는가?
- 이 route를 지나갈 때 구간별 시간과 고도 변화는 어떤가?
- 이 결과가 어떤 algorithm version으로 만들어졌는가?

---

## Trade-Offs

### Advantages

- Route matching이 per-cell absorption보다 보수적이다.
- 잘못 bootstrap된 route가 새 정확한 trajectory를 계속 흡수하는 문제를 줄인다.
- Candidate geometry가 cell 중심 그래프보다 실제 이동 shape에 가깝다.
- 20m resampling과 weighted merge로 canonical line이 더 부드럽다.
- 100m segment metric으로 소요 시간, 방향별 속도, 고도 급변을 저장할 수 있다.
- Raw GPS를 장기 보존하지 않고도 운영 진단에 필요한 aggregate를 남긴다.

### Costs

- Raw point를 처리할 때 더 많은 계산이 필요하다.
- 처리 후 raw를 폐기하므로 같은 세션을 새 알고리즘으로 재계산할 수 없다.
- Algorithm version 관리가 중요해진다.
- Candidate review가 자동 split보다 운영자 개입을 더 요구한다.
- Representative geometry는 aggregate 결과이므로, 개별 사용자의 정확한 이동
  path를 복원할 수 없다.

---

## Privacy Insight

v3의 privacy boundary는 실용적 절충이다.

완전히 raw를 보존하면:

- 재계산과 debugging은 쉬워진다.
- 하지만 위치정보 장기 보관 부담이 커진다.

완전히 raw를 즉시 폐기하면:

- privacy risk는 낮아진다.
- 하지만 시간/고도/품질 metric을 나중에 만들 수 없다.

v3는 upload transaction과 aggregation window 안에서만 raw를 사용하고,
그 순간 필요한 aggregate를 모두 만든 뒤 raw를 제거한다.

이 설계는 "운영자가 개인의 이동 기록을 보는 시스템"이 아니라
"집계된 route support를 보는 시스템"으로 제품 정체성을 명확히 한다.

---

## Algorithm Insight

H3 cell은 "공간 집계"에는 유용하지만 "산행 route 결정"에는 충분하지 않았다.
등산로는 좁고 구불구불하며, 인접 cell 중 어디를 지나갔는지가 geometry 품질에
큰 영향을 준다.

v3의 핵심 알고리즘 판단:

- cell membership보다 ordered trajectory가 중요하다.
- point-to-route 거리보다 path-level similarity가 중요하다.
- candidate는 route에 흡수되지 않은 residual이 아니라 독립된 trajectory
  support로 봐야 한다.
- smoothing은 geometry에만 적용하고 attribution count를 바꾸지 않아야 한다.

---

## Current Risks

### 1. Cold Start

초기 route가 없으면 첫 사용자에게 줄 수 있는 안내 가치가 약하다.

대응:

- 공개 GPX 또는 운영자 seed로 reference route를 초기화한다.
- 초기 seed는 `reference`로 표시하고 사용자 support가 쌓이면
  `recommended`로 올린다.

### 2. No Recalculation After Raw Purge

처리 완료 세션은 raw point를 삭제하므로 algorithm vN 결과를 vN+1로 재계산할
수 없다.

대응:

- `algorithm_version`을 모든 inference result에 저장한다.
- major algorithm 변경 시 "이전 결과는 재계산 불가"를 operator UI에 명확히
  표시한다.
- 필요한 경우 향후 opt-in raw retention policy를 별도 설계한다.

### 3. Candidate Promotion Quality

자동 split을 제거했기 때문에 candidate를 route로 만드는 판단은 운영자에게
더 중요해졌다.

대응:

- Discovery에서 trajectory count, point count, session contribution,
  latest evidence, confidence를 명확히 보여준다.
- candidate geometry preview를 route와 함께 비교한다.

### 4. GPS Error In Forest Terrain

GPS 오차는 여전히 route geometry와 snap-position 품질을 흔든다.

대응:

- accuracy 기반 point validation 유지
- route match threshold를 보수적으로 유지
- snap-position은 moving average 또는 dynamic threshold 개선 후보로 둔다.

### 5. Segment Time Model Validation

100m segment metric은 충분한 observation이 쌓이기 전에는 흔들릴 수 있다.

대응:

- duration observation count를 함께 표시한다.
- forward/reverse를 분리한다.
- abrupt altitude change count로 이상치를 진단한다.

---

## Updated Priority

| Priority | Area | Reason |
|---|---|---|
| 1 | Seed/reference route import | Cold start를 줄여야 사용자가 첫 산행부터 가치를 얻는다 |
| 2 | Operator candidate review | 자동 split 제거 후 candidate promotion 품질이 중요하다 |
| 3 | Segment metric UX | 소요 시간/고도 변화는 trajectory 방식의 새 장점이다 |
| 4 | Algorithm version visibility | raw purge 이후 재계산 불가성을 명확히 해야 한다 |
| 5 | GPS quality improvement | 산림/계곡 GPS 오차는 계속 남는 제품 리스크다 |

---

## What Changed Since v2

Removed:

- H3 route inference
- trail/candidate cell accumulation
- transition graph path extraction
- route split audit and auto split flow
- recompute-canonical-trails
- H3 heatmap UI

Added:

- refined trajectory inference
- path-level Fréchet matching
- representative candidate trajectories
- session trajectory attribution
- 100m directional segment metrics
- raw purge after aggregation
- algorithm versioning in inference outputs

