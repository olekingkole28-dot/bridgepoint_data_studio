# BridgePoint Global Intelligence — V1 Scope

## Objective

Extend BridgePoint’s existing property identity, geospatial and public-source signal layers into one global infrastructure intelligence workspace. V1 should make existing data useful in one surface without implying that feeds are continuous, complete or independently verified.

## Existing BridgePoint building blocks

The production project already has:
- `intelligence_live_entity_v5500`: public-source entities with domain/type, location fields, observation/expiry timestamps and metadata.
- `intelligence_global_signal_v5503`: normalized source-backed signals with severity, timestamps and payload.
- `intelligence_reference_geometry_v5505`: reference geometry for non-event spatial context.
- `intelligence_bridge_source_v5540`, `intelligence_bridge_coverage_v5540`, and `intelligence_bridge_geometry_v5540`: infrastructure source, coverage and geometry layers.
- `bridgepoint_global_progress_v5700` and `bridgepoint_global_country_progress_v5710`: worldwide and country-level property coverage metrics.
- Existing source adapters/ingestion for public earthquakes, global hazards, volcanoes and space weather.

Reuse these foundations; do not create a competing data model.

## V1 contents on this branch

1. A bounded Edge Function reading the current property-coverage snapshot, public hazard records and space-weather signals.
2. An allow-listed response that excludes coordinates, tracks, heading, speed and altitude from the general overview.
3. A Flutter screen that presents:
   - canonical property identity, building-footprint and materialized-boundary metrics;
   - registered infrastructure sources, rights class, ingest mode, status and discovered/materialized counts;
   - recent public-source hazard events;
   - space-weather signals;
   - country coverage and source-refresh metadata.
4. A navigation entry under Explore.
5. Explicit error/empty states and source timestamps. Show returned-record counts as counts loaded, not as total-world counts.

No production database schema, credentials, paid feeds, refresh jobs or deployment are changed by this branch. Deploy the new Edge Function only after review, with JWT verification enabled.

## Data path

Authorized/public source → source-specific ingestion → normalized entity/signal → bounded overview API → Flutter Global Intelligence screen → BridgePoint World for broader spatial exploration.

Preserve source key, observation time, ingestion/update time, expiry where applicable, rights/terms and provenance. Keep source observations separate from BridgePoint-derived context and model hypotheses.

## Follow-on phases

### V2 — infrastructure relationship graph
Connect public property/facility identities, registries, permitted records, publicly documented operators, transport/utility dependencies and hazards to canonical BridgePoint entities. Store provenance and match confidence on every link; keep ambiguous matches reviewable.

### V3 — satellite change candidates
Evaluate Copernicus Data Space catalog access for historical imagery analysis. Retain product ID, acquisition/processing timestamps, footprint, resolution/band metadata, license/terms and model version. Mark detections as review candidates, not confirmed use or intent.

### V4 — commercial logistics context
Review authorized aviation/maritime datasets for cost, API rights, update latency, coverage and redistribution terms. Start with historical or delayed commercial logistics trends, port context and regional aggregates. Do not expose exact live military deployments, troop movements or person-level geolocation in the general product.

### V5 — resilience analytics
Join facilities and supply dependencies to hazards, public outage/disruption reports and historical events. Explain why each alert exists, which records contributed, when they were observed and what remains unknown.

## Trust and security requirements

- Deploy the overview endpoint with JWT verification.
- Keep the Supabase service-role key server-side.
- Use explicit selected columns and response allow-lists; never proxy entire table rows.
- Avoid publishing exact live entity locations or movement tracks through the general overview.
- Respect source license, rate limits, attribution, retention and redistribution rules.
- Separate observation time from ingestion time. Recent ingestion does not prove the underlying event is current.
- Mark data as observed, derived or inferred; show disagreements instead of silently overwriting source truth.
- A missing signal is not proof that an asset or activity is absent. AIS gaps are not an exact location.
- Weather exposure is not verified damage; imagery change is not verified intent; an entity match is not confirmed ownership unless the source establishes it.

## Acceptance criteria

- The deployed endpoint rejects unauthenticated requests.
- Response size is bounded: at most 40 country rows, 25 infrastructure source rows, 60 public events and 20 space-weather signals.
- Event payload contains no coordinates, track, heading, speed or altitude.
- Source key and observation time are displayed when present.
- Flutter handles missing progress, empty feeds, endpoint failures and retry without inventing values.
- Labels distinguish canonical identities, boundary records, building footprints and source completeness.
- Dart and Edge Function checks pass before merge; test against a development project before production deployment.

## Positioning

Present this as global property and infrastructure context powered by source-backed evidence—not as an all-seeing live tracker. BridgePoint’s differentiator is identity resolution, relationships, evidence provenance and explainable prioritization on top of a shared property-data foundation.
