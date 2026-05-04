# Notion Source Summary

**Source**: SanDeVentura - 산드벤처 page and child pages read from Notion during the SDD preparation session.  
**Role**: Historical source material only. The authoritative baseline is now the Spec Kit Markdown in this repository.

## Source Pages Used

- SanDeVentura - 산드벤처
- SanDeVentura 문서 인덱스 (PM Review)
- 개발 배경
- 기획
- 주요기능 초안
- SanDeVentura MVP 기획 초안 (최소 스펙)
- 요구사항정의서 (MVP)
- 설계 및 수학모델 결정안 (MVP)
- OpenAPI 계약서 초안 (MVP)
- MVP 실행 백로그 (2주/4주)
- Acceptance Criteria (MVP)
- User Stories (MVP)

## Product Problem Extracted

SanDeVentura addresses hiking uncertainty at trail forks, especially on small mountains or informal paths where existing map data is weak. The motivating scenarios are wrong turns, unreliable phone network coverage, and the need for guidance based on accumulated real hiking traces rather than only official trail data.

## MVP Inputs Carried Forward

- Offline hiking route recording while network access is unavailable.
- Session recovery after app restart or interruption.
- Upload of completed sessions when connectivity returns.
- Validation and filtering of invalid or implausible track points.
- Generation and retrieval of one canonical representative trail per mountain.
- Confidence score in the range 0.00 to 1.00, with 0.70 as the recommended-route threshold.
- Current-position comparison to the canonical trail for fork/branch decisions.
- MVP operational events: session_started, session_uploaded, trail_served, snap_requested.

## Decisions Changed During SDD Baseline

- Earlier draft technologies such as Spring Boot, PostgreSQL/PostGIS, MapLibre, OSM offline tiles, Firebase, and Flutter prototype behavior are not fixed in `spec.md`.
- The implementation stack will be selected later in `/speckit.plan` after research and comparison.
- Existing Flutter/Firebase code is considered discarded and does not define requirements.
- Notion is no longer the master document.

## Explicitly Deferred

- Real-time rescue or command-center functionality.
- Photo-based automatic terrain recognition.
- Community, group planning, ranking, mileage, or social feed features.
- Launch marketing, go-to-market planning, pricing, positioning, and growth loops.
- Exact API contracts, database schema, route-processing algorithm, map provider, and batch cadence.

## Clarifications Recorded in Spec

- `mountainId` is an internal stable MVP identifier; public data keys may be mapped later.
- Upload idempotency is required through a stable client-generated session key or equivalent mechanism.
- Confidence >= 0.70 means "recommended route"; lower confidence is "reference route" or not recommended.
- Beta validation requires at least three selected mountains, but the exact list is outside this baseline.
