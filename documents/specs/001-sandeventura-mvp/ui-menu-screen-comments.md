# SanDeVentura MVP UI Menu and Screen Comments

**Purpose**: Confirm that MVP screen designs use matching menu icons, consistent components, and feature comments grounded in the active SDD scope.

**Source of truth**: `prd.md`, `spec.md`, `plan.md`.

**Deprecated input**: Existing Flutter/Firebase prototype screens and menus are not active product requirements.

## MVP Navigation

Use four primary menus for the MVP app surface.

| Menu | Icon | Primary user | Scope |
|------|------|--------------|-------|
| Record | hiking / record-circle | Hiker | Start, pause, resume, finish one active offline hiking session |
| Route | route / map-pin | Hiker | View canonical trail state, confidence, and current-position comparison |
| Sessions | list-check / cloud-upload | Hiker | Review local/completed sessions and upload/sync state |
| Quality | activity / gauge | Operator | Inspect MVP health signals and route-quality inputs |

Mobile apps should use these as bottom navigation items. Tablet and web surfaces may use the same menu order in a rail or sidebar.

## Shared UI Components

Use these components consistently across screens.

| Component | Usage |
|-----------|-------|
| App header | App name, current mountain or screen title, connectivity state when relevant |
| Bottom navigation / rail / sidebar | Same four menu labels and icons in the same order |
| Status chip | Short state labels such as Offline, Recording, Recovered, Uploaded, Reference route |
| Primary action button | Main next action only, such as Start hike, Finish, Sync, Compare |
| Secondary action button | Pause, Resume, Retry, View detail |
| Metric tile | Distance, point count, upload success, accepted points, rejected points |
| Map panel | Route trace, canonical trail, current position, nearest route point, ambiguous branch |
| Confidence indicator | Numeric score plus wording: no route, reference route, recommended route |
| Warning banner | Permission blocker, location disabled, no route ready, low confidence |
| Empty state | No active session, no completed sessions, no representative trail ready |

Keep copy short and operational. Do not add marketing messages, social prompts, ratings, photos, rankings, rescue claims, or emergency dispatch language in MVP screens.

## Screen Comments

### Record

**Feature comment**: This screen contains the offline recording loop. It lets the user start, pause, resume, and finish one active hike while location points are stored locally, including when network access is unavailable.

Required visible elements:

- Selected `Record` menu icon and label.
- Current recording state: idle, recording, paused, finished, or recovered.
- Offline/local persistence indicator.
- Timer or elapsed time.
- Distance and point count.
- Location accuracy when available.
- Start, Pause, Resume, and Finish actions.
- Permission or location-service blocker message when recording cannot start.
- Recovered-session banner after app restart when applicable.

Do not include route recommendation, social sharing, reviews, photos, or rankings on this screen.

### Route

**Feature comment**: This screen contains user guidance for the selected mountain. It shows whether a representative trail is unavailable, reference-only, or recommended, and compares the user's current position to the canonical route.

Required visible elements:

- Selected `Route` menu icon and label.
- Mountain selection or confirmed mountain area.
- Route state: No route, Reference route, or Recommended route.
- Confidence score and confidence wording.
- Canonical trail map line when available.
- Current position marker.
- Nearest route point and distance.
- On route or Away from route judgment.
- Version and updated time for the canonical trail.
- Ambiguous-branch indication when branch support is similar.
- No-route empty state that clearly says no representative trail is ready.

Do not claim official-grade navigation, emergency status, or rescue capability.

### Sessions

**Feature comment**: This screen contains completed-session management. It shows local sessions, upload queue state, retry status, idempotent upload identity, and accepted/rejected point counts after server validation.

Required visible elements:

- Selected `Sessions` menu icon and label.
- Local completed session list.
- Upload queue summary.
- Sync or Retry action.
- Upload state: Local, Uploading, Uploaded, Failed, or Retry.
- Stable client session key or shortened key display for duplicate-safe upload.
- Accepted and rejected point counts after upload.
- Start/end time, distance, and point count for each session.
- Empty state for no completed sessions.

Do not include review writing, photo upload, comments, likes, or social feed behavior.

### Quality

**Feature comment**: This screen contains operator visibility for the MVP. It helps the solo operator understand whether recording, uploads, route availability, confidence labeling, point validation, and snap-position usage are working.

Required visible elements:

- Selected `Quality` menu icon and label.
- Upload success metric.
- Accepted and rejected point metrics.
- Route coverage across at least three beta mountains.
- Trail state counts: No route, Reference route, Recommended route.
- Snap requests count.
- Session count per mountain.
- Confidence inputs: GPS quality, branch ambiguity, support count, recency.
- Debug map or table showing accepted cells, rejected points, canonical route, and ambiguous branches.

This screen may be web/tablet first. Keep it utilitarian and avoid user-facing social/admin features outside MVP scope.

## Cross-Platform Rules

- Android: bottom navigation for the four menus; Material 3 buttons, chips, cards, and snackbars.
- iOS: same menu names and order; use iOS-safe spacing and native-feeling touch targets.
- Tablet: navigation rail or sidebar; preserve menu order and icons.
- Web/operator: sidebar is acceptable; preserve `Quality` as an operator-focused area.
- Touch targets should remain at least 44 px high on mobile.
- Do not change route-state colors across platforms.

## State Color Guidance

| State | Color role |
|-------|------------|
| Recording / on route / recommended | Forest green |
| Offline / reference route / ambiguous branch / retry | Amber |
| Away from route / rejected / blocked | Red |
| Local / neutral / no route | Slate or gray |
| Current position | Blue accent |

Do not use color alone. Pair every state color with text and iconography.

## MVP Exclusions Checklist

The following should not appear in MVP UI comments or screens:

- Reviews and ratings.
- Photo upload.
- Hiking groups or community feed.
- Ranking, mileage competition, badges, or leaderboards.
- Real-time rescue, emergency dispatch, or command-center monitoring.
- Marketing landing-page copy.
- Official-grade route certainty when confidence is low.

