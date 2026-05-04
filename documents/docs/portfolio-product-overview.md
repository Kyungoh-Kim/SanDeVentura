# SanDeVentura Portfolio Brief

**Purpose**: Job-search and interview portfolio page  
**Project Type**: Product development case study, MVP planning, geospatial mobile service  
**Status**: SDD baseline and MVP planning completed  
**Last Updated**: 2026-05-04  
**Notion Page**: https://www.notion.so/35613c20d71c81299a8fd685f06a06bb

## 1. Product Summary

SanDeVentura is a hiking safety and route-learning MVP for small mountains and informal trails where official trail data may be missing or unreliable.

The product records hiking traces offline, uploads completed sessions later, filters noisy GPS points, and turns repeated user movement into confidence-labeled reference routes. Its core value is helping hikers answer a simple question at confusing forks:

> "Am I still near the route that people usually take, or am I drifting into an accidental side path?"

The MVP does not try to become a full hiking community or a perfect official map. It focuses on one field problem: reducing uncertainty when trail information is weak.

## 2. Problem and User Value

### Problem

Small local mountains often have unclear branches, informal paths, animal paths, maintenance paths, and poor official map coverage. When network access is unreliable, users cannot depend on online maps or real-time lookup.

### Target Users

- **Local casual hikers** who walk small or mid-sized mountains and face confusing forks.
- **Repeat hikers** whose traces can make the same mountain more useful over time.
- **Solo operator/developer** who needs route-quality signals to debug and improve the MVP.

### Expected Effects for Users

- Users can keep a personal route record even without network access.
- Users can recover an interrupted hike after app restart.
- Users can see whether a route is unavailable, only a reference route, or recommended.
- Users can compare their current position to the representative route and avoid wrong turns.
- Users gain useful route guidance in places where official trail data does not exist yet.

## 3. MVP Scope

### P0

- Offline hiking session recording.
- Active session restoration after app restart.
- Idempotent upload when connectivity returns.
- GPS point validation and rejected-point reporting.
- No-base-trail reference route generation from accepted traces.
- Confidence labeling for route reliability.
- Current-position-to-route comparison.

### P1

- Basic operator metrics.
- Route-quality debug signals.
- Conservative branch handling when multiple paths have similar support.

### Explicit Non-Goals

- Real-time rescue or emergency dispatch.
- Community, ranking, group hiking, or social feeds.
- Photo-based terrain recognition AI.
- Launch marketing, pricing, positioning, or growth-loop planning.
- Full official-grade trail map replacement.

## 4. Technical Stack Recommendation

The recommended minimal MVP stack is:

- **Flutter**: Android-first mobile app, with iOS possible later.
- **Local SQLite**: Offline sessions, active-session recovery, completed-session queue, and track points.
- **Supabase Auth**: User identity for MVP uploads.
- **Supabase Postgres + PostGIS**: Remote geospatial storage, spatial indexes, route geometry, distance queries, and confidence metadata.
- **Supabase Edge Functions**: Idempotent session ingestion, point validation, canonical route retrieval, and position snapping.

### Why This Stack

This stack is intentionally small. It avoids a custom Spring Boot server, Kubernetes, queues, and separate GIS infrastructure while still supporting the hard parts of the MVP:

- offline-first mobile recording
- spatial data storage
- geospatial distance queries
- confidence-labeled canonical routes
- authenticated upload and validation

Firebase was rejected for the new MVP because it does not naturally support the route-inference and nearest-line spatial queries without adding a separate geospatial backend.

## 5. No-Base-Trail Route Inference

The core technical idea is to convert "no trail data" into "confidence-labeled reference route" using accumulated GPS traces.

### Pipeline

1. **Discard way-off points**
   - Coordinate validity filter
   - Accuracy filter
   - Haversine speed filter
   - Elevation jump filter
   - Isolated point filter

2. **Aggregate accepted points into cells**
   - H3 or fixed-size grid
   - Target cell size: 8m-15m
   - Track point count, unique session count, accuracy, recency, elevation, and direction

3. **Prune weak cells**
   - Remove low-support cells
   - Remove isolated cells
   - Down-rank low-quality cells
   - Remove weak shortcut-like links

4. **Build a session transition graph**
   - Node: valid spatial cell
   - Edge: observed consecutive movement between cells
   - Edge support: number of sessions that made that transition

5. **Extract representative path**
   - Select the largest connected component
   - Identify endpoint candidates
   - Extract the strongest weighted path
   - Convert cell centers into a LineString

6. **Handle branches conservatively**
   - Highest-support branch becomes canonical
   - Similar-strength branches reduce confidence
   - Ambiguous routes are shown as reference routes, not recommended routes

## 6. Product and Engineering Decisions

### Key Product Decisions

- Start with safety and route confidence, not social features.
- Use "reference route" language when confidence is low.
- Do not present sparse GPS traces as authoritative.
- Treat official trail data as future enhancement, not a hard MVP dependency.
- Keep the MVP useful even before every mountain has a canonical route.

### Key Engineering Decisions

- Keep the spec technology-neutral until planning.
- Use SDD documents as the source of truth.
- Discard the earlier Flutter/Firebase prototype as reference only.
- Prefer inspectable grid-and-graph route inference over early complex AI/HMM models.
- Use confidence, rejected-point counts, and branch ambiguity as route-quality signals.

## 7. Success Criteria

- A user can record a 30-minute airplane-mode hike and recover it after app restart.
- Completed sessions upload without duplicate contribution.
- At least three beta mountains can be classified as no route, reference route, or recommended route.
- A canonical-route mountain can return route geometry, confidence, version, and updated time.
- Position comparison returns nearest route coordinate, distance, and on/off route judgment.

## 8. Interview Talking Points

- **Product judgment**: I narrowed a broad hiking/community concept into a safety-first MVP.
- **Technical judgment**: I selected a minimal stack that still supports geospatial route learning.
- **Data judgment**: I designed confidence-based output so noisy or sparse data does not mislead users.
- **SDD process**: I converted rough Notion notes into constitution, spec, PRD, checklist, and technical recommendation documents.
- **Algorithm design**: I proposed a practical grid-and-graph inference pipeline before moving to complex models.
- **Privacy awareness**: I treated location traces as sensitive data and made raw-path sharing out of scope.

## 9. Current Artifacts

- `specs/001-sandeventura-mvp/spec.md`: technology-neutral MVP specification.
- `specs/001-sandeventura-mvp/prd.md`: product-development PRD.
- `docs/minimal-tech-stack-recommendation.md`: technical stack and algorithm recommendation.
- `.specify/memory/constitution.md`: product and engineering principles.
- `docs/notion-source-summary.md`: source-note summary and scope decisions.

## 10. Next Step

Run `/speckit.plan` using the minimal tech stack recommendation, then generate technical plan artifacts such as data model, API contracts, quickstart, and implementation tasks.
