# SanDeVentura — 워크플로우

## 개요

SanDeVentura의 핵심 워크플로우는 **"GPS 흔적 수집 → 노이즈 제거 → 경로 추론 → 사용자 피드백"** 의 사이클로 구성됩니다. 사용자가 등산을 반복할수록 기준 경로의 신뢰도가 높아지는 누적 학습 구조입니다.

---

## 1. 등산 세션 기록 워크플로우 (모바일)

```
[앱 실행]
    │
    ▼
[산 선택] ─── get-mountains Edge Function 호출 → 산 목록 반환
    │
    ▼
[기록 시작] ─── SQLite에 세션 row 생성 (상태: recording)
    │
    ▼
[GPS 포인트 수집] (오프라인 동작)
    │   ├── geolocator로 위치 수신
    │   ├── 정확도(accuracy), 속도(speed), 고도(altitude) 기록
    │   └── SQLite track_points 테이블에 로컬 저장
    │
    ▼
[앱 종료/재시작 발생 시]
    │   └── SQLite에서 미완료 세션 복구 (Active Session Recovery)
    │
    ▼
[기록 종료] ─── 세션 상태 → completed
    │
    ▼
[업로드 큐 진입] ─── sync 기능으로 대기
```

---

## 2. 세션 업로드 워크플로우

```
[업로드 시도] (네트워크 연결 시)
    │
    ▼
[upload-session Edge Function 호출]
    │
    ├── [포인트 검증] ─ validation.ts
    │       ├── 정확도 임계값 필터링
    │       ├── 속도 이상치 제거
    │       └── 실패 포인트 → rejected_track_points 저장 (rejection_reason 포함)
    │
    ├── [검증 통과 포인트] → track_points (PostGIS geography 컬럼) 저장
    │
    └── [세션 메타데이터] → hiking_sessions 저장
            ├── 업로드 동의 여부 기록
            └── 상태: uploaded
```

---

## 3. 경로 추론 워크플로우 (백엔드)

```
[match-and-aggregate-sessions Edge Function 호출]
    │   (스케줄러(cron) 또는 수동 트리거)
    │
    ▼
[세션-경로 매칭] (migration 0012 로직)
    │   └── GPS 포인트들을 기존 route geometry에 매핑
    │
    ▼
[grid-and-graph 알고리즘] ─── route_inference.ts (24KB)
    │   ├── 좌표를 H3 육각형 셀(trail_cells)로 변환 (resolution 11, ~25m 엣지)
    │   ├── 셀 간 이동을 그래프 엣지(trail_cell_transitions)로 구성
    │   └── 가장 많이 통과된 경로를 canonical trail로 선정
    │
    ▼
[canonical_trails 업데이트]
    │   ├── LineString geometry 갱신
    │   ├── 신뢰도(confidence) 재계산
    │   └── 버전(version) 증가
    │
    ▼
[route_quality_inputs 갱신]
    │   ├── 누적 포인트 수
    │   ├── 참여 세션(unique sessions) 수
    │   └── 평균 정확도 지표
    │
    ▼
[operator_quality_views 갱신] ─── 운영자 대시보드 읽기 모델
```

---

## 4. 등산 중 경로 안내 워크플로우 (실시간)

```
[등산 중 갈림길 접근]
    │
    ▼
[snap-position Edge Function 호출]
    │   └── 현재 좌표 → 기준 경로와의 최근접 거리 계산 (PostGIS)
    │
    ├── 거리 ≤ 25m → "경로 위" 상태 반환
    ├── 거리 25–50m → "경로 근처" 경고 반환
    └── 거리 > 50m → "경로 이탈" 경보 반환
            │
            ▼
        [모바일 UI에 상태 표시] ─── 색상/알림으로 사용자에게 피드백
```

---

## 5. 운영자 모니터링 워크플로우 (웹 대시보드)

```
[운영자 대시보드 접속]
    │
    ▼
[Overview] ─── 세션 수, 경로 수, 포인트 수 요약
    │
    ├── [Mountains] ─── 산별 커버리지 현황
    │
    ├── [Routes] ─── 경로 상세 및 geometry 지도 시각화 (OpenLayers)
    │
    ├── [Sessions] ─── 업로드 히스토리, 세션별 품질 신호
    │
    └── [Quality] ─── route_quality_inputs 기반 신뢰도 디버깅
                  ├── 참여 세션 수
                  ├── 포인트 밀도
                  └── 거부 포인트 비율
```

---

## 6. 개발 워크플로우

```
[로컬 개발]
    │
    ├── Supabase CLI로 로컬 DB/함수 구동 (포트 54321–54323)
    ├── Flutter 에뮬레이터 (10.0.2.2) 또는 실물 기기 (127.0.0.1)
    └── Vite 개발 서버로 웹 대시보드 구동
    │
    ▼
[Git 브랜치 전략]
    │   ├── feat/sprint-N-... 브랜치에서 개발
    │   ├── PR을 통해 main 브랜치에 병합
    │   └── 부모 레포에서 submodule 포인터 업데이트 커밋
    │
    ▼
[커밋 컨벤션] ─── AGENTS.md 규칙
        format: <type>: <subject> (50자 이하, 영어, 명령형)
        types: feat / fix / build / chore / ci / docs / style / refactor / test / release
```

---

## 데이터 흐름 요약

```
사용자 GPS 흔적
    → [모바일 SQLite] (오프라인 버퍼)
        → [upload-session] (검증 + 저장)
            → [match-and-aggregate-sessions] (경로 추론)
                → [canonical_trails] (기준 경로 갱신)
                    → [snap-position] (실시간 안내)
                    → [operator dashboard] (품질 모니터링)
```
