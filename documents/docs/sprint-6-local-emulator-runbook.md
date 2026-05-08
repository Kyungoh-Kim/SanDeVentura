# Sprint 6 Local Emulator Runbook

This runbook verifies the MVP loop on the Android Emulator without
`adb reverse`. Use `10.0.2.2` as the emulator's alias for the host machine.

## 1. Start Supabase

```powershell
cd C:\dev\projects\SanDeVentura\web
npm run supabase:reset
Copy-Item supabase\.env.example supabase\.env.local
```

Update `supabase/.env.local` with the local Secret key printed by
`npx supabase status`, then serve functions:

```powershell
npm run supabase:functions
```

## 2. Seed Route Replay Data

In a second terminal:

```powershell
cd C:\dev\projects\SanDeVentura\web
npx supabase db query -f supabase/replay/sprint4_route_replay.sql

Invoke-RestMethod -Method Post `
  -Uri http://127.0.0.1:54321/functions/v1/recompute-canonical-trails `
  -ContentType application/json `
  -Body '{"mountainId":"beta-mountain","mode":"single"}'
```

Expected: `cellCount` is greater than `0` and route state is not `none`.

## 3. Run Mobile on Android Emulator

```powershell
cd C:\dev\projects\SanDeVentura\mobile
flutter run --dart-define=SUPABASE_FUNCTIONS_URL=http://10.0.2.2:54321/functions/v1
```

Expected:

- `Sessions` upload Retry does not show `Connection refused`.
- `Route` refresh shows the seeded route state.
- `Compare` uses the emulator's current location.

## 4. Optional ADB Reverse Path

Use this only for a physical Android device or explicit localhost testing:

```powershell
adb reverse tcp:54321 tcp:54321
flutter run --dart-define=SUPABASE_FUNCTIONS_URL=http://127.0.0.1:54321/functions/v1
```

## 5. Evidence to Record

- Supabase function URL used by the mobile build.
- Upload status and accepted/rejected counts.
- Route state, confidence, and version.
- Snap judgment and distance.
- Any socket error text, if present.

