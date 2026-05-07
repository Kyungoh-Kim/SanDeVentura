# Sprint 1 Field Recording Plan

**Project**: SanDeVentura MVP  
**Scope**: Mobile local/offline recording foundation  
**Branch**: `feat/sprint-1-recording-foundation`  
**Source**: `development-execution-plan.md`, `spec.md`, `architecture.md`,
`data-model.md`, `privacy-retention.md`

## Goal

Prove that a hiker can record one local hiking session without network access
and recover that same session after app restart.

Sprint 1 intentionally avoids backend upload, route inference, canonical trail
display, snap-position, and operator dashboard work. The mobile app must first
own local session continuity.

## Success Criteria

- A user can start a foreground hiking recording while offline.
- The app stores timestamped location points in local SQLite.
- The app allows only one active or paused session at a time.
- Location permission or disabled location service blocks session creation.
- An active or paused session is restored after app restart.
- Restored sessions append new points to the existing session.
- A completed session remains available locally with start/end time and point
  count.
- `flutter analyze` and `flutter test` pass.

## Required Product Rules

- `FR-001`: Start, pause/resume, and finish one active hiking session.
- `FR-002`: Store local points with timestamp, latitude, longitude, optional
  altitude, accuracy, and speed.
- `FR-003`: Preserve active and completed sessions across app restart.
- `FR-004`: Prevent duplicate active sessions for the same device/user context.
- `FR-015` is noted but deferred: upload consent is required before sync, not
  before local recording.

## Implementation Decisions

- Use Flutter mobile as the Sprint 1 implementation surface.
- Use SQLite through a typed persistence layer.
- Wrap location plugin access behind `LocationService` and
  `LocationPermissionService` so state-machine tests do not depend on device
  APIs.
- Keep Sprint 1 UI status-first. A map can be stubbed or omitted until route
  guidance work begins.
- Treat foreground recording as MVP behavior. Background GPS is out of scope.

## Data Scope

### `local_sessions`

- `id`: stable client-generated session key
- `user_id`: optional local/auth user identifier
- `mountain_id`: internal stable mountain identifier
- `status`: `active`, `paused`, `completed`, `queued`, `uploaded`, `failed`
- `started_at`, `ended_at`
- `created_at`, `updated_at`

### `local_track_points`

- `id`
- `session_id`
- `recorded_at`
- `lat`, `lon`
- `altitude`
- `accuracy`
- `speed`
- `sequence_index`
- `sync_status`

`upload_queue` is not required for the first local recording slice. It can be
introduced in Sprint 2 when completed sessions are synced.

## Step Plan

### Step 1: Dependencies and Persistence Baseline

- Add SQLite and location dependencies.
- Add typed local database schema for `local_sessions` and
  `local_track_points`.
- Add migration/opening path for mobile app startup.
- Add basic DAO tests against an in-memory or test database.

Done when local session and point rows can be inserted and queried in tests.

### Step 2: Recording State Machine

- Define valid transitions:
  - `idle -> recording`
  - `recording -> paused`
  - `paused -> recording`
  - `recording|paused -> completed`
  - `active|paused on startup -> recoveredRecording`
- Reject start when a recoverable session already exists.
- Reject start when permission or location service is blocked.

Done when unit tests cover valid transitions, invalid duplicate starts, and
permission-blocked starts.

### Step 3: Location Capture Use Cases

- Start foreground location stream after session creation.
- Persist each accepted point with increasing `sequence_index`.
- Track elapsed time, point count, latest accuracy, and approximate distance.
- Keep the session active if location service is disabled mid-session and
  expose a degraded state to UI.

Done when mocked location events append to the same local session.

### Step 4: Restart Recovery

- Query active or paused sessions during app startup.
- Restore existing session state and point count.
- Append new points to the restored session.
- If crash state is ambiguous, expose a recovery choice to continue or finish.

Done when a controller/use-case test simulates app restart and verifies no
duplicate session is created.

### Step 5: MVP Recording UI

- Show status, elapsed time, point count, latest accuracy, and approximate
  distance.
- Provide Start, Pause, Resume, and Finish controls for valid states.
- Show permission/service blockers before recording starts.
- Show recovered-session banner after startup recovery.

Done when widget tests verify the core states and controls.

### Step 6: Field Smoke Checklist

- Run on a real Android device.
- Start recording.
- Enable airplane mode.
- Record a short route.
- Force-close and reopen app.
- Confirm the same session is restored.
- Finish session and verify completed local summary remains.

Done when the manual field result is recorded in the implementation notes.

## Out of Scope

- Supabase Auth and upload.
- Upload consent prompt.
- Edge Functions.
- Canonical trail generation.
- Route guidance map.
- Snap-position.
- Operator overview/routes/sessions screens.
- Background recording.
- Offline map tiles.

## Open Inputs Before Field Testing

- Default beta `mountain_id` for local-only testing.
- Whether local recording is allowed before sign-in in the first Android build.
- Minimum accepted location quality for local point storage, if any.
- Real Android device model and OS version for first smoke test.
