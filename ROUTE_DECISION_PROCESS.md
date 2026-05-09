# 경로 결정 프로세스 (Route Decision Process)

사용자의 GPS 세션 기록이 어떻게 수집되고, 어떤 처리를 거쳐, 최종적으로 경로 정보로 확정되는지를 파이프라인 순서대로 설명한다.

---

## 전체 흐름 개요

```
사용자 (모바일 앱)
  │
  ├─ 1. 세션 기록 시작 (mountain 선택 → GPS 수집)
  │
  ├─ 2. 세션 종료 → 업로드 (upload-session edge function)
  │       └─ track_points / rejected_track_points 저장
  │           status: ingesting → ingested
  │
  ├─ 3. 15분마다 자동 처리 (match-and-aggregate-sessions, pg_cron)
  │       ├─ GPS 포인트 → H3 Cell 변환
  │       ├─ Cell을 기존 경로에 매칭 (75m 반경)
  │       ├─ 매칭된 Cell → trail_cells 누적
  │       ├─ 미매칭 Cell → candidate_cells 누적
  │       └─ Transition 4분류 및 각 테이블에 보존
  │
  ├─ 4. Canonical Trail 추론 (recomputeRouteConfidence)
  │       ├─ 누적 Cell/Transition → 연결 그래프
  │       ├─ Best Component 선택 → Best Path 선택
  │       ├─ Confidence 점수 계산 (6개 항목 가중합)
  │       └─ canonical_trails 테이블에 버전별 저장
  │
  ├─ 5. 운영자 관리 (Operator Dashboard)
  │       ├─ Quality: 경로별 confidence 모니터링
  │       ├─ Discovery: candidate cluster → 새 경로 승격
  │       └─ Split Detection: 분기 감지 → 경로 분할
  │
  └─ 6. 모바일 앱 경로 활용
          ├─ get-canonical-trail: 경로 GeoJSON 조회
          └─ snap-position: 현재 위치 경로에 스냅
```

---

## 1. 세션 기록 시작

### 1-1. Mountain 선택

사용자는 앱에서 **산(mountain)만** 선택한다. 개별 경로(route)는 선택하지 않는다.

- `mobile/lib/app/app_shell.dart:211-219` — `RecordingScreen`에 `mountainId`만 전달
- `mobile/lib/features/recording/recording_screen.dart:76` — Start 버튼이 `controller.start(widget.mountainId)` 호출
- `mobile/lib/features/recording/recording_controller.dart:64` — `start(String mountainId)` 시그니처에 `routeId` 없음

이 설계는 의도적이다. 사용자가 어느 경로로 올라갔는지는 시스템이 사후에 GPS 데이터를 분석해서 결정하며, 사용자는 그 결정에 관여하지 않는다.

### 1-2. GPS 포인트 수집

```dart
// mobile/lib/shared/location/location_service.dart:34-37
accuracy: LocationAccuracy.best
distanceFilter: 5  // 5m 이상 이동 시에만 이벤트 발생
```

각 위치 이벤트는 `AppendLocationPointUseCase`를 거쳐 로컬 SQLite DB의 `local_track_points` 테이블에 저장된다.

저장되는 필드 (`mobile/lib/shared/db/track_point_dao.dart`):

| 필드 | 설명 |
|---|---|
| `recorded_at` | GPS 수신 시각 |
| `lat`, `lon` | 위경도 |
| `altitude` | 고도 (m) |
| `accuracy` | GPS 정확도 반경 (m, 낮을수록 정확) |
| `speed` | 속도 (m/s) |
| `sequence_index` | 세션 내 순서 번호 |

---

## 2. 세션 업로드

### 2-1. 업로드 흐름

세션 종료 후 `UploadQueueService` (`mobile/lib/features/sync/upload_queue_service.dart:119-175`)가 다음 순서로 처리한다.

1. 세션 상태를 `uploading`으로 변경
2. 로컬 DB에서 세션과 track_points 조회
3. `upload-session` edge function에 POST

```typescript
// 전송 페이로드 (upload_session_client.dart:102-134)
{
  idempotencyKey,               // 중복 방지용 UUID
  uploadConsentVersion: 'beta-upload-consent-v1',
  mountainId,                   // 사용자가 선택한 산
  routeId,                      // null (사용자가 선택 안 함)
  startedAt, endedAt,
  points: [{ recordedAt, lat, lon, altitude, accuracy, speed, sequenceIndex }]
}
```

### 2-2. 서버측 포인트 검증

`upload-session` edge function (`web/supabase/functions/upload-session/index.ts`)이 각 포인트를 검증한다.

**거절(rejected) 조건** (`web/supabase/functions/_shared/validation.ts:144-170`):

| 조건 | 이유 |
|---|---|
| `recordedAt` 없음 | `missing_recorded_at` |
| 위도가 −90~90 벗어남 | `invalid_lat` |
| 경도가 −180~180 벗어남 | `invalid_lon` |
| `sequenceIndex` 없음 | `missing_sequence_index` |
| `sequenceIndex` 중복 | `duplicate_sequence_index` |
| 속도 > 15 m/s (54 km/h) | `implausible_speed` |
| 정확도 > 100m | `low_accuracy` |

**포인트 분류:**
- 통과한 포인트 → `track_points` 테이블
- 거절된 포인트 → `rejected_track_points` 테이블 (이유 포함)

**세션 최종 상태:**
- 통과 포인트가 1개 이상 → `status = 'ingested'` (처리 대기열에 진입)
- 전부 거절 → `status = 'rejected'`

> **Raw GPS는 이후 삭제되지 않지만 외부에 노출되지 않는다.** `Block direct raw point reads` 정책(`web/supabase/migrations/0006_route_policies.sql:11-18`)으로 클라이언트의 직접 조회를 차단한다. 경로 추론이 완료되면 이 데이터의 역할은 끝난다.

---

## 3. GPS 포인트 → H3 Cell 변환 및 경로 귀속

`match-and-aggregate-sessions` edge function이 15분마다 pg_cron(`web/supabase/migrations/0013_match_cron.sql`)으로 실행되며, `unprocessed_ingested_sessions` 뷰에서 최대 50개의 미처리 세션을 가져와 순차 처리한다.

### 3-1. GPS 포인트 → H3 Cell

```typescript
// web/supabase/functions/_shared/route_inference.ts:199-262
export function buildSessionHitmap(points: RoutePoint[])
```

**Step 1: H3 변환**

각 GPS 포인트를 H3 resolution 11 셀 키로 변환한다.

```typescript
// route_inference.ts:394-396
export function pointToCellKey(lat: number, lon: number): string {
  return latLngToCell(lat, lon, 11);
}
```

H3 resolution 11의 특성:
- 평균 셀 면적: 약 0.019 km²
- 셀 간 평균 거리: 약 25m
- 산악 트레일 추적에 적합한 정밀도

**Step 2: GPS 간격 보간 (`expandWithGridPath`)**

GPS 샘플링 간격이 클 때(빠르게 이동하거나 신호 약화로 포인트가 드문드문 찍힌 경우), 연속된 두 GPS 포인트 사이의 H3 경로(`gridPathCells`)를 보간해서 경로가 끊기지 않도록 한다.

```typescript
// route_inference.ts:238-254
const intermediate = gridPathCells(fromKey, toKey);
// fromKey ~ toKey 사이의 H3 셀들을 순서대로 반환
// 고도는 선형 보간, 정확도는 양 끝의 평균
```

**Step 3: Cell 집계 (TrailCell)**

같은 H3 셀을 지나간 포인트들은 하나의 `TrailCell`로 집계된다.

```typescript
// route_inference.ts:13-23
type TrailCell = {
  cellKey: string;              // H3 셀 ID (예: "8b283471e46ffff")
  lat: number;                  // 이 셀을 지난 GPS 포인트들의 가중평균 위도
  lon: number;                  // 가중평균 경도
  pointCount: number;           // 이 셀을 지난 총 GPS 포인트 수
  sessionCount: number;         // 이 셀을 지난 고유 세션 수
  avgAccuracy: number | null;   // 평균 GPS 정확도 (m)
  avgAltitude: number | null;   // 평균 고도 (m)
  lastSeenAt: string;           // 마지막으로 지나간 시각
  qualityScore: number;         // 1 − (avgAccuracy / 100)
};
```

**Step 4: Transition 집계 (TrailTransition)**

연속된 셀 간의 이동을 `TrailTransition`으로 기록한다.

```typescript
// route_inference.ts:25-31
type TrailTransition = {
  fromCellKey: string;        // 출발 셀
  toCellKey: string;          // 도착 셀
  transitionCount: number;    // 총 이동 횟수
  sessionCount: number;       // 이 이동을 한 고유 세션 수
  edgeCost: number;           // 1 / max(1, transitionCount) — 자주 쓰일수록 비용 낮음
};
```

### 3-2. 기존 경로에 Cell 매칭 (75m 반경)

세션의 각 Cell을 이미 DB에 쌓인 `trail_cells`와 비교해 어느 경로에 속하는지 결정한다.

```typescript
// match-and-aggregate-sessions/index.ts:259-275
const matchRadiusMeters = 75;

function findNearestRouteCell(sessionCell, storedCells): string | null {
  // storedCells = 해당 산의 모든 경로에 속한 trail_cells
  // 각 stored cell과의 haversine 거리를 계산
  // 75m 이내에서 가장 가까운 cell의 routeId를 반환
  // 75m 이내에 아무것도 없으면 null (orphan)
}
```

**Bootstrap 예외:** 아직 `trail_cells`가 하나도 없는 빈 경로가 해당 산에 존재하면, 75m 매칭이 실패하더라도 산의 bbox 안에 있는 Cell은 그 빈 경로에 귀속된다(`findBootstrapRoute`, index.ts:223-255). 이는 운영자가 경로를 사전 생성해 두면 첫 번째 세션이 자동으로 그 경로를 채우도록 하는 메커니즘이다.

### 3-3. Transition 4분류

Cell 분류가 끝나면 `classifyTransitions`이 각 Transition을 4가지로 나눈다.

```
fromCell       toCell         분류                      저장 대상
─────────────────────────────────────────────────────────────────────
route X       route X        route-internal           trail_cell_transitions
orphan        orphan         candidate-internal       candidate_cell_transitions  ← Phase 2 신규
route X       orphan         route_to_candidate       route_to_candidate_transitions  ← Phase 2 신규
orphan        route X        candidate_to_route       route_to_candidate_transitions  ← Phase 2 신규
route X       route Y        cross-route              폐기 (다른 경로 간 이동은 노이즈)
```

분기 경로(예: C→F)가 있는 시나리오에서 C→F transition은 `route_to_candidate`로 보존된다. 이전에는 이 신호가 폐기되어 분기 감지가 불가능했으나, Phase 2 이후부터는 분기점 탐지에 활용된다.

### 3-4. Cell/Transition DB 누적

**Trail Cells (기존 경로에 매칭된 경우):**

`accumulate_trail_cells` RPC (`web/supabase/migrations/0021_split_rpcs.sql`)가 가중평균 UPSERT를 수행한다.

```sql
ON CONFLICT (route_id, cell_key) DO UPDATE SET
  geom            = 가중평균 좌표 (기존 point_count vs 신규 point_count),
  point_count     = 기존 + 신규,
  session_count   = 기존 + 1 (같은 세션 중복 방지),
  contributing_sessions = array_append(기존, p_session_id),
  avg_accuracy    = 가중평균,
  avg_altitude    = 가중평균,
  last_seen_at    = GREATEST(기존, 신규)
```

**Candidate Cells (미매칭된 경우):**

`accumulate_candidate_cells` RPC (`web/supabase/migrations/0012_session_route_attribution.sql:277`)도 동일한 가중평균 UPSERT를 수행한다. `contributing_sessions` 배열로 어느 세션이 이 셀에 기여했는지 추적한다.

**Session Route Assignment:**

매칭된 경로마다 `session_route_assignments` 테이블에 row가 생성된다.

```sql
-- 0012_session_route_attribution.sql:11-18
(session_id, route_id) PRIMARY KEY
contributed_cell_count        -- 이 세션이 이 경로에 기여한 셀 수
contributed_transition_count  -- 이 세션이 이 경로에 기여한 transition 수
matched_at
```

한 세션이 A경로와 B경로에 동시에 기여할 수 있다 (예: 능선을 공유하는 두 루트).

---

## 4. Canonical Trail 추론

각 세션 처리 후 영향받은 모든 경로에 대해 `recomputeRouteConfidence`가 호출되어 `canonical_trails`에 새 버전을 생성한다.

### 4-1. 입력 데이터 수집

```typescript
// match-and-aggregate-sessions/index.ts:421-431
const [cells, transitions, qualityInputs, sessionCount] = await Promise.all([
  supabase.rpc('route_accumulated_cells', { p_route_id: routeId }),
  supabase.from('trail_cell_transitions').select(...).eq('route_id', routeId),
  supabase.rpc('route_quality_inputs', { p_route_id: routeId }),
  supabase.from('session_route_assignments').select('session_id', { count: 'exact' }),
]);
```

`route_accumulated_cells`는 각 셀의 위경도를 포인트 수 기반 가중평균으로 계산해서 반환하는 DB 함수다.

### 4-2. Cell/Transition 필터링

```typescript
// route_inference.ts:71-80 (상수)
const minCellPointCount        = 2;    // 최소 2개 GPS 포인트를 모아야 셀로 인정
const minCellSessionCount      = 1;    // 최소 1개 세션 필요
const minTransitionCount       = 1;    // 최소 1회 이동
const minTransitionSessionCount = 1;   // 최소 1개 세션
```

기준에 미달하는 셀/transition은 제거된다. 고립된 셀(연결된 transition이 없는 셀)도 `pruneIsolatedCells`로 추가 제거된다.

### 4-3. Connected Component 선택 (`selectBestComponent`)

필터링 후 남은 셀과 transition으로 무방향 그래프를 구성하고, BFS로 연결 컴포넌트를 찾는다.

```typescript
// route_inference.ts:552-619
// 각 컴포넌트의 점수 계산
score = sum(transitions.map(t => t.sessionCount))      // 전이 세션 지지도
      + sum(cells.map(c => c.pointCount)) * 0.25       // 셀 포인트 수
      + sessions.size * 0.5;                           // 고유 세션 수
```

가장 점수가 높은 컴포넌트가 "이 경로의 실제 트레일"을 대표하는 것으로 선택된다. 이 과정에서 노이즈 포인트(홀로 떨어진 셀들)가 자연스럽게 걸러진다.

### 4-4. 최적 경로 선택 (`selectPath`)

선택된 컴포넌트 내에서 시작점부터 끝점까지의 선형 경로를 추출한다.

```typescript
// route_inference.ts:621-665
// 1. 가장 강한 transition을 시작 엣지로 선택
const startEdge = [...transitions].sort(compareTransitionStrength)[0];

// 2. 시작점에서 뒤로 연장 (extendPathStart)
//    - 현재 경로 시작점에서 아직 사용하지 않은 인접 transition 중
//      가장 강한 것을 따라 경로를 앞으로 확장
//    - 더 이상 확장할 transition이 없을 때 멈춤

// 3. 끝점에서 앞으로 연장 (extendPathEnd)
//    - 위와 동일하게 경로를 뒤로 확장
```

`compareTransitionStrength`: `sessionCount * 10 + transitionCount` — 같은 경로를 여러 세션이 지나갈수록 그 transition이 강해진다.

### 4-5. Confidence 점수 계산

```typescript
// route_inference.ts:354-361
const confidence = clamp(
  sessionSupportScore      * 0.35 +   // 세션 수 (권장: 5개 이상)
  gpsQualityScore          * 0.20 +   // GPS 정확도 (낮은 accuracy = 높은 점수)
  transitionConsistency    * 0.15 +   // 선택된 경로의 transition 지지도 비율
  (1 - branchAmbiguity)    * 0.15 +   // 분기 명확성 (낮은 ambiguity = 높은 점수)
  (1 - rejectedPointRate)  * 0.10 +   // 수락된 포인트 비율
  recencyScore             * 0.05     // 최신성 (30일 이내 = 최대)
);
```

**각 항목 세부:**

| 항목 | 계산 방법 | 만점 조건 |
|---|---|---|
| `sessionSupportScore` | `min(1, sessionCount / 5)` | 세션 5개 이상 |
| `gpsQualityScore` | 셀별 `qualityScore`의 평균 | accuracy 0m (이론상) |
| `transitionConsistency` | 선택된 경로의 세션 지지도 / 전체 transition 지지도 | 모든 세션이 같은 경로 |
| `branchAmbiguity` | 분기점에서 1위/2위 transition의 강도 비율 평균 | 모든 분기점에서 한쪽이 압도적으로 강함 |
| `rejectedPointRate` | 거절 포인트 / (수락 + 거절) 포인트 | 거절 포인트 0개 |
| `recencyScore` | 마지막 증거일을 기준으로 30일 이내 = 1.0, 1년 이후 = 0.0 | 30일 이내 |

### 4-6. Confidence Level 결정

```typescript
// route_inference.ts:723-737
function isRecommended(route): boolean {
  return confidence >= 0.70               // 종합 점수
    && sessionCount >= 5                  // 최소 5개 세션
    && branchAmbiguity <= 0.30            // 분기 모호성 낮음
    && gpsQuality >= 0.70                 // GPS 품질 양호
    && rejectedPointRate <= 0.30          // 거절 비율 낮음
    && recencyScore >= 0.50;              // 6개월 이내 최근 증거
}
// 모두 만족 → 'recommended'
// 일부 미달  → 'reference'
// 경로 추론 불가 → 'none'
```

### 4-7. canonical_trails 버전 저장

```typescript
// match-and-aggregate-sessions/index.ts:476-495
await supabase.from('canonical_trails').insert({
  route_id: routeId,
  version: previousVersion + 1,        // 매번 새 버전 (append-only)
  geom: lineStringWkt(route.line),     // WKT "LINESTRING(lon1 lat1, lon2 lat2, ...)"
  confidence: route.confidence,
  confidence_level: 'recommended' | 'reference' | 'none',
  session_count: route.sessionCount,
  branch_ambiguity_score: route.branchAmbiguityScore,
  gps_quality_score: route.gpsQualityScore,
});
```

`canonical_trails`는 append-only다. 세션이 추가될수록 버전이 쌓이며, 항상 최신 버전(가장 높은 version 번호)이 실제 경로로 사용된다.

---

## 5. 운영자 관리

### 5-1. Quality 모니터링

운영자는 `QualityPage`에서 경로별 현재 상태를 확인한다.

| 지표 | 의미 |
|---|---|
| `confidence` | 0~1의 종합 신뢰도 점수 |
| `confidence_level` | `recommended` / `reference` / `none` |
| `session_count` | 이 경로에 기여한 고유 세션 수 |
| `branch_ambiguity_score` | 경로 분기 모호성 (0에 가까울수록 명확) |
| `gps_quality_score` | GPS 데이터 품질 평균 |
| `latest_evidence_at` | 가장 최근 세션 기여 시점 |

### 5-2. 새 경로 발견 (Discovery)

`candidate_cell_clusters` 뷰는 미매칭 Cell이 5개 이상 쌓인 산을 표시한다.

```sql
-- 0012_session_route_attribution.sql:71-79
SELECT mountain_id, COUNT(*) AS cell_count, ...
FROM candidate_cells
GROUP BY mountain_id
HAVING COUNT(*) >= 5;
```

운영자가 "Create Route" 버튼을 누르면 `promote-candidate-cluster` edge function이 실행된다:

1. `candidate_cells` → `trail_cells`로 이전 (새 route_id 부여)
2. H3 인접성 기반으로 transition 생성 (candidate_cell_transitions 또는 grid 인접)
3. `inferCanonicalRouteFromCells` 실행 → `canonical_trails` 첫 버전 생성
4. 기여 세션들의 status를 `complete` → `ingested`로 되돌림 → 다음 처리 사이클에서 새 경로에 재귀속

### 5-3. 자동 분기 감지 및 경로 분할

기존 경로 ABCDE와 새 경로 ABCFG가 C에서 분기하는 경우를 자동으로 감지한다.

**감지 조건** (`web/supabase/functions/_shared/route_split_detection.ts`):
- `cfgConfidence >= 0.50` — 분기 클러스터(CFG)의 추론 신뢰도
- `crossBranchRatio >= 0.30` — C셀에서 나가는 이동 중 후보 경로로 향하는 비율
- `clusterSessionCount >= 2` — 최소 2개 세션
- `minSegmentCells >= 3` — 분할 후 각 segment 최소 3개 셀

**감지되면:**
1. `route_split_audit`에 dry-run 기록 → 운영자가 DiscoveryPage에서 힌트 확인
2. 운영자가 "Execute split" 또는 1시간마다 자동 실행 (`0023_split_cron.sql`)
3. `split_route_atomic` RPC가 단일 트랜잭션으로:
   - ABCDE → ABC(기존 ID 유지) + CDE(신규 ID) 분할
   - CFG 셀 → 새 branch route 생성
   - `session_route_assignments` 재계산 (contributing_sessions 기반)

---

## 6. 모바일 앱의 경로 활용

### 6-1. 경로 데이터 조회

`TrailGuidanceScreen`은 산에 연결된 모든 경로의 canonical trail을 `get-canonical-trail` edge function으로 조회한다.

```typescript
// get-canonical-trail/index.ts
GET /get-canonical-trail?routeId=<id>
→ {
    routeId, mountainId,
    routeState: 'recommended' | 'reference' | 'none',
    version, confidence,
    trailGeoJson: { type: 'LineString', coordinates: [[lon, lat], ...] },
    metrics: { sessionCount, branchAmbiguityScore, gpsQualityScore }
  }
```

### 6-2. 현재 위치 스냅

`snap-position` edge function이 현재 위치를 경로 선상의 가장 가까운 점으로 스냅한다.

```typescript
// snap-position/index.ts:5-6
const onRouteMeters    = 25;   // 이 이내 → 'on_route'
const awayFromRouteMeters = 50;  // 25-50m → 'caution', 50m 초과 → 'away_from_route'
```

```typescript
POST /snap-position
{ routeId, lat, lon, accuracy }
→ {
    snapped: { lat, lon },      // 경로 선상의 가장 가까운 점
    distanceMeters,             // 현재 위치 ↔ 경로 거리
    routeJudgment,              // 'on_route' | 'caution' | 'away_from_route'
    onTrail: boolean,
    trailVersion, routeState
  }
```

### 6-3. 가장 가까운 경로 자동 스냅

산에 여러 경로가 있을 때, `TrailGuidanceController`가 모든 경로에 동시에 snap 요청을 보내고 거리가 가장 짧은 경로를 자동으로 선택한다.

```dart
// mobile/lib/features/trails/trail_guidance_controller.dart:74-110
Future<void> compareCurrentPosition() async {
  // 모든 routeIds에 대해 병렬로 snap 요청
  final snaps = await Future.wait(
    _routeIds.map((id) => _snapPositionClient.snapPosition(...))
  );
  
  // 가장 거리가 짧은 경로 선택
  snappedRouteId = snaps
    .where((s) => s != null)
    .reduce((a, b) => a.distanceMeters < b.distanceMeters ? a : b)
    .routeId;
}
```

선택된 `snappedRouteId`의 경로가 지도에서 강조 표시되고, 해당 경로의 `routeJudgment`가 사용자에게 표시된다.

---

## 데이터 흐름 요약

```
[모바일] GPS 포인트 수집
    ↓
[모바일 → 서버] 세션 업로드 (upload-session)
    ↓ status: ingested
[서버, 15분마다] match-and-aggregate-sessions
    ├─ GPS → H3 Cell 변환 (resolution 11, ~25m 정밀도)
    ├─ 보간: gridPathCells (GPS 간격 채우기)
    ├─ 75m 매칭: trail_cells 누적 + contributing_sessions 추적
    ├─ 미매칭: candidate_cells 누적
    └─ Transition 4분류 → 각 테이블 보존
    ↓
[서버] recomputeRouteConfidence
    ├─ 연결 그래프 구성 → Best Component → Best Path
    └─ Confidence 계산 → canonical_trails 버전 저장
    ↓
[운영자] QualityPage (모니터링) / DiscoveryPage (신규 경로 승격)
    ↓
[서버, 1시간마다] evaluate-route-splits (분기 감지 + 자동 분할)
    ↓
[모바일] get-canonical-trail + snap-position → 경로 안내
```

---

## 핵심 파일 위치

| 역할 | 파일 |
|---|---|
| 세션 기록 시작 | `mobile/lib/features/recording/recording_controller.dart` |
| GPS 수집 | `mobile/lib/shared/location/location_service.dart` |
| 세션 업로드 | `mobile/lib/features/sync/upload_queue_service.dart` |
| 포인트 검증 | `web/supabase/functions/_shared/validation.ts` |
| 업로드 처리 | `web/supabase/functions/upload-session/index.ts` |
| GPS → H3 변환 | `web/supabase/functions/_shared/route_inference.ts` (`buildSessionHitmap`, `expandWithGridPath`) |
| 경로 귀속 | `web/supabase/functions/match-and-aggregate-sessions/index.ts` (`processSession`) |
| Cell/Transition 누적 RPC | `web/supabase/migrations/0021_split_rpcs.sql` |
| Canonical Trail 추론 | `web/supabase/functions/_shared/route_inference.ts` (`inferCanonicalRouteFromCells`) |
| DB 스키마 (cells) | `web/supabase/migrations/0003_schema_trails_cells.sql` |
| DB 스키마 (attribution) | `web/supabase/migrations/0012_session_route_attribution.sql` |
| 분기 감지 | `web/supabase/functions/_shared/route_split_detection.ts` |
| 분할 실행 | `web/supabase/migrations/0022_split_route_atomic.sql` |
| 경로 조회 API | `web/supabase/functions/get-canonical-trail/index.ts` |
| 위치 스냅 API | `web/supabase/functions/snap-position/index.ts` |
| 경로 안내 화면 | `mobile/lib/features/trails/trail_guidance_screen.dart` |
| 가장 가까운 경로 선택 | `mobile/lib/features/trails/trail_guidance_controller.dart` |
