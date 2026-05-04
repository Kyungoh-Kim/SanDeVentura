# API Contract: SanDeVentura MVP

## POST /functions/v1/upload-session

Uploads a completed local hiking session.

### Request

- `idempotencyKey`
- `uploadConsentVersion`
- `mountainId`
- `startedAt`
- `endedAt`
- `points[]`
  - `recordedAt`
  - `lat`
  - `lon`
  - `altitude`
  - `accuracy`
  - `speed`
  - `sequenceIndex`

### Response

- `success`
- `sessionId`
- `acceptedPointCount`
- `rejectedPointCount`
- `retentionExpiresAt`
- `status`: ingested, duplicate, rejected
- `errors[]`

## GET /functions/v1/get-canonical-trail

Retrieves the latest route state for a mountain.

### Query

- `mountainId`

### Response

- `success`
- `mountainId`
- `routeState`: none, reference, recommended
- `version`
- `confidence`
- `updatedAt`
- `trailGeoJson`
- `metrics`
  - `sessionCount`
  - `branchAmbiguityScore`
  - `gpsQualityScore`

## POST /functions/v1/snap-position

Compares the user's current coordinate to the canonical trail.

### Request

- `mountainId`
- `lat`
- `lon`
- `accuracy`

### Response

- `success`
- `input`
- `snapped`
- `distanceMeters`
- `routeJudgment`: on_route, caution, away_from_route
- `onTrail`
- `thresholds`
  - `onRouteMeters`: 25
  - `awayFromRouteMeters`: 50
- `trailVersion`
- `routeState`

## POST /functions/v1/recompute-canonical-trails

Operator-only MVP function for recalculating canonical trails.

### Request

- `mountainId`
- `mode`: single, all

### Response

- `success`
- `mountainId`
- `previousVersion`
- `newVersion`
- `confidence`
- `routeState`
- `cellCount`
- `edgeCount`
