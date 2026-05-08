# Sprint 8 Guidance and Operator Design Plan

**Goal**: make hiker guidance and operator quality review clearer, more
data-driven, and closer to the design baseline.

## Scope

- Mobile Route screen design refinement.
- Web operator dashboard live-data integration.
- OpenStreetMap-based route preview for operator and hiker guidance.

Sprint 8 required scope is route preview plus route state clarity. Sessions
detail improvements and advanced route debug overlays are stretch work only.

## Map SDK Decision

Sprint 8 should use the smallest open-source map stack that supports route
inspection without committing the product to a paid cloud map platform.

| Surface | Choice | Why |
|---------|--------|-----|
| Operator Web | OpenLayers | Best fit for GIS-style inspection, GeoJSON route rendering, debug overlays, and future cell/transition layers. |
| Mobile Flutter App | flutter_map | Pure Flutter implementation with low integration risk for OSM raster tiles, route polylines, current-position markers, and widget tests. |
| Deferred 3D Terrain | CesiumJS | Apache-2.0 and strong for 3D terrain, but unnecessary for Sprint 8 route quality review. |
| Deferred Vector Map Engine | MapLibre | Better when vector tiles, style-spec rendering, or offline vector maps become required. |

### Tile and Attribution Rules

- Use OpenStreetMap-compatible XYZ/raster tiles for local MVP map previews.
- Always show OpenStreetMap attribution on visible maps.
- Do not rely on `tile.openstreetmap.org` for sustained beta/production
  traffic. Before external beta, switch to a compliant provider such as
  OpenFreeMap, MapTiler/Stadia, or a self-hosted tile service.
- Keep route geometry and quality overlays first-party; map tiles are only the
  background.

## Specific Steps

1. Mobile Route screen:
   - show no-route/reference/recommended states with distinct visual hierarchy
   - show confidence, version, updated time, and session count
   - show branch ambiguity and caution copy
   - show snap distance, judgment, and thresholds
   - add a `flutter_map` route preview backed by OSM-compatible raster tiles
   - render canonical route geometry as a polyline when available
   - render current/snap position marker when snap data is available
   - preserve a non-map fallback summary for no-network or no-route states
   - parse `trailGeoJson` LineString coordinates from `[lon, lat]` into
     Flutter `LatLng(lat, lon)` route points
   - keep `recommended` language gated by `routeState`, not confidence alone

2. Mobile route geometry contract:
   - add a route geometry model to `CanonicalTrail`
   - support only GeoJSON `LineString` in Sprint 8
   - ignore invalid, empty, or unsupported geometry and show fallback copy
   - add parser unit tests for valid LineString, invalid type, and malformed
     coordinates

3. Mobile Sessions screen (stretch):
   - clarify retryable failure vs duplicate success vs validation rejected
   - expose accepted/rejected details in a detail view or expandable section
   - keep idempotency/debug details secondary

4. Operator dashboard:
   - replace static route fixtures with live Supabase reads
   - show route coverage by mountain
   - show confidence inputs and rejected counts
   - add a data fetch module for `operator_route_coverage`
   - add selected-row state so the map panel has a concrete mountain context
   - load the selected mountain detail through `latest_canonical_trail`
   - add a typed GeoJSON route detail model
   - add an OpenLayers map panel to the route detail area
   - render `latest_canonical_trail` GeoJSON as a route polyline
   - color route lines by state:
     - `recommended`: green
     - `reference`: amber
     - `none`: gray or empty state
   - add optional debug overlays for route cells and transitions after the
     base route preview is stable
   - show MVP event counts for upload, trail served, and snap requested
   - keep raw traces protected by RLS

5. Web map implementation:
   - add `ol` to the web package
   - import `ol/ol.css`
   - give the map container a stable fixed height
   - clean up OpenLayers map instances on unmount
   - show an empty state for missing, invalid, or unsupported GeoJSON

6. Mobile map implementation:
   - add `flutter_map` and `latlong2` to the mobile package
   - build a separate route preview widget so map rendering is isolated from
     route state copy
   - centralize tile URL and attribution text in config/constants
   - avoid CesiumJS and MapLibre in Sprint 8 unless OpenLayers/flutter_map
     cannot render the required route preview

7. Tests:
   - widget tests for no-route/reference/recommended route states
   - widget tests for snap judgment states
   - widget tests for map fallback/no-route rendering
   - unit tests for mobile GeoJSON-to-route-point parsing
   - web smoke checks are limited to `npm run typecheck` and `npm run build`
     because no React component test runner exists yet
   - web typecheck/build
   - DB test for operator route coverage view shape

## Acceptance Criteria

- Hiker UI does not imply recommendation when confidence is below `0.70`.
- No-route state disables or blocks position comparison clearly.
- Operator routes screen reflects live local Supabase route coverage.
- Operator route detail displays an OpenLayers map when route GeoJSON exists.
- Operator route detail has a stable selected mountain and empty state when
  no route geometry exists.
- Mobile route screen displays a `flutter_map` preview when route GeoJSON exists.
- Mobile route screen falls back gracefully when route GeoJSON is missing or
  unsupported.
- Map attribution is visible on both web and mobile map surfaces.
- Upload/session quality data is easier to inspect without exposing raw traces.

## Deferred

- CesiumJS 3D terrain and globe rendering.
- MapLibre vector tile/style-spec integration.
- Real topographic map rendering beyond the selected OSM-compatible base map.
- Full offline map tiles.
- Production auth and hosted operator roles.
- Sessions detail redesign if it does not fit after map preview work.
