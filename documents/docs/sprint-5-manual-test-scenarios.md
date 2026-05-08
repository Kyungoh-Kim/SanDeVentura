# Sprint 5 Manual Test Scenarios

## Scenario 1: Airplane-Mode Recovery

1. Start a recording with connectivity available.
2. Enable airplane mode.
3. Record for 30 minutes.
4. Force close and reopen the app.
5. Expected: the same active or paused session is restored and new points append
   to that session.

## Scenario 2: Upload Consent Gate

1. Finish a local session.
2. Keep upload consent unaccepted.
3. Try automatic upload and manual Retry.
4. Expected: upload is blocked until consent is accepted.

## Scenario 3: Duplicate Upload

1. Upload a completed session.
2. Retry the same local session.
3. Expected: backend returns duplicate success and accepted point totals do not
   increase as a new contribution.

## Scenario 4: Low-Confidence Route Wording

1. Seed or upload only one accepted trace.
2. Recompute canonical trails.
3. Open Route guidance.
4. Expected: the route is labeled reference, not recommended.

## Scenario 5: Fork Position Judgment

1. Load a canonical trail with a known nearby fork.
2. Compare current position on the route, near the fork, and clearly away from
   the route.
3. Expected: results are `on_route`, `caution`, and `away_from_route` using the
   25 m and 50 m thresholds.

## Scenario 6: No-Route State

1. Use a mountain id with no canonical trail.
2. Open Route guidance or call `get-canonical-trail`.
3. Expected: route state is `none`, no GeoJSON is fabricated, and Compare is
   disabled or returns a no-route error.

## Scenario 7: Invalid Point Rejection

1. Upload or replay a completed session that includes one invalid coordinate,
   high-accuracy-noise point, or implausible speed point.
2. Expected: valid points are accepted, invalid points are rejected with a
   reason, and the session response reports both counts.

## Scenario 8: Event and Privacy Payload Spot Check

1. Retrieve a canonical trail.
2. Request snap-position.
3. Inspect `mvp_events`.
4. Expected: `trail_served` and `snap_requested` exist, event payloads contain
   state/version/judgment buckets, and no full raw coordinate arrays are stored.
