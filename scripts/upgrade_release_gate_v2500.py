from pathlib import Path

p = Path('.github/workflows/flutter-web-v2-production.yml')
text = p.read_text(encoding='utf-8')


def transition(old: str, new: str, label: str) -> None:
    global text
    oc, nc = text.count(old), text.count(new)
    if oc == 1 and nc == 0:
        text = text.replace(old, new, 1)
        print(f'fixed {label}')
        return
    if oc == 0 and nc == 1:
        print(f'already fixed {label}')
        return
    raise SystemExit(f'{label}: release-gate contract drift old={oc} new={nc}')


transition(
    '# V1900 authoritative Clean V2 compiler/handoff with 3D world static surfaces',
    '# V2500 authoritative Clean V2 compiler/handoff with BridgePoint World replacement',
    'release header',
)
transition(
    "          test -s lib/v2/bridgepoint_map_weather_v2.dart\n          test -s lib/v2/bridgepoint_products_settings_v2.dart",
    "          test -s lib/v2/bridgepoint_map_weather_v2.dart\n          test -s lib/v2/bridgepoint_world_embed_v2.dart\n          test -s lib/v2/bridgepoint_world_embed_web_v2.dart\n          test -s lib/v2/bridgepoint_products_settings_v2.dart",
    'world embed source checks',
)
transition(
    "          test -s web/bridgepoint-3d-world/index.html\n          test -s web/owner-downloads/bridgepoint-storage-check.ps1",
    "          test -s web/bridgepoint-3d-world/index.html\n          test -s web/bridgepoint-3d-world/world-v2500.js\n          test -s web/bridgepoint-3d-world/world-v2500-inspector.js\n          test -s web/bridgepoint-3d-world/world-v2500.css\n          test -s web/bridgepoint-3d-world/world-contract-v2500.json\n          test -s web/owner-downloads/bridgepoint-storage-check.ps1",
    'V2500 asset source checks',
)
transition(
    "            'BridgePointV2App','BridgePointHomeV2','BridgePointMapWeatherV2','BridgePointProductsSettingsV2',",
    "            'BridgePointV2App','BridgePointHomeV2','BridgePointWorldEmbedV2','BridgePointProductsSettingsV2',",
    'active map marker',
)
transition(
    "          world=Path('web/bridgepoint-3d-world/index.html').read_text(encoding='utf-8')\n          assert \"static const primary",
    "          world=Path('web/bridgepoint-3d-world/index.html').read_text(encoding='utf-8')\n          world_js=Path('web/bridgepoint-3d-world/world-v2500.js').read_text(encoding='utf-8')\n          world_contract=Path('web/bridgepoint-3d-world/world-contract-v2500.json').read_text(encoding='utf-8')\n          embed=Path('lib/v2/bridgepoint_world_embed_web_v2.dart').read_text(encoding='utf-8')\n          assert \"static const primary",
    'V2500 release inputs',
)
transition(
    "          assert \"if (owner) _Group(title:'Owner only'\" in app or \"if (owner) _Group(title: 'Owner only'\" in app\n          assert \"Duration(milliseconds: 2600)\" in map_src",
    "          assert \"if (owner) _Group(title:'Owner only'\" in app or \"if (owner) _Group(title: 'Owner only'\" in app\n          assert 'BridgePointWorldEmbedV2' in app\n          assert 'BridgePointMapWeatherV2()' not in app\n          assert 'bridgepoint-world-v2500' in embed\n          assert 'world-v2500.js' in world\n          assert 'BridgePointWorldV2500' in world_js\n          assert 'bridgepoint_3d_world_viewport_v1899' in world_js\n          assert 'basemap.nationalmap.gov' in world_js\n          assert 'mapservices.weather.noaa.gov' in world_js\n          forbidden=['tile.googleapis.com','googleMapsTileKey','Cesium.Ion','cesiumIonToken','api.mapbox.com','virtualearth.net','nearmap','openfreemap','tile.openstreetmap.org']\n          hit=[x for x in forbidden if x.lower() in (world+'\\n'+world_js+'\\n'+world_contract).lower()]\n          assert not hit, f'Forbidden World V2500 provider dependency: {hit}'\n          assert \"Duration(milliseconds: 2600)\" in map_src",
    'active world and public-only production assertions',
)
transition(
    "          test -s build/web/bridgepoint-3d-world/index.html\n          test -s build/web/owner-downloads/bridgepoint-storage-check.ps1",
    "          test -s build/web/bridgepoint-3d-world/index.html\n          test -s build/web/bridgepoint-3d-world/world-v2500.js\n          test -s build/web/bridgepoint-3d-world/world-v2500-inspector.js\n          test -s build/web/bridgepoint-3d-world/world-v2500.css\n          grep -q 'BridgePointWorldV2500' build/web/bridgepoint-3d-world/world-v2500.js\n          grep -q 'world-v2500.js' build/web/bridgepoint-3d-world/index.html\n          test -s build/web/owner-downloads/bridgepoint-storage-check.ps1",
    'assembled V2500 publish checks',
)

# Release metadata should describe the active world rather than the unused legacy map animation.
text = text.replace('"radar_frame_ms":2600,"professional_map_markers":true', '"world_version":2500,"radar_refresh_ms":120000,"world_data_policy":"bridgepoint_public_only","professional_map_markers":true')
text = text.replace('"plans_cta":"gold","radar_frame_ms":2600,', '"plans_cta":"gold","world_version":2500,"radar_refresh_ms":120000,"world_data_policy":"bridgepoint_public_only",')
text = text.replace('"plans_cta":"gold","radar_frame_ms":2600,"parcel_progress_contract"', '"plans_cta":"gold","world_version":2500,"radar_refresh_ms":120000,"world_data_policy":"bridgepoint_public_only","parcel_progress_contract"')

p.write_text(text, encoding='utf-8')
print('Production release gate upgraded to BridgePoint World V2500.')
