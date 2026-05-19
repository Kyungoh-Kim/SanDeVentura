# SanDeVentura — 아키텍처 v2

## 시스템 전체 구조

```
┌──────────────────────────────────────────────────────────────────────┐
│                    SanDeVentura 모노레포 (부모)                        │
│          서브모듈 포인터 + 문서 + 커밋 컨벤션 관리                     │
│                                                                      │
│  ┌────────────────────────┐    ┌──────────────────────────────────┐  │
│  │  mobile/ (submodule)   │    │        web/ (submodule)          │  │
│  │  Flutter Android-first │    │  React 운영자 대시보드            │  │
│  │  + SQLite 오프라인 DB   │    │  + Supabase 백엔드               │  │
│  └────────────────────────┘    └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. 모바일 레이어 (Flutter)

### 아키텍처 패턴: Feature-first + Layered

```
mobile/lib/
├── main.dart                      # 앱 진입점, MaterialApp, DI 초기화
├── app/
│   ├── app_shell.dart            # 탭 네비게이션 셸 (Record / Route / Sessions)
│   └── dependency_injection.dart  # 서비스 인스턴스 생성 및 주입
├── features/
│   ├── mountains/                 # 산 선택 (get-mountains 연동)
│   │   └── mountain_list_client.dart
│   ├── recording/                 # GPS 세션 기록 (핵심 기능)
│   │   ├── recording_screen.dart
│   │   ├── recording_controller.dart
│   │   ├── recording_map_view.dart
│   │   └── recording_use_cases.dart
│   ├── trails/                    # 경로 안내 (snap-position / canonical trail)
│   │   ├── trail_guidance_screen.dart
│   │   ├── trail_guidance_controller.dart
│   │   ├── trail_route_preview.dart
│   │   ├── snap_position_client.dart
│   │   └── canonical_trail_client.dart
│   └── sync/                      # 업로드 큐 관리 및 Sessions 탭
│       ├── sessions_screen.dart
│       ├── sync_controller.dart
│       ├── upload_session_client.dart
│       └── upload_queue_service.dart
└── shared/
    ├── db/                        # SQLite DAOs
    │   ├── app_database.dart      # DB 스키마 초기화
    │   ├── session_dao.dart
    │   ├── track_point_dao.dart
    │   └── upload_queue_dao.dart
    ├── domain/                    # 비즈니스 엔티티 및 유틸
    │   ├── entities.dart          # Mountain, Session, TrackPoint
    │   ├── result.dart            # Result<T, E> 에러 처리 타입
    │   └── geo_math.dart          # 지리 계산 (haversine 등)
    ├── location/
    │   ├── location_permission_service.dart
    │   └── location_service.dart  # geolocator 래퍼
    └── widgets/
        ├── mountain_selector.dart
        └── mountain_search_modal.dart
```

### 기술 스택

| 레이어 | 라이브러리 | 버전 | 역할 |
|--------|-----------|------|------|
| UI 프레임워크 | Flutter | 3.11.5 | 크로스플랫폼 UI (Android-first) |
| 지도 | flutter_map + latlong2 | 8.3.0 | 경로 폴리라인, 내 위치 마커 |
| GPS | geolocator | 14.0.2 | 위치 수신 (accuracy: best, distanceFilter: 5m) |
| 로컬 DB | sqflite (SQLite) | - | 오프라인 세션 + 포인트 저장 |
| 네트워크 감지 | connectivity_plus | 6.0.0 | 자동 업로드 트리거 |
| 백엔드 통신 | HTTP (dart:io) | - | Supabase Edge Function 호출 |

### 오프라인-퍼스트 설계

```
GPS 수신 (geolocator)
    │
    ▼
AppendLocationPointUseCase
    │
    ▼
SQLite (local_track_points)  ◄─── 앱 재시작 시 자동 복구
    │
    ▼ (세션 종료 후)
upload_queue (SQLite)
    │
    ▼ (connectivity 이벤트 - Wi-Fi/모바일 감지)
upload-session Edge Function
```

**Active Session Recovery**: 앱이 강제 종료되거나 기기가 재시작되어도 `session_dao`에서 `status = 'active'`인 세션을 찾아 자동으로 기록을 재개한다.

### 세션 상태 전이 (로컬)

```
active → paused → active → completed → queued → uploading → uploaded
```

### 지도 레이어

- **기본**: OpenStreetMap (OSM) 타일
- **위성**: Esri World Imagery
- 자동 중심(auto-center) 토글: 내 위치 추적 ↔ 자유 탐색 전환

---

## 2. 백엔드 레이어 (Supabase)

### 아키텍처 패턴: Serverless PostgreSQL-centric

```
Supabase Platform
├── PostgreSQL 15 + PostGIS    # 지리공간 데이터베이스
├── Deno Edge Functions        # 비즈니스 로직 서버리스
├── Supabase Auth              # JWT 인증 (MVP: 검증 비활성화)
├── REST API (PostgREST)       # 자동 생성 CRUD API
└── pg_cron                    # 스케줄 작업 (15분/1시간 간격)
```

### Edge Functions (8개)

```
web/supabase/functions/
├── upload-session/              # 세션 수집 + GPS 포인트 검증
├── get-canonical-trail/         # 기준 경로 GeoJSON 반환
├── snap-position/               # 실시간 경로 위치 스냅 (PostGIS)
├── get-mountains/               # 산 + 경로 목록 반환
├── match-and-aggregate-sessions/# 세션-경로 매칭 + 경로 갱신 (pg_cron 15분)
├── recompute-canonical-trails/  # 경로 재추론 수동 트리거
├── evaluate-route-splits/       # 분기 감지 + 경로 분할 (pg_cron 1시간)
├── promote-candidate-cluster/   # 미매칭 셀 클러스터 → 신규 경로 승격
└── _shared/
    ├── route_inference.ts       # Grid-and-Graph 경로 추론 알고리즘 (~24KB)
    ├── route_split_detection.ts # 분기 감지 로직
    ├── validation.ts            # GPS 포인트 검증
    └── response.ts              # JSON 응답 포맷터
```

### 데이터베이스 스키마

```
mountains
    │
    ├── routes (산-경로 매핑)
    │       │
    │       ├── trail_cells (H3 셀 누적)
    │       │       └── trail_cell_transitions (셀 간 이동 그래프)
    │       │
    │       ├── canonical_trails (추론된 경로, append-only 버전)
    │       │
    │       ├── candidate_cells (미매칭 셀 - 신규 경로 후보)
    │       │       └── candidate_cell_transitions
    │       │
    │       ├── route_to_candidate_transitions (경계 전이)
    │       │
    │       └── route_split_audit (분기 감지 dry-run 기록)
    │
    └── hiking_sessions
            │
            ├── track_points (PostGIS geography)
            ├── rejected_track_points (거부 포인트 + 사유)
            └── session_route_assignments (세션 ↔ 경로 귀속 매핑)
```

#### 주요 테이블 상세

| 테이블 | PK/FK | 역할 |
|--------|-------|------|
| `mountains` | `id` | 산 레지스트리 (display_name, source) |
| `routes` | `id`, FK→`mountains` | 산-경로 매핑, 경로명 |
| `hiking_sessions` | `id` | 세션 메타 (status, accepted/rejected count, idempotency_key) |
| `track_points` | `id`, FK→`sessions` | GPS 포인트 (PostGIS geography, accuracy, altitude, sequence_index) |
| `rejected_track_points` | `id`, FK→`sessions` | 거부 포인트 (rejection_reason, debug_payload 7일 후 삭제) |
| `trail_cells` | `(route_id, cell_key)` | H3 셀 누적 (point_count, session_count, avg_accuracy, contributing_sessions[]) |
| `trail_cell_transitions` | `(route_id, from_cell_key, to_cell_key)` | 셀 간 이동 그래프 (transition_count, session_count, edge_cost) |
| `candidate_cells` | `(mountain_id, cell_key)` | 미매칭 셀 후보 |
| `candidate_cell_transitions` | `(mountain_id, from_cell_key, to_cell_key)` | 후보 셀 간 이동 |
| `route_to_candidate_transitions` | `(route_id, from_cell_key, to_cell_key)` | 경로↔후보 경계 전이 (분기 신호) |
| `canonical_trails` | `(route_id, version)` | 추론 경로 (LineString WKT, confidence, confidence_level) |
| `session_route_assignments` | `(session_id, route_id)` | 세션-경로 귀속 (contributed_cell_count, contributed_transition_count) |
| `route_split_audit` | `id` | 분기 감지 dry-run 기록 |
| `mvp_events` | `id` | 시스템 이벤트 로그 |

### 마이그레이션 목록 (0001~0025)

| 번호 | 파일 | 내용 |
|------|------|------|
| 0001 | `enable_extensions.sql` | PostGIS, pg_cron, uuid-ossp 활성화 |
| 0002 | `schema_sessions_points.sql` | hiking_sessions, track_points, rejected_track_points |
| 0003 | `schema_trails_cells.sql` | trail_cells, trail_cell_transitions, canonical_trails |
| 0004 | `rls_*.sql` | Row Level Security 정책 |
| 0005~0011 | 다양 | 뷰, 샘플 데이터, RPC 함수 |
| 0012 | `session_route_attribution.sql` | session_route_assignments, candidate_cells, candidate_cell_transitions |
| 0013 | `match_cron.sql` | pg_cron 15분 스케줄 (match-and-aggregate-sessions) |
| 0021 | `split_rpcs.sql` | accumulate_trail_cells, accumulate_candidate_cells RPC |
| 0022 | `split_route_atomic.sql` | split_route_atomic 트랜잭션 RPC |
| 0023 | `split_cron.sql` | pg_cron 1시간 스케줄 (evaluate-route-splits) |

---

## 3. 핵심 알고리즘: Grid-and-Graph Route Inference

**위치**: `web/supabase/functions/_shared/route_inference.ts`

### 전체 파이프라인

```
track_points (GPS 좌표들)
    │
    ▼  pointToCellKey(lat, lon, resolution=11)
H3 셀 변환 (trail_cells)
    셀 특성: 엣지 길이 ~24.9m, 6방향 균일 이웃
    │
    ▼  expandWithGridPath
GPS 간격 보간 (gridPathCells)
    연속 두 포인트 사이의 H3 경로 보간
    고도: 선형 보간 / 정확도: 양 끝 평균
    │
    ▼  buildSessionHitmap
TrailCell 집계: (cellKey, pointCount, sessionCount, avgAccuracy, qualityScore)
TrailTransition 집계: (fromCellKey, toCellKey, transitionCount, sessionCount, edgeCost)
    edgeCost = 1 / max(1, transitionCount)  ← 자주 통과할수록 비용 낮음
    │
    ▼ (match-and-aggregate에서 DB 반영 후)
    ▼  inferCanonicalRouteFromCells
입력 데이터 수집
    - route_accumulated_cells (가중평균 좌표)
    - trail_cell_transitions
    - route_quality_inputs
    - session_route_assignments count
    │
    ▼  필터링
minCellPointCount = 2, minCellSessionCount = 1
minTransitionCount = 1, minTransitionSessionCount = 1
pruneIsolatedCells: 연결된 transition이 없는 셀 제거
    │
    ▼  selectBestComponent (BFS)
연결 컴포넌트 탐색 → 점수 = Σ(transition.sessionCount) + Σ(cell.pointCount)×0.25 + sessions×0.5
가장 높은 컴포넌트 선택
    │
    ▼  selectPath (greedy)
startEdge = sort by (sessionCount×10 + transitionCount)[0]
양방향 탐욕적 경로 확장 (extendPathStart / extendPathEnd)
    │
    ▼  confidence 계산
sessionSupportScore   × 0.35  (min(1, sessionCount/5))
gpsQualityScore       × 0.20  (셀별 1-accuracy/100 평균)
transitionConsistency × 0.15  (선택 경로 세션 지지도 / 전체)
(1 - branchAmbiguity) × 0.15  (분기점 1위/2위 강도 비율)
(1 - rejectedPointRate)×0.10  (수락 포인트 비율)
recencyScore          × 0.05  (30일 이내=1.0, 1년+=0.0)
    │
    ▼  confidence_level 결정
confidence >= 0.70 AND sessionCount >= 5
AND branchAmbiguity <= 0.30 AND gpsQuality >= 0.70
AND rejectedPointRate <= 0.30 AND recencyScore >= 0.50
→ 'recommended'
그 외 → 'reference'
경로 추론 불가 → 'none'
    │
    ▼
canonical_trails INSERT (version+1, geom WKT, confidence, confidence_level)
← append-only: 히스토리 보존, 최신 버전이 활성 경로
```

### Transition 4분류

세션 처리 시 각 셀 간 이동을 아래와 같이 분류한다.

| from | to | 분류 | 저장 위치 |
|------|----|------|-----------|
| route X | route X | route-internal | `trail_cell_transitions` |
| orphan | orphan | candidate-internal | `candidate_cell_transitions` |
| route X | orphan | route-to-candidate | `route_to_candidate_transitions` |
| orphan | route X | candidate-to-route | `route_to_candidate_transitions` |
| route X | route Y | cross-route | 폐기 (노이즈) |

### 경로 매칭 로직

- **75m 반경 매칭**: 세션의 H3 셀을 DB의 `trail_cells`와 haversine 거리로 비교, 75m 이내 가장 가까운 셀의 `route_id`에 귀속
- **Bootstrap 예외**: `trail_cells`가 비어 있는 경로가 산 bbox 내에 있으면 해당 경로에 첫 세션을 자동 귀속 (운영자가 경로를 사전 생성해두는 메커니즘)

---

## 4. 분기 감지 및 경로 분할

**위치**: `web/supabase/functions/_shared/route_split_detection.ts`

### 감지 조건

```
cfgConfidence >= 0.50       분기 클러스터의 추론 신뢰도
crossBranchRatio >= 0.30    분기점 셀에서 후보로 나가는 이동 비율
clusterSessionCount >= 2    최소 2개 세션
minSegmentCells >= 3        분할 후 각 segment의 최소 셀 수
```

### 분할 프로세스

```
감지 → route_split_audit에 dry-run 기록
    │
    ▼
운영자 DiscoveryPage에서 힌트 확인
    │
    ├── 수동 "Execute split" 버튼
    └── 1시간마다 자동 실행 (evaluate-route-splits, 0023_split_cron.sql)
    │
    ▼  split_route_atomic RPC (단일 트랜잭션)
ABCDE → ABC (기존 route_id 유지) + CDE (신규 route_id)
CFG → 새 branch route 생성
session_route_assignments 재계산
```

---

## 5. 웹 레이어 (React 운영자 대시보드)

### 아키텍처 패턴: Page-based + Repository

```
web/src/operator/
├── main.tsx
├── OperatorApp.tsx              # 앱 셸 + 사이드 네비게이션
├── pages/
│   ├── OverviewPage.tsx         # 요약 지표 (세션 수, 경로 수, 포인트 수)
│   ├── MountainsPage.tsx        # 산별 커버리지 + bbox 지도
│   ├── RoutesPage.tsx           # 경로 목록 + canonical trail 지도
│   ├── SessionsPage.tsx         # 세션 업로드 히스토리 + 파이프라인 상태
│   ├── QualityPage.tsx          # 신뢰도 디버깅 + 이상치 탐지
│   └── DiscoveryPage.tsx        # candidate 클러스터 → 신규 경로 승격
├── data/
│   ├── supabaseClient.ts        # Supabase 클라이언트 초기화
│   ├── readModels.ts            # 읽기 모델 쿼리
│   ├── routesRepository.ts
│   ├── mountainsRepository.ts
│   └── operationsRepository.ts
└── components/
    └── OperatorRouteMap.tsx     # OpenLayers 지도 컴포넌트
```

### 기술 스택

| 레이어 | 기술 | 버전 | 역할 |
|--------|------|------|------|
| UI | React + TypeScript | 19.0.0 / 5.8.0 | 컴포넌트 UI |
| 빌드 | Vite | 7.0.0 | 번들링 + 개발 서버 |
| 지도 | OpenLayers | 10.9.0 | canonical trail geometry 시각화 |
| 데이터 | @supabase/supabase-js | v2 | DB 직접 쿼리 |

---

## 6. API 계약 요약

### POST `/functions/v1/upload-session`

```typescript
Request {
  idempotencyKey: string         // 중복 방지 UUID
  uploadConsentVersion: string   // "beta-upload-consent-v1"
  mountainId: string
  startedAt: string              // ISO 8601
  endedAt: string
  points: Array<{
    recordedAt: string
    lat: number                  // -90 ~ 90
    lon: number                  // -180 ~ 180
    altitude: number
    accuracy: number             // 미터 단위, 낮을수록 정확
    speed: number                // m/s
    sequenceIndex: number
  }>
}

Response {
  success: boolean
  sessionId: string
  acceptedPointCount: number
  rejectedPointCount: number
  retentionExpiresAt: string     // 90일 후
  status: "ingested" | "duplicate" | "rejected"
}
```

### GET `/functions/v1/get-canonical-trail?routeId=<id>`

```typescript
Response {
  routeId: string
  mountainId: string
  routeState: "recommended" | "reference" | "none"
  version: number
  confidence: number             // 0.0 ~ 1.0
  updatedAt: string
  trailGeoJson: {
    type: "LineString"
    coordinates: [number, number][]   // [lon, lat]
  }
  metrics: {
    sessionCount: number
    branchAmbiguityScore: number
    gpsQualityScore: number
  }
}
```

### POST `/functions/v1/snap-position`

```typescript
Request { routeId: string; lat: number; lon: number; accuracy: number }

Response {
  snapped: { lat: number; lon: number }
  distanceMeters: number
  routeJudgment: "on_route" | "caution" | "away_from_route"
  onTrail: boolean
  trailVersion: number
  routeState: string
  thresholds: { onRouteMeters: 25; awayFromRouteMeters: 50 }
}
```

### GET `/functions/v1/get-mountains`

```typescript
Response {
  mountains: Array<{
    id: string
    displayName: string
    routes: Array<{ id: string; name: string; routeState: string }>
  }>
}
```

---

## 7. 배포 아키텍처

### 로컬 개발

```
Supabase CLI       → http://localhost:54321 (Studio: 54323)
Flutter 에뮬레이터  → http://10.0.2.2:54321 (Android AVD)
Flutter 실물 기기   → http://127.0.0.1:54321
Vite 개발 서버      → http://localhost:5173
```

### 프로덕션 (예정)

```
Supabase Cloud     → PostgreSQL + Edge Functions 호스팅
Flutter APK        → Android (Google Play Store)
웹 대시보드         → 정적 호스팅 (Vercel 또는 Supabase Hosting)
```

---

## 8. 설계 원칙

| 원칙 | 구현 방식 |
|------|-----------|
| 오프라인-퍼스트 | SQLite 로컬 저장 + 업로드 큐 + Active Session Recovery |
| 프라이버시 중심 | 운영자는 raw 좌표 열람 불가 (RLS), H3 셀 집계 단위만 노출 |
| 점진적 신뢰도 | 세션 누적 → confidence 선형 향상 → reference → recommended |
| 최소 의존성 | Supabase 단일 플랫폼으로 DB + Auth + Functions + REST 통합 |
| 지리공간 우선 | PostGIS 거리 계산, H3 resolution 11 (~24.9m 셀) 경로 추론 |
| 분기 보존 | Phase 2: route_to_candidate_transitions로 분기 신호 유실 방지 |

---

## 9. 모노레포 구조 및 Git 전략

```
SanDeVentura (부모 레포, main 브랜치)
├── .gitmodules          # mobile + web 서브모듈 등록
├── mobile/              # submodule → 독립 git 히스토리
├── web/                 # submodule → 독립 git 히스토리
└── documents/           # SDD, PRD, 스프린트 계획, 프레젠테이션
```

**브랜치 전략**:
- `feat/sprint-N-<설명>` 브랜치에서 기능 개발
- PR → `main` 병합
- 부모 레포: 서브모듈 포인터 업데이트 커밋으로 릴리스 버전 고정
