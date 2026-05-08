# Sprint 3 Reference Route and Guidance Plan

**Goal**: repeated accepted traces produce a confidence-labeled canonical route,
and the mobile app can compare the current position against that route.

## Specific Steps

1. Implement deterministic fixed-grid route inference from accepted
   `track_points`.
2. Persist route cells, cell transitions, and a versioned canonical LineString.
3. Calculate confidence from session support, GPS quality, and branch
   ambiguity.
4. Implement `get-canonical-trail` with `none`, `reference`, and
   `recommended` route states.
5. Implement `snap-position` with the MVP 25 m / 50 m thresholds.
6. Replace mobile guidance stubs with API clients, controller state, and route
   status UI.
7. Add Deno, DB, and Flutter tests for route retrieval and snap judgment.

## Test Scenario I Cannot Perform

Real mountain validation with repeated GPS traces from the same beta mountain:
record at least three real hikes over the same trail, upload them, recompute
the route, then verify in the field that snap guidance reports `on_route`,
`caution`, and `away_from_route` at actual trail forks.

