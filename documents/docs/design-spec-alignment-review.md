# Design / Spec Alignment Review

**Date**: 2026-05-05  
**Reviewed Images**:

- `designs/mvp-menu-record.png`
- `designs/mvp-menu-route.png`
- `designs/mvp-menu-sessions.png`
- `designs/mvp-menu-quality.png`
- `designs/mvp-menu-record-v2.png`
- `designs/mvp-menu-route-v2.png`
- `designs/mvp-menu-sessions-v2.png`
- `designs/mvp-quality-web-v2.png`
- `designs/mvp-menu-record-v3.png`
- `designs/mvp-menu-route-v3.png`
- `designs/mvp-menu-sessions-v3.png`
- `designs/mvp-quality-web-v3.png`

**Compared Against**:

- `specs/001-sandeventura-mvp/spec.md`
- `specs/001-sandeventura-mvp/architecture.md`
- `specs/001-sandeventura-mvp/plan.md`
- `docs/development-execution-plan.md`

## Overall Verdict

The designs are directionally aligned with the MVP. They cover the four main surfaces implied by the SDD:

1. Recording and local recovery.
2. Route state and current-position comparison.
3. Completed sessions and upload queue.
4. Operator route quality and MVP health.

However, two design choices need correction before implementation:

- The **Quality** screen is an operator/P1 surface and should not appear as a normal hiker bottom-tab item in the MVP mobile app.
- The **Record** screen currently shows `Recording` while also showing `Location permission is off`; this conflicts with the spec, which says no misleading active session should be created when permission is blocked.

The v2 sample image set applies these corrections:

- Mobile MVP navigation now contains only `Record`, `Route`, and `Sessions`.
- `Quality` is represented as a separate web/admin operator dashboard.
- The Record screen no longer combines a blocked permission state with an active recording state.
- Route state examples are presented as data-driven route states, not as user toggles.
- Sessions keeps upload status, idempotency, accepted/rejected counts, and retry state visible.

The v3 sample image set supersedes v2 as the current visual baseline. It keeps the v2 information architecture, but restores the v1 presentation quality:

- phone mockup and presentation-card composition for mobile screens
- higher-fidelity map texture, route geometry, status cards, chips, and shadows
- three-tab hiker mobile navigation: `Record`, `Route`, `Sessions`
- separate web/admin layout for `Quality`
- no impossible Record state where blocked permission and active recording appear together

## Screen-by-Screen Review

## 1. Record Screen

**Alignment**: Strong, with one important state conflict.

The screen reflects the following SDD requirements:

- Start/pause/resume/finish one active hike.
- Store points locally while offline.
- Recover active session after restart.
- Show permission blocker before recording.
- Surface recording state, elapsed time, distance, point count, and accuracy.

Relevant SDD links:

- `FR-001`: start/pause/resume/finish one active session.
- `FR-002`: store hiking points locally while offline.
- `FR-003`: preserve active sessions across app restart.
- `UC-01`: record offline hike.
- `UC-02`: restore interrupted session.
- Sprint 1: Field Recording Foundation.

### Issues

- The design shows `Recording` and `Location permission is off` at the same time. According to the spec, if location permission is unavailable, the app should explain the blocker and not create a misleading active session.
- `Start`, `Pause`, `Resume`, and `Finish` are all visible together. This is acceptable for a conceptual overview, but implementation should make the active state clear:
  - idle: show Start
  - recording: show Pause + Finish
  - paused: show Resume + Finish
  - permission blocked: show blocker and disable Start
- The map shown on the recording screen may imply map rendering is required in Sprint 1. The execution plan says map/guidance UI comes later. For Sprint 1, the map should be optional or replaced with a simple recording status panel.

### Required Design Adjustment

Record screen state model should be explicit:

- `idle`
- `permission_blocked`
- `recording`
- `paused`
- `recovered_recording`
- `completed_queued`

## 2. Route Screen

**Alignment**: Strong.

The route screen maps well to:

- route states: no route / reference / recommended
- confidence and freshness display
- current-position-to-trail comparison
- nearest route point
- ambiguous branch warning

Relevant SDD links:

- `FR-010`: expose latest canonical trail with geometry, version, confidence, updated time, recommendation status.
- `FR-011`: classify confidence >= 0.70 as recommended and lower as reference/not recommended.
- `FR-012`: compare current coordinate to canonical trail.
- `UC-05`: compare current position to route.
- Phase 4: Guidance UI and Position Comparison.

### Strengths

- `Reference route` with confidence `0.64` correctly avoids overclaiming.
- `Distance 18m` and `On route` match snap-position output.
- Ambiguous branch warning aligns with branch ambiguity confidence penalty.
- Version and updated time map cleanly to `canonical_trails.version` and `updated_at`.

### Issues

- `Route state examples` should not look like user-selectable route-state toggles in production. They should be removed or moved to a debug/design annotation.
- The base/topographic map should not imply offline map tiles are P0. The current plan defers offline tile packaging unless field testing proves it necessary.
- `Bukhansan` is fine as mock data, but the product data model should use an internal `mountainId`, not depend on a display name.

### Required Design Adjustment

Route state UI should be data-driven:

- no route: no route card, no snap action
- reference route: amber confidence card, caution language
- recommended route: green confidence card
- ambiguous branch: warning badge and confidence penalty explanation

## 3. Sessions Screen

**Alignment**: Very strong.

This screen directly supports:

- completed local session list
- upload queue
- upload-once behavior
- retry without duplicate contribution
- accepted/rejected point counts
- stable key / idempotency key visibility

Relevant SDD links:

- `FR-005`: upload completed local sessions after connectivity is available.
- `FR-006`: stable client-generated session key / idempotency.
- `FR-007`: accepted and rejected point counts.
- `UC-03`: upload completed session.
- Phase 2: Upload, Validation, and Remote Storage.

### Strengths

- Status chips (`Local`, `Uploading`, `Uploaded`, `Retry`) map well to upload queue state.
- `Stable key` reinforces idempotency.
- Accepted/rejected counts align with backend validation.
- Empty state is included.

### Issues

- The top upload queue says `2 sessions` waiting to sync while the list mixes uploaded/retry/local examples. This is fine for a mock, but implementation should calculate queue count only from `queued` and retryable `failed` states.
- Retry UX should distinguish:
  - retryable network/server failure
  - already uploaded duplicate success
  - validation rejected session
- User-facing stable key may be useful for debugging, but normal users may not need to see it. Consider showing it only in details/debug mode.

### Required Design Adjustment

Add session detail state or bottom sheet for:

- idempotency key
- accepted/rejected reasons
- last upload attempt
- retry eligibility

## 4. Quality Screen

**Alignment**: Strong for operator/P1, not for normal hiker MVP.

The screen aligns with P1 operator requirements:

- track MVP health signals
- inspect route coverage by mountain
- review confidence inputs
- find rejected points and ambiguous branches
- route-quality debug map

Relevant SDD links:

- User Story 6: Observe MVP health signals (P1).
- `FR-014`: MVP events.
- `UC-04`: route recompute and confidence inputs.
- P1 operator metrics and route-quality debug view.

### Strengths

- Upload success, accepted/rejected points, coverage, and snap requests match MVP metrics.
- Confidence inputs match the planned route-quality signals:
  - session count
  - GPS quality
  - branch ambiguity
  - recency
- Route quality debug map maps to `trail_cells`, rejected points, canonical route, and ambiguous branches.

### Issues

- This screen should not be a standard mobile bottom-nav item for hikers. It is an operator/developer dashboard.
- The layout is desktop/tablet-like, not mobile-first. That is acceptable if this is an operator view, but it should live outside the hiker mobile navigation.
- The map legend includes `Trail (base)`. MVP is centered on no-base-trail inference. If a base trail is shown, it must be clearly treated as optional/future or mock debug context.

### Required Design Adjustment

Move Quality to one of:

- web/admin dashboard
- hidden debug mode
- operator-only tablet/desktop view

Do not include it in the hiker's normal bottom navigation for MVP.

### V2 Decision

Use `designs/mvp-quality-web-v3.png` as the implementation reference for Quality. Quality should be built as a lightweight web/admin surface after the mobile MVP's core recording, upload, and route guidance loop is usable. It should not be shipped as menu item 4 in the hiker-facing mobile app.

The web/admin form is justified because Quality is about operator judgment and route health, not in-field hiking behavior:

- route coverage by mountain
- confidence inputs
- rejected point inspection
- ambiguous branch review
- recompute/debug state
- MVP health metrics

This also keeps the mobile MVP minimal and avoids exposing internal confidence mechanics as if they were normal user controls.

## Cross-Screen Alignment

## Matches the SDD Well

- Bottom-level concepts match the planned modules:
  - Record -> `features/recording`
  - Sessions -> `features/sync`
  - Route -> `features/trails`
  - Quality -> operator/debug tools
- Designs reflect the main architecture data:
  - local session
  - upload queue
  - idempotency key
  - accepted/rejected point counts
  - canonical route
  - confidence
  - branch ambiguity
  - snap distance
- Designs avoid social/ranking/community features, which matches MVP non-goals.

## Gaps to Cover Before Implementation

- Explicit no-route state screen.
- Explicit permission-denied pre-recording state.
- Explicit location-service-disabled mid-session state.
- Active session recovery choice when prior state is ambiguous.
- Upload failure reason and retry eligibility.
- Low-confidence caution copy for reference routes.
- Privacy/consent surface before uploading location traces.
- Operator-only access boundary for Quality.

## Implementation Impact

### Sprint 1

Use only the Record screen essentials:

- recording state
- permission blocker
- elapsed time
- distance
- point count
- accuracy
- recovered session banner

Map display can be stubbed or omitted if it slows down offline recording and recovery.

### Sprint 2

Use the Sessions screen as the primary upload/sync UI:

- queued sessions
- uploading
- uploaded
- retryable failure
- accepted/rejected counts
- duplicate-safe upload behavior

### Sprint 3

Use the Route screen:

- no route/reference/recommended states
- confidence
- version/freshness
- nearest route point
- distance/on route
- ambiguous branch warning

### Sprint 4 or P1

Use the Quality screen only for operator/debug:

- route coverage by mountain
- confidence inputs
- rejected points
- ambiguous branches
- debug map

## Final Recommendation

The original designs are usable as an MVP visual direction after these changes:

1. Remove `Quality` from normal hiker mobile navigation.
2. Fix impossible Record state: permission blocked must not also show active recording.
3. Treat map-heavy views as Sprint 3+ unless required for Sprint 1 field tests.
4. Add explicit no-route, privacy consent, and upload failure reason states.
5. Keep route confidence and branch ambiguity visually prominent, because they are core to preventing false certainty.

For implementation, use the v3 image set as the current design baseline:

- `designs/mvp-menu-record-v3.png`
- `designs/mvp-menu-route-v3.png`
- `designs/mvp-menu-sessions-v3.png`
- `designs/mvp-quality-web-v3.png`
