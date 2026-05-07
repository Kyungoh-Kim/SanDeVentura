# Sprint 2 Upload and Spatial Backend Plan

**Project**: SanDeVentura MVP  
**Scope**: Completed-session upload, validation, idempotency, and remote
spatial evidence  
**Proposed Branch**: `feat/sprint-2-upload-backend`  
**Source**: `development-execution-plan.md`, `spec.md`, `architecture.md`,
`data-model.md`, `api-contract.md`, `privacy-retention.md`

## Goal

Make completed offline sessions upload automatically and safely into the
Supabase backend so they become route-learning evidence exactly once.

Sprint 2 starts after Sprint 1 local recording is code-complete. It does not
generate canonical trails or build route guidance. The backend only needs to
ingest, validate, store, and report accepted/rejected point counts.

## Confirmed Product Decisions

- Sprint 2 uses a temporary dev user instead of full production
  authentication.
- Upload consent is required before any completed location trace is uploaded.
- Consent version is `beta-upload-consent-v1`.
- Default MVP `mountainId` remains `beta-mountain`.
- Upload can be automatic only when the user enables automatic upload.
- The app must provide an automatic upload on/off interface.
- Automatic upload is disabled until upload consent is accepted.
- Failed automatic uploads retry every 10 minutes, up to 2 retries after the
  first attempt, for 3 automatic attempts total.
- Users can manually Retry at any point, including between or after automatic
  retry attempts.
- Upload queue must store `attempt_count` and `last_error`.
- Uploaded raw local points are deleted only by explicit user choice.
- Sprint 2 targets local Supabase first. Hosted Supabase is deferred until the
  local ingestion path is stable.
- Rejected points store original coordinates in Sprint 2 to support validation
  debugging during beta.

## Consent Copy

Before first upload, show:

> 제공된 위치 경로 데이터는 SanDeVentura의 경로 데이터 품질 개선과
> 대표 경로 생성을 위해 사용됩니다. 완료된 산행 기록에는 위치 경로가
> 포함되며, 원하지 않으면 업로드하지 않고 기기에만 보관할 수 있습니다.
> 자동 업로드는 설정에서 언제든 켜거나 끌 수 있습니다.
> 다른 사용자의 원본 경로와 신원은 MVP에서 공개되지 않습니다.

The app stores acceptance of `beta-upload-consent-v1` locally and sends that
version in every upload request.

Consent acceptance does not force automatic upload. The user controls automatic
upload separately through an on/off setting.

## Success Criteria

- A completed local session is added to the upload queue.
- Upload consent blocks upload until accepted.
- Automatic upload runs only after consent is accepted and automatic upload is
  enabled.
- If automatic upload is off, completed sessions remain local/queued and can be
  uploaded through manual Retry/Sync.
- Failed automatic uploads retry twice at 10-minute intervals.
- Manual Retry works regardless of automatic retry timing.
- Duplicate upload attempts for the same session return duplicate success and
  do not create a second route contribution.
- Backend returns accepted and rejected point counts.
- Remote accepted points are stored in PostGIS.
- Remote rejected points store original coordinates, sequence index, and
  rejection reason.
- Local session status becomes `uploaded` only after successful or duplicate
  backend response.
- `flutter analyze`, `flutter test`, Supabase migration reset, Deno function
  tests, and DB/privacy tests pass where tooling is available locally.

## Required Product Rules

- `FR-005`: Upload completed local sessions after connectivity is available or
  after the user initiates synchronization.
- `FR-006`: Use a stable client-generated session key or equivalent
  idempotency mechanism.
- `FR-007`: Validate uploaded points and report accepted/rejected point counts.
- `FR-008`: Reject or down-rank invalid or implausible points.
- `FR-015`: Require upload consent before uploading completed sessions that
  contain location traces.
- `FR-016`: Avoid exposing another user's raw session path, raw track points,
  or identity through hiker-facing APIs.
- `FR-017`: Avoid storing full raw coordinates in MVP event payloads.

## Data Scope

### Temporary Dev User

Sprint 2 does not implement production sign-in. Instead, it uses one configured
temporary dev user for upload ownership.

- Local config key: `dev-user`
- Remote `hiking_sessions.user_id`: temporary dev user identifier
- Edge Function accepts requests only when the request maps to this dev user
  context.
- The dev user must be easy to replace with real Supabase Auth in a later
  sprint.
- No public raw trace read API is added for the dev user.

### Mobile Local Additions

`upload_queue`

- `id`
- `session_id`
- `idempotency_key`
- `attempt_count`
- `last_attempt_at`
- `next_attempt_at`
- `last_error`
- `status`: `queued`, `uploading`, `uploaded`, `failed`

Local consent storage:

- accepted consent version
- accepted timestamp

Upload preference storage:

- automatic upload enabled/disabled
- preference updated timestamp

Local session status transitions in Sprint 2:

- `completed -> queued -> uploaded`
- `queued -> failed -> queued`
- manual Retry can move `failed -> queued`

### Upload Request

`POST /functions/v1/upload-session`

- `idempotencyKey`
- `uploadConsentVersion`
- `mountainId`
- `startedAt`
- `endedAt`
- `points[]`
  - `recordedAt`
  - `lat`
  - `lon`
  - `altitude`
  - `accuracy`
  - `speed`
  - `sequenceIndex`

### Upload Response

- `success`
- `sessionId`
- `acceptedPointCount`
- `rejectedPointCount`
- `retentionExpiresAt`
- `status`: `ingested`, `duplicate`, `rejected`
- `errors[]`

### Remote Data

Remote tables used in Sprint 2:

- `mountains`
- `hiking_sessions`
- `track_points`
- `rejected_track_points`
- `mvp_events`

Route inference tables may exist in migrations but are not implemented as
Sprint 2 behavior.

## Validation Rules

Initial point validation defaults:

- `lat` must be between `-90` and `90`.
- `lon` must be between `-180` and `180`.
- `recordedAt` is required.
- `sequenceIndex` must be present and unique within the uploaded session.
- Points are processed in `sequenceIndex` order.
- `speed > 15 m/s` is rejected.
- `accuracy > 100 m` is rejected for Sprint 2 beta ingestion.
- Missing optional `altitude`, `accuracy`, or `speed` is allowed unless a rule
  needs that value.

Rejected point storage includes:

- original `lat` and `lon`
- `recordedAt`
- `point_sequence_index`
- rejection `reason`
- optional short debug payload
- expiration metadata for debug retention

## Step Plan

### Step 1: Branches and Sprint 2 Plan

- Create parent, mobile, and web/backend branches:
  `feat/sprint-2-upload-backend`.
- Commit this Sprint 2 plan before implementation.
- Keep unrelated design assets out of the Sprint 2 commit unless explicitly
  requested.

Done when the plan is reviewed and branch scope is clean.

### Step 2: Supabase Local Baseline

- Verify Supabase CLI availability.
- Start local Supabase.
- Apply migrations from empty state.
- Confirm PostGIS extension is enabled.
- Record any missing local prerequisites.

Done when local DB reset succeeds or blockers are documented.

### Step 3: Remote Schema and Privacy Review

- Confirm idempotency constraint on `hiking_sessions.client_session_key`.
- Confirm `track_points` stores PostGIS point geometry.
- Add original coordinate fields or debug payload structure for
  `rejected_track_points`.
- Confirm hiker clients cannot directly read raw remote traces.
- Use a temporary dev user for Sprint 2 upload, but avoid adding raw trace read
  APIs.

Done when migrations express the Sprint 2 data contract and privacy baseline.

### Step 4: Point Validation Library

- Implement validation as pure shared Edge Function code.
- Unit test coordinate bounds, missing timestamp, duplicate sequence,
  implausible speed, high accuracy, and mixed accepted/rejected payloads.

Done when validation tests pass without requiring a running database.

### Step 5: `upload-session` Edge Function

- Accept Sprint 2 requests for the configured temporary dev user.
- Reject missing or unsupported `uploadConsentVersion`.
- Check `idempotencyKey` / `client_session_key`.
- Insert one remote `hiking_sessions` row for new sessions.
- Insert accepted points into `track_points`.
- Insert rejected points with original coordinates into
  `rejected_track_points`.
- Return accepted/rejected counts and duplicate status.

Done when Deno function tests cover ingestion, missing consent, invalid points,
and duplicate upload.

### Step 6: Mobile Upload Queue

- Create local `upload_queue` DAO and schema migration.
- Generate stable `idempotency_key` for each completed session.
- Queue completed sessions after Finish once consent exists.
- Store `attempt_count`, `last_attempt_at`, `next_attempt_at`, and
  `last_error`.

Done when mobile unit tests cover queue creation and retry state transitions.

### Step 7: Mobile Consent

- Show consent before the first upload.
- Store acceptance of `beta-upload-consent-v1` locally.
- Prevent upload until consent is accepted.
- Include consent version in each upload request.
- Keep consent acceptance separate from automatic upload preference.

Done when widget/unit tests cover blocked upload and accepted-consent upload.

### Step 8: Automatic Upload Preference

- Add automatic upload on/off control in the Sessions surface.
- Default automatic upload to off until the user accepts consent and enables it.
- Allow the user to disable automatic upload without deleting completed local
  sessions.
- Manual Retry/Sync remains available when automatic upload is off.

Done when tests cover automatic upload disabled, enabled, and manual upload
while disabled.

### Step 9: Mobile Upload Client and Scheduler

- Implement `UploadSessionClient`.
- Serialize completed local session and points.
- Automatically attempt queued uploads only when consent is accepted and
  automatic upload is enabled.
- Retry failed automatic uploads after 10 minutes, up to 3 total automatic
  attempts.
- Allow manual Retry anytime.
- Mark local session `uploaded` after `ingested` or `duplicate` response.

Done when mocked client tests cover success, duplicate success, failure,
scheduled retry, and manual retry.

### Step 10: Sessions UI

- Show completed, queued, uploading, failed, and uploaded states.
- Show last error and attempt count.
- Show automatic upload on/off control.
- Show Retry action.
- Show accepted/rejected counts after upload.
- Offer delete-local-raw-points action only after upload success.

Done when widget tests cover upload status and Retry visibility.

### Step 11: End-to-End Local Smoke

- Record and finish a session in emulator.
- Accept upload consent.
- Enable automatic upload.
- Start local Supabase.
- Let automatic upload run.
- Disable automatic upload and verify manual Retry/Sync still works.
- Retry the same upload and verify duplicate success.
- Confirm remote accepted/rejected counts.
- Confirm local status is `uploaded`.

Done when the smoke result is recorded in implementation notes.

## Out of Scope

- Supabase hosted/staging deployment.
- Login, account linking, or user profile.
- Canonical trail generation.
- Route inference graph quality.
- `get-canonical-trail`.
- `snap-position`.
- Operator dashboard improvements.
- Background upload while app is terminated.
- Deleting uploaded local raw points automatically.

## Test Strategy

Mobile:

- `flutter analyze`
- `flutter test`
- DAO tests for upload queue.
- Use-case tests for consent, auto retry, manual Retry, and status changes.
- Widget tests for Sessions upload states.

Backend:

- Supabase migration reset from empty state.
- Deno tests for `upload-session`.
- DB tests for idempotency and raw trace privacy.
- Validation unit tests for accepted/rejected split.

Manual:

- Emulator recording and automatic upload smoke.
- Duplicate upload smoke.
- Failed upload retry smoke by stopping local Supabase temporarily.

## Definition of Done

- Sprint 2 plan is committed.
- Local Supabase migrations apply from empty state.
- `upload-session` passes validation and duplicate tests.
- Missing consent is rejected.
- Invalid points are rejected and original rejected coordinates are stored.
- Duplicate upload does not create duplicate canonical contributions.
- Mobile queue stores attempts, errors, and retry timing.
- Automatic upload is user-controlled through an on/off setting.
- Automatic retry follows 10-minute interval and 3-attempt total rule only when
  automatic upload is enabled.
- Manual Retry is available at any time.
- Sessions UI shows upload state and accepted/rejected counts.
- Raw local point deletion is user-controlled.

## Risks and Notes

- Production authentication is intentionally deferred. Sprint 2 uses one
  temporary dev user to keep ownership explicit while avoiding full account
  work. This still limits how much Sprint 2 can prove about multi-user RLS.
  The mitigation is to expose ingestion through `upload-session` only and avoid
  raw trace read APIs.
- Privacy baseline differs from the earlier preference for rejected summaries:
  Sprint 2 stores original rejected coordinates for beta debugging. Add
  retention metadata and avoid event payload coordinate arrays.
- Automatic upload in foreground is in scope. Upload while the app is fully
  terminated is out of scope.
- Hosted Supabase is deferred until local ingestion is stable.

## Implementation Verification Notes

- `flutter analyze` passed on 2026-05-07.
- `flutter build apk --debug` passed on 2026-05-07.
- `npm run typecheck` passed on 2026-05-07.
- `npm run build` passed on 2026-05-07.
- `npm run test:functions` could not run because `deno` is not installed or
  not available on PATH.
- `npm run supabase:reset` could not run because `supabase` is not installed
  or not available on PATH.
- `flutter test --concurrency=1` currently hangs before producing test output
  in this local shell session, so the added DAO/service/widget tests still need
  to be executed once the local Flutter test runner issue is cleared.
- Independent subagent validation was requested, but the validation subagent
  could not start because the current Codex usage limit was reached.
