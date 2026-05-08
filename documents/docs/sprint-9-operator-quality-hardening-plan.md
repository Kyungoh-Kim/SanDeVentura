# Sprint 9 Operator Quality Hardening Plan

**Goal**: make the operator web surface useful for local beta judgment while
hosted staging credentials and physical-device field evidence remain blocked.

## Scope

- Web operator dashboard only.
- Supabase read models and database views for local quality inspection.
- No mobile feature changes unless a contract bug is discovered.

## Constraint

The post-Sprint 6 beta gate still requires hosted Supabase access or an
Android field-test device. Sprint 9 must not pretend to complete that gate.
It should instead make local operator quality evidence easier to inspect.

## Specific Steps

1. Database read models:
   - add `operator_quality_summary` for upload success, queued uploads, route
     coverage, snap request count, and trail served count
   - add `operator_route_quality_detail` with route state, confidence,
     session count, GPS score, branch ambiguity, accepted/rejected point counts,
     latest evidence timestamp, and updated time
   - calculate latest evidence from accepted track points and rejected point
     timestamps
   - keep raw point tables blocked by existing RLS policies
   - do not expose raw coordinates, geometry, or route GeoJSON from the quality
     detail view

2. Web data layer:
   - add fetch functions for summary metrics and route quality detail
   - preserve static fallback rows when Supabase env vars are not configured
   - keep error states visible without blocking the whole operator app

3. Operator Overview:
   - replace static metrics with live `operator_quality_summary`
   - show upload success, queued uploads, route coverage, snap requests, and
     trail served counts
   - preserve `null` route coverage as no-data instead of converting it to zero

4. Operator Quality:
   - replace static route counts with live `operator_route_quality_detail`
   - show recommended/reference/no-route counts
   - add a detail table for confidence, GPS, ambiguity, accepted/rejected
     evidence, and latest evidence timestamp
   - surface beta gate language clearly: staging/device evidence remains
     blocked, local quality evidence is available
   - use live `operator_route_quality_detail` when Supabase is configured
   - keep fallback rows and visible error notice when live reads fail

5. Tests and validation:
   - add pgTAP coverage for the new views
   - run `npm run test:db`
   - run `npm run test:functions`
   - run `npm run typecheck`
   - run `npm run build`

## Acceptance Criteria

- Overview reads live metrics when Supabase is configured and otherwise uses
  local fallback metrics.
- Quality page exposes route-quality detail without raw trace access.
- Rejected point counts and latest evidence time are visible per mountain.
- Latest evidence includes accepted track points and rejected point timestamps.
- Operator copy does not claim beta readiness without staging/device evidence.
- Existing route map behavior from Sprint 8 remains intact.

## Deferred

- Hosted staging smoke test.
- Physical Android field validation.
- Production operator auth and role-gated routes.
- Offline tile packaging.
