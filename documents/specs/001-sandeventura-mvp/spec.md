# Feature Specification: SanDeVentura MVP

**Feature Branch**: `001-sandeventura-mvp`  
**Created**: 2026-05-04  
**Status**: Draft  
**Input**: Notion source pages under "SanDeVentura - 산드벤처"; user decision to discard the existing prototype and create a technology-neutral SDD baseline.

**Related Product Document**: [Product Requirements Document](prd.md) generated from `phuryn/pm-skills` `create-prd` / `write-prd` guidance for product development only. Marketing, GTM, pricing, positioning, and growth planning are excluded from the MVP PRD.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record a Hike Without Connectivity (Priority: P0)

As a hiker on a mountain with weak or unavailable network coverage, I want my route to keep recording locally from start to finish so that I do not lose my path history while I am offline.

**Why this priority**: Offline recording is the foundation for later route learning and for the user's own safety record.

**Independent Test**: Put the device in airplane mode, start a hike, move for at least 30 minutes, end the hike, and verify that the session and accumulated points are still available locally.

**Acceptance Scenarios**:

1. **Given** the user is signed in or otherwise allowed to record locally and network access is unavailable, **When** the user starts a hike, **Then** the system creates an active local session and begins storing timestamped location points.
2. **Given** an active offline session has been recording for 30 minutes, **When** the user ends the hike, **Then** the system preserves the completed session locally with start time, end time, and recorded point count.
3. **Given** location permission or device location service is unavailable, **When** the user attempts to start recording, **Then** the system explains the blocker and does not create a misleading active session.

---

### User Story 2 - Restore an Interrupted Session (Priority: P0)

As a hiker, I want an active hiking session to survive app restart so that accidental app closure does not create duplicate sessions or lose my ongoing recording.

**Why this priority**: Mobile apps may be killed in the field; losing state breaks the core offline-first promise.

**Independent Test**: Start a session, record points, force close the app, reopen it, and verify that the same active session resumes with prior points intact.

**Acceptance Scenarios**:

1. **Given** a hike is actively recording, **When** the app is force closed and reopened, **Then** the system restores the same active session and shows it as recording or resumable.
2. **Given** an active session is restored after restart, **When** new points are recorded, **Then** they are appended to the existing session rather than creating a duplicate session.
3. **Given** the last saved state is ambiguous after a crash, **When** the app starts, **Then** the user can choose to continue or end the recovered session without losing saved points.

---

### User Story 3 - Upload a Completed Session Once Connectivity Returns (Priority: P0)

As a hiker, I want completed offline sessions to upload when network connectivity returns so that my route contributes to better future trail guidance without requiring repeated manual work.

**Why this priority**: Uploaded sessions are the raw material for canonical trail generation and upload success rate is a primary MVP metric.

**Independent Test**: Complete a session offline, restore connectivity, trigger synchronization, and verify that the remote system accepts the session exactly once and reports accepted/rejected point counts.

**Acceptance Scenarios**:

1. **Given** a completed local session has not been uploaded, **When** network connectivity becomes available, **Then** the system attempts to upload the session metadata and recorded points.
2. **Given** the same completed session is retried after a timeout or app restart, **When** synchronization runs again, **Then** the remote system treats it as the same session and prevents duplicate contribution.
3. **Given** uploaded points include invalid coordinates or implausible movement, **When** the remote system processes the upload, **Then** the response distinguishes accepted and rejected point counts.

---

### User Story 4 - View a Canonical Trail With Confidence (Priority: P0)

As a hiker preparing for or navigating a mountain, I want to view the latest available representative trail and its confidence so that I know whether to treat it as recommended guidance or only a reference.

**Why this priority**: The product's core value is reducing wrong decisions at trail branches by turning accumulated logs into a usable reference.

**Independent Test**: Request a mountain that has a canonical trail and verify that the response includes route geometry, version, last update time, confidence, and recommendation status.

**Acceptance Scenarios**:

1. **Given** a mountain has a generated canonical trail, **When** the user opens trail guidance for that mountain, **Then** the system provides the latest trail, confidence score, version, and updated time.
2. **Given** the canonical trail confidence is at least 0.70, **When** the user views it, **Then** the system labels it as a recommended route.
3. **Given** the canonical trail confidence is below 0.70, **When** the user views it, **Then** the system labels it as a reference route or withholds recommendation language.
4. **Given** no canonical trail is available for the selected mountain, **When** the user requests guidance, **Then** the system clearly states that no representative trail is ready.

---

### User Story 5 - Compare Current Position to the Canonical Trail (Priority: P0)

As a hiker at a fork or uncertain section, I want to know whether my current position is on or away from the representative trail so that I can avoid following an accidental side path.

**Why this priority**: This is the direct safety outcome described in the original problem: reducing wrong branch choices.

**Independent Test**: Provide a current coordinate near and far from a known canonical trail and verify that the system returns the nearest trail position, distance, and on/off trail judgment.

**Acceptance Scenarios**:

1. **Given** a canonical trail exists for the current mountain, **When** the user requests current position comparison, **Then** the system returns the nearest point on the trail and the distance from the user's input position.
2. **Given** the user is close enough to the canonical trail according to the MVP threshold, **When** position comparison completes, **Then** the system reports the user as on trail.
3. **Given** the user is beyond the MVP threshold from the canonical trail, **When** position comparison completes, **Then** the system reports the user as away from the trail without claiming emergency status.
4. **Given** the user is between the on-route and away-from-route thresholds, **When** position comparison completes, **Then** the system reports a caution state instead of a false on/off certainty.

---

### User Story 6 - Observe MVP Health Signals (Priority: P1)

As the operator, I want core events and weekly MVP metrics so that I can identify whether recording, upload, canonical trail availability, and snap guidance are improving.

**Why this priority**: Operational learning is necessary, but users can still receive P0 value before full operator dashboards exist.

**Independent Test**: Perform the core flows and verify that the named events are recorded and can be aggregated into the MVP success metrics.

**Acceptance Scenarios**:

1. **Given** a user starts recording, uploads a session, receives a trail, or requests position comparison, **When** each action completes, **Then** the system records the corresponding event for later aggregation.
2. **Given** at least one week of event data exists, **When** the operator reviews MVP health, **Then** the system can report upload success rate, recommended-route coverage, and position-comparison usage.

---

### Edge Cases

- A session has too few points to be useful for canonical trail learning.
- A user records in airplane mode and the device battery dies before explicit finish.
- A user denies precise location permission or disables location services mid-session.
- A session upload is interrupted after partial transfer.
- Multiple devices or installs attempt to upload the same logical session.
- The current mountain identifier is unknown or not yet mapped to the user's location.
- Canonical trail confidence changes while the user is hiking.
- The user is near a fork where two plausible trail branches are close together.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a user to start, pause or resume, and finish one active hiking session at a time.
- **FR-002**: The system MUST store hiking points locally while offline with timestamp, latitude, longitude, altitude when available, accuracy when available, and speed when available.
- **FR-003**: The system MUST preserve active and completed local sessions across app restart.
- **FR-004**: The system MUST prevent duplicate active sessions for the same user/device context.
- **FR-005**: The system MUST upload completed local sessions after connectivity is available or after the user initiates synchronization.
- **FR-006**: The system MUST use a stable client-generated session key or equivalent idempotency mechanism so repeated uploads of the same session are not counted twice.
- **FR-007**: The system MUST validate uploaded points and report accepted and rejected point counts.
- **FR-008**: The system MUST reject or down-rank points with invalid coordinate ranges, missing timestamps, implausible speed, or implausible elevation changes.
- **FR-009**: The system MUST maintain a canonical trail per mountain when enough accepted session data exists.
- **FR-010**: The system MUST expose the latest canonical trail with route geometry, version, confidence, updated time, and recommendation status.
- **FR-011**: The system MUST classify a canonical trail with confidence >= 0.70 as recommended and confidence < 0.70 as reference or not recommended.
- **FR-012**: The system MUST compare a user's current coordinate to the canonical trail and return nearest trail coordinate, distance, and on/off trail judgment.
- **FR-013**: The system MUST show users when no canonical trail is ready instead of fabricating guidance.
- **FR-014**: The system MUST record MVP events for session_started, session_restored, session_uploaded, trail_served, and snap_requested.
- **FR-015**: The system MUST require upload consent before uploading completed sessions that contain location traces.
- **FR-016**: The system MUST avoid exposing another user's raw session path, raw track points, or identity through hiker-facing APIs.
- **FR-017**: The system MUST avoid storing full raw coordinates in MVP event payloads.
- **FR-018**: The MVP specification MUST remain technology-neutral; implementation technologies are decided only in the implementation plan.

### Key Entities *(include if feature involves data)*

- **Mountain**: A logical hiking area used to group sessions and canonical trails. For MVP documentation, `mountainId` is an internal stable identifier that may later map to public data keys.
- **Hiking Session**: One user-recorded hike from start to finish, including local state, upload status, timestamps, and point count.
- **Track Point**: A timestamped location observation captured during a session with optional altitude, accuracy, and speed.
- **Canonical Trail**: The current representative route for a mountain, derived from accepted sessions and exposed with version and confidence.
- **Confidence**: A 0.00 to 1.00 score representing how much the canonical trail should be trusted for user guidance.
- **Position Comparison**: A result that links an input coordinate to the nearest canonical trail coordinate and on/off trail judgment.
- **MVP Event**: A timestamped operational event used to measure recording, upload, trail availability, and position-comparison flows.
- **Upload Consent**: The user's acknowledgement that a completed hiking session contains location traces and may be uploaded to improve representative routes for the same mountain.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can record a 30-minute airplane-mode hiking session and still see the session after app restart.
- **SC-002**: At least 95% of completed local sessions upload successfully within the first available connectivity window during controlled beta testing.
- **SC-003**: Duplicate upload attempts for the same completed session produce one canonical contribution.
- **SC-004**: For a mountain with a prepared canonical trail, users can retrieve route geometry, confidence, version, and updated time in one guidance request.
- **SC-005**: Position comparison returns a nearest trail coordinate, distance, and on/off trail judgment for canonical-trail mountains.
- **SC-006**: During beta, at least three selected mountains can be tracked for coverage status: no trail, reference trail, or recommended trail.

## Clarifications Resolved for This Baseline

- **mountainId**: MVP documentation treats it as an internal stable identifier. External public-data keys may be mapped later but are not the primary key in the spec.
- **Upload idempotency**: MVP requires a stable client-generated session key or equivalent mechanism. Exact implementation is deferred to the technical plan.
- **Confidence wording**: Confidence >= 0.70 is "recommended route"; confidence < 0.70 is "reference route" or not recommended.
- **Beta mountains**: MVP success tracking requires at least three selected mountains, chosen later by operator criteria, not hard-coded in the spec.
- **Position comparison thresholds**: Initial MVP defaults are on route at `<= 25m`, caution at `> 25m and <= 50m`, and away from route at `> 50m`. These values are beta defaults and may be adjusted after field testing.
- **Location privacy baseline**: Completed sessions require upload consent; hiker-facing APIs expose canonical routes and snap results, not other users' raw traces. Detailed retention rules are defined in `privacy-retention.md`.

## Out of Scope

- Real-time rescue, emergency dispatch, or command-center monitoring.
- Full community features, hiking groups, ranking, mileage competition, or social feeds.
- Photo-based terrain recognition AI.
- Technology stack selection, API wire format, database engine, map provider, and batch architecture.
- Reusing or preserving behavior from the discarded Flutter/Firebase prototype.

## Assumptions

- Users explicitly start and finish hiking sessions.
- Users allow location access for recording and guidance.
- Offline session recording has value even before canonical trail guidance is available for every mountain.
- The MVP can use lower-confidence reference trails as long as the UI does not present them as recommended.
- The technical plan will compare mobile platform, backend, storage, map, and processing options after this spec is accepted.
