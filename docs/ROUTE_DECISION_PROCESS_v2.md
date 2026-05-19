# 경로 결정 프로세스 v2

사용자의 GPS 세션이 어떻게 수집되고, 어떤 처리를 거쳐, 최종적으로 등산 경로(canonical trail)로 확정되는지를 파이프라인 순서대로 설명한다.

---

## 전체 흐름 개요

```
[모바일] 산 선택 → GPS 수집 → 세션 종료 → 업로드
    ↓
[upload-session] 포인트 검증 → track_points / rejected_track_points 저장
    ↓  (status: ingested)
[match-and-aggregate-sessions] pg_cron 15분마다
    ├── GPS → H3 셀 변환
    ├── 75m 반경으로 기존 경로에 셀 귀속
    ├── 미매칭 셀 → candidate_cells 누적
    └── Transition 4분류 → 각 테이블 보존
    ↓
[recomputeRouteConfidence]
    ├── 연결 그래프 구성 → Best Component → Best Path
    └── Confidence 계산 → canonical_trails 버전 저장
    ↓
[evaluate-route-splits] pg_cron 1시간마다
    └── 분기 감지 → route_split_audit → 자동 또는 수동 분할
    ↓
[운영자 대시보드]
    ├── QualityPage: confidence 모니터링
    └── DiscoveryPage: candidate 클러스터 → 신규 경로 승격
    ↓
[모바일]
    ├── get-canonical-trail: 경로 GeoJSON 조회
    └── snap-position: 현재 위치 스냅 + 경로 판정
```

---

## 1. 세션 기록 시작

### 1-1. 산만 선택, 경로는 선택하지 않는다

사용자는 산(mountain)을 선택한다. 개별 경로(route)는 선택하지 않는다.

```
app_shell.dart:211-219  → RecordingScreen에 mountainId만 전달
recording_screen.dart:76 → Start 버튼: controller.start(widget.mountainId)
recording_controller.dart:64 → start(String mountainId) — routeId 없음
```

**의도적 설계**: 사용자가 어느 경로로 올라갔는지는 시스템이 사후에 GPS 데이터를 분석해서 결정하며, 사용자는 그 결정에 관여하지 않는다.

### 1-2. GPS 포인트 수집

```dart
// location_service.dart:34-37
accuracy: LocationAccuracy.best
distanceFilter: 5  // 5m 이상 이동 시에만 이벤트 발생
```

각 위치 이벤트는 `AppendLocationPointUseCase`를 거쳐 로컬 SQLite `local_track_points`에 저장된다.

| 필드 | 설명 |
|------|------|
| `recorded_at` | GPS 수신 시각 |
| `lat`, `lon` | 위경도 |
| `altitude` | 고도 (m) |
| `accuracy` | GPS 정확도 반경 (m, 낮을수록 정확) |
| `speed` | 속도 (m/s) |
| `sequence_index` | 세션 내 순서 번호 |

### 1-3. Active Session Recovery

앱이 강제 종료되거나 기기가 재시작되어도 `session_dao`에서 `status = 'active'`인 세션을 찾아 자동 복구한다. SQLite는 비휘발성이므로 데이터 유실이 없다.

---

## 2. 세션 업로드 (`upload-session`)

### 2-1. 업로드 흐름

세션 완료 후 `UploadQueueService`가 처리한다.

```
1. 세션 status → 'uploading'
2. SQLite에서 세션 + track_points 조회
3. upload-session Edge Function에 POST
4. 응답 수신 → 로컬 status 갱신
```

업로드 페이로드:

```json
{
  "idempotencyKey": "<UUID>",
  "uploadConsentVersion": "beta-upload-consent-v1",
  "mountainId": "<UUID>",
  "routeId": null,
  "startedAt": "<ISO 8601>",
  "endedAt": "<ISO 8601>",
  "points": [
    { "recordedAt": "...", "lat": 37.6, "lon": 127.0, "altitude": 340,
      "accuracy": 8, "speed": 0.5, "sequenceIndex": 0 }
  ]
}
```

### 2-2. 서버측 포인트 검증 (`validation.ts`)

각 포인트는 아래 조건으로 검증된다.

| 거부 사유 | 조건 |
|-----------|------|
| `missing_recorded_at` | 시각 정보 없음 |
| `invalid_lat` | 위도가 −90~90 벗어남 |
| `invalid_lon` | 경도가 −180~180 벗어남 |
| `missing_sequence_index` | 순서 번호 없음 |
| `duplicate_sequence_index` | 같은 세션 내 중복 번호 |
| `implausible_speed` | 속도 > 15m/s (54km/h) |
| `low_accuracy` | accuracy > 100m |

포인트 품질 점수: `qualityScore = max(0, min(1, 1 - accuracy / 100))`

**분기**:
- 통과 포인트 → `track_points` (PostGIS geography)
- 거부 포인트 → `rejected_track_points` (rejection_reason, debug_payload 7일 후 삭제)
- 수락 1개 이상 → `session.status = 'ingested'`
- 전부 거부 → `session.status = 'rejected'`

**보안**: `Block direct raw point reads` 정책(0006_route_policies.sql)으로 클라이언트의 track_points 직접 조회를 차단한다.

---

## 3. GPS → H3 셀 변환 및 경로 귀속

`match-and-aggregate-sessions`가 pg_cron으로 15분마다 실행된다(0013_match_cron.sql). `unprocessed_ingested_sessions` 뷰에서 최대 50개의 미처리 세션을 가져와 순차 처리한다.

### 3-1. H3 셀 변환 (`buildSessionHitmap`)

**Step 1: H3 변환**

```typescript
// route_inference.ts:394-396
export function pointToCellKey(lat: number, lon: number): string {
  return latLngToCell(lat, lon, 11);
}
```

H3 resolution 11 특성:
- 평균 셀 면적: 약 0.019km²
- 셀 간 평균 거리: 약 25m
- 6방향 균일 이웃 — 산악 트레일 추적에 적합

**Step 2: GPS 간격 보간 (`expandWithGridPath`)**

GPS 포인트가 드문드문 찍힌 경우(빠른 이동, 신호 약화), 연속된 두 포인트 사이의 H3 경로(`gridPathCells`)를 보간해 경로가 끊기지 않도록 한다.

```typescript
// route_inference.ts:238-254
const intermediate = gridPathCells(fromKey, toKey);
// 고도: 선형 보간 / 정확도: 양 끝 평균
```

**Step 3: TrailCell 집계**

```typescript
type TrailCell = {
  cellKey: string;         // H3 셀 ID
  lat: number;             // 포인트들의 가중평균 위도
  lon: number;             // 가중평균 경도
  pointCount: number;      // 이 셀을 지난 총 GPS 포인트 수
  sessionCount: number;    // 이 셀을 지난 고유 세션 수
  avgAccuracy: number;     // 평균 GPS 정확도 (m)
  avgAltitude: number;     // 평균 고도 (m)
  lastSeenAt: string;
  qualityScore: number;    // 1 − (avgAccuracy / 100)
};
```

**Step 4: TrailTransition 집계**

```typescript
type TrailTransition = {
  fromCellKey: string;
  toCellKey: string;
  transitionCount: number;    // 총 이동 횟수
  sessionCount: number;       // 이 이동을 한 고유 세션 수
  edgeCost: number;           // 1 / max(1, transitionCount)
};
```

### 3-2. 기존 경로에 셀 귀속 (75m 반경)

```typescript
// match-and-aggregate-sessions/index.ts:259-275
const matchRadiusMeters = 75;

function findNearestRouteCell(sessionCell, storedCells): string | null {
  // storedCells = 해당 산의 모든 경로 trail_cells
  // haversine 거리 계산 → 75m 이내 최근접 routeId 반환
  // 75m 이내 없으면 null (orphan → candidate)
}
```

**Bootstrap 예외**: `trail_cells`가 비어 있는 경로가 해당 산에 있으면, 75m 매칭 실패라도 산 bbox 안의 셀은 그 빈 경로에 귀속된다(`findBootstrapRoute`). 운영자가 경로를 사전 생성해 두면 첫 번째 세션이 자동으로 그 경로를 채운다.

### 3-3. Transition 4분류

```
fromCell       toCell         분류                    저장 위치
────────────────────────────────────────────────────────────────────
route X       route X        route-internal          trail_cell_transitions
orphan        orphan         candidate-internal       candidate_cell_transitions
route X       orphan         route-to-candidate       route_to_candidate_transitions
orphan        route X        candidate-to-route       route_to_candidate_transitions
route X       route Y        cross-route              폐기 (노이즈)
```

route_to_candidate와 candidate-to-route는 분기 신호를 보존한다. 이전(Sprint 9 이전)에는 이 신호가 cross-route로 폐기되어 분기 감지가 불가능했다.

### 3-4. DB 누적

**Trail Cells (기존 경로 귀속)**: `accumulate_trail_cells` RPC (0021_split_rpcs.sql)

```sql
ON CONFLICT (route_id, cell_key) DO UPDATE SET
  geom              = 가중평균 좌표 (point_count 기반),
  point_count       = 기존 + 신규,
  session_count     = 기존 + 1,
  contributing_sessions = array_append(기존, p_session_id),
  avg_accuracy      = 가중평균,
  avg_altitude      = 가중평균,
  last_seen_at      = GREATEST(기존, 신규)
```

**Candidate Cells (미매칭)**: `accumulate_candidate_cells` RPC

동일한 가중평균 UPSERT. `contributing_sessions[]`로 어느 세션이 이 셀에 기여했는지 추적한다.

**Session Route Assignments**:

```sql
-- 0012_session_route_attribution.sql
(session_id, route_id) PRIMARY KEY
contributed_cell_count        -- 이 세션이 이 경로에 기여한 셀 수
contributed_transition_count  -- 이 세션이 이 경로에 기여한 transition 수
matched_at
```

한 세션이 A경로와 B경로에 동시에 기여할 수 있다 (예: 능선을 공유하는 두 루트).

---

## 4. Canonical Trail 추론 (`recomputeRouteConfidence`)

각 세션 처리 후 영향받은 모든 경로에 대해 `recomputeRouteConfidence`가 호출된다.

### 4-1. 입력 데이터 수집

```typescript
const [cells, transitions, qualityInputs, sessionCount] = await Promise.all([
  supabase.rpc('route_accumulated_cells', { p_route_id: routeId }),
  supabase.from('trail_cell_transitions').select(...).eq('route_id', routeId),
  supabase.rpc('route_quality_inputs', { p_route_id: routeId }),
  supabase.from('session_route_assignments').select('session_id', { count: 'exact' }),
]);
```

`route_accumulated_cells`: 각 셀의 좌표를 포인트 수 기반 가중평균으로 계산해서 반환하는 DB 함수.

### 4-2. 필터링

```typescript
// route_inference.ts:71-80
const minCellPointCount         = 2;    // 최소 2개 GPS 포인트
const minCellSessionCount       = 1;    // 최소 1개 세션
const minTransitionCount        = 1;    // 최소 1회 이동
const minTransitionSessionCount = 1;    // 최소 1개 세션
```

기준 미달 셀/transition은 제거. 고립된 셀(연결 transition 없음)도 `pruneIsolatedCells`로 추가 제거.

### 4-3. Best Component 선택 (`selectBestComponent`)

BFS로 연결 컴포넌트를 찾아 점수가 가장 높은 컴포넌트를 선택한다.

```typescript
// route_inference.ts:552-619
score = Σ(transitions.map(t => t.sessionCount))
      + Σ(cells.map(c => c.pointCount)) × 0.25
      + sessions.size × 0.5;
```

노이즈 포인트(홀로 떨어진 셀들)가 자연스럽게 걸러진다.

### 4-4. Best Path 선택 (`selectPath`)

```typescript
// route_inference.ts:621-665
// 1. 가장 강한 transition을 시작 엣지로 선택
const startEdge = [...transitions].sort(compareTransitionStrength)[0];

// compareTransitionStrength: sessionCount × 10 + transitionCount

// 2. 시작점에서 뒤로 연장 (extendPathStart)
// 3. 끝점에서 앞으로 연장 (extendPathEnd)
// → 더 이상 확장할 transition이 없을 때 멈춤
```

### 4-5. Confidence 계산

```typescript
// route_inference.ts:354-361
confidence = clamp(
  sessionSupportScore      × 0.35 +
  gpsQualityScore          × 0.20 +
  transitionConsistency    × 0.15 +
  (1 - branchAmbiguity)    × 0.15 +
  (1 - rejectedPointRate)  × 0.10 +
  recencyScore             × 0.05
);
```

| 항목 | 계산 | 만점 조건 |
|------|------|-----------|
| `sessionSupportScore` | `min(1, sessionCount / 5)` | 세션 5개 이상 |
| `gpsQualityScore` | 셀별 `qualityScore` 평균 | accuracy → 0m |
| `transitionConsistency` | 선택 경로 세션 지지도 / 전체 | 모든 세션이 같은 경로 |
| `branchAmbiguity` | 분기점 1위/2위 강도 비율 평균 | 한쪽이 압도적 |
| `rejectedPointRate` | 거부 포인트 / (수락 + 거부) | 거부 0개 |
| `recencyScore` | 30일 이내=1.0, 1년+=0.0 | 30일 이내 |

### 4-6. Confidence Level 결정

```typescript
// route_inference.ts:723-737
function isRecommended(route): boolean {
  return confidence >= 0.70
    && sessionCount >= 5
    && branchAmbiguity <= 0.30
    && gpsQuality >= 0.70
    && rejectedPointRate <= 0.30
    && recencyScore >= 0.50;
}
// true  → 'recommended'
// false → 'reference'
// 경로 추론 불가 → 'none'
```

### 4-7. canonical_trails 버전 저장

```typescript
await supabase.from('canonical_trails').insert({
  route_id: routeId,
  version: previousVersion + 1,        // append-only
  geom: lineStringWkt(route.line),     // "LINESTRING(lon1 lat1, ...)"
  confidence: route.confidence,
  confidence_level: 'recommended' | 'reference' | 'none',
  session_count: route.sessionCount,
  branch_ambiguity_score: route.branchAmbiguityScore,
  gps_quality_score: route.gpsQualityScore,
});
```

`canonical_trails`는 append-only다. 세션이 추가될수록 버전이 쌓이며, 최신 버전이 항상 활성 경로다.

---

## 5. 분기 감지 및 경로 분할

### 5-1. 감지 조건 (`route_split_detection.ts`)

| 조건 | 의미 |
|------|------|
| `cfgConfidence >= 0.50` | 분기 클러스터(CFG)의 추론 신뢰도 |
| `crossBranchRatio >= 0.30` | 분기점 셀에서 후보로 나가는 이동 비율 |
| `clusterSessionCount >= 2` | 최소 2개 세션 |
| `minSegmentCells >= 3` | 분할 후 각 segment의 최소 셀 수 |

### 5-2. 분할 프로세스

```
evaluate-route-splits (pg_cron 1시간마다, 0023_split_cron.sql)
    ↓
route_split_audit에 dry-run 기록
    ↓
운영자 DiscoveryPage에서 힌트 확인
    ↓
"Execute split" 또는 자동 실행
    ↓
split_route_atomic RPC (단일 트랜잭션, 0022_split_route_atomic.sql)
    ├── ABCDE → ABC (기존 route_id 유지) + CDE (신규 route_id)
    ├── CFG → 새 branch route 생성
    └── session_route_assignments 재계산 (contributing_sessions 기반)
```

---

## 6. 운영자 관리

### 6-1. Quality 모니터링

`QualityPage`에서 경로별 현재 상태를 확인한다.

| 지표 | 의미 |
|------|------|
| `confidence` | 0~1 종합 신뢰도 |
| `confidence_level` | `recommended` / `reference` / `none` |
| `session_count` | 기여 세션 수 |
| `branch_ambiguity_score` | 0에 가까울수록 명확한 경로 |
| `gps_quality_score` | GPS 데이터 평균 품질 |
| `latest_evidence_at` | 가장 최근 세션 기여 시점 |

### 6-2. 신규 경로 발굴 (Discovery)

`candidate_cell_clusters` 뷰가 미매칭 셀 5개 이상 쌓인 산을 표시한다.

```sql
-- 0012_session_route_attribution.sql:71-79
SELECT mountain_id, COUNT(*) AS cell_count
FROM candidate_cells
GROUP BY mountain_id
HAVING COUNT(*) >= 5;
```

"Create Route" 버튼 → `promote-candidate-cluster` Edge Function:

1. `candidate_cells` → `trail_cells`로 이전 (새 route_id 부여)
2. H3 인접성 기반 transition 생성
3. `inferCanonicalRouteFromCells` 실행 → `canonical_trails` 첫 버전 생성
4. 기여 세션들의 status를 `ingested`로 되돌림 → 다음 처리 사이클에서 새 경로에 재귀속

---

## 7. 모바일 앱의 경로 활용

### 7-1. 경로 조회

```typescript
GET /get-canonical-trail?routeId=<id>
→ {
    routeId, mountainId,
    routeState: 'recommended' | 'reference' | 'none',
    version, confidence,
    trailGeoJson: { type: 'LineString', coordinates: [[lon, lat], ...] },
    metrics: { sessionCount, branchAmbiguityScore, gpsQualityScore }
  }
```

### 7-2. 위치 스냅

```typescript
POST /snap-position
{ routeId, lat, lon, accuracy }
→ {
    snapped: { lat, lon },
    distanceMeters,
    routeJudgment: 'on_route' | 'caution' | 'away_from_route',
    onTrail: boolean,
    thresholds: { onRouteMeters: 25, awayFromRouteMeters: 50 }
  }
```

### 7-3. 자동 최근접 경로 선택

산에 여러 경로가 있을 때 `TrailGuidanceController`가 모든 경로에 동시에 snap 요청을 보내고, 거리가 가장 짧은 경로를 자동으로 활성화한다.

```dart
// trail_guidance_controller.dart:74-110
final snaps = await Future.wait(
  _routeIds.map((id) => _snapPositionClient.snapPosition(...))
);
snappedRouteId = snaps
  .where((s) => s != null)
  .reduce((a, b) => a.distanceMeters < b.distanceMeters ? a : b)
  .routeId;
```

---

## 핵심 파일 위치

| 역할 | 파일 |
|------|------|
| 세션 기록 시작 | `mobile/lib/features/recording/recording_controller.dart` |
| GPS 수집 | `mobile/lib/shared/location/location_service.dart` |
| 세션 업로드 | `mobile/lib/features/sync/upload_queue_service.dart` |
| 포인트 검증 | `web/supabase/functions/_shared/validation.ts` |
| 업로드 처리 | `web/supabase/functions/upload-session/index.ts` |
| GPS → H3 변환 | `web/supabase/functions/_shared/route_inference.ts` (`buildSessionHitmap`, `expandWithGridPath`) |
| 경로 귀속 | `web/supabase/functions/match-and-aggregate-sessions/index.ts` (`processSession`) |
| Cell 누적 RPC | `web/supabase/migrations/0021_split_rpcs.sql` |
| Canonical Trail 추론 | `web/supabase/functions/_shared/route_inference.ts` (`inferCanonicalRouteFromCells`) |
| DB 스키마 (셀) | `web/supabase/migrations/0003_schema_trails_cells.sql` |
| DB 스키마 (귀속) | `web/supabase/migrations/0012_session_route_attribution.sql` |
| 분기 감지 | `web/supabase/functions/_shared/route_split_detection.ts` |
| 분기 감지 스케줄 | `web/supabase/migrations/0023_split_cron.sql` |
| 분할 실행 RPC | `web/supabase/migrations/0022_split_route_atomic.sql` |
| 경로 조회 API | `web/supabase/functions/get-canonical-trail/index.ts` |
| 위치 스냅 API | `web/supabase/functions/snap-position/index.ts` |
| 경로 안내 화면 | `mobile/lib/features/trails/trail_guidance_screen.dart` |
| 최근접 경로 선택 | `mobile/lib/features/trails/trail_guidance_controller.dart` |
