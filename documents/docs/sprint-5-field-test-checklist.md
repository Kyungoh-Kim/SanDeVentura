# Sprint 5 Field Test Checklist

Use this checklist for the first controlled Android beta field test.

## Before Leaving

- Install the latest debug or beta APK on the Android test device.
- Confirm local recording starts with location permission granted.
- Confirm battery saver is off for the test app.
- Confirm the test mountain is mapped to `beta-mountain` or the intended
  staging `mountainId`.
- Confirm upload consent can be accepted from the Sessions screen.
- Confirm local or staging Supabase function URLs are configured.

## Offline Recording and Recovery

- Put the device in airplane mode.
- Start recording from the Record tab.
- Walk for at least 30 minutes.
- Force close the app.
- Reopen the app and verify the same session is restored.
- Add more movement and verify point count increases.
- Finish the session and verify it appears in Sessions.

## Upload and Duplicate Safety

- Restore connectivity.
- Accept upload consent if it has not already been accepted.
- Enable automatic upload or use Retry/Sync.
- Verify the session reaches uploaded state.
- Record the remote accepted point count and rejected point count.
- Trigger Retry again and verify the backend reports duplicate success rather
  than another contribution.
- Confirm accepted and rejected point counts are visible.
- Upload a trace with at least one intentionally invalid/rejected test point in
  local or staging replay and confirm rejected count and reason are visible to
  the tester without exposing another user's raw trace.

## Route Recompute and Guidance

- Recompute canonical trails for the test `mountainId`.
- Open Route guidance.
- Verify no route, reference route, or recommended route wording matches the
  returned confidence.
- Record route state, confidence, route version, updated time, session count,
  branch ambiguity score, and GPS quality score.
- Tap Compare at a known point on the trail and verify `on_route`.
- Record the returned distance in meters and trail version.
- Move to a nearby ambiguous/fork area and verify `caution` when appropriate.
- Record the returned distance in meters and judgment.
- Move clearly away from the route and verify `away_from_route`.
- Record the returned distance in meters and judgment.

## Three-Mountain Coverage

- Select three beta `mountainId` values before beta launch.
- For each mountain, record current coverage state: no route, reference route,
  or recommended route.
- Confirm at least one mountain can be recomputed from accepted traces.
- Confirm no-route mountains show no fabricated guidance.
- Confirm route state changes are visible in the operator Routes screen or the
  `operator_route_coverage` view.

## Evidence to Capture

- Device model, OS version, app build, and test date.
- Session id, mountain id, started/ended timestamps, and local point count.
- Upload status, accepted/rejected point counts, and duplicate retry status.
- Canonical route version, confidence, updated time, and route state.
- Snap distances and judgments for on-route, caution, and away probes.
- Screenshots or logs for any stop condition.

## Stop Conditions

- Stop the field test if active session state is lost.
- Stop if duplicate upload creates an additional canonical contribution.
- Stop if confidence below 0.70 is labeled recommended.
- Stop if snap guidance claims emergency/rescue status.
