# Local Env and Secret Handling

SanDeVentura keeps real local environment files and secret files out of git.
Only `.example` templates are committed.

## Rules

- Store connection values in ignored environment files.
- Store credentials and signing material in ignored secret files.
- Commit only placeholder templates such as `.env.example` or
  `.secrets.example`.
- Never commit Supabase service role keys, JWT secrets, passwords, private
  keys, tokens, or production URLs with credentials.

## Environment Files

Use env files for non-secret connection/configuration values:

- parent: `.env.local`
- mobile: `.env.local` or `.env.local.json`
- web: `.env.local`
- Supabase functions: `supabase/.env.local`

Examples are available at:

- `.env.example`
- `mobile/.env.example`
- `mobile/.env.example.json`
- `web/.env.example`
- `web/supabase/.env.example`

Flutter can consume the JSON example after copying it:

```powershell
flutter run --dart-define-from-file=.env.local.json
```

For Android Emulator local Supabase, use the emulator host alias:

```powershell
flutter run --dart-define=SUPABASE_FUNCTIONS_URL=http://10.0.2.2:54321/functions/v1
```

For a physical Android device, or when explicitly testing localhost through
ADB, keep `adb reverse` active and use `127.0.0.1`:

```powershell
adb reverse tcp:54321 tcp:54321
flutter run --dart-define=SUPABASE_FUNCTIONS_URL=http://127.0.0.1:54321/functions/v1
```

## Secret Files

Use ignored secret files for credentials:

- `.secrets/local.secrets`
- `mobile/.secrets/local.secrets`
- `web/.secrets/local.secrets`

Examples are available at:

- `.secrets.example`
- `mobile/.secrets.example`
- `web/.secrets.example`

Supabase Edge Function local serving should read secrets from an ignored env
file:

```powershell
npx supabase functions serve --no-verify-jwt --env-file supabase/.env.local
```

## Current Local Values

- `SUPABASE_FUNCTIONS_URL` is connection configuration, not a secret.
- `SUPABASE_URL` is connection configuration, not a secret.
- `SPRINT2_DEV_USER_ID` is a temporary dev identifier, not a credential.
- `SUPABASE_SERVICE_ROLE_KEY` is a secret and must only live in ignored local
  files or shell environment variables.
