from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v352-national-sprint-release-guard'

# During the national expansion sprint the database is intentionally protected from
# new count-heavy state polling. The global strip reports workspace synchronization,
# not state intelligence readiness, until a selected surface has cached strict truth.
legacy="const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8))"
replacement="const Text('WORKSPACE SYNC',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8))"
if legacy in text:
    if text.count(legacy)!=1:
        raise SystemExit(f'v352 ambiguous global live-intelligence strip count: {text.count(legacy)}')
    text=text.replace(legacy,replacement,1)
elif replacement not in text:
    raise SystemExit('v352 could not locate the global workspace sync strip')

# These contracts are valid backend contracts, but their current implementations still
# perform request-time state scans/counting. They must not be added to the sprint Flutter
# release until worker 3 replaces those paths with cached/incremental truth.
for forbidden in (
    'bridgepoint_flutter_dashboard_state_v344',
    'bridgepoint_flutter_opportunities_state_v341',
    'bridgepoint_flutter_properties_state_v345',
):
    if forbidden in text:
        raise SystemExit(
            f'v352 I/O guard: generated Flutter calls count-heavy state contract {forbidden}; '
            'use cached sprint truth before wiring this surface'
        )

# The optimized state-status contract is intentionally allowed, but it must never be tied
# to the periodic workspace refresh in this release layer. No call exists yet; future
# surface migrations may call it only on initial surface load / explicit state changes.
refresh_start=text.find('void _refreshLiveWorkspace()')
refresh_end=text.find('void _navigateTo(',refresh_start)
if refresh_start<0 or refresh_end<0:
    raise SystemExit('v352 could not locate periodic workspace refresh boundary')
refresh_body=text[refresh_start:refresh_end]
if 'bridgepoint_flutter_state_status_v345' in refresh_body:
    raise SystemExit('v352 I/O guard: state-status RPC must not run from periodic workspace refresh')

for required in (
    'bridgepoint-v341-national-customer-surfaces',
    'bridgepoint_property_suggestions_v192',
    'All My States',
    'bridgepoint-v340-national-onboarding-scope',
):
    if required not in text:
        raise SystemExit(f'v352 national sprint prerequisite missing: {required}')

if marker not in text:
    text += (
        "\nconst String _bridgePointNationalSprintReleaseGuardV352="
        "'bridgepoint-v352-national-sprint-release-guard | truthful workspace sync | no count-heavy state polling';\n"
    )

path.write_text(text,encoding='utf-8')
print('BRIDGEPOINT NATIONAL SPRINT RELEASE GUARD V352 PASSED')
print(' - global status strip no longer claims LIVE_INTELLIGENCE without selected-state strict truth')
print(' - count-heavy state dashboard/opportunity/property contracts are absent from generated Flutter')
print(' - state-status RPC is not attached to periodic workspace refresh')
print(' - existing national onboarding/search/properties surfaces remain present')
