# SanDeVentura

Parent workspace repository for the SanDeVentura MVP.

This repository owns:

- `documents/`: SDD, PRD, specs, plans, design references, and
  implementation guidance.
- `mobile/`: Git submodule pointing to the Android-first Flutter mobile app.
- `web/`: Git submodule pointing to the operator web dashboard and Supabase
  backend workspace.

Clone with submodules:

```powershell
git clone --recurse-submodules https://github.com/Kyungoh-Kim/SanDeVentura.git
```

Update submodules:

```powershell
git submodule update --init --recursive
```

