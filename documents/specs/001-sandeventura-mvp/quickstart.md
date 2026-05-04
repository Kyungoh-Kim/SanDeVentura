# Quickstart: SanDeVentura MVP Development

## Prerequisites

- Flutter SDK stable channel
- Android Studio or VS Code
- Android emulator and one real Android device
- Docker-compatible runtime
- Node.js/npm for Supabase CLI installation
- Supabase CLI
- Deno CLI
- Git

## Local Setup

```powershell
git clone <repo-url> SanDeVentura
cd SanDeVentura

# Supabase
npm install supabase --save-dev
npx supabase init
npx supabase start
npx supabase db reset

# Flutter
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

## Daily Development Commands

```powershell
# Start backend
npx supabase start
npx supabase functions serve

# Mobile checks
cd apps/mobile
flutter analyze
flutter test
flutter run

# Database tests
npx supabase test db

# Edge Function tests
deno test supabase/functions
```

## Manual MVP Smoke Test

1. Start local Supabase.
2. Launch Android app.
3. Sign in with beta/dev user.
4. Start a hike.
5. Toggle airplane mode.
6. Record points for a short test route.
7. Force-close and reopen the app.
8. Confirm the same session is restored.
9. Finish session.
10. Confirm upload consent prompt appears before first sync.
11. Restore network.
12. Upload session.
13. Confirm accepted/rejected point counts.
14. Recompute canonical trail.
15. Request canonical trail.
16. Request snap-position for current coordinate.
17. Confirm snap-position returns on route, caution, or away from route using the MVP thresholds.
