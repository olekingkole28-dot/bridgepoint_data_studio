from pathlib import Path
import runpy

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v341-national-customer-surfaces'

# Replace only CT-specific phrases on GENERIC customer surfaces. Phrase-level
# matching survives responsive/newline formatting changes while remaining narrow
# enough not to touch genuinely Connecticut-specific tools.
phrase_replacements=[
    ('Live source registry • Connecticut intelligence','Live source registry • national intelligence coverage'),
    ('live ranked Connecticut property intelligence','live ranked property intelligence'),
    ('Canonical Connecticut property record','Canonical property record'),
]
for old,new in phrase_replacements:
    if new in text:
        continue
    count=text.count(old)
    if count==1:
        text=text.replace(old,new,1)
    elif count>1:
        raise SystemExit(f'v341 ambiguous customer phrase count {count}: {old}')
    # count==0 is valid when a newer surface already removed the obsolete phrase.

old_fallback="final address = (property['address'] ?? 'Connecticut property').toString();"
new_fallback="final address = (property['address'] ?? 'Property record').toString();"
if old_fallback in text:
    if text.count(old_fallback)!=1:
        raise SystemExit('v341 ambiguous legacy property fallback')
    text=text.replace(old_fallback,new_fallback,1)

for needle in ['national intelligence coverage','live ranked property intelligence']:
    if needle not in text:
        raise SystemExit(f'missing v341 national customer marker: {needle}')
for forbidden in [
    'Live source registry • Connecticut intelligence',
    'live ranked Connecticut property intelligence',
    old_fallback,
]:
    if forbidden in text:
        raise SystemExit(f'generic CT-only customer copy remains after v341: {forbidden}')

if marker not in text:
    text += (
        "\nconst String _bridgePointNationalCustomerSurfacesV341="
        "'bridgepoint-v341-national-customer-surfaces | national coverage copy | truthful partial-state support';\n"
    )

# IMPORTANT: v345 is a broad dashboard/opportunities/field/properties/search migration,
# not a map-only release layer. Its current generator targets an older numeric navigation
# layout and is intentionally NOT chained into this map/radar/ETA release. The v345 source
# remains in the repository for a dedicated compatibility release after its own full CI pass.
# The Intelligence Map itself is already backed by national entitlement-aware RPC aliases
# plus the v350 national map patch, so deferring v345 does not weaken map geography/package
# enforcement or radar/build-status behavior.
compat="const String _bridgePointV345DeferredCompatibilityV350='v345 broad app migration retained for dedicated compatibility validation';"
if compat not in text:
    text += compat+"\n"

path.write_text(text,encoding='utf-8')
print('National customer surfaces v341 verified; broad v345 migration decoupled from map release')

# Sprint guard runs before the isolated Daily Brief migration so the base generated app
# must still be free of count-heavy state polling. V354 may then add only the explicitly
# allowed cached map-state shell plus live-only state-status lookup.
runpy.run_path('tool/apply_national_sprint_release_guard_v352.py',run_name='__main__')

# Migrate exactly one current-code customer surface at a time. V354 executes the
# low-I/O Daily Brief/dashboard migration using structural compatibility anchors
# for the evolved generated release. No other customer surface is touched.
runpy.run_path('tool/apply_national_dashboard_v354.py',run_name='__main__')

# Owner/co-owner Sources can consume the existing V356 payload without any extra
# national DB polling: bridgepoint_flutter_sources already returns the national
# accepted-source array only to platform owners. V357 renders that payload with
# state filtering and preserves the customer-safe hidden-infrastructure response.
runpy.run_path('tool/apply_owner_national_sources_ui_v357.py',run_name='__main__')

# V359 adds a low-I/O self-diagnostic to the owner-only Sources surface. It calls the
# protected V358 owner-access contract only after the V357 owner payload proves this
# is an owner view, so customer accounts do not incur failed owner RPCs or gain access.
runpy.run_path('tool/apply_owner_access_health_ui_v359.py',run_name='__main__')

# P0 radar playback repair runs after the current owner/customer surface layers so it
# patches the exact generated Intelligence Map that ships. V360 keeps a stable latest
# NOAA reflectivity safety layer behind historical playback, crossfades frame swaps,
# slows dwell time for mobile/slow networks, preserves pause/resume position, and holds
# on the newest verified NOW frame instead of instantly wrapping to the oldest frame.
runpy.run_path('tool/fix_live_radar_animation_v360.py',run_name='__main__')

# V380 replaces the old per-state owner expansion polling panel with one cached 49-state
# visual command center, adds compact owner progress rings to the national map, and removes
# both redundant floating expansion launchers so Owner Center is the single source of truth.
runpy.run_path('tool/apply_owner_national_cockpit_v380.py',run_name='__main__')

# V390-V394 are post-v380 generated-app cleanup layers. They run last so no historical
# release generator can re-add mobile floating controls, cluttered expansion defaults,
# cosmetic owner preview, unscoped preview data, or generic CT-only coverage copy.
runpy.run_path('tool/apply_mobile_shell_cleanup_v390.py',run_name='__main__')
runpy.run_path('tool/apply_map_cleanup_radar_v391.py',run_name='__main__')
runpy.run_path('tool/apply_owner_customer_preview_v392.py',run_name='__main__')
runpy.run_path('tool/apply_preview_pages_v393.py',run_name='__main__')
runpy.run_path('tool/apply_national_coverage_copy_v394.py',run_name='__main__')

# Keep two historical release-marker strings strictly as non-runtime compatibility markers.
# The manual v212 expansion controls stay removed; this only lets the older workflow audit
# recognize that the newer replacement was intentionally applied.
runpy.run_path('tool/preserve_v212_guard_compat_v380.py',run_name='__main__')

# Verify the complete active release graph after the isolated dashboard, owner Sources,
# radar persistence and owner national command layers have materialized their markers.
# The deprecated broad v345 migration must still remain unreachable from production.
runpy.run_path('tool/audit_national_release_compat_v351.py',run_name='__main__')
