# Product Requirements Document: SanDeVentura MVP

**Author**: Product/Founder  
**Date**: 2026-05-04  
**Status**: Draft  
**Source Method**: Based on `phuryn/pm-skills` `pm-execution/create-prd` and `write-prd` structure, adapted for product development only.  
**Marketing/GTM Scope**: Excluded. This PRD does not define launch channels, pricing, positioning copy, growth loops, or acquisition strategy.

## 1. Summary

SanDeVentura MVP helps hikers avoid wrong turns on small mountains and informal trails where official trail data may not exist. The product records hikes offline, uploads completed sessions later, turns repeated user traces into confidence-labeled reference routes, and compares the user's current position to the best available representative route.

The MVP is valuable if it can turn "no useful trail information" into "a cautious, confidence-labeled route reference" without pretending that sparse or noisy data is authoritative.

## 2. Contacts

| Name | Role | Comment |
|------|------|---------|
| Product/Founder | Product owner | Owns product scope, safety principles, and beta criteria |
| Engineering | Implementer | Owns technical plan, data model, mobile app, backend, and route inference |
| Beta hikers | Field testers | Validate offline recording, route usefulness, and confusing fork scenarios |

## 3. Background

The original problem comes from ordinary hikes where a person reaches an unclear branch, follows an informal-looking path, and later realizes they left the intended route. This is more likely on small local mountains because official map data may be missing or too coarse.

Existing map apps can help when official trails exist, but they do not fully solve informal trail discovery. SanDeVentura's product bet is that repeated GPS traces from real hikers can become useful route information even when there is no base trail dataset.

Why now:

- Mobile devices can record location locally even when network access is poor.
- A small MVP can store GPS traces, perform basic spatial filtering, and expose a confidence-labeled reference route without building a full GIS platform.
- The first product question is not "Can we build a perfect trail map?" It is "Can we reduce uncertainty at branches enough to be useful?"

## 4. Objective

### Objective

Deliver an MVP that proves hikers can record routes offline and receive useful reference guidance in areas without reliable official trail data.

### Why it matters

For users, the MVP reduces uncertainty during hiking and creates a personal route record. For the product, each completed session improves the future route reference for the same mountain.

### Key Results

| Key Result | Target |
|------------|--------|
| KR1 | A beta user can record a 30-minute airplane-mode hike and recover the session after app restart |
| KR2 | Completed beta sessions upload without duplicate contribution when connectivity returns |
| KR3 | At least three beta mountains can show one of three states: no route, reference route, or recommended route |
| KR4 | For a mountain with a canonical route, position comparison returns nearest route point, distance, and on/off route judgment |
| KR5 | Routes with low data support are shown as reference routes, not recommended routes |

## 5. Target Users and Product Segments

This section is for product development segmentation, not marketing.

### Primary user: local casual hiker

- Walks small or mid-sized mountains.
- Encounters unclear forks or informal paths.
- May not know trail names or official course IDs.
- Needs simple confidence guidance, not expert GIS detail.

### Secondary user: repeat hiker

- Revisits the same mountain.
- Creates higher-value traces over time.
- Benefits from seeing whether the accumulated route has become more reliable.

### Operator user: solo product owner/developer

- Needs enough operational visibility to know whether recording, upload, and route inference are working.
- Needs confidence and rejected-point counts to debug bad route quality.

### Non-target users for MVP

- Rescue teams needing real-time location sharing.
- Hiking communities planning group events.
- Competitive/ranking users.
- Users expecting complete official-grade trail maps.

## 6. Value Propositions

### For hikers

- **Job**: "When I am unsure at a branch, I want to know whether I am still near the route people usually take, so I can avoid a wrong turn."
- **Gain**: A simple reference route and on/off route judgment.
- **Pain avoided**: Following animal paths, maintenance paths, or accidental side paths because the map has no useful trail.

### For repeat users

- **Job**: "When I return to a mountain, I want my previous and other users' traces to make future guidance better."
- **Gain**: The product gets more useful as sessions accumulate.
- **Pain avoided**: Starting from zero every time official trail data is missing.

### For the operator

- **Job**: "When generated routes look wrong, I need to know whether the issue is sparse data, GPS noise, branch ambiguity, or algorithm thresholds."
- **Gain**: Traceable confidence inputs and rejected-point counts.
- **Pain avoided**: Silent bad recommendations.

## 7. Solution

### 7.1 UX and User Flow

1. User selects or confirms the hiking area.
2. User starts a hike.
3. App records location points locally, including when offline.
4. If the app restarts, it restores the active session.
5. User finishes the hike.
6. When online, the app uploads the completed session once.
7. System filters bad points and stores accepted route evidence.
8. System generates or updates a canonical route candidate.
9. User views the route as one of:
   - no route available
   - reference route
   - recommended route
10. At a branch, user compares current position to the route and sees distance/on-route status.
11. Before uploading completed location traces for the first time, user sees and accepts a concise upload consent notice.

### 7.2 Key Features

#### P0 - Must Have

| # | Feature | Product Requirement | Acceptance Criteria |
|---|---------|---------------------|---------------------|
| P0-1 | Offline recording | The user can record a hike without network access | 30-minute airplane-mode recording remains available locally |
| P0-2 | Session restoration | The active session survives app restart | Restart restores the same active session without duplicate session creation |
| P0-3 | Idempotent upload | Completed sessions upload once even after retries | Repeated upload attempts count as one contribution |
| P0-4 | Point validation | Bad points are rejected or down-ranked | Upload result includes accepted/rejected point counts |
| P0-5 | No-base-trail route inference | Accepted traces can create a reference route without official trail data | A mountain can progress from no route to reference route based on repeated traces |
| P0-6 | Confidence labeling | Route reliability is visible to users | Confidence >= 0.70 is recommended; lower confidence is reference or not recommended |
| P0-7 | Position comparison | User can compare current position to canonical route | Result includes nearest route point, distance, and on/off route judgment |
| P0-8 | Upload consent and privacy baseline | Location traces are uploaded only after consent and are not exposed as raw paths to other users | Upload request includes consent version; hiker APIs expose canonical routes and snap results, not raw user traces |

#### P1 - Should Have

| # | Feature | Product Requirement | Acceptance Criteria |
|---|---------|---------------------|---------------------|
| P1-1 | Basic operator metrics | Operator can inspect MVP health | Upload success, rejected points, trail served, and snap requested can be counted |
| P1-2 | Route-quality debug view | Operator can diagnose bad canonical routes | Shows session count, branch ambiguity, GPS quality, and confidence inputs |
| P1-3 | Conservative branch handling | Product avoids false certainty at forks | Similar-strength branches lower confidence instead of forcing recommendation |

#### P2 - Future

| # | Feature | Product Requirement | Acceptance Criteria |
|---|---------|---------------------|---------------------|
| P2-1 | Official trail ingestion | Official trail data can improve guidance where available | Official route can be used as a prior but does not override observed evidence blindly |
| P2-2 | Offline map tiles | User can view base map tiles without network | Field test proves tile absence blocks MVP usefulness |
| P2-3 | Reviews/photos/community | Users can add richer hiking context | Separate PRD and spec define consent, moderation, and privacy rules |

### 7.3 Technology

Technology decisions are not part of `spec.md`, but the current MVP implementation recommendation is:

- Android-first Flutter app.
- Local SQLite for offline sessions and upload queue.
- Supabase Auth for identity.
- Supabase Postgres with PostGIS for spatial storage and nearest-route queries.
- Supabase Edge Functions for idempotent upload, validation, canonical route retrieval, and snap-position logic.

### 7.4 No-Base-Trail Algorithm

For mountains without official trail data, MVP route inference should use an inspectable pipeline:

1. Clean raw points using coordinate validity, accuracy, Haversine speed, elevation jump, and isolated point filters.
2. Aggregate accepted points into H3 or fixed-size cells of roughly 8m-15m.
3. Track point count, unique session count, average accuracy, recency, elevation, and entry/exit direction per cell.
4. Prune low-support or isolated cells.
5. Build a session transition graph from time-ordered cell sequences.
6. Remove weak edges and select the largest connected component.
7. Extract the strongest path using weighted shortest path or highest-support path.
8. Convert cell centers to a LineString.
9. Penalize confidence when branches have similar support.

### 7.5 Assumptions

- Users will explicitly start and finish hikes.
- Local recording is useful even when no canonical route exists yet.
- A reference route with honest confidence is better than no information.
- MVP users will tolerate basic route visualization if the safety signal is clear.
- Route generation should be explainable before it becomes advanced.

### 7.6 Privacy and Retention Baseline

- Completed sessions contain sensitive location traces and require upload consent before the first sync.
- Users can keep completed sessions local by not syncing them.
- Hiker-facing route guidance must not expose another user's raw path or identity.
- Remote accepted points are used for MVP beta route learning; rejected-point storage should prefer structured summaries over full raw payloads.
- MVP event payloads must not store full raw coordinate arrays.
- Initial retention policy is defined in `privacy-retention.md`.
- Initial snap-position thresholds are `<= 25m` on route, `> 25m and <= 50m` caution, and `> 50m` away from route.

## 8. Release

### Version 0 - SDD and validation setup

- Finalize PRD, spec, minimal tech recommendation, and plan inputs.
- Confirm beta mountain selection criteria.
- Confirm privacy constraints for raw location data using `privacy-retention.md` as the MVP baseline.

### Version 1 - Minimal field loop

- Offline recording.
- Session restoration.
- Completed session upload.
- Point validation.
- Basic remote storage.

### Version 2 - No-base-trail reference route

- Accepted-point cell aggregation.
- Session transition graph.
- Low-support pruning.
- Canonical LineString generation.
- Confidence calculation.

### Version 3 - User guidance loop

- Route state display: no route, reference route, recommended route.
- Position comparison.
- Distance/on-route judgment.
- Minimal operator metrics.

### Non-goals for MVP release

- Launch marketing.
- Pricing or monetization.
- Growth loops.
- Social/community features.
- Real-time rescue.
- Photo AI.
- Production-grade official trail ingestion.

## Open Questions

| Question | Owner | Timing |
|----------|-------|--------|
| What exact field-test mountains should be used for beta? | Product/Founder | Before Version 1 field test |
| Should H3 or fixed-size grid be used for the first inference implementation? | Engineering | During technical plan |
| What minimum support should move a route from no route to reference route? | Product/Engineering | During Version 2 validation |
