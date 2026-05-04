# Development Execution Plan

**Project**: SanDeVentura MVP  
**Purpose**: Practical engineering plan for coding, debugging, implementation, testing, feature order, and timeline  
**Source Methods**: Spec Kit `plan` workflow; PM Skills `sprint-plan` and prioritization guidance  
**Estimated Duration**: 35 working days for one developer

## Tool Decisions

| Area | Tool | Why |
|------|------|-----|
| Coding assistant | Codex | SDD-aware planning, implementation support, review |
| Mobile IDE | VS Code or Android Studio | Flutter editing, emulator/device debugging |
| Mobile framework | Flutter | Single Android-first codebase, iOS possible later |
| Local mobile storage | SQLite | Offline session persistence and recovery |
| Backend platform | Supabase | Auth, Postgres, Edge Functions, local development |
| Geospatial database | Postgres + PostGIS | Spatial storage, indexes, distance/nearest-route queries |
| Backend functions | Supabase Edge Functions + Deno | Small authenticated API surface |
| DB testing | pgTAP via Supabase CLI | Database constraints and spatial function tests |
| Mobile debugging | Flutter DevTools | UI/performance/memory/log inspection |
| Field testing | Real Android device | Actual GPS, airplane mode, app restart behavior |

> Current implementation stage: SDD and architecture planning are complete enough to start a fresh implementation. The old Flutter/Firebase prototype is discarded. The next executable step is monorepo creation, followed by Sprint 1: Flutter app setup, SQLite local session schema, foreground location recording, and app restart recovery.

## Development Order

1. Build local/offline recording before any backend work.
2. Add session restoration before upload.
3. Add idempotent upload before route inference.
4. Add upload consent and privacy/RLS checks before remote raw point storage.
5. Add point validation before canonical trail generation.
6. Add no-base-trail inference before route UI.
7. Add confidence labels before any "recommended" route wording.
8. Add position comparison after canonical trail retrieval works.
9. Add operator metrics after the P0 user loop is testable.

## Timeline

| Phase | Days | Output |
|-------|------|--------|
| 0. Setup and contracts | 3 | Monorepo, Flutter app, Supabase local stack, migrations baseline |
| 1. Offline recording | 7 | Local session state machine, SQLite persistence, restart recovery |
| 2. Upload and validation | 7 | Auth, Edge Function ingestion, idempotency, accepted/rejected points |
| 3. Route inference | 8 | Cell aggregation, transition graph, canonical route, confidence |
| 4. Guidance UI | 5 | Route state display, snap-position, distance/on-route result |
| 5. Beta hardening | 5 | Integration tests, field test pack, logs, critical fixes |

Total: **35 working days**.

## Sprint Plan

### Sprint 1: Field Recording Foundation

- Duration: 10 working days
- Goal: record and recover a local hiking session without network access
- Scope: setup, contracts, SQLite schema, recording state machine, location capture, restart recovery

### Sprint 2: Upload and Spatial Backend

- Duration: 10 working days
- Goal: completed offline sessions upload once and become spatial evidence
- Scope: Supabase Auth, upload-session, validation, idempotency, remote storage, first route aggregation spike

### Sprint 3: Reference Route and Guidance

- Duration: 10 working days
- Goal: repeated traces produce a confidence-labeled route and current-position comparison
- Scope: transition graph, canonical LineString, confidence, get-canonical-trail, snap-position, route status UI

### Sprint 4: Beta Hardening

- Duration: 5 working days
- Goal: prepare first field-test build
- Scope: integration tests, replay data, field test checklist, logs, critical fixes

## Test Strategy

- Unit tests for state machines, upload queue, filters, distance calculations, and confidence labels.
- Widget tests for recording states, permission blockers, route status labels, and upload status.
- Integration tests for offline recording, restart recovery, upload, route retrieval, and snap-position.
- Deno tests for Edge Function request validation, upload consent enforcement, duplicate upload handling, and response contracts.
- pgTAP tests for database constraints, PostGIS routines, confidence thresholds, and RLS/privacy basics.
- Manual field tests for real GPS noise, airplane mode, forced app restart, and branch guidance.

## Definition of Done

- `flutter analyze` passes.
- `flutter test` passes.
- Edge Function Deno tests pass.
- Supabase migrations apply locally from empty state.
- pgTAP DB tests pass.
- P0 smoke flow works on a real Android device.
- Routes below confidence threshold are not labeled recommended.
- Duplicate upload attempts do not create duplicate canonical contributions.
- Upload without consent is rejected.
- Users cannot read another user's raw sessions or track points.

## Key Risks

- GPS noise creates false trails: mitigate with filters and confidence penalties.
- Route inference complexity expands: ship deterministic grid/graph first.
- Local/hosted Supabase mismatch: use local first, then staging smoke tests.
- Background GPS constraints: MVP starts with foreground recording.
- Solo-dev capacity: preserve buffer and keep P1/P2 out until P0 works.
