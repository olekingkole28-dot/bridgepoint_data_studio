# BridgePoint World V2400

V2400 consolidates the standalone Cesium world into a production-oriented source module while preserving the existing BridgePoint property RPCs and main-app authentication flow.

## What changed

- Continuous globe-to-walk U.S. camera navigation with no artificial zoom reset inside unlocked geography.
- Non-U.S. countries are rendered as locked construction geography and deep zoom is physically clamped before property-level detail.
- Existing `bridgepoint_3d_world_viewport_v1899`, `bridgepoint_flutter_property_detail`, `bridgepoint_universal_search_context_v244`, and country-expansion request RPCs remain the application bridge.
- Google Photorealistic 3D Tiles are an optional high-fidelity U.S. rendering mode. They are never required for BridgePoint property truth and are hidden outside unlocked geography.
- Source-backed building extrusions remain visible; optional `parcels` and `roofs` arrays returned by the viewport RPC are rendered automatically without fabricating missing geometry.
- Structure labels are rendered only when the backend supplies a real name, category, or classification.
- Device-tier LOD adjusts resolution, target FPS, 3D Tiles screen-space error, tile cache, detail limits, and label limits.
- NWS active-alert polygons remain context only. Weather can call `BridgePointWorldV2400.applyWeather(...)` or dispatch `bridgepoint:weather` to drive fog and precipitation atmosphere.
- Cesium/Google attribution remains visible. Do not hide or cover the credit area.

## Google Photorealistic 3D Tiles

Enable the Google Map Tiles API in a billing-enabled Google Cloud project and create a browser-restricted key limited to the Map Tiles API and BridgePoint production/dev origins. Do not commit an unrestricted key.

The runtime reads `web/bridgepoint-3d-world/runtime-config.local.js`. The bootstrap script creates that untracked file from environment variables.

```powershell
$env:BRIDGEPOINT_GOOGLE_MAPS_TILE_KEY = 'your-browser-restricted-key'
$env:BRIDGEPOINT_CESIUM_ION_TOKEN = '' # optional terrain fallback
.\scripts\bootstrap_bridgepoint_world.ps1
```

Without a Google key, V2400 stays operational in source-backed globe mode. Without a Cesium ion token, it uses ellipsoid terrain until Google photoreal tiles become active.

## Windows bootstrap and export

```powershell
git fetch origin
git switch bridgepoint-world-v2400
.\scripts\bootstrap_bridgepoint_world.ps1
```

The script runs Flutter diagnostics, resolves packages, generates untracked runtime config, builds the web app, copies the standalone world into `build/web/bridgepoint-3d-world/`, and creates timestamped archives in `exports/`:

- `BridgePoint-source-*.zip` — tracked source snapshot from `git archive`; local keys are excluded.
- `BridgePoint-web-runtime-*.zip` — runnable production web bundle.

Preview locally:

```powershell
python -m http.server 8787 --directory build/web
```

Open `http://localhost:8787/bridgepoint-3d-world/`.

## Runtime contract

`window.BridgePointWorldV2400` exposes `state`, `streamBuildings(force)`, `setPhotoreal(enabled)`, `applyWeather(payload)`, and `loadHazards()`.

The world listens for both `bridgepoint:weather` and `bp:weather` custom events.

## Optional viewport payload extension

The current viewport RPC can keep returning `buildings`. V2400 also consumes optional `parcels` and `roofs` arrays when present:

```json
{
  "lod_level": "property",
  "source_mode": "source-backed",
  "buildings": [],
  "parcels": [{"property_id":"...","geometry":{"type":"Polygon","coordinates":[]},"render_score":81}],
  "roofs": [{"property_id":"...","geometry":{"type":"Polygon","coordinates":[]},"roof_base_m":18,"roof_top_m":22}]
}
```

Missing parcel or roof arrays do not produce synthetic geometry; those layers remain empty.
