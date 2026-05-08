# Sprint 7 Route Quality Algorithm Plan

**Goal**: improve canonical route quality and confidence so the product avoids
overconfident guidance before real-device field testing.

## Scope

- Backend route inference only.
- Replay data and tests for route quality.
- Minimal operator-visible metrics needed to debug confidence.

## Specific Steps

1. Add explicit support thresholds for cells and transitions.
2. Prune isolated cells with no supported transitions.
3. Build undirected connected components from supported transitions and select
   the strongest component.
4. Replace greedy path extraction with support-weighted path selection inside
   the strongest component.
5. Add confidence inputs for:
   - distinct session count
   - GPS quality
   - branch ambiguity
   - rejected-point rate
   - evidence recency
6. Make recompute safer by avoiding partial deletion of previous route quality
   data on failure.
7. Extend replay datasets:
   - clean repeated traces
   - sparse single trace
   - noisy low-accuracy trace
   - branch-ambiguous trace
   - stale evidence trace
8. Add Deno and pgTAP tests for confidence labels and route quality metrics.

## Algorithm Contract

These constants are Sprint 7 beta defaults and must be easy to tune later.

| Rule | Value | Purpose |
|------|-------|---------|
| Minimum supported cell point count | `2` | Drop one-off GPS noise cells. |
| Minimum supported cell session count | `1` | Keep single-session reference candidates, but never recommend them. |
| Minimum supported transition count | `1` | Preserve sparse paths for reference routes. |
| Minimum supported transition session count | `1` | Preserve single-session paths for reference routes. |
| Isolated cell pruning | Drop cells not used by any supported transition when there are at least 2 supported transitions | Avoid single noise dots in route lines. |
| `none` route | Fewer than 2 selected line points | Do not fabricate route geometry. |
| `reference` route | Selected line has at least 2 points and confidence `< 0.70` | Cautious guidance only. |
| `recommended` route | Confidence `>= 0.70`, at least 3 distinct sessions, branch ambiguity `<= 0.30`, rejected point rate `<= 0.30`, GPS quality `>= 0.70`, and recency score `>= 0.50` | Prevent single-trace and high-risk recommendations. |

### Component Selection

- Treat supported transitions as undirected edges for component discovery.
- Component score:
  - sum of supported edge `session_count`
  - plus `0.25 * sum(point_count)` for cells in the component
  - plus `0.5 * distinct session count` represented by cells in the component
- Tie-breakers:
  1. higher distinct session count
  2. higher cell count
  3. lexicographically smaller first cell key for deterministic output

### Path Selection

- Path candidates are built inside the selected component.
- Start with the supported edge with the highest `(session_count,
  transition_count)`.
- Extend in both directions by repeatedly choosing the unused adjacent edge with
  the highest score:
  `session_count * 10 + transition_count * 3 - edge_cost`.
- Stop when no unused adjacent edge remains.
- Branches are not forced into the route line; similar-strength branches reduce
  confidence instead.

### Confidence Formula

All scores are clamped to `0..1`.

```text
confidence =
  sessionSupportScore * 0.35 +
  gpsQualityScore * 0.20 +
  transitionConsistencyScore * 0.15 +
  (1 - branchAmbiguityScore) * 0.15 +
  (1 - rejectedPointRate) * 0.10 +
  recencyScore * 0.05
```

Definitions:

- `sessionSupportScore = min(1, distinctSessionCount / 3)`.
- `gpsQualityScore` is the average cell quality score.
- `transitionConsistencyScore = selectedPathEdgeSessionCount /
  max(1, allSupportedEdgeSessionCount)`.
- `branchAmbiguityScore` is the average ratio of second-best outgoing branch
  support to best outgoing branch support for branch nodes.
- `rejectedPointRate = rejectedPointCount / max(1, acceptedPointCount +
  rejectedPointCount)`.
- `recencyScore = 1` when latest accepted evidence is within 30 days of
  `now`; `0.5` within 90 days; `0.2` after 90 days; `0` when no evidence date
  exists.

### Data Sources

- Accepted route points: `accepted_route_points(mountainId)`.
- Session accepted/rejected counts and latest evidence timestamp:
  `route_quality_inputs(mountainId)` added in Sprint 7.
- Tests inject `now` into pure inference code so stale evidence is
  deterministic.

### Recompute Safety

Sprint 7 must not delete the previous usable canonical trail or quality debug
tables before a new route has been fully calculated.

Implementation approach:

1. Calculate route inference result in memory first.
2. Insert the new `canonical_trails` version.
3. Delete and replace `trail_cells` / `trail_cell_transitions` only after the
   canonical insert succeeds.
4. If any debug-table replacement fails, return an error but leave the latest
   canonical trail available.
5. Add a DB or function test proving canonical trail remains available after a
   simulated debug replacement failure where feasible.

This is not full database atomicity, but it removes the current highest-risk
failure mode where debug rows are deleted before new route validity is known.

## Replay Expectations

| Fixture | Expected label | Confidence range | GPS score | Branch score | Notes |
|---------|----------------|------------------|-----------|--------------|-------|
| Clean repeated traces | `recommended` | `>= 0.70` | `>= 0.80` | `<= 0.20` | Three consistent sessions. |
| Sparse single trace | `reference` | `< 0.70` | any | `<= 0.20` | Never recommended. |
| Noisy low-accuracy trace | `reference` | `< clean confidence` | `< 0.60` | any | Accuracy penalty visible. |
| Branch-ambiguous trace | `reference` | `< clean confidence` | `>= 0.70` | `>= 0.30` | Similar branch support lowers confidence. |
| Stale evidence trace | `reference` | `< clean confidence` | any | any | Recency penalty visible. |

## Acceptance Criteria

- Clean repeated traces produce `recommended`.
- Sparse or single traces remain `reference`.
- Branch-ambiguous traces have lower confidence than clean traces.
- Noisy traces lower GPS quality and confidence.
- Stale traces lower recency score and confidence.
- Fewer than 2 selected line points produce `none`.
- Recompute failure does not remove the latest usable canonical route.
- Tests pass:
  - `npm run test:functions`
  - `npm run test:db`
  - `npm run typecheck`

## Deferred

- Real GPS field validation.
- H3 integration.
- Offline map tiles.
- Visual map rendering.
