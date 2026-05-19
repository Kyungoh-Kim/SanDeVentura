# SanDeVentura — 아키텍처

## 시스템 전체 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                        SanDeVentura 모노레포                      │
│  (부모 레포: submodule 포인터 + 문서 + CI 관리)                   │
│                                                                  │
│  ┌─────────────────────┐    ┌──────────────────────────────────┐ │
│  │  mobile/ (submodule) │    │    web/ (submodule)              │ │
│  │  Flutter Android-first│   │  React + Supabase Backend        │ │
│  └─────────────────────┘    └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. 모바일 레이어 (Flutter)

### 아키텍처 패턴: Feature-first + Layered

```
lib/
├── main.dart                  # 진입점, DI 초기화
├── app/                       # 앱 셸, 라우팅, 의존성 주입
└── features/                  # 기능 모듈 (수직 분리)
    ├── mountains/             # 산 선택 (get-mountains 연동)
    ├── recording/             # 오프라인 GPS 세션 기록
    ├── sync/                  # 업로드 큐 관리 및 UI
    └── trails/                # 경로 안내 (snap-position 연동)

shared/
├── db/                        # SQLite DAOs (sessions, track_points, upload_queue)
├── domain/                    # 엔티티, geo 계산, Result 타입
├── location/                  # 권한 관리, GPS 서비스 래퍼
└── widgets/                   # 공유 UI 컴포넌트
```

### 핵심 기술 스택

| 레이어 | 기술 | 역할 |
|---|---|---|
| UI | Flutter 3.11.5 | 크로스플랫폼 UI |
| 지도 | flutter_map 8.3.0 + latlong2 | 지도 렌더링 |
| 위치 | geolocator 14.0.2 | GPS 수신 |
| 로컬 DB | sqflite (SQLite) | 오프라인 세션 저장 |
| 네트워크 | connectivity_plus 6.0.0 | 연결 상태 감지 |
| 백엔드 통신 | HTTP → Supabase Edge Functions | 업로드/조회 |

### 오프라인-퍼스트 설계

```
GPS 수신 ──→ SQLite (로컬) ──→ 업로드 큐 ──→ Edge Function (온라인 시)
                  ↑
            앱 재시작 시 세션 복구 (Active Session Recovery)
```

---

## 2. 백엔드 레이어 (Supabase)

### 아키텍처 패턴: Serverless + PostgreSQL-centric

```
Supabase Platform
├── PostgreSQL 15 + PostGIS    # 지리공간 데이터베이스
├── Edge Functions (Deno)      # 비즈니스 로직 서버리스 함수
├── Supabase Auth              # 사용자 인증 (MVP: JWT 검증 비활성화)
└── REST API                   # 자동 생성 CRUD API
```

### Edge Functions 구조

```
supabase/functions/
├── upload-session/            # 세션 수집 + 포인트 검증
├── snap-position/             # 실시간 경로 위치 스냅
├── get-canonical-trail/       # 기준 경로 geometry 반환
├── get-mountains/             # 산 목록 반환
├── recompute-canonical-trails/# 경로 재추론 트리거
├── match-and-aggregate-sessions/ # 세션-경로 매칭 + 경로 갱신
└── _shared/
    ├── route_inference.ts     # 핵심 grid-and-graph 알고리즘 (24KB)
    ├── validation.ts          # 포인트 검증 로직
    └── response.ts            # JSON 응답 포맷터
```

### 데이터베이스 스키마 (14 마이그레이션)

```
mountains ──────────────────────────┐
                                    │
hiking_sessions ─────────────────── │ ─── route_quality_inputs
    │                               │           │
track_points (PostGIS)              │    operator_quality_views
    │                               │
rejected_track_points               ▼
                               routes ──────── canonical_trails
                                   │               │
                               trail_cells ── trail_cell_transitions
```

**주요 테이블 역할:**

| 테이블 | 역할 |
|---|---|
| `mountains` | 산 레지스트리 (이름, 출처) |
| `hiking_sessions` | 세션 메타데이터 + 업로드 동의 |
| `track_points` | GPS 포인트 (PostGIS geometry) |
| `rejected_track_points` | 거부 포인트 + 거부 사유 |
| `routes` | 산-경로 매핑 |
| `canonical_trails` | 추론된 기준 경로 LineString |
| `trail_cells` | H3 그리드 셀 |
| `trail_cell_transitions` | 셀 간 이동 그래프 엣지 |
| `route_quality_inputs` | 경로 신뢰도 입력 지표 |
| `operator_quality_views` | 대시보드 읽기 모델 |

### 핵심 알고리즘: Grid-and-Graph Route Inference

```
GPS 포인트들 (track_points)
    │
    ▼
H3 육각형 셀 매핑 (trail_cells)
    cellKey = latLngToCell(lat, lon, resolution=11)  ← npm:h3-js
    셀 특성: 엣지 길이 ~24.9m, 전방향 이웃 거리 균일 (6방향)
    │
    ▼
셀 간 이동 → 방향 그래프 (trail_cell_transitions)
    │   └── 엣지 가중치 = 1 / transitionCount (적게 통과할수록 비용 큼)
    │
    ▼
최빈 경로 추출 (가중치 기반 greedy path extension)
    │   startEdge = 가장 강한 전이(sessionCount × 10 + transitionCount)
    │   양방향으로 인접 엣지를 탐욕적으로 확장
    │
    ▼
LineString 생성 → canonical_trails 저장
    │
    ▼
신뢰도 점수 = 세션수(35%) + GPS품질(20%) + 전이일관성(15%)
             + 분기모호성(15%) + 거부율(10%) + 최신성(5%)
```

---

## 3. 웹 레이어 (React 운영자 대시보드)

### 아키텍처 패턴: Page-based + Repository 패턴

```
src/
├── main.tsx                   # 진입점
└── operator/
    ├── OperatorApp.tsx        # 앱 셸 + 내비게이션
    ├── pages/                 # 대시보드 페이지
    │   ├── OverviewPage.tsx   # 요약 지표
    │   ├── MountainsPage.tsx  # 산별 커버리지
    │   ├── RoutesPage.tsx     # 경로 상세
    │   ├── SessionsPage.tsx   # 세션 히스토리
    │   └── QualityPage.tsx    # 품질 디버깅
    ├── data/                  # 데이터 접근 레이어
    │   ├── supabaseClient.ts  # Supabase 클라이언트
    │   ├── readModels.ts      # 읽기 모델 쿼리
    │   ├── routesRepository.ts
    │   ├── mountainsRepository.ts
    │   └── operationsRepository.ts
    └── components/
        └── OperatorRouteMap.tsx # OpenLayers 지도 컴포넌트
```

### 기술 스택

| 레이어 | 기술 | 역할 |
|---|---|---|
| UI | React 19.0.0 + TypeScript 5.8.0 | 컴포넌트 UI |
| 빌드 | Vite 7.0.0 | 번들링/개발 서버 |
| 지도 | OpenLayers 10.9.0 | 경로 geometry 시각화 |
| 데이터 | @supabase/supabase-js v2 | DB 직접 쿼리 |

---

## 4. 모노레포 구조와 Git 전략

```
SanDeVentura (부모 레포)
├── .gitmodules               # submodule 등록
├── mobile → (submodule)      # 별도 git 히스토리 관리
├── web → (submodule)         # 별도 git 히스토리 관리
└── documents/                # SDD, PRD, 스프린트 계획, 프레젠테이션
```

**브랜치 전략:**
- `feat/sprint-N-<설명>` 브랜치에서 기능 개발
- PR → `main` 병합
- 부모 레포: submodule 포인터 업데이트로 릴리스 버전 고정

---

## 5. 배포 아키텍처

```
[Local Dev]
    Supabase CLI (포트 54321–54323)
    Flutter 에뮬레이터 (10.0.2.2) / 실물 기기 (127.0.0.1)
    Vite 개발 서버

[Production (예정)]
    Supabase Cloud → PostgreSQL + Edge Functions 호스팅
    Flutter APK → Android 배포
    웹 대시보드 → 정적 호스팅 (Vercel 등)
```

---

## 6. 설계 원칙 요약

| 원칙 | 적용 방식 |
|---|---|
| 오프라인-퍼스트 | SQLite 로컬 저장 + 업로드 큐 |
| 프라이버시 중심 | 운영자는 raw 경로 열람 불가, 집계 지표만 노출 |
| 점진적 신뢰도 | 세션이 쌓일수록 canonical trail 품질 향상 |
| 최소 의존성 MVP | Supabase 단일 백엔드로 DB+Auth+함수+스토리지 통합 |
| 지리공간 우선 | PostGIS 기반 거리 계산, H3 그리드 셀 기반 경로 추론 |
