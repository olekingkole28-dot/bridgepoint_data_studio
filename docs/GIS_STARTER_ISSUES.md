# GIS contributor starter issues

BridgePoint needs GIS contributors across source acquisition, PostGIS analysis, hazard overlays, and globe rendering. These are actionable starter issues linked to the main public backlog.

## Priority order

1. **Global parcel boundaries:** [Issue #367 — Render every source-cleared public source worldwide](https://github.com/olekingkole28-dot/bridgepoint-live/issues/367). Complete the country/region coverage matrix and make every boundary source that is explicitly cleared for public display available at suitable zoom levels.
2. **Municipal zoning:** [Issue #368 — Resolve official district and maximum lot coverage](https://github.com/olekingkole28-dot/bridgepoint-live/issues/368). Ingest official district data and verified ordinance rules with the source URL, code section, and effective dates.
3. **Lot-coverage calculation:** [Issue #369 — Union eligible building footprints inside each parcel](https://github.com/olekingkole28-dot/bridgepoint-live/issues/369). Clip eligible building polygons to parcel boundaries, spatially union overlaps, calculate area ratios, and show completeness limits.
4. **Flood hazards:** [Issue #370 — Add FEMA flood-zone overlay and parcel intersection](https://github.com/olekingkole28-dot/bridgepoint-live/issues/370).
5. **Wildfire data:** [Issue #371 — Add source-dated wildfire perimeters and risk polygons](https://github.com/olekingkole28-dot/bridgepoint-live/issues/371).
6. **Shared spatial analysis:** [Issue #372 — Link parcel/building geometry to hazard polygons](https://github.com/olekingkole28-dot/bridgepoint-live/issues/372).
7. **Globe performance:** [Issue #373 — Optimize parcel/hazard vector overlays](https://github.com/olekingkole28-dot/bridgepoint-live/issues/373).

## Current zoning implementation

The first public analysis path is implemented in Supabase migration `20261025214000_global_public_parcel_zoning_coverage_v1.sql` and exposed through `public.bridgepoint_public_zoning_coverage_v1(lng, lat)`. It can return a matched public parcel, a union of eligible source-backed building footprints, and a measured lot-coverage ratio where the inputs exist.

The municipal zoning tables are intentionally empty until official sources and rules are ingested and verified. A missing district or ordinance must remain **not verified**—never fill it with a guessed allowed percentage. The initial ratio also reports source coverage, not proof that every physical structure is represented or a legal compliance determination.

## Data integrity requirements

- Keep source URL, provider, license, retrieval/version date, and source-record ID attached to every geometry and derived value.
- Respect source-level display, redistribution, caching, and derivative-data restrictions. A public website or open-source repository does not override upstream terms.
- Never expose owner-only data or owner/contact information through a public API.
- Do not confuse a building footprint with a parcel boundary, roof area, building part, or 3D mesh.
- Hazard-zone intersection is exposure context, not evidence of damage, an evacuation order, insurance eligibility, or a legal determination.
- Prefer a meaningful `UNKNOWN / COVERAGE UNAVAILABLE` state to a fabricated “no risk,” missing percentage, or false compliance result.
- Add small fixtures and tests for spatial edge cases: overlaps, boundaries that only touch, holes, multipolygons, invalid geometry, expired zoning rules, and incomplete source coverage.

## Where to contribute

- Main renderer and web UI: [bridgepoint-live](https://github.com/olekingkole28-dot/bridgepoint-live)
- Data ingestion and automation: [bridgepoint_data_studio](https://github.com/olekingkole28-dot/bridgepoint_data_studio)

To start, open one issue above, state which part you are taking, and submit a focused PR with a reproducible test.
