# Sprint 5 Final Verification Notes

## MVP Functional Requirement Trace

- `FR-001`: Sprint 1 recording supports start, pause/resume, and finish; the
  field checklist verifies the same controls on device.
- `FR-002`: Sprint 1 local SQLite points include timestamp, latitude,
  longitude, altitude, accuracy, speed, and sequence index.
- `FR-003`: Sprint 1 recovery tests and Sprint 5 field checklist verify app
  restart recovery.
- `FR-004`: Sprint 1 state machine prevents duplicate active sessions.
- `FR-005`: Sprint 2 queue and Sprint 5 upload checklist cover completed
  session upload.
- `FR-006`: Sprint 2 idempotency key and duplicate retry scenario cover
  one-time contribution.
- `FR-007`: Sprint 2 upload response and Sprint 5 evidence capture record
  accepted/rejected point counts.
- `FR-008`: Sprint 2 validation tests reject invalid coordinates, duplicate
  sequence indices, implausible speed, and low accuracy; Sprint 5 adds an
  invalid-point manual scenario.
- `FR-009`: route cells, transitions, and canonical trails are persisted by
  `recompute-canonical-trails`.
- `FR-010`: `get-canonical-trail` returns route state, version, confidence,
  updated time, GeoJSON, and metrics.
- `FR-011`: confidence `>= 0.70` is recommended; lower confidence remains
  reference.
- `FR-012`: `snap-position` returns nearest route distance and route judgment.
- `FR-013`: missing canonical trails return no-route state instead of
  fabricated guidance.
- `FR-014`: route-served and snap-requested events are recorded without raw
  coordinate payloads.
- `FR-015`: Sprint 2 consent gate and Sprint 5 consent scenario require upload
  consent before trace upload.
- `FR-016`: RLS policies block direct raw accepted/rejected point reads; route
  APIs expose canonical trail and snap results rather than other users' traces.
- `FR-017`: event payload checks verify no full raw coordinates or point arrays
  are stored in MVP events.

## MVP Success Criteria Trace

- `SC-001`: Covered by Sprint 1 automated recovery tests and Sprint 5
  airplane-mode recovery field scenario; real 30-minute field execution remains
  non-local.
- `SC-002`: Covered by upload queue/retry implementation and Sprint 5 upload
  evidence capture; 95% rate requires controlled beta measurement.
- `SC-003`: Covered by Sprint 2 duplicate upload behavior and Sprint 5
  duplicate retry scenario.
- `SC-004`: Covered by `get-canonical-trail` function, DB tests, and route
  guidance checklist.
- `SC-005`: Covered by `snap-position` function, threshold tests, and fork
  position field scenario.
- `SC-006`: Covered by Sprint 5 three-mountain coverage checklist and operator
  route coverage view/UI examples.

## Automated Checks Used

Run date: 2026-05-08, local workspace `C:\dev\projects\SanDeVentura`.

| Check | Result | Notes |
|-------|--------|-------|
| `npm run typecheck` | Pass | Web TypeScript check passed. |
| `npm run build` | Pass | Vite production build passed. |
| `npm run test:functions` | Pass | 15 Deno tests passed. |
| `npm run supabase:reset` | Pass | Migrations `0001` through `0006` applied. |
| `npm run test:db` | Pass | 26 pgTAP tests passed. |
| `flutter analyze` | Pass | Mobile analyzer found no issues. |
| `flutter test test\features\trails\trail_guidance_screen_test.dart` | Pass | 2 widget tests passed. |

## Residual Security Advisory

Supabase local `db query` reports RLS disabled on `public.spatial_ref_sys`,
which is installed by PostGIS. Sprint 4 enables RLS on SanDeVentura-owned route
tables (`mountains`, `trail_cells`, `trail_cell_transitions`, and
`canonical_trails`). Changing extension metadata should be reviewed separately
before beta deployment.

## Not Locally Performable

| Sprint | Scenario not performable here | Required later evidence |
|--------|-------------------------------|--------------------------|
| Sprint 1 | Real Android 30-minute airplane-mode recording and forced restart on a mountain. | Device model, OS, session id, point count before/after restart, completed summary. |
| Sprint 2 | Hosted or device-to-staging upload with real network loss/retry conditions. | Upload status, accepted/rejected counts, duplicate retry response, consent version. |
| Sprint 3 | Real GPS route guidance at trail forks using repeated traces from the same beta mountain. | Route version/confidence, snap distances, on/caution/away judgments at known locations. |
| Sprint 4 | Hosted Supabase staging smoke and non-service-role operator access validation. | Deployment target, account role, route coverage view result, event payload sample. |
| Sprint 5 | Final thirty-minute Android field test across weak connectivity and route guidance. | Completed checklist, screenshots/logs for stop conditions, three-mountain coverage table. |

## Before Beta Deployment

- Run the full field checklist on a real Android device.
- Run a hosted Supabase staging smoke with deployed functions and migrations.
- Validate operator/admin access using real project roles.
- Review the PostGIS `spatial_ref_sys` RLS advisory separately.
- Choose and document the three beta mountains and their starting route states.
