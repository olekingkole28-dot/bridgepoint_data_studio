# BridgePoint Intelligence — Clean V2 Architecture

## Non-negotiable release rule

The clean V2 app does **not** rebuild itself by replaying historical source-patch scripts during release.

A production build is:

1. verify backend/product contracts,
2. Flutter analyze,
3. tests,
4. Flutter build,
5. artifact/deploy verification.

If a feature needs to change, change the source module or backend contract itself. Do not add a versioned text-replacement step to CI.

## Backend continuity

V2 uses the existing production Supabase data plane. The rewrite does not discard or fork the property warehouse, ingestion system, scoring/pattern/opportunity engines, source registries, permissions, owner controls, worker truth, digital-twin data, exports, or integration contracts.

## Product areas

The top-level product stays intentionally small:

- **Home** — daily brief, health, market context and next actions.
- **Property Intelligence** — canonical property, evidence, ownership, permits, timeline, media, risk and opportunities.
- **Map & Weather** — imagery, parcels/buildings, opportunities/signals, hazards and time-enabled NOAA weather.
- **Workflows & AI** — field/work items, notes, CRM/claims handoff, automations and customer-safe AI capabilities.
- **Intelligence Studio** — sources → matching → evidence → signals → patterns → models → opportunities → actions.
- **Integrations** — Cotality/CoreLogic, Verisk, Palantir, Yardi, Nearmap, EagleView, MCP, REST/webhooks and GIS/OGC adapters with truthful connection state.
- **Owner Control** — completion ledger, AI/local workers, global expansion/export, operations and backend→surface coverage.

Detailed tools belong under these areas rather than becoming dozens of unrelated top-level navigation items.

## Nothing-hidden rule

`product.capability_surface_registry_v791` is the inventory of backend capability → product surface intent.

Every capability must resolve to one of:

- CUSTOMER_UI
- OWNER_UI
- INTEGRATION_API
- INTERNAL_AUTOMATION
- SECURITY_INTERNAL

`UNCLASSIFIED` means unfinished product architecture. `PARTIAL` means the capability exists but complete UI/integration coverage is not yet proven. Neither is allowed to masquerade as done.

Authenticated customer/integration visibility is exposed through `public.bridgepoint_capability_library_v831` without exposing internal automation implementation details.

## Integration rule

A provider definition is not a connection. BridgePoint only labels an integration connected after authorized credentials/rights and a successful governed exchange are verified.

BridgePoint should support both directions where provider rights allow it:

- provider → BridgePoint canonical intelligence,
- BridgePoint intelligence/actions/exports → provider.

## Geospatial/weather rule

Maps are multiresolution. A layer is shown only at scales where its native resolution is meaningful.

NOAA MRMS time-enabled base reflectivity is regional weather context with an approximately four-hour time window and frequent updates. Raw radar pixels are not property-level proof of damage.

Premium aerial/oblique/measurement providers remain separate licensed layers and must not be represented as active until provider access is actually configured.

## Migration rule

The old app remains a rollback reference until Clean V2 passes compile, tests, build, backend contract checks and live verification. Production is switched only after that proof. After cutover, old release patch scripts are archived/removed from the active publisher rather than carried forward indefinitely.
