# Implementation Plan: SanDeVentura MVP

**Branch**: `001-sandeventura-mvp` | **Date**: 2026-05-04 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/001-sandeventura-mvp/spec.md`; product PRD from `prd.md`; tech stack recommendation from `docs/minimal-tech-stack-recommendation.md`

## Summary

Build a solo-developer, Android-first MVP that proves the end-to-end safety loop: offline hike recording, session recovery, idempotent upload, accepted-point storage, no-base-trail reference route generation, confidence labeling, and current-position-to-route comparison.

Use Flutter + local SQLite on mobile, Supabase Auth/Postgres/PostGIS for backend state and spatial operations, and Supabase Edge Functions for ingestion and route APIs. Keep route inference transparent and deterministic with grid/cell aggregation plus session transition graph extraction before introducing more advanced models.

## Technical Context

**Language/Version**: Dart/Flutter stable channel for mobile; TypeScript on Deno runtime for Supabase Edge Functions; SQL/PLpgSQL for database and PostGIS routines  
**Primary Dependencies**: Flutter SDK, SQLite package for Flutter, device location plugin, Supabase Flutter client, Supabase CLI, Deno, Postgres/PostGIS, pgTAP  
**Storage**: Local SQLite for offline mobile state; Supabase Postgres with PostGIS for remote sessions, points, canonical trails, confidence, and metrics  
**Testing**: Flutter unit/widget/integration tests; Deno tests for Edge Functions; pgTAP for database constraints/functions; Supabase local stack for contract and integration tests  
**Target Platform**: Android-first beta; iOS kept structurally possible but not targeted for first beta  
**Project Type**: Mobile app + Supabase backend + database migrations + Edge Functions  
**Performance Goals**: Offline session recording must continue for at least 30 minutes; canonical-trail lookup and snap-position should feel interactive in beta; upload should be asynchronous and retryable  
**Constraints**: Offline-first; no raw path sharing; confidence must prevent false certainty; no custom backend server in MVP; no social/community features  
**Scale/Scope**: Solo-developer MVP; three beta mountains; small beta user group; route inference optimized for correctness and inspectability over scale

## Tooling Plan

### Coding

- **Codex**: primary SDD-driven implementation assistant for planning, code review, and task execution.
- **VS Code or Android Studio**: Flutter editing, emulator/device control, breakpoints, and project navigation.
- **Flutter CLI**: `flutter create`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`.
- **Supabase CLI**: local Supabase stack, migrations, Edge Function serve/deploy, local database tests.
- **Deno CLI**: Edge Function type checking, linting, formatting, and function-level tests.
- **SQL editor**: Supabase Studio or local DB client for inspecting Postgres/PostGIS tables and query plans.

### Debugging

- **Flutter DevTools**: widget rebuilds, performance, memory, logging, and network inspection during mobile flows.
- **Android Emulator + one real Android device**: emulator for fast iteration; real device for GPS/session-recovery field validation.
- **Supabase local Studio**: inspect local Auth, tables, rows, functions, rejected points, and canonical trails.
- **PostGIS SQL probes**: inspect geometries, nearest-line distances, cell aggregation outputs, and graph intermediate tables.
- **Structured logs**: mobile session state logs, Edge Function request IDs, idempotency key logs, accepted/rejected point summaries.

### Testing

- **Flutter unit tests**: local session state machine, upload queue, distance calculations, confidence display rules.
- **Flutter widget tests**: recording state UI, route-state labels, permission blockers, upload status.
- **Flutter integration tests**: start/stop session, app restart recovery, offline-to-online upload with local Supabase.
- **Deno tests**: Edge Function validation, idempotency, response shape, error handling.
- **pgTAP tests**: database constraints, RLS basics, PostGIS function behavior, confidence threshold rules.
- **Manual field tests**: airplane mode 30-minute recording, force-close recovery, actual GPS noise validation.

## Constitution Check

*GATE: Must pass before implementation.*

- **Hiking Safety First**: Pass. Feature order prioritizes offline recording, confidence, and fork guidance over social features.
- **Offline-First Field Reliability**: Pass. First development slice is local recording and restart recovery.
- **Location Privacy and Data Minimization**: Pass. `privacy-retention.md` defines MVP upload consent, data minimization, retention defaults, event payload limits, and access-control expectations. Data model and RLS must implement those rules before beta.
- **Testable Requirements Before Implementation**: Pass. P0 user stories have independent tests and acceptance scenarios.
- **Technology-Neutral Spec, Explicit Technical Plan**: Pass. `spec.md` stays technology-neutral; this `plan.md` owns stack decisions.

## Project Structure

### Documentation

```text
specs/001-sandeventura-mvp/
├── plan.md
├── prd.md
├── spec.md
├── architecture.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── api-contract.md
└── checklists/
    └── requirements.md
```

### Source Code

```text
apps/mobile/
├── lib/
│   ├── app/
│   ├── features/recording/
│   ├── features/sync/
│   ├── features/trails/
│   ├── shared/db/
│   └── shared/location/
├── test/
└── integration_test/

supabase/
├── migrations/
├── functions/
│   ├── upload-session/
│   ├── get-canonical-trail/
│   ├── snap-position/
│   └── recompute-canonical-trails/
└── tests/
```

**Structure Decision**: Use a monorepo containing the Flutter app and Supabase backend. This keeps migrations, Edge Functions, and mobile contracts versioned together and is simpler than separate repositories for a solo MVP.

## Development Sequence and Timeline

Assumption: one developer, 5 focused development days per week, 6 productive engineering hours per day, 20% buffer included in estimates. Total expected duration: **35 working days** (about 7 calendar weeks).

### Phase 0 - Project Setup and Baseline Contracts (3 days)

- Create monorepo skeleton: `apps/mobile`, `supabase`, shared docs.
- Initialize Flutter app and Supabase local project.
- Enable PostGIS and pgTAP in migrations.
- Add CI/check scripts for analyze/test/lint.
- Define initial API contract files and local environment quickstart.

**Exit criteria**: app boots, Supabase local stack starts, empty tests run, migrations apply locally.

### Phase 1 - Offline Recording and Local Recovery (7 days)

- Implement local SQLite schema for active session, track points, completed sessions, and upload queue.
- Implement start/pause/resume/finish session state machine.
- Integrate foreground location recording.
- Persist points while offline.
- Restore active session after app restart.
- Add permission/service blocker states.

**Exit criteria**: 30-minute airplane-mode recording can survive app restart on emulator and one real Android device.

### Phase 2 - Upload, Validation, and Remote Storage (7 days)

- Implement Supabase Auth baseline.
- Implement `upload-session` Edge Function.
- Add idempotency key handling.
- Add upload consent version handling.
- Validate coordinates, timestamps, accuracy, speed, elevation jumps, and isolated points.
- Store sessions, accepted points, rejected point summaries, and MVP events.
- Add RLS policies that prevent raw trace access across users.
- Add local upload retry queue.

**Exit criteria**: completed offline session uploads once; repeated upload attempts do not duplicate contribution; accepted/rejected point counts are returned.
Privacy exit criteria: upload without consent is rejected; users cannot read another user's raw sessions or track points through client-accessible policies.

### Phase 3 - No-Base-Trail Route Inference (8 days)

- Create point-to-cell aggregation tables or routines.
- Implement H3 or fixed-grid decision from research; default to fixed grid if H3 adds setup risk.
- Build session transition graph from ordered cell sequences.
- Prune low-support nodes/edges.
- Extract largest connected component and strongest path.
- Store canonical LineString, version, confidence inputs, and recommendation status.
- Add operator/debug SQL views for route quality.

**Exit criteria**: a beta mountain can move from no route to reference route based on repeated traces; ambiguous branches lower confidence.

### Phase 4 - Guidance UI and Position Comparison (5 days)

- Implement `get-canonical-trail`.
- Implement `snap-position`.
- Build mobile trail status UI: no route, reference route, recommended route.
- Display current distance/on-route judgment.
- Add confidence wording and route freshness.

**Exit criteria**: user can request a canonical trail and compare current position against it.

### Phase 5 - Beta Hardening and Field Test Pack (5 days)

- Add integration tests for the full local loop.
- Add beta seed data and replay scripts.
- Add logging and metric summaries.
- Run real-device field test.
- Fix critical failure cases: lost session, duplicate upload, misleading route status.

**Exit criteria**: first beta build is ready for three selected mountains.

## Feature Priority

Use MoSCoW for release scope and ICE for sequence inside each phase. P0 features are ordered by dependency and user value:

1. Offline recording
2. Session restoration
3. Idempotent upload
4. Point validation
5. Remote accepted-point storage
6. No-base-trail reference route generation
7. Confidence labeling
8. Position comparison
9. Minimal operator metrics

Do not start route inference before upload and accepted-point persistence are working. Do not start route guidance UI before canonical trail retrieval and snap-position contracts are testable.

## Sprint Plan

### Sprint 1 - Field Recording Foundation (10 working days)

**Sprint Goal**: A user can record and recover a local hiking session without network access.  
**Committed scope**: Phase 0 + Phase 1.  
**Buffer**: 1 day inside sprint.

### Sprint 2 - Upload and Spatial Backend (10 working days)

**Sprint Goal**: Completed offline sessions upload once and become validated spatial evidence.  
**Committed scope**: Phase 2 + first two days of Phase 3.  
**Buffer**: 1 day inside sprint.

### Sprint 3 - Reference Route and Guidance (10 working days)

**Sprint Goal**: Repeated traces produce a confidence-labeled reference route and current-position comparison.  
**Committed scope**: remainder of Phase 3 + Phase 4.  
**Buffer**: 1 day inside sprint.

### Sprint 4 - Beta Hardening (5 working days)

**Sprint Goal**: Prepare a field-testable beta build with logs, replay data, and critical failure fixes.  
**Committed scope**: Phase 5.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| GPS noise creates false route candidates | Misleading guidance | Keep low-confidence routes as reference; expose rejected counts and branch ambiguity |
| Local Supabase differs from hosted Supabase | Integration surprises | Test locally first, then run a staging smoke test before beta |
| Edge Function auth/idempotency bugs | Duplicate or failed uploads | Add Deno tests and replay tests for repeated requests |
| Route inference takes longer than expected | Schedule slip | Ship manual/semi-manual recompute first; postpone advanced smoothing |
| Background location constraints | Recording gaps | MVP uses foreground recording first; background mode is future scope unless field tests require it |
| Solo developer overload | Quality risk | Preserve 20% buffer and avoid P1/P2 until P0 field loop passes |

## Complexity Tracking

No constitution violations are accepted for MVP. Complexity intentionally stays low:

- One mobile app.
- One backend platform.
- One geospatial database.
- Four Edge Functions.
- Deterministic route inference before advanced models.
