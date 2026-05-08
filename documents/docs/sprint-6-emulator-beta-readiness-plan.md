# Sprint 6 Emulator and Beta Readiness Plan

**Goal**: remove the remaining local emulator friction and package the
pre-beta evidence needed before a real Android/staging field test.

## Scope

- Make Android Emulator networking work with `10.0.2.2` without requiring
  `adb reverse` for upload, route retrieval, and snap-position.
- Keep `adb reverse` documented as an alternative for real devices or explicit
  localhost testing.
- Add a repeatable local smoke path for Supabase env setup, route replay,
  recompute, upload retry, and route guidance.
- Add a beta mountain selection/evidence template for the required
  three-mountain coverage check.
- Keep real-device field execution and hosted Supabase deployment as explicit
  non-local validation tasks.

## Specific Steps

1. Remove mobile dependency-injection endpoint host rewriting that turns
   `10.0.2.2` into `127.0.0.1`.
2. Change upload client fallback behavior so configured `10.0.2.2` is tried
   first; `127.0.0.1` is only a secondary fallback for explicit `adb reverse`
   workflows.
3. Add mobile tests proving configured `10.0.2.2` function URLs are preserved
   and upload endpoint candidates try `10.0.2.2` before `127.0.0.1`.
4. Update `mobile/.env.example`, `mobile/.env.example.json`, and
   `documents/docs/local-env-and-secrets.md` so `10.0.2.2` is the default
   Android Emulator path and `adb reverse` is documented as an alternative.
5. Add or update local emulator runbook commands for Supabase functions, replay
   data, upload retry, route recompute, and Flutter execution.
6. Add beta mountain coverage template and evidence fields while separating
   local setup checks from real-device/staging evidence.
7. Run the available local check set. Note that `supabase:reset` recreates the
   local database.
8. Validate plan and result with read-only subagents.

## Test Scenario I Cannot Perform

Real Android device and hosted Supabase staging smoke:
deploy functions/migrations to staging, configure a physical Android device
against the staging functions URL, record in weak connectivity, upload with
retry, recompute a route, and capture route guidance evidence for three named
beta mountains.
