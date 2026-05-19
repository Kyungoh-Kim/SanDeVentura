# SanDeVentura — 유즈케이스 시뮬레이션 v2

> 4가지 실제 사용 시나리오와 정량적 효과를 분석한다.  
> 수치는 국내 등산 통계(소방청 산악 구조 통계, 한국등산지도 연구소)와 앱 특성을 기반으로 한 추정값이다.

---

## 유즈케이스 1: "혼자 등산하는 직장인" — 갈림길 불안 해소

### 시나리오 배경

**페르소나**: 김지수 (32세, 서울 거주, 회사원)

- 주 1회 북한산, 도봉산 등 수도권 중소 산 등산
- 스마트폰으로 등산 기록하는 습관
- 혼자 산행 시 갈림길에서 자주 불안감을 느낌
- 공식 앱(산림청)에 해당 코스 데이터가 없거나 부정확한 경험

### 시뮬레이션

```
시나리오: 북한산 숨은벽 코스 첫 단독 산행

10:15 — 앱에서 산 선택 후 기록 시작 (오프라인 동작)
        Route 탭: 이전 사용자들이 쌓은 canonical trail 표시
        confidence = 0.78 ('recommended'), version = 12

10:47 — 첫 번째 갈림길 도착
        snap-position 호출 → distanceMeters: 12m
        routeJudgment: 'on_route'
        → 오른쪽 경로 선택, 불안 없이 진행

11:23 — 세 번째 갈림길 (비공식 샛길)
        snap-position 호출 → distanceMeters: 63m
        routeJudgment: 'away_from_route'
        → 뒤로 돌아 올바른 경로로 복귀

13:40 — 하산 완료, 세션 종료
14:05 — Wi-Fi 연결 후 자동 업로드 (1개 세션, 약 3,200 포인트)
14:20 — match-and-aggregate-sessions가 이 세션을 처리
        → 기존 경로의 trail_cells에 추가 기여 → confidence 소폭 상승
```

### 기존 방식과 비교

| 항목 | 기존 (공식 앱/지도) | SanDeVentura |
|------|---------------------|--------------|
| 해당 코스 데이터 | 없음 또는 1~2년 전 정적 데이터 | 실제 산행자 경로 실시간 축적 |
| 갈림길 실시간 안내 | 불가 | snap-position으로 25m 이내 감지 |
| 비공식 샛길 탐지 | 불가 | 경로 이탈 즉시 경보 |
| 단독 산행 불안도 | 높음 | 경로 판정으로 즉시 확인 가능 |

### 정량적 효과

**개인 효과**:
- 갈림길 결정 시간: 평균 4~7분 → 1분 이내 (약 80% 단축)
- 잘못된 경로 진입 후 복귀 추가 시간: 평균 22분 → 거의 0
- 단독 산행 중 길 잃음 위험 체감: 연 3~5회 → 연 0~1회

**데이터 기여 효과**:
- 1회 산행 = 약 3,000~5,000개 GPS 포인트 기여
- 10회 산행 누적: canonical trail 신뢰도 ≥ 0.8 도달
- `session_route_assignments`로 내 기여가 어느 경로에 반영됐는지 추적 가능

**소방청 통계 맥락**:
- 2022년 산악 조난 사고 중 약 31%가 "실족 및 길 잃음" (소방청)
- 수도권 중소 산 단독 산행 조난의 70% 이상이 비공식 코스에서 발생
- SanDeVentura가 활성화된 산에서 길 잃음 조난 10~20% 감소 가능 (초기 예측)

---

## 유즈케이스 2: "등산 동호회 총무" — 집단 기여로 빠른 경로 구축

### 시나리오 배경

**페르소나**: 박상호 (48세, 경기도 거주, 중견기업 관리직)

- 30명 규모 직장 등산 동호회 총무
- 월 2회 정기 산행, 비공식 코스 자주 이용
- 동호회 코스 기록을 체계적으로 남기고 싶은 니즈

### 시뮬레이션

```
시나리오: 6개월간 강원도 비공식 코스 정기 산행 (월 2회, 총 12회)

[1~3회차] 해당 산 canonical trail 없음
    snap-position: 'none' (경로 데이터 없음)
    기록만 진행 → 업로드
    백엔드: candidate_cells에 미매칭 셀 누적 시작

    3개 세션 후 → Discovery 페이지에 후보 클러스터 출현
    운영자가 "Create Route" 실행
    → promote-candidate-cluster → canonical_trails v1 생성 (confidence 0.30)

[4~6회차] 초기 경로 안내 시작
    snap-position: 기본 안내 (confidence 0.30, 'reference')
    동호회원 2명도 앱 사용 → 총 9개 세션
    confidence: 0.30 → 0.55, 'reference' 유지

[7~12회차] 안정적 경로 안내
    동호회원 5명 사용 → 총 24개 세션
    confidence: 0.55 → 0.82, 'recommended' 달성
    갈림길 안내 정확도: 실사용 기준 약 90%

    분기 지점(C셀)에서 route_to_candidate_transitions 축적
    → evaluate-route-splits가 분기 감지
    → split_route_atomic으로 경로 분할 (A코스 / B코스)
```

### 기존 방식과 비교

| 항목 | 기존 방식 | SanDeVentura |
|------|-----------|--------------|
| 비공식 코스 데이터 생성 | 개인 메모 또는 Komoot 수동 업로드 | 자동 수집 + 자동 경로 추론 |
| 데이터 재사용성 | 개인 기기에 고립 | 전체 사용자 공유 canonical trail |
| 분기 경로 처리 | 불가 | route_split_detection으로 자동 분기 |
| 신뢰도 향상 | 수동 판단 | 세션 누적 시 자동 계산 |

### 정량적 효과

**데이터 생산 효과**:
- 6개월 × 동호회 6명 = 24~30개 세션 → 약 90,000~150,000 GPS 포인트 기여
- 강원 비공식 코스 2~3개에 confidence 0.8+ canonical trail 생성
- 수동 GPX 파일 편집 대비: 건당 30분 → 0분

**플랫폼 성장 효과**:
- 동호회 1개(6명 활성)가 6개월 내 코스 3개 커버리지 확보
- 해당 코스 연간 이용자: 500~2,000명 추정 → 30% 앱 사용 시 선순환 구조

**비용 절감**:
- 전통적 비공식 코스 데이터 수집: 코스당 현장 실측 80~200만원
- SanDeVentura: 사용자 기여로 비용 0원, 자동 갱신

---

## 유즈케이스 3: "서비스 운영자(개발자)" — 경로 품질 모니터링

### 시나리오 배경

**페르소나**: 최운영 (개발자, SanDeVentura 운영자)

- 앱 출시 후 베타 테스트 기간 (첫 3개월)
- 사용자 5~20명, 산 10개, 세션 50~200개 누적 중
- snap-position 오류 신고 수 파악 필요
- 경로 추론 결과가 실제 코스와 일치하는지 검증 필요

### 시뮬레이션

```
시나리오: 베타 3주차 — 특정 산에서 이탈 알림 오작동 신고 접수

[월요일] 사용자 2명 "경로 위인데 이탈 경고 뜸" 신고
    ↓
[대시보드 Quality 페이지]
    confidence: 0.42 ('reference')
    session_count: 4 (임계값 5개 미달)
    gps_quality_score: 0.64 (임계값 0.70 미달)
    rejected_point_rate: 0.12 (정상 기준 0.08 대비 높음)
    ↓
[Routes 페이지]
    OpenLayers 지도에서 canonical trail 시각화
    → 특정 구간에서 경로가 실제 등산로에서 15m 편차 발견
    ↓
[원인 분석]
    rejected_track_points 조회:
    rejection_reason이 없음 (포인트는 수락됨)
    → 수락 기준 내(accuracy 18~22m)이지만 산림 밀집으로 오차 누적
    → buildSessionHitmap의 가중평균이 실제 경로에서 벗어나는 중
    ↓
[대응]
    1. validation.ts의 accuracy 임계값: 100m → 유지 (원인 아님)
    2. 해당 산에서만 recompute-canonical-trails 수동 트리거
       → 세션 4개 데이터 그대로지만 신호가 더 강한 쪽으로 재수렴
    3. 3일 후 사용자 3명 추가 업로드 → confidence 0.42 → 0.68
    4. 경로 편차: 15m → 5m로 개선
    ↓
[결과]
    이탈 오경보 신고: 주 4건 → 0건
    confidence: 0.68 → 'reference' 유지 (sessionCount 5개 미달)
    → 다음 산행 시즌(2~3주 후) sessionCount 5개 충족 → 'recommended' 승격 예정
```

### 기존 방식과 비교

| 항목 | 로그 직접 조회 | SanDeVentura 대시보드 |
|------|--------------|----------------------|
| 문제 파악 시간 | DB 쿼리 + 로그 분석 2~4시간 | 대시보드 진입 후 10~20분 |
| 시각적 경로 확인 | GeoJSON 수동 파싱 + QGIS 외부 도구 | OpenLayers 즉시 확인 |
| 재추론 트리거 | Edge Function 직접 curl 호출 | 대시보드 버튼 클릭 |
| 분기 감지 | 불가 | route_split_audit + DiscoveryPage |

### 정량적 효과

**운영 효율**:
- 품질 이슈 진단 시간: 2~4시간 → 15~30분 (75~85% 단축)
- 월 발생 이슈 건수 (베타): 8~15건 → 절약 시간: 월 약 10~30시간

**제품 품질 개선 속도**:
- 발견 → 수정 → 재추론 → 검증 사이클: 5~7일 → 2~3일

**사용자 리텐션**:
- 오경보 없을 경우 30일 리텐션: 약 60%
- 오경보 다발 시: 약 35%
- 차이: 25%p → 베타 20명 기준 5명 추가 유지

---

## 유즈케이스 4: "신규 경로 발굴" — 미등록 코스 자동 감지

### 시나리오 배경

운영자가 기존에 등록하지 않은 산에서 사용자들이 자연스럽게 반복 통과하는 구간이 candidate_cells에 누적되는 케이스.

### 시뮬레이션

```
시나리오: 경기도 모 저산에 경로 등록이 없는 상태

[3개 세션 업로드 후]
    match-and-aggregate-sessions가 실행:
    → 해당 산에 trail_cells가 없음
    → 모든 셀이 candidate_cells에 누적
    → route_to_candidate_transitions도 없음 (순수 orphan)

[Discovery 페이지]
    candidate_cell_clusters 뷰: 해당 산, cell_count = 47
    → "Create Route" 버튼 클릭

[promote-candidate-cluster 실행]
    candidate_cells → trail_cells (신규 route_id = R001)
    H3 인접성 기반 trail_cell_transitions 생성
    inferCanonicalRouteFromCells 실행
    → canonical_trails v1 생성 (confidence = 0.28, 'reference')
    기여 3개 세션 status → 'ingested' 재설정

[다음 pg_cron 사이클 (15분 후)]
    3개 세션이 R001에 재귀속
    recomputeRouteConfidence 재실행
    → confidence = 0.31 (session_count = 3)

[이후 5개 세션 추가 업로드]
    → confidence = 0.63 → 'reference'
    → 7번째 세션 → sessionCount = 8, confidence = 0.74 → 'recommended' 달성
```

### 시사점

- 운영자가 산을 미리 등록하지 않아도 사용자 GPS 데이터만으로 경로 후보가 자동 형성된다.
- Discovery 페이지가 없으면 이 candidate 데이터는 쌓이지만 경로로 변환되지 않는다.
- 특히 **비공식 코스가 많은 지역**에서 이 파이프라인의 가치가 크다.

---

## 요약: 4가지 유즈케이스 정량 효과

| 유즈케이스 | 핵심 효과 | 정량 수치 |
|-----------|-----------|-----------|
| 1. 단독 산행 직장인 | 갈림길 결정 속도 + 조난 위험 감소 | 결정 시간 80% 단축, 길 잃음 위험 연 3→0회 |
| 2. 동호회 총무 | 비공식 경로 자동 데이터화 | 6개월 150,000 포인트, 코스당 공수 30분→0분 |
| 3. 서비스 운영자 | 품질 모니터링 + 빠른 대응 | 진단 시간 80% 단축, 베타 리텐션 25%p 개선 |
| 4. 미등록 경로 발굴 | candidate 파이프라인 자동화 | 운영자 개입 없이 경로 후보 형성 |

---

## 실패 시나리오 (리스크 인식)

### 콜드 스타트 실패

초기 사용자가 유즈케이스 1처럼 경로 있는 산에 오는 것이 아니라, 전혀 데이터가 없는 산에 처음 오는 경우:

```
Route 탭 → 'none' 상태 → "경로 데이터 없음" 표시
→ snap-position 호출해도 의미 있는 결과 없음
→ 등산 중 앱의 가치 경험 불가 → 재방문 확률 낮음
```

**대응**: seed GPX 데이터 import로 초기 'reference' 경로를 미리 구성해야 한다.

### GPS 오차 실패

산림 밀집 구간에서 GPS 오차가 25m를 초과하면:

```
실제로 경로 위에 있음 + snap-position distanceMeters: 30m
→ routeJudgment: 'caution'
→ 사용자 혼란: "나는 경로 위인데 왜 경고가?"
```

**대응**: 이동 평균 필터 + 구간별 GPS 품질 지도 + 사용자 안내 UI ("이 구간은 GPS 정확도가 낮습니다").
