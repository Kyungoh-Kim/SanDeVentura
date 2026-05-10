# SanDeVentura — 워크플로우 v2

## 개요

SanDeVentura의 핵심 워크플로우는 **"GPS 흔적 수집 → 검증 → 경로 귀속 → 경로 추론 → 사용자 피드백"** 사이클로 구성된다. 세션이 누적될수록 canonical trail의 신뢰도가 높아지는 누적 학습 구조다.

Sprint 9 기준으로 세션-경로 귀속(attribution) 시스템, candidate 경로 파이프라인, 분기 감지가 포함된다.

---

## 1. 등산 세션 기록 워크플로우 (모바일)

```
앱 실행
    │
    ▼
산 선택 (MountainSearchModal)
    └── GET /get-mountains → 산 목록 + 경로 목록 반환
    │
    ▼
기록 시작 (RecordingController.start(mountainId))
    └── SQLite에 세션 row 생성 (status: 'active')
    │
    ▼
GPS 포인트 수집 루프 (LocationService)
    ├── geolocator 이벤트: accuracy=best, distanceFilter=5m
    ├── AppendLocationPointUseCase
    └── SQLite local_track_points에 저장
         (lat, lon, altitude, accuracy, speed, sequence_index)
    │
    ▼ (앱 종료/재시작 시)
Active Session Recovery
    └── session_dao에서 status='active' 세션 조회 → 기록 재개
    │
    ▼
기록 종료 (Stop 버튼)
    └── 세션 status → 'completed'
    │
    ▼
업로드 큐 등록 (UploadQueueService)
    └── connectivity 이벤트 감지 시 자동 업로드 시도
```

---

## 2. 세션 업로드 워크플로우

```
업로드 시도 (Wi-Fi 또는 모바일 데이터 연결 시)
    │
    ▼
POST /upload-session
    │
    ├── 중복 검사 (idempotencyKey)
    │       중복이면 → status: 'duplicate' 반환, 로컬 status → 'uploaded'
    │
    ├── GPS 포인트 검증 (validation.ts)
    │       수락 조건:
    │       - recordedAt 있음
    │       - lat: −90~90, lon: −180~180
    │       - sequenceIndex 있음, 중복 없음
    │       - speed ≤ 15m/s
    │       - accuracy ≤ 100m
    │
    │   수락 포인트 → track_points (PostGIS geography)
    │   거부 포인트 → rejected_track_points (rejection_reason, debug_payload)
    │
    ├── 세션 메타 저장 (hiking_sessions)
    │       status: 'ingested' (수락 포인트 ≥ 1)
    │       status: 'rejected' (전부 거부)
    │
    └── 응답 반환
            { sessionId, acceptedPointCount, rejectedPointCount, retentionExpiresAt }
```

---

## 3. 경로 추론 워크플로우 (백엔드, 15분 간격)

```
pg_cron 15분 (0013_match_cron.sql)
    └── match-and-aggregate-sessions Edge Function
    │
    ▼
unprocessed_ingested_sessions 뷰에서 최대 50개 미처리 세션 조회
    │
    ▼ 세션별 processSession()
    │
    ├── GPS → H3 셀 변환 (buildSessionHitmap)
    │       pointToCellKey(lat, lon, resolution=11)  // ~25m 셀
    │       expandWithGridPath: GPS 간격 보간 (gridPathCells)
    │       TrailCell 집계: pointCount, sessionCount, avgAccuracy
    │       TrailTransition 집계: transitionCount, sessionCount, edgeCost
    │
    ├── 기존 경로에 셀 귀속 (75m 반경)
    │       findNearestRouteCell: trail_cells와 haversine 거리 비교
    │       Bootstrap 예외: 빈 경로 있으면 bbox 내 셀 자동 귀속
    │
    ├── Transition 4분류
    │       route-internal → trail_cell_transitions
    │       candidate-internal → candidate_cell_transitions
    │       route-to-candidate → route_to_candidate_transitions
    │       candidate-to-route → route_to_candidate_transitions
    │       cross-route → 폐기
    │
    ├── DB 누적 RPC (0021_split_rpcs.sql)
    │       accumulate_trail_cells: UPSERT 가중평균
    │       accumulate_candidate_cells: UPSERT 가중평균
    │       session_route_assignments: 세션-경로 귀속 기록
    │
    └── recomputeRouteConfidence (영향받은 각 경로)
            입력: route_accumulated_cells, trail_cell_transitions,
                  route_quality_inputs, session_route_assignments count
            │
            ├── 필터링 (minCellPointCount=2, minTransitionCount=1)
            ├── pruneIsolatedCells
            ├── selectBestComponent (BFS, 점수 기반)
            ├── selectPath (greedy, sessionCount×10 + transitionCount)
            ├── Confidence 계산 (6개 항목 가중합)
            └── canonical_trails INSERT (version+1, append-only)
```

---

## 4. 분기 감지 워크플로우 (백엔드, 1시간 간격)

```
pg_cron 1시간 (0023_split_cron.sql)
    └── evaluate-route-splits Edge Function
    │
    ▼
route_to_candidate_transitions 분석
    ├── cfgConfidence >= 0.50
    ├── crossBranchRatio >= 0.30
    ├── clusterSessionCount >= 2
    └── minSegmentCells >= 3
    │
    ▼ 조건 충족 시
route_split_audit에 dry-run 기록
    │
    ├── 운영자 DiscoveryPage에서 힌트 확인 후 수동 "Execute split"
    └── 또는 자동 실행 (조건 충족 즉시)
    │
    ▼
split_route_atomic RPC (단일 트랜잭션, 0022_split_route_atomic.sql)
    ├── ABCDE → ABC (기존 route_id 유지) + CDE (신규 route_id)
    ├── CFG → 새 branch route
    └── session_route_assignments 재계산
```

---

## 5. 신규 경로 발굴 워크플로우 (운영자)

```
candidate_cell_clusters 뷰 (0012_session_route_attribution.sql)
    └── mountain_id별 candidate_cells COUNT, 5개 이상인 산 표시
    │
    ▼
운영자 DiscoveryPage에서 확인
    │
    ▼ "Create Route" 버튼 클릭
    └── promote-candidate-cluster Edge Function
            1. candidate_cells → trail_cells (신규 route_id 부여)
            2. H3 인접성 기반 trail_cell_transitions 생성
            3. inferCanonicalRouteFromCells → canonical_trails v1
            4. 기여 세션 status → 'ingested' 재설정
    │
    ▼ (다음 pg_cron 15분 후)
match-and-aggregate-sessions가 재귀속 세션 처리
    └── canonical_trails confidence 갱신
```

---

## 6. 실시간 경로 안내 워크플로우 (모바일)

```
Route 탭 진입
    │
    ▼
산 선택 → 모든 경로의 canonical trail 조회
    └── GET /get-canonical-trail?routeId=<id> (병렬 요청)
         → trailGeoJson (LineString), confidence, routeState
    │
    ▼
경로 폴리라인 지도에 표시
    ├── 'recommended' → 초록색
    ├── 'reference' → 주황색
    └── 'none' → 회색
    │
    ▼ (사용자 위치 이동 또는 수동 트리거)
snap-position 호출 (모든 경로에 병렬 요청)
    └── POST /snap-position { routeId, lat, lon, accuracy }
         → distanceMeters, routeJudgment, snapped {lat, lon}
    │
    ▼
가장 가까운 경로 자동 선택 (TrailGuidanceController)
    └── snaps.reduce((a, b) => a.distanceMeters < b.distanceMeters ? a : b)
    │
    ▼
선택된 경로 강조 표시 + 스냅 결과 카드 표시
    ├── distanceMeters
    ├── routeJudgment ('on_route' / 'caution' / 'away_from_route')
    └── 경로 상태 카드 (confidence, version, updatedAt)
```

---

## 7. 운영자 모니터링 워크플로우

```
운영자 대시보드 진입
    │
    ├── Overview
    │       세션 총수, 산 수, 포인트 수, 최근 업로드 세션
    │
    ├── Mountains
    │       산별 커버리지 현황, bbox 지도 시각화
    │
    ├── Routes
    │       경로 목록 + confidence + canonical trail 지도
    │       위성 이미지와 겹쳐 육안 검증
    │
    ├── Sessions
    │       업로드 히스토리, 수락/거부 포인트 비율, 파이프라인 단계 추적
    │
    ├── Quality
    │       경로별 confidence 분해
    │       (sessionCount, gpsQuality, transitionConsistency, branchAmbiguity, rejectedRate, recency)
    │       이상치 탐지 → recompute-canonical-trails 트리거
    │
    └── Discovery
            candidate 클러스터 목록 → "Create Route" 버튼
            route_split_audit 힌트 → "Execute split" 버튼
```

---

## 8. 개발 워크플로우

```
로컬 개발 환경 설정
    ├── supabase start (포트 54321 Studio, 54322 API, 54323 DB)
    ├── Flutter 에뮬레이터 (10.0.2.2:54321) 또는 실물 기기 (127.0.0.1:54321)
    └── Vite 개발 서버 (localhost:5173)
    │
    ▼
Git 브랜치 전략
    ├── feat/sprint-N-<description> 브랜치에서 기능 개발
    ├── PR → main 병합
    └── 부모 레포: submodule 포인터 업데이트 커밋
    │
    ▼
커밋 컨벤션 (AGENTS_v2.md 참조)
    format: <type>: <subject> (50자 이하, 영어, 명령형)
    types: feat / fix / build / chore / ci / docs / style / refactor / test / release
    │
    ▼
마이그레이션 추가 시
    ├── 기존 번호 확인 후 다음 번호 부여 (현재 최대: 0025)
    ├── 단일 목적 원칙 (테이블 / 정책 / RPC / cron 혼합 금지)
    └── supabase db reset으로 전체 마이그레이션 재실행 검증
```

---

## 데이터 흐름 요약

```
[모바일] GPS 포인트
    → SQLite (오프라인 버퍼, Active Session Recovery 지원)
    → upload-session (검증 + 저장)
    → [status: ingested]
    → match-and-aggregate-sessions (15분마다)
        → H3 셀 변환 + 보간
        → 75m 반경 경로 귀속 또는 candidate 누적
        → Transition 4분류 + DB 누적
        → recomputeRouteConfidence → canonical_trails 버전 갱신
    → evaluate-route-splits (1시간마다)
        → 분기 감지 → route_split_audit → 경로 분할
    → [운영자] Quality 모니터링 + Discovery 신규 경로 승격
    → [모바일] get-canonical-trail + snap-position → 실시간 경로 안내
```

---

## 스케줄러 요약

| 스케줄 | 함수 | 간격 | 역할 |
|--------|------|------|------|
| pg_cron | `match-and-aggregate-sessions` | 15분 | 세션 처리 + 경로 추론 |
| pg_cron | `evaluate-route-splits` | 1시간 | 분기 감지 + 자동 분할 |
| 수동/대시보드 | `recompute-canonical-trails` | 온디맨드 | 특정 경로 재추론 |
| 수동/대시보드 | `promote-candidate-cluster` | 온디맨드 | candidate → 신규 경로 |
| 수동/대시보드 | `split_route_atomic` | 온디맨드 | 경로 분할 실행 |
