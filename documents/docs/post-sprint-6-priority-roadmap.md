# Post Sprint 6 Priority Roadmap

**Context**: No physical Android device is currently available. Real-device
field validation remains required before beta, but it should not block local
product quality work.

## Revised Priority

### P0 Now: Route Quality Algorithm

Improve the generated route so it is safer and more explainable before field
testing.

- Add low-support and isolated-cell pruning.
- Select the largest connected route component instead of relying on a greedy
  path only.
- Penalize confidence for branch ambiguity, poor GPS quality, stale evidence,
  and high rejected-point rate.
- Preserve the previous canonical trail when recompute fails.
- Add replay and DB/function tests for clean, noisy, sparse, and branchy traces.

### P0 Now: Hiker Guidance Design

Make route guidance states clear enough to avoid false certainty.

- Strengthen no-route, reference-route, and recommended-route states.
- Show route version, updated time, confidence, and evidence count.
- Show branch ambiguity/caution language when confidence is low.
- Surface snap distance and judgment with explicit thresholds.
- Add basic route geometry preview or route summary if full map rendering stays
  out of scope.

### P1 Now: Operator Quality Design

Turn operator views from static fixtures into live quality inspection.

- Query live route coverage from `operator_route_coverage`.
- Add route quality detail: session count, GPS score, ambiguity, rejected count,
  last recompute time, and route state.
- Add replay/smoke evidence panels for local beta readiness.
- Keep raw point tables inaccessible to normal clients.

### Beta Gate: Blocked Until Device or Staging Access Exists

- Real Android 30-minute mountain field test.
- Device-specific battery and background behavior.
- Physical-device staging upload retry.
- Final APK/AAB release signing.

These are not current local-development blockers, but they remain beta launch
gates. Sprint 9 should start only when hosted Supabase credentials or an
Android test device is available.

## Recommended Next Sprints

1. **Sprint 7: Route Quality Algorithm**
   - Hardens inference and confidence.
   - Adds stronger replay tests.
   - Makes recompute safer.

2. **Sprint 8: Guidance and Operator Design**
   - Improves mobile route UX.
   - Connects operator dashboard to live data.
   - Adds quality detail screens.

3. **Sprint 9: Staging and Beta Evidence**
   - Starts when hosted Supabase credentials or Android device access is
     available.
   - Covers deployment, access validation, and field evidence.
