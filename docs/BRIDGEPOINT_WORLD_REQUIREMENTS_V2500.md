# BridgePoint World V2500 — Recovered Requirements & Regression Contract

This document is the source-of-truth contract for the replacement BridgePoint Intelligence Map. It consolidates the behaviors repeatedly requested during the BridgePoint world build and the regressions that repeatedly broke when one fix displaced another.

## Product intent

BridgePoint World is one continuous digital-twin surface: globe → state → city → neighborhood → parcel → structure → roof/ground study. It is not a second map, a demo map, or a vendor map with BridgePoint cards pasted on top. BridgePoint property intelligence remains the truth layer. Visual context may use only BridgePoint-owned/derived data and free/public sources that permit this use.

## Hard source rules

1. Do not depend on Google Maps, Google Photorealistic 3D Tiles, Cesium ion terrain/data, Mapbox, Bing, Nearmap, OpenFreeMap, or another commercial/competitor map-data product.
2. CesiumJS/Three.js may be used as open-source rendering libraries; they are not data sources.
3. Public visual/context sources may include USGS National Map/NAIP/3DEP, NOAA/NWS/NHC, NIFC/WFIGS, FEMA and other public-government/open feeds already legal-gated by BridgePoint.
4. Source-backed BridgePoint geometry always wins over a visual context layer.
5. Never invent exact roof shape, exact building height, parcel boundary, weather observation, fire perimeter, flood depth, lightning strike, rail alignment, road detail, or terrain height.
6. Estimated values must be labeled estimated. If the source does not supply a feature, omit it rather than fabricate it.

## Camera and interaction

- Start near the user when browser location permission is available; otherwise use the U.S. overview.
- U.S. and approved U.S. jurisdictions remain continuously zoomable. No snap-back, forced zoom-out, periodic camera reset, or refresh jolt.
- Locked countries may be visible on the globe, but property-level zoom is blocked before deep detail and the lock card remains stable.
- Panning, pinch-zoom, wheel zoom and tilt inside the world belong to the world. They must not scroll the surrounding Flutter page.
- Close-up walk/inspection angles remain possible without losing the selected parcel/structure or camera state.
- Closing Structure + Parcel Lab returns to the exact prior map camera because the lab is an overlay, not a replacement navigation state.

## App integration

- The existing Intelligence Map tab is replaced by BridgePoint World; do not add another competing map tab.
- The map page is immersive and non-scrolling.
- Hide the old map toolbar/chrome. Do not place state/county controls over +/- controls. Avoid the previous county-card swarm/glitch.
- Keep only compact floating BridgePoint controls needed for layers, location, U.S. reset and current selection.
- On compact/mobile, retain only the app navigation required to leave the map; do not cover interactive map controls.

## Visual hierarchy / detail

- Buildings: source-backed footprints, source height when available, clearly labeled estimated height only when allowed by the existing BridgePoint truth field.
- Parcels: source-backed boundaries, glowing/thin enough to remain readable over imagery.
- Roofs: source-backed roof polygons/attributes only. Never synthesize an exact roof claim.
- Opportunity/intelligence color survives selection. Selection adds outline/glow without replacing the intelligence hue.
- Structure, street, city/state, water and facility labels appear progressively by scale and only when supplied by source data.
- Roads, rail, parking/pavement, water, streetlights and vegetation render only from BridgePoint-streamed legal/public geometry. No client fallback to a commercial/competitor vector provider.
- Buildings/roads/parcels/terrain remain visible beneath weather effects.

## Weather and hazards

- Weather is nationwide and spatially shaped by real source geometry; do not reduce events to generic dots.
- NOAA/NWS radar is on by default.
- Property circles are off by default.
- Other physical 3D effects are conservative and source-gated; do not overload the screen at national zoom.
- Exact alert/fire/storm/flood geometry uses a thin boundary + restrained translucent interior.
- Effects progressively appear only at useful zooms.
- Filters include: hail, rain, snow/ice, wind, tornado, hurricane/tropical cyclone, wildfire/fire/smoke where supported, flood, lightning only when a strike source exists, and outage only when a source exists.
- Alerts/forecast context never becomes a claim of observed property damage.
- No fake lightning. No fake burn scar. No invented flood depth.
- Present-weather atmosphere may adjust fog/cloud/storm lighting from real current observations.
- Weather refresh preserves camera, selected property, layer visibility and radar state. Do not recreate the world or reset zoom every few seconds.

## Building click / card behavior

The card must appear immediately from already-loaded viewport values, then progressively enrich. A slow secondary RPC must never blank or close the card.

Immediate fields where available:
- address / property ID / parcel ID
- municipality / county / state
- source name and truth label
- building height + height truth
- floors
- footprint area
- land/parcel area
- year built
- assessed value
- perimeter
- roof shape/material/pitch/area where source-backed
- BridgePoint score/opportunity context
- elevation / 3DEP provenance where available

Enrichment may use:
- `bridgepoint_building_detail_v2300`
- `bridgepoint_flutter_property_detail_v344`
- `bridgepoint_property_timeline_v857`
- `bridgepoint_property_climate_profile_v510`
- `bridgepoint_digital_twin_summary_v856`
- `bridgepoint_property_geometry_v854`
- `bridgepoint_flutter_permit_context_v68`
- `bridgepoint_property_media_bundle_v169`

Resilience rules:
- staged loading with independent timeouts
- `Promise.allSettled`-style enrichment
- cache successful property/building responses
- keep partial data visible when one source times out
- retry button for failed enrichment
- never replace valid viewport truth with a failed/empty secondary response

## Structure + Parcel Lab

Preserve the prior successful isolated-study behavior:
- exact source footprint/parcel geometry only
- orbit/rotate/zoom/reset
- true 3D point-to-point measurement on rendered source geometry
- X-ray/transparency control
- source/truth badges
- no synthetic detailed structure if source footprint is missing
- explicit notice when a displayed height is visual/estimated
- release WebGL resources when closed

## Performance / regression protections

- device-tier resolution/detail budgets
- frustum/camera-distance culling through Cesium
- strict detail caps at low-end mobile tiers
- viewport data refresh only after meaningful camera movement and with debounce/throttle
- no full scene teardown on weather refresh
- no 3-second camera/data reset loops
- no secondary full-screen map canvas
- no control overlap on mobile
- no toolbar obscuring the map
- no county-card swarm
- no selected-card timeout causing a blank panel

## Public terrain reality

BridgePoint already has USGS 3DEP property elevation ingestion. V2500 may use those source elevations immediately. A true continuous terrain mesh must wait for a public 3DEP-to-tile pipeline or another explicitly approved public terrain feed. Do not substitute Cesium ion or another proprietary terrain dataset.

## Release gate

Do not replace the live Intelligence Map until all of the following are green:
1. V2500 JavaScript parses.
2. Public-source/forbidden-provider contract scan passes.
3. Clean V2 Flutter web compiles.
4. V2500 files survive Flutter web assembly.
5. Intelligence Map points at the V2500 embed, not the legacy FlutterMap weather page.
6. No proprietary provider strings remain in V2500 runtime.
7. Production publish workflow succeeds.
8. Live route returns V2500 assets.

A real WebGL/browser visual test is still required before calling the experience visually perfect.
