# Data Model: SanDeVentura MVP

## Mobile Local Data

### local_sessions

- `id`: stable client-generated session key
- `user_id`: local/auth user identifier when available
- `mountain_id`: internal stable mountain identifier
- `status`: active, paused, completed, queued, uploaded, failed
- `started_at`, `ended_at`
- `created_at`, `updated_at`

### local_track_points

- `id`
- `session_id`
- `recorded_at`
- `lat`, `lon`
- `altitude`
- `accuracy`
- `speed`
- `sequence_index`
- `sync_status`

### upload_queue

- `id`
- `session_id`
- `idempotency_key`
- `attempt_count`
- `last_attempt_at`
- `last_error`
- `status`

## Remote Data

### mountains

- `id`
- `display_name`
- `source`: internal, public-data, manual
- `created_at`

### hiking_sessions

- `id`
- `user_id`
- `mountain_id`
- `client_session_key`
- `started_at`, `ended_at`
- `status`
- `upload_consent_version`
- `accepted_point_count`
- `rejected_point_count`
- `retention_review_at`
- `created_at`

### track_points

- `id`
- `session_id`
- `mountain_id`
- `recorded_at`
- `geom`: PostGIS point
- `altitude`
- `accuracy`
- `speed`
- `quality_score`
- `sequence_index`

### rejected_track_points

- `id`
- `session_id`
- `reason`
- `point_sequence_index`
- `debug_payload_sample`
- `debug_payload_expires_at`
- `created_at`

### trail_cells

- `id`
- `mountain_id`
- `cell_key`
- `geom`
- `point_count`
- `session_count`
- `avg_accuracy`
- `avg_altitude`
- `last_seen_at`
- `quality_score`

### trail_cell_transitions

- `id`
- `mountain_id`
- `from_cell_key`
- `to_cell_key`
- `transition_count`
- `session_count`
- `edge_cost`

### canonical_trails

- `id`
- `mountain_id`
- `version`
- `geom`: PostGIS LineString
- `confidence`
- `confidence_level`: none, reference, recommended
- `session_count`
- `branch_ambiguity_score`
- `gps_quality_score`
- `updated_at`

### mvp_events

- `id`
- `user_id`
- `mountain_id`
- `session_id`
- `event_name`
- `event_payload`
- `created_at`

`event_payload` must not store full raw coordinate arrays or full track point payloads.

## State Transitions

- Local session: `active -> paused -> active -> completed -> queued -> uploaded`
- Upload failure: `queued -> failed -> queued`
- Canonical trail: `none -> reference -> recommended`; can downgrade from recommended to reference if confidence drops.

## Privacy Constraints

- `hiking_sessions.client_session_key` must be unique per user or device context to enforce idempotency.
- `track_points` and `rejected_track_points` are not directly readable by normal hiker clients.
- `rejected_track_points.debug_payload_sample` is optional, disabled by default, and must expire within 7 days when used.
- Accepted points are used for beta route learning; retention is reviewed after 90 days of beta data.
