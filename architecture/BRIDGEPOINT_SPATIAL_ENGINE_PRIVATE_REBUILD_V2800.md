# BridgePoint Spatial Engine + Private Rebuild Directive V2800

Status: OWNER DIRECTIVE — ACTIVE
Date: 2026-09-11

## Product state

BridgePoint is in private rebuild mode.

The public application, login, map, owner surfaces, and prior world experience are not the product to preserve. They are temporary historical artifacts. The next public release is rebuilt from the completed truth layers after export/bootstrap.

## Spatial engine end-state

BridgePoint will own its spatial runtime.

Target architecture:

BridgePoint truth graph / PostGIS
→ BridgePoint spatial streaming service
→ BridgePoint native scene graph
→ BridgePoint tile/mesh format
→ BridgePoint WebGPU renderer
→ web / desktop / mobile clients

A Rust spatial core compiled to WebAssembly is the preferred cross-platform foundation. WebGPU is the low-level hardware interface, not the world engine.

CesiumJS is transitional scaffolding only. It may be used as a comparison/reference renderer during migration, but it is not the long-term BridgePoint spatial engine.

BridgePoint should own:
- global coordinate/origin rebasing and high-precision georeferencing
- quadtree/octree/3D spatial indexing
- scene graph
- continuous LOD
- frustum/occlusion culling
- GPU instancing
- terrain tiling
- parcel boundary rendering
- building/roof/floor/unit hierarchy
- object picking and canonical-ID resolution
- weather/effects simulation
- world-state streaming
- offline/local cache
- 3D asset/provenance truth classes
- source-backed vs derived vs game/procedural labeling

## World truth hierarchy

The renderer must preserve the difference between truth and simulation.

1. SOURCE_BACKED_EXACT
   Government/custodian geometry or measurement.

2. SOURCE_BACKED_DERIVED
   Geometry computed from lawful source measurements with provenance.

3. ESTIMATED
   Clearly marked approximation.

4. PROCEDURAL_GAME
   Fictional/interior/gameplay content. Never represented as real-world truth.

Unknown interiors remain unknown in the truth world. Gameplay interiors may exist only as a separate procedural layer.

## Canonical spatial hierarchy

A ground polygon and a canonical asset are not the same thing.

Required hierarchy:

jurisdiction
→ parcel/land estate
→ building/site structure
→ vertical stack
→ floor
→ condo/unit/suite canonical identity
→ room/interior only where source-backed

Many vertical canonicals may share one ground parcel polygon. Do not fabricate overlapping ground polygons to make unit counts appear larger.

## Source policy

### Parcel/property truth

FREE PUBLIC GOVERNMENT/CUSTODIAN SOURCES ONLY.

Prohibited as BridgePoint parcel/property source dependencies:
- Regrid
- ReportAll
- CoreLogic
- ATTOM
- Nearmap
- LightBox
- other commercial parcel/data aggregators

Competitor/public marketing pages may be used only as discovery breadcrumbs to locate the original government/custodian source.

Paid parcel licenses do not satisfy the owner’s current #5 source rule.

### Other world inputs

Allowed only when license/provenance permit BridgePoint’s intended use:
- USGS 3DEP terrain/elevation
- government LiDAR and imagery
- government building/transport/hydrography/infrastructure datasets
- permissively licensed Overture components
- other open standards/open data after license verification

No third-party render engine or proprietary data provider should become an unavoidable BridgePoint dependency.

## Rebuild order

Do not veer from the current completion sequence.

1. Finish #5 parcel/canonical truth and coverage gates.
2. Finish uniqueness certification and vertical parent-boundary relationships.
3. Finish all remaining source/truth layers and export.
4. Bootstrap local/private runtime on owner hardware.
5. Build BridgePoint Spatial Engine beside the frozen truth dataset.
6. Validate BridgePoint renderer against source truth and transitional renderer.
7. Rebuild app/web/login/owner UI on top of the BridgePoint engine.
8. Public launch only after security, provenance, performance, mobile, and owner acceptance gates pass.

## Public lockdown

Until full rebuild release:
- public site shows only “BridgePoint is building its 3D universe”
- no customer login
- no owner portal
- no public map
- no public app bundle
- no public Supabase application RPC access
- no public data-browser surfaces
- search indexing disabled
- development repositories containing proprietary implementation should be private

## Security

The public maintenance page must contain no Supabase client, API key, world code, map SDK, app bundle, owner routes, or data endpoints.

Application-level anon/authenticated Supabase grants remain revoked during lockdown. A grant snapshot must exist before restoration.

Re-enable public access only as part of a controlled new-release security review.

## Release language

Do not claim:
- “190M unique assets”
- “100% coverage”
- “exact entire U.S.”
- “no other company has this”

until the relevant BridgePoint audit gates support those statements.

The system may research those ceilings, but public claims follow certified truth, not aspirational counts.
