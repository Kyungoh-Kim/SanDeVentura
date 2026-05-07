# Sprint 4 Beta Hardening Plan

**Goal**: make the route-learning loop inspectable and reliable enough for a
first controlled beta build.

## Specific Steps

1. Add route quality DB helpers for operator-visible route coverage.
2. Add operator read-model fixtures and UI states for no/reference/recommended
   coverage.
3. Add replay seed data that exercises route inference, ambiguity, and snap
   thresholds.
4. Add smoke scripts and test notes for local Supabase reset, recompute, trail
   retrieval, and snap-position.
5. Add structured MVP events for route served and snap requested.
6. Run available automated checks and document local tooling blockers.

## Test Scenario I Cannot Perform

Controlled beta staging smoke on hosted Supabase: deploy migrations/functions,
upload the replay dataset through a staging mobile build, run recompute, and
verify operator coverage from a non-service-role account.

