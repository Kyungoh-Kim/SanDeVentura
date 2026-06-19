# Codex Agent Rules

## Commit Message Conventions

Follow these rules for every commit in this workspace, including the
parent folder and independent `mobile` and `web` repositories.

### Basic Rules

1. Separate subject and body with one blank line.
2. Keep the subject line 50 characters or less.
3. Capitalize the first letter of the subject.
4. Do not end the subject with a period.
5. Use the imperative mood in the subject, for example `Add`, not `Added`.
6. Wrap body lines at 72 characters.
7. In the body, explain what and why, not only how.

### Structure

```text
<type>: <subject>

<body>

<footer>
```

Subject is required. Body and footer are optional when the subject is
enough.

### Types

| Type | Use |
|------|-----|
| `feat` | New feature or behavior change to meet requirements |
| `fix` | Bug fix |
| `build` | Build system or dependencies |
| `chore` | Misc maintenance, such as package manager or `.gitignore` |
| `ci` | CI configuration |
| `docs` | Documentation or comments |
| `style` | Formatting or style only, with no logic change |
| `refactor` | Refactor without behavior change |
| `test` | Tests |
| `release` | Version release |

### Language

Prefer English for `type`, subject, and body so logs and tooling stay
consistent. Project docs for humans may still use Korean elsewhere.



## Agent guidance — repository specific notes

The section above (commit conventions) is the canonical, unchanged baseline.
Additions below are project-specific rules that help an automated coding agent be
productive in this workspace. Keep these concise and actionable; follow them
exactly when making edits or proposing changes.

### Repository layout and submodules

- This repository is a parent workspace. The `mobile/` and `web/` folders are
  Git submodules (see `README.md`). Do not edit files inside those submodule
  trees from the parent repository — open and commit changes inside the
  submodule repository instead.
- Commands:
  - Clone with submodules: `git clone --recurse-submodules <url>`
  - Update submodules: `git submodule update --init --recursive`

### Submodule pointer updates

- When updating a submodule pointer in this parent repo, use the commit format
  shown here to make the change discoverable:

  feat: Update mobile submodule — short summary

  One-line explanation of why the submodule pointer was moved.

  Example subject from history: `feat: Update mobile submodule — session delete + details route map`

### File-work rules (surgical, project-specific)

- Do not modify `web/supabase/migrations/` file numbering. New migrations must
  use the next numeric prefix and be single-purpose (one schema/policy/task
  per file).
- Edge Functions: create new functions under `web/supabase/functions/<name>/index.ts`.
  - Put shared helpers in `web/supabase/functions/_shared/`.
  - Use the project response formatter in `web/supabase/functions/_shared/response.ts`.
  - All functions must handle OPTIONS (CORS preflight).

### Coding and commit principles for agents

- Minimize comments: prefer clear code; add a one-line `WHY` comment only when
  the reason is not obvious from the code.
- Security: avoid introducing OWASP Top 10 risks (SQL injection, XSS,
  command-injection). Prefer parameterized queries and sanitized inputs when
  touching DB or request handlers (see `web/` code that uses Supabase clients).
- Minimal implementation: implement the smallest change that satisfies the
  requirement; do not add unrelated abstractions.

### Local development quick commands (examples)

- Mobile (Android-first Flutter):
  - Emulator: `cd mobile` then `flutter run -d emulator-5554 --dart-define=DOTENV=.env.local`
  - Physical device: `flutter run -d <device-id> --dart-define=DOTENV=.env.dev`
  - Tests: `cd mobile` then `flutter test`

- Web / Supabase (PowerShell examples):
  - Start local Supabase (recommended): `cd web/supabase` then `supabase start`
  - Serve functions locally (dev): from `web` run
	`npx supabase functions serve --no-verify-jwt --env-file supabase/.env.local`
  - Reset local DB (destructive): `supabase db reset`

### Migrations and destructive changes

- Keep each migration single-purpose. Mark irreversible DDL (DROP TABLE/COLUMN)
  explicitly in the migration file and call out the impact in the commit body.

### Language for agent replies and PRs

- Use English in commit messages, branch names, and code comments that affect
  build/test tooling. Project documentation or PR discussions may contain
  Korean; reference existing docs for context.

---

End of project-specific additions. If a rule conflicts with the baseline above,
follow the baseline unless there is an explicit, documented exception in this
repository's other agent files (e.g., `AGENTS_v2.md`, `agent.md`).
