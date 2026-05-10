# SanDeVentura — 개발 진행 과정

> GPS 기반 크라우드소싱 등산 경로 플랫폼의 처음부터 현재까지의 설계·구현 기록.  
> 스프린트별 목표, 실제 구현 결과, 기술적 결정, 발생한 제약을 시간 순으로 기록한다.

---

## 프로젝트 출발점

**시작일**: 2026-05-05  
**개발자**: 1인 (Kyungoh)  
**개발 보조**: Claude Code (Codex 기반 AI 코딩 어시스턴트)  
**목표**: 공식 등산 앱에 없는 비공식 코스를 사용자 GPS 데이터로 자동 구축하는 MVP

이전에 Flutter + Firebase 프로토타입이 존재했으나 폐기하고, Supabase + PostGIS 기반으로 처음부터 재설계했다.

### 초기 기술 스택 결정

| 영역 | 선택 | 이유 |
|------|------|------|
| 모바일 | Flutter (Android-first) | 단일 코드베이스, 추후 iOS 확장 가능 |
| 로컬 저장 | SQLite (sqflite) | 오프라인 세션 지속성 + 앱 재시작 복구 |
| 백엔드 | Supabase | DB + Auth + Functions + REST 통합 단일 플랫폼 |
| 지리공간 | PostgreSQL + PostGIS | 공간 인덱스, 거리 계산, nearest-route 쿼리 |
| 서버리스 | Deno Edge Functions | 소형 인증 API 서피스 |
| DB 테스트 | pgTAP (Supabase CLI) | DB 제약 및 공간 함수 테스트 |
| 지도 (웹) | OpenLayers | GIS 스타일 경로 검수, GeoJSON 렌더링 |
| 지도 (모바일) | flutter_map | 순수 Flutter 구현, OSM 라스터 타일 |

### 개발 원칙

구현 순서를 명확히 정했다. 각 단계는 이전 단계가 안정화된 이후에 시작한다.

1. 백엔드보다 **로컬/오프라인 기록** 먼저
2. 업로드 전에 **세션 복구** 먼저
3. 경로 추론 전에 **이중 방지(idempotency) 업로드** 먼저
4. 원격 저장 전에 **업로드 동의 + RLS** 먼저
5. canonical trail 생성 전에 **포인트 검증** 먼저
6. 경로 UI 전에 **기본 경로 추론** 먼저
7. "recommended" 표시 전에 **신뢰도 레이블** 먼저
8. canonical trail 이후에 **snap-position** 먼저
9. P0 사용자 루프 이후에 **운영자 메트릭**

---

## Sprint 0: 프로젝트 초기화

**기간**: 2026-05-05  
**커밋**: `b20dc57 chore: Initialize parent workspace`

### 작업 내용

- 모노레포 구조 확정: 부모 레포(문서 + CI) + `mobile/`, `web/` 서브모듈
- `.gitmodules` 설정
- `AGENTS.md` 작성 (커밋 컨벤션)
- 개발 실행 계획(`development-execution-plan.md`) 작성
- 전체 스프린트 계획 수립 (Sprint 1~4, 총 35 working days 예상)

### 확정된 프로젝트 구조

```
SanDeVentura (부모)
├── mobile/ (submodule) — Flutter Android-first
└── web/ (submodule) — React + Supabase Backend
```

---

## Sprint 1: 오프라인 GPS 기록 기반

**기간**: 2026-05-06  
**계획**: `sprint-1-field-recording-plan.md`  
**브랜치**: `feat/sprint-1-recording-foundation`

### 목표

네트워크 없이 등산 세션을 기록하고, 앱 재시작 이후에도 세션을 복구한다.

업로드, 경로 추론, 운영자 대시보드는 의도적으로 제외.

### 구현 결과

| 기능 | 결과 |
|------|------|
| SQLite 스키마 (`local_sessions`, `local_track_points`) | 완료 |
| 세션 상태 머신 (`active → paused → completed`) | 완료 |
| 위치 스트림 (geolocator, distanceFilter: 5m) | 완료 |
| 앱 재시작 복구 (Active Session Recovery) | 완료 |
| 중복 세션 방지 | 완료 |
| 권한 차단 시 세션 생성 방지 | 완료 |
| 기록 UI (상태, 경과 시간, 포인트 수, 정확도) | 완료 |

### 기술적 결정

- `LocationService`와 `LocationPermissionService`를 기기 API에 의존하지 않도록 래퍼로 분리 → 단위 테스트 가능
- UI는 status-first로 설계. 지도는 나중 스프린트로 미룸
- 포그라운드 기록만 구현. 백그라운드 GPS는 MVP 범위 외

### 필드 스모크 테스트 항목

- 실제 안드로이드 기기에서 기록 시작
- 비행기 모드 전환 후 기록 유지 확인
- 앱 강제 종료 후 재실행 → 세션 복구 확인
- 세션 완료 후 로컬 요약 정보 유지 확인

---

## Sprint 2: 업로드 및 공간 백엔드

**기간**: 2026-05-07  
**계획**: `sprint-2-upload-spatial-backend-plan.md`  
**브랜치**: `feat/sprint-2-upload-backend` → PR #1 병합

### 목표

완료된 오프라인 세션을 Supabase 백엔드에 안전하게 단 한 번 업로드하여 경로 학습 데이터로 만든다.

### 구현 결과

**백엔드 (Supabase)**:

| 기능 | 결과 |
|------|------|
| `upload-session` Edge Function | 완료 |
| GPS 포인트 검증 (`validation.ts`) | 완료 |
| 이중 방지 (`idempotencyKey`) | 완료 |
| `track_points` (PostGIS geography) 저장 | 완료 |
| `rejected_track_points` 저장 (거부 사유 포함) | 완료 |
| 마이그레이션 0001~0004 적용 | 완료 |

**검증 규칙**:
- lat: −90~90, lon: −180~180
- speed > 15m/s → `implausible_speed` 거부
- accuracy > 100m → `low_accuracy` 거부
- sequenceIndex 없거나 중복 → 거부

**모바일**:

| 기능 | 결과 |
|------|------|
| `upload_queue` SQLite DAO | 완료 |
| 업로드 동의 (`beta-upload-consent-v1`) 저장 | 완료 |
| 자동 업로드 on/off 설정 | 완료 |
| 자동 재시도 (10분 간격, 최대 3회) | 완료 |
| 수동 재시도 | 완료 |
| Sessions UI (상태, 수락/거부 포인트 수) | 완료 |

### 검증 결과 (로컬 Supabase)

```
npx supabase start               → 성공
npx supabase db reset (0001~0004) → 성공
npm run test:db                  → 10개 pgTAP 통과
npm run test:functions           → 10개 Deno 테스트 통과

실제 스모크:
- 첫 POST: status: ingested, acceptedPointCount: 1, rejectedPointCount: 1
- 중복 POST: status: duplicate (이중 방지 동작 확인)
- rejected_track_points에 위도 91 (유효 범위 초과) 저장 확인
```

### 기술적 결정

- 프로덕션 인증(Supabase Auth)은 이 스프린트에서 구현하지 않음. 임시 dev user 사용
- 거부 포인트에 원본 좌표 저장 (베타 디버깅 용도, 7일 후 삭제 메타데이터 추가)
- 호스티드 Supabase 배포는 로컬 수집 경로 안정화 이후로 연기

### 기술 이슈

- `flutter test --concurrency=1`이 로컬 쉘에서 실행 전 중단되는 현상 → 로컬 Flutter 테스트 러너 이슈로 기록. Deno/DB 테스트로 대체
- Deno가 PATH에 없어 `npx deno`로 우회

---

## Sprint 3: 기준 경로 및 경로 안내

**기간**: 2026-05-08  
**계획**: `sprint-3-reference-route-guidance-plan.md`  
**커밋**: `4a6ee95 feat: Add Sprint 3 route guidance`

### 목표

반복된 GPS 세션으로 신뢰도 레이블이 붙은 canonical trail을 생성하고, 모바일 앱에서 현재 위치와 경로 거리를 비교한다.

### 구현 결과

**백엔드**:

| 기능 | 결과 |
|------|------|
| Grid-and-Graph 경로 추론 알고리즘 초안 (`route_inference.ts`) | 완료 |
| H3 resolution 11 셀 변환 (`trail_cells`) | 완료 |
| 셀 간 이동 그래프 (`trail_cell_transitions`) | 완료 |
| `canonical_trails` (append-only 버전 저장) | 완료 |
| 신뢰도 계산 (초기 버전) | 완료 |
| `get-canonical-trail` Edge Function | 완료 |
| `snap-position` Edge Function (25m/50m 임계값) | 완료 |
| `recompute-canonical-trails` Edge Function | 완료 |

**모바일**:

| 기능 | 결과 |
|------|------|
| `CanonicalTrailClient` | 완료 |
| `SnapPositionClient` | 완료 |
| Route 탭 UI (경로 상태, 신뢰도, 스냅 결과) | 완료 |

### 기술적 결정

- H3 resolution 11 선택: 셀 엣지 길이 ~24.9m로 산악 트레일 추적에 적합
- `snap_position_to_trail` PostGIS RPC로 서버 측 거리 계산
- `none` / `reference` / `recommended` 3단계 상태 레이블 도입

### 한계

실제 산에서 반복된 GPS 트레이스로 canonical trail을 검증하는 테스트는 실제 기기가 없어 불가. 리플레이 데이터셋으로 대체.

---

## Sprint 4: 베타 하드닝

**기간**: 2026-05-08  
**계획**: `sprint-4-beta-hardening-plan.md`  
**커밋**: `14cf3e7 feat: Add Sprint 4 beta hardening`

### 목표

첫 번째 통제된 베타 빌드에 충분한 신뢰성을 부여한다.

### 구현 결과

| 기능 | 결과 |
|------|------|
| 운영자 읽기 모델 (`operator_route_coverage`) | 완료 |
| 운영자 UI 상태 (no/reference/recommended 커버리지) | 완료 |
| 리플레이 seed 데이터 (경로 추론, 분기 모호성, 스냅 임계값) | 완료 |
| 로컬 Supabase 스모크 스크립트 | 완료 |
| `mvp_events` 구조화 이벤트 (route served, snap requested) | 완료 |

### 기술적 제약

호스티드 Supabase 접속 또는 실제 안드로이드 기기 없이는 스테이징 스모크 테스트 불가 → 다음 스프린트로 연기.

---

## Sprint 5: 필드 테스트 패키지

**기간**: 2026-05-08  
**계획**: `sprint-5-field-test-pack-plan.md`  
**커밋**: `5b02b62 docs: Add Sprint 5 field test pack`

### 목표

실제 기기에서 30분 산행 필드 테스트를 사전 계획 없이도 실행할 수 있도록 체크리스트와 시나리오를 패키징한다.

### 산출물

| 문서 | 내용 |
|------|------|
| `sprint-5-field-test-checklist.md` | 기록 → 업로드 → 재계산 → 안내 → 스냅 전체 체크 |
| `sprint-5-manual-test-scenarios.md` | 비행기 모드, 재시작, 중복 업로드, 낮은 신뢰도 경로, 갈림길 |
| `sprint-5-final-verification-notes.md` | Sprint 3/4/5 출력을 MVP 인수 기준에 연결 |
| `sprint-5-field-test-pack-plan.md` | 로컬 리플레이 README |

### 기술적 제약

30분 안드로이드 필드 테스트는 실제 기기 없이 불가. 이 제약이 이후 스프린트 방향을 결정짓는 분기점.

---

## Sprint 6: 에뮬레이터 베타 준비

**기간**: 2026-05-08  
**계획**: `sprint-6-emulator-beta-readiness-plan.md`  
**커밋**: `c1a3df8 feat: Add Sprint 6 readiness`

### 목표

실제 기기 없이 안드로이드 에뮬레이터에서 전체 업로드-경로-안내 루프를 반복 가능하게 만든다.

### 구현 결과

| 기능 | 결과 |
|------|------|
| `10.0.2.2` (에뮬레이터 → 로컬호스트) 네트워킹 수정 | 완료 |
| `adb reverse` 대안 문서화 | 완료 |
| 에뮬레이터 로컬 스모크 런북 | 완료 |
| 베타 산 커버리지 템플릿 (3개 산 기준) | 완료 |
| `mobile/.env.example` 업데이트 | 완료 |

### 베타 게이트 확인

다음 두 조건 중 하나가 충족되어야 베타 게이트 통과 가능:
1. 호스티드 Supabase 접속 자격증명
2. 실제 안드로이드 기기

이 두 조건이 모두 없는 상태에서 Sprint 9 계획(스테이징/베타 증거)은 조건부로 연기.

---

## 방향 전환: Post-Sprint 6 로드맵

**날짜**: 2026-05-08  
**문서**: `post-sprint-6-priority-roadmap.md`  
**커밋**: `433da6e docs: Add post Sprint 6 priorities`

실제 기기와 스테이징 환경이 없는 상태에서, **로컬 제품 품질 강화**로 방향을 전환.

### 새로운 우선순위

```
P0 지금: 경로 품질 알고리즘 강화 (Sprint 7)
P0 지금: 등산객 경로 안내 UI 개선 (Sprint 8)
P1 지금: 운영자 품질 검토 대시보드 라이브 연동 (Sprint 8/9)
베타 게이트 (차단): 실제 기기 또는 스테이징 접속 시까지 보류
```

---

## Sprint 7: 경로 품질 알고리즘

**기간**: 2026-05-08  
**계획**: `sprint-7-route-quality-algorithm-plan.md`  
**커밋**: `ef3ed80 feat: Add Sprint 7 route quality`

### 목표

실제 기기 필드 테스트 전에 canonical trail 품질과 신뢰도가 과신 없이 설명 가능한 수준으로 만든다.

### 구현 결과

**알고리즘 개선** (`route_inference.ts`):

| 개선 항목 | 내용 |
|-----------|------|
| 셀/전이 지지도 임계값 | minCellPointCount=2, minTransitionCount=1 도입 |
| 고립 셀 제거 | `pruneIsolatedCells`: 연결된 transition 없는 셀 제거 |
| 연결 컴포넌트 선택 | BFS 기반 `selectBestComponent` (점수: Σsession + 0.25×Σpoint + 0.5×sessions) |
| 경로 선택 가중치 | `compareTransitionStrength: sessionCount×10 + transitionCount×3 - edgeCost` |
| 양방향 경로 확장 | `extendPathStart` + `extendPathEnd` (greedy) |

**신뢰도 공식 (6개 항목)** 도입:

```
confidence =
  sessionSupportScore      × 0.35  (min(1, sessionCount/5))
  gpsQualityScore          × 0.20
  transitionConsistency    × 0.15
  (1 - branchAmbiguity)    × 0.15
  (1 - rejectedPointRate)  × 0.10
  recencyScore             × 0.05
```

**`recommended` 조건 강화**:

```
confidence >= 0.70 AND sessionCount >= 5
AND branchAmbiguity <= 0.30 AND gpsQuality >= 0.70
AND rejectedPointRate <= 0.30 AND recencyScore >= 0.50
```

**리플레이 데이터셋 확장**:

| 케이스 | 목적 |
|--------|------|
| 반복 클린 트레이스 | 정상 동작 검증 |
| 단일 희박 트레이스 | sparse 입력 처리 |
| 저정확도 노이즈 트레이스 | GPS 품질 점수 검증 |
| 분기 모호 트레이스 | branchAmbiguity 계산 검증 |
| 오래된 증거 트레이스 | recencyScore 검증 |

---

## Sprint 8: 경로 안내 및 운영자 지도

**기간**: 2026-05-08  
**계획**: `sprint-8-guidance-operator-design-plan.md`  
**커밋**: `c70b47e feat: Add Sprint 8 map guidance`  
**후속**: `4383001 ~ 919267d` (지도 타일, 레이어, UI 수정)

### 목표

등산객 경로 안내와 운영자 품질 검토를 데이터 기반으로, 지도 시각화와 함께 제공한다.

### 지도 SDK 결정

| 서피스 | 선택 | 이유 |
|--------|------|------|
| 운영자 웹 | OpenLayers | GIS 검수, GeoJSON 렌더링, 디버그 오버레이에 적합 |
| 모바일 | flutter_map | 순수 Flutter, OSM 라스터 타일, 위젯 테스트 |
| 3D 지형 (미래) | CesiumJS | 현재는 불필요 |
| 벡터 지도 (미래) | MapLibre | 오프라인 벡터 타일 필요 시 전환 |

### 구현 결과

**모바일 Route 탭**:

| 기능 | 결과 |
|------|------|
| flutter_map 경로 폴리라인 | 완료 |
| OSM 타일 + Esri 위성 레이어 전환 | 완료 |
| no-route/reference/recommended 시각적 구분 | 완료 |
| 신뢰도, 버전, 업데이트 시간, 세션 수 카드 | 완료 |
| 스냅 거리, 판정, 임계값 카드 | 완료 |
| 경로 geometry 파싱 (`[lon, lat]` → `LatLng(lat, lon)`) | 완료 |

**운영자 웹 대시보드**:

| 기능 | 결과 |
|------|------|
| Supabase 라이브 데이터 연동 (정적 픽스처 제거) | 완료 |
| OpenLayers 지도 패널 | 완료 |
| canonical trail GeoJSON 폴리라인 렌더링 | 완료 |
| 경로 상태별 색상 (초록/주황/회색) | 완료 |
| 신뢰도 입력 지표 및 거부 포인트 수 | 완료 |

**웹 UI v2 리디자인**: `fed8fec feat: Update web submodule to v2 UI redesign`

---

## Sprint 9: 세션-경로 귀속 시스템 + 운영자 품질 강화

**기간**: 2026-05-08 ~ 2026-05-09  
**계획**: `sprint-9-operator-quality-hardening-plan.md`  
**커밋**: `8859419 feat: Add Sprint 9 quality hardening`  
**주요 커밋**: `a783715 feat: update web submodule to Sprint 9 hitmap attribution`  
**병합**: `d943ee6 Merge branch 'feat/sprint-9-operator-quality-hardening'`

### 목표

실제 기기와 스테이징 환경이 없는 상태에서, 로컬 베타 판단을 위한 운영자 품질 검토 기반을 구축한다.

이 스프린트는 Sprint 9 계획보다 훨씬 큰 범위인 **세션-경로 귀속(Attribution) 시스템 전체**를 구현했다.

### 구현 결과

**Sprint 9 원래 계획 (운영자 품질 읽기 모델)**:

| 기능 | 결과 |
|------|------|
| `operator_quality_summary` 뷰 | 완료 |
| `operator_route_quality_detail` 뷰 | 완료 |
| Overview 라이브 메트릭 연동 | 완료 |
| Quality 페이지 라이브 신뢰도 상세 | 완료 |
| pgTAP 커버리지 추가 | 완료 |

**실제 구현된 추가 범위 (Attribution + Phase 2 파이프라인)**:

| 마이그레이션 | 내용 |
|-------------|------|
| `0012_session_route_attribution.sql` | `session_route_assignments`, `candidate_cells`, `candidate_cell_transitions`, `route_to_candidate_transitions` 테이블 |
| `0013_match_cron.sql` | pg_cron 15분 스케줄 (`match-and-aggregate-sessions`) |

**`match-and-aggregate-sessions` Edge Function** (핵심):

- `unprocessed_ingested_sessions` 뷰에서 최대 50개 미처리 세션 처리
- H3 셀 변환 + `expandWithGridPath` 보간
- 75m 반경 경로 귀속 또는 `candidate_cells` 누적
- **Transition 4분류**: route-internal / candidate-internal / route-to-candidate / candidate-to-route / cross-route(폐기)
- `accumulate_trail_cells` / `accumulate_candidate_cells` RPC (가중평균 UPSERT)
- `session_route_assignments` 생성 (`contributing_sessions[]` 추적)

**이전 대비 가장 큰 변화**:

Sprint 9 이전에는 기존 경로에 매칭되지 않는 GPS 셀("orphan")이 모두 폐기됐다. 이후 `candidate_cells`에 누적되어 신규 경로 발굴의 원료가 된다.

경로 간 이동(`cross-route`, 분기 신호)도 이전에는 폐기됐으나, 이후 `route_to_candidate_transitions`에 보존되어 분기 감지에 활용된다.

---

## Sprint 10: 경로 탐지 + 분기 감지 + 다중 경로

**기간**: 2026-05-09 ~ 2026-05-10  
**주요 커밋**:

| 커밋 해시 | 날짜 | 내용 |
|-----------|------|------|
| `1f666c4` | 2026-05-09 | `feat: Update web submodule — Sprint 10 Route Discovery` |
| `62699fa` | 2026-05-09 | `feat: Update web submodule — auto route split & branch detection (Phases 1-5 + UI)` |
| `107b3da` | 2026-05-09 | `feat: Update submodules — mountain → route linking` |
| `e6401c2` | 2026-05-09 | `feat: Update submodules — multi-route display and nearest-snap` |
| `2661599` | 2026-05-09 | `feat: Update mobile submodule — map controls (zoom, auto-center, fit-to-routes)` |
| `b3babee` | 2026-05-09 | `feat: mountain list refresh on resume + split name/RLS fixes` |
| `708933c` | 2026-05-09 | `feat: Update mobile submodule — consent sheet + auto-center fix` |
| `f373e33` | 2026-05-09 | `docs: add ROUTE_DECISION_PROCESS.md + update web submodule` |
| `eda7b97` | 2026-05-10 | `feat: Update mobile submodule — session delete + details route map` |
| `28ab377` | 2026-05-10 | `fix: Update mobile submodule — location permission in Route tab` |
| `624b430` | 2026-05-10 | `feat: Update mobile submodule — fix test API drift` |
| `0397add` | 2026-05-10 | `feat: Update web submodule — GPX test tracks + simplified KML` |

### 목표

candidate 셀을 신규 경로로 승격하고, 분기를 자동 감지해 경로를 분할하며, 한 산의 여러 경로를 동시에 표시한다.

### 구현 결과

**백엔드**:

| 기능 | 마이그레이션/파일 | 내용 |
|------|-----------------|------|
| `split_route_atomic` RPC | `0022_split_route_atomic.sql` | 단일 트랜잭션으로 경로 분할 |
| `evaluate-route-splits` Edge Function | - | 분기 감지 + 자동/수동 분할 |
| pg_cron 1시간 스케줄 | `0023_split_cron.sql` | evaluate-route-splits 자동 실행 |
| `promote-candidate-cluster` Edge Function | - | candidate → 신규 경로 승격 |
| `route_split_audit` 테이블 | - | dry-run 기록 |
| `route_split_detection.ts` | `_shared/` | 분기 감지 알고리즘 |
| `accumulate_trail_cells` / `accumulate_candidate_cells` RPC | `0021_split_rpcs.sql` | 가중평균 UPSERT |

**분기 감지 조건** (`route_split_detection.ts`):

```
cfgConfidence >= 0.50
crossBranchRatio >= 0.30
clusterSessionCount >= 2
minSegmentCells >= 3
```

**Bootstrap 메커니즘**:

운영자가 `trail_cells`가 비어 있는 경로를 사전 생성해 두면, 첫 번째 세션의 셀이 자동으로 그 경로에 귀속된다. Discovery 페이지에서 candidate 클러스터 확인 → "Create Route" 클릭으로도 동일한 효과.

**모바일**:

| 기능 | 내용 |
|------|------|
| 다중 경로 동시 표시 (신뢰도 색상 구분) | 완료 |
| 자동 최근접 경로 선택 (`nearest-snap`) | 완료 |
| 지도 컨트롤 (줌 인/아웃, 자동 중심, fit-to-routes) | 완료 |
| 세션 삭제 (스와이프) | 완료 |
| 세션 상세 화면 경로 지도 | 완료 |
| 동의 시트(consent sheet) | 완료 |
| Route 탭 위치 권한 처리 수정 | 완료 |
| mountain → route 연결 구조 | 완료 |

**운영자 웹**:

| 기능 | 내용 |
|------|------|
| Discovery 페이지 (candidate 클러스터, 분기 힌트) | 완료 |
| "Create Route" 버튼 (promote-candidate-cluster) | 완료 |
| "Execute split" 버튼 (split_route_atomic) | 완료 |
| 경로 이름 변경 (operator route rename) | 완료 |
| GPX 테스트 트랙 + KML 시각화 | 완료 |

**문서**:

- `ROUTE_DECISION_PROCESS.md` 작성 (경로 결정 파이프라인 전체 설명)

---

## 현재 시스템 상태 (2026-05-10 기준)

### 구현 완료된 기능

| 레이어 | 기능 |
|--------|------|
| **모바일** | 오프라인 GPS 기록, 세션 복구, 업로드 큐, 경로 안내, 다중 경로 표시, snap-position, 세션 관리 |
| **백엔드** | GPS 검증, 업로드, H3 셀 귀속, candidate 누적, Transition 4분류, canonical trail 추론, 분기 감지, 경로 분할, 신뢰도 계산 |
| **운영자** | 전체 6개 페이지 라이브 데이터 연동, 지도 시각화, Discovery + 분기 분할 UI |

### 스케줄러

| 함수 | 간격 | 역할 |
|------|------|------|
| `match-and-aggregate-sessions` | 15분 | 세션 처리 + 경로 추론 |
| `evaluate-route-splits` | 1시간 | 분기 감지 + 자동 분할 |

### 미완료 / 제약

| 항목 | 상태 |
|------|------|
| 실제 안드로이드 기기 필드 테스트 | 미실행 (기기 없음) |
| 호스티드 Supabase 스테이징 배포 | 미실행 |
| Supabase Auth (실제 사용자 인증) | 미구현 (임시 dev user 사용) |
| route_inference.ts 단위 테스트 | 없음 |
| GPS 이동 평균 필터 | 미구현 |
| GPX seed 데이터 import | 미구현 |

---

## 주요 기술 결정 이력

| 시점 | 결정 | 이유 |
|------|------|------|
| Sprint 0 | Flutter + Supabase 재시작 (Firebase 폐기) | Supabase의 PostGIS + Edge Functions 통합 강점 |
| Sprint 1 | `LocationService` 래퍼 분리 | 기기 API 의존 없이 단위 테스트 가능 |
| Sprint 2 | 임시 dev user (Supabase Auth 미구현) | 인증 작업 없이 업로드 경로 검증 집중 |
| Sprint 2 | 거부 포인트 원본 좌표 저장 | 베타 디버깅 지원 (7일 보존 후 삭제) |
| Sprint 3 | H3 resolution 11 선택 | ~24.9m 셀로 산악 트레일 추적 정밀도 최적 |
| Sprint 6 | `10.0.2.2` 에뮬레이터 네트워킹 | `adb reverse` 없이 에뮬레이터 테스트 가능 |
| Sprint 7 | BFS 연결 컴포넌트 + 가중 경로 선택 | 탐욕적 경로만으로 생기는 노이즈 셀 포함 문제 해결 |
| Sprint 8 | OpenLayers (웹) + flutter_map (모바일) | 오픈소스, 라이선스 무료, GeoJSON 지원 |
| Sprint 9 | Transition 4분류 (cross-route 폐기 → 분류 보존) | 분기 신호 유실 문제 해결 |
| Sprint 10 | `split_route_atomic` 단일 트랜잭션 | 경로 분할 시 데이터 일관성 보장 |

---

## 남은 과제 (우선순위 순)

1. **GPX seed 데이터 import** — 콜드 스타트 해결, 운영자 GPX 업로드 기능
2. **`route_inference.ts` 단위 테스트** — 핵심 알고리즘 회귀 방지 (24KB, 테스트 없음)
3. **실제 안드로이드 기기 필드 테스트** — 베타 게이트 조건
4. **snap-position 이동 평균 필터** — GPS 오차 한계 완화
5. **Supabase Auth 구현** — 다중 사용자 세션 분리
6. **호스티드 Supabase 배포** — 외부 사용자 베타 테스트 가능
