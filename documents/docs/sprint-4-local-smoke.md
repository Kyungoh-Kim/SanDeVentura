# Sprint 4 Local Smoke

Run after sprint 3 route functions are implemented.

```powershell
npm run supabase:reset
npx supabase db query -f supabase/replay/sprint4_route_replay.sql
npm run supabase:functions
```

1. Reset local Supabase from an empty state.
2. Load `web/supabase/replay/sprint4_route_replay.sql`.
3. Serve all route functions with `npm run supabase:functions`.
4. Recompute `beta-mountain`.
5. Retrieve `get-canonical-trail` and confirm route state is `recommended`.
6. Call `snap-position` near the replay line and confirm `on_route`.
7. Call `snap-position` with the mid-distance replay probe and confirm
   `caution`.
8. Call `snap-position` farther away and confirm `away_from_route`.
9. Recompute `branch-test-mountain` and confirm branch ambiguity lowers
   confidence relative to the clean replay route.
10. Open the operator web app and confirm no/reference/recommended examples are
   visible in the Routes and Quality screens.

## Cannot Perform Here

Hosted staging deployment and non-service-role operator access validation
require project credentials and a deployed Supabase environment.
