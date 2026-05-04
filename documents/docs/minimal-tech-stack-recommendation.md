# Minimal Tech Stack Recommendation for SanDeVentura MVP

**Date**: 2026-05-04  
**Status**: Recommended input for `/speckit.plan`  
**Scope**: MVP implementation only. Existing Flutter/Firebase prototype remains discarded.

## Recommendation

Use a **Flutter mobile app + local SQLite + Supabase Postgres/PostGIS + Supabase Edge Functions** stack.

This is the smallest practical stack that still fits the MVP's hard requirements:

- offline hiking-session recording and app restart recovery
- authenticated upload and idempotent session ingestion
- geospatial storage/querying for track points and canonical trails
- current-position-to-trail distance checks
- a future path to canonical trail confidence and simple batch processing

## Minimal Stack

### Mobile client

- **Flutter** for Android-first MVP, with iOS kept possible but not required for first beta.
- **SQLite on device** for active sessions, completed sessions, upload queue, and track points.
- **Device location plugin** for foreground MVP recording only.
- **No offline map tiles in MVP** unless later field testing proves that trail display without tiles is unusable.

Rationale: The MVP requires reliable local persistence more than rich UI. Flutter remains a good fit for a single developer because it provides one mobile codebase and has official guidance for SQLite-backed persistence.

### Backend and data

- **Supabase Postgres** as the single remote database.
- **PostGIS extension** for geospatial point/line storage, spatial indexes, distance checks, and nearest-trail queries.
- **Supabase Auth** for MVP user identity.
- **Supabase Edge Functions** for write-side operations that need validation, service-role access, and idempotency checks.

Rationale: This avoids a separate Spring Boot service, separate database hosting, Firebase-to-PostGIS mismatch, and custom auth wiring. PostGIS keeps the core route problem in the database where MVP spatial operations are simplest to verify.

### Server logic

Keep server logic deliberately small:

- `upload-session`: accepts a completed session, validates metadata, enforces idempotency, stores accepted/rejected points.
- `get-canonical-trail`: returns latest trail geometry, version, confidence, updated time, and recommendation status.
- `snap-position`: returns nearest canonical trail coordinate, distance, route judgment, and on/off trail judgment. Initial MVP thresholds are `<= 25m` on route, `> 25m and <= 50m` caution, and `> 50m` away from route.
- `recompute-canonical-trails`: manual or scheduled MVP job that creates a simple canonical route from accepted points.

For the first MVP, canonical trail generation should be simple and transparent rather than clever. Prefer deterministic SQL/procedure-based processing or one small worker function before introducing clustering pipelines, HMM, particle filters, or external GIS services.

## What Not To Build Yet

- No Spring Boot API unless Supabase limits become a proven blocker.
- No Kubernetes, message queue, Redis, or separate worker service.
- No offline MBTiles/PMTiles pipeline in the first build.
- No real-time location sharing.
- No community, ranking, or photo AI.
- No complex route inference model before accepted-point ingestion, confidence, and snap-position are working end to end.
- No upload of completed location traces before the user has accepted the MVP upload consent notice.

## No-Base-Trail Inference Algorithm for MVP

For mountains without official/base trail data, the MVP should infer a reference route from user GPS traces using a simple, inspectable grid-and-graph pipeline. The goal is not perfect automatic map inference; the goal is to turn "no trail information" into "confidence-labeled reference route" without overclaiming accuracy.

### 1. Discard way-off points

Clean raw points before they influence route inference:

- **Coordinate validity filter**: reject invalid latitude/longitude ranges and points without usable timestamps.
- **Accuracy filter**: reject or down-weight points with poor device accuracy.
- **Haversine speed filter**: compute speed between consecutive points; reject impossible jumps.
  - Existing requirement baseline: `2.8 m/s` is the hiking outlier threshold.
  - MVP planning recommendation: use `> 5.0 m/s` as hard reject and `2.8-5.0 m/s` as low-quality/down-weighted unless field tests prove stricter rejection is safe.
- **Elevation jump filter**: reject short-interval altitude jumps that are not plausible for walking.
- **Isolated point filter**: reject a point that is far from both neighboring points and is not supported by nearby points from the same session.

### 2. Aggregate points into cells

Convert accepted points into spatial cells:

- Use **H3 grid** or a simple fixed-size grid; choose in `/speckit.plan`.
- Target MVP cell size: approximately `8m-15m`.
- Track per-cell statistics:
  - point count
  - unique session count
  - average/median accuracy
  - average elevation
  - recency
  - entry/exit direction distribution

### 3. Prune weak cells

Remove cells that are unlikely to represent a real walked path:

- Remove cells below minimum session support, e.g. `session_count < 2`, from canonical candidates.
- Remove isolated cells without neighboring candidate cells.
- Down-rank cells dominated by low-quality points.
- Remove shortcut-like cells that only weakly connect two dense areas without repeated session transitions.

### 4. Build a session transition graph

Treat the remaining cells as a graph:

- **Node**: valid spatial cell.
- **Edge**: observed consecutive movement from one cell to another in a session's time-ordered cell sequence.
- **Edge support**: number of sessions that made the transition.
- **Edge cost** should prefer frequently repeated, accurate, physically plausible movement:

```text
edge_cost =
  1 / log(1 + transition_count)
  + accuracy_penalty
  + slope_penalty
  + direction_inconsistency_penalty
```

Edges with only one weak transition should be removed from canonical-route candidates unless the beta dataset is too sparse and the route is explicitly marked low confidence.

### 5. Extract the MVP canonical route

Use a deterministic graph extraction process:

1. Build valid cells from accepted points.
2. Build session transition edges from each session's ordered cell sequence.
3. Remove low-support nodes and edges.
4. Select the largest connected component as the primary candidate network.
5. Identify endpoint candidates from degree-1 cells and high-support boundary cells.
6. Extract the strongest path using weighted shortest path or highest-support path over the graph.
7. Convert cell centers into a LineString.
8. Apply only light smoothing, if needed, and keep raw graph data for debugging.

### 6. Handle branches conservatively

MVP branch policy:

- Select the highest-support branch as the canonical route.
- Keep alternative branches as internal candidates or hide them.
- If multiple branches have similar support, lower confidence instead of forcing a "recommended" route.
- Use branch ambiguity as a confidence penalty.

### 7. Confidence inputs

Confidence should incorporate:

- sample/session count
- transition consistency
- branch ambiguity
- GPS quality
- recency

This keeps no-base-trail output honest: sparse or conflicting data becomes a "reference route"; repeated consistent movement can become a "recommended route" after crossing the confidence threshold.

## `/speckit.plan` Input Draft

Use this as the technical input when running the plan step:

```text
Build the SanDeVentura MVP as an Android-first Flutter mobile app backed by Supabase. Use local SQLite for offline sessions, active-session recovery, and upload queue persistence. Use Supabase Auth for identity, Supabase Postgres with the PostGIS extension for remote hiking sessions, track points, canonical trails, confidence metadata, and nearest-trail spatial queries. Use Supabase Edge Functions for authenticated ingestion, idempotency enforcement, point validation, canonical trail retrieval, and position-to-trail snapping. For mountains without official/base trail data, use a simple accepted-point -> grid cell aggregation -> session transition graph -> low-support pruning -> largest connected component -> weighted path extraction pipeline. Use Haversine speed filtering, accuracy filtering, elevation jump filtering, and isolated point filtering to discard way-off points. Keep map UI minimal and do not include offline tile packaging in MVP unless required by acceptance testing. Defer advanced route inference, community features, ranking, photo AI, and real-time rescue features.
```

## Decision Notes

- **Why not Firebase again**: It does not naturally satisfy the MVP's geospatial canonical-trail and nearest-line query requirements without adding a separate spatial backend.
- **Why not Spring Boot + PostGIS now**: It is technically strong but adds backend hosting, auth integration, deployment, and operational overhead that is not needed for the smallest MVP.
- **Why not React Native**: It is viable, but the MVP's domain risk is offline recording and geospatial backend logic, not UI framework capability. Flutter keeps the mobile choice simple.
- **Why not native Android first**: Native Android is lean for one platform, but it makes later iOS support a rewrite. Flutter is a reasonable minimal compromise for a solo MVP.

## Sources Checked

- Flutter official documentation describes Flutter as a single-codebase, multi-platform app framework.
- Flutter's official SQLite persistence recipe recommends a database for apps that need to persist and query larger local datasets.
- Supabase official docs state each project includes a Postgres database and supports extensions.
- Supabase official PostGIS docs describe PostGIS as enabling geospatial data types, spatial indexes, distance queries, and bounding-box queries.
- Supabase official Edge Functions docs describe TypeScript/Deno server functions for authenticated business logic and local development.
