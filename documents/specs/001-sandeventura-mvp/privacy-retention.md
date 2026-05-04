# Privacy and Retention Policy: SanDeVentura MVP

**Status**: MVP baseline  
**Date**: 2026-05-05  
**Related**: [spec.md](spec.md), [prd.md](prd.md), [plan.md](plan.md), [data-model.md](data-model.md), [contracts/api-contract.md](contracts/api-contract.md)

## Purpose

SanDeVentura collects location data only to support the MVP safety loop:

1. Record a user's own hiking session locally.
2. Restore an interrupted local session.
3. Upload a completed session when the user syncs or connectivity returns.
4. Validate noisy GPS points.
5. Convert accepted points into confidence-labeled representative routes.
6. Compare the user's current position to the representative route.

Location data must not be used for social sharing, ranking, public profiles, rescue dispatch, or marketing in the MVP.

## Data Minimization Rules

| Data | Why collected | MVP storage |
|------|---------------|-------------|
| Latitude / longitude | Record route shape and derive representative trails | Local SQLite before upload; PostGIS after accepted upload |
| Timestamp | Preserve point order, speed filtering, session reconstruction | Local SQLite and remote accepted points |
| Accuracy | Reject or down-rank low-quality points | Local SQLite and remote quality metrics |
| Altitude | Reject implausible elevation jumps and debug route quality | Optional local/remote field |
| Speed | Reject implausible movement | Optional local/remote field |
| Session key | Prevent duplicate contribution | Local SQLite and remote unique key |
| Rejection reason | Debug validation quality without exposing full raw traces | Remote summary only |

Rejected-point storage should prefer structured rejection summaries. Do not store full raw point payloads unless they are sampled for short-lived debugging.

## Upload Consent

Before the first completed-session upload, the app must present a concise consent notice covering:

- Completed hiking sessions contain location traces.
- Uploaded accepted points may improve representative routes for the same mountain.
- Other users must not see another user's raw path or identity in the MVP.
- The user can keep a session local by not syncing it.

The upload request must include the accepted consent version. If consent is missing, `upload-session` must reject the upload with a user-actionable error.

## Upload Triggers

Allowed MVP upload triggers:

- User taps Sync for a completed session.
- User has accepted upload consent and the app retries a queued completed session when connectivity returns.

Disallowed MVP upload triggers:

- Uploading an active session before the user finishes it.
- Uploading solely because the app launched.
- Uploading for social sharing, ranking, or marketing.

## Retention Baseline

| Data | Retention |
|------|-----------|
| Local active session | Until completed, discarded by user, or recovered and finished |
| Local completed unsynced session | Until user deletes it or syncs it |
| Local uploaded session copy | Keep summary by default; raw local points may be deleted after successful upload confirmation |
| Remote accepted points | Keep for MVP beta route learning; review after 90 days of beta data |
| Remote rejected point summaries | Keep for 30 days unless aggregated into non-identifying metrics |
| Debug raw rejection samples | Maximum 7 days; disabled by default |
| MVP events | Keep event summaries for beta metrics; avoid storing raw coordinates in event payloads |

## Access Control

- Users can access their own local sessions and upload status.
- Users must not access other users' raw sessions or raw track points.
- Hiker-facing route APIs expose only canonical trail geometry, confidence, version, and snap-position results.
- Operator access to route quality data must be restricted to authenticated operator/admin contexts.
- RLS policies must prevent direct client reads of `track_points`, `rejected_track_points`, and other users' `hiking_sessions`.

## Event Payload Limits

`mvp_events.event_payload` may store counters, state names, request IDs, route versions, and error categories. It must not store full raw coordinates or full track point arrays.

## Implementation Checks

- `upload-session` validates consent version.
- Remote schema includes retention metadata for uploaded sessions or point batches.
- RLS tests verify users cannot read other users' raw traces.
- Rejected-point tests verify full raw payload storage is not required for normal validation.
- Deletion/retention job is documented before beta launch.

