from pathlib import Path
import re
import subprocess
import sys

PATH = Path('lib/main.dart')
DASHBOARD = 'class _DashboardScreenState extends State<DashboardScreen>'
NAV = 'static const navigationItems = <_NavigationItem>['
DISPOSE = '  @override\n  void dispose()'
EXPERIENCE = 'class _ExperienceBackground extends StatelessWidget'
OPEN_STRIPE = 'Future<void> _openStripeFlow'
LEGAL_STATE = 'class _LegalAcceptanceScreenState extends State<_LegalAcceptanceScreen>'
BILLING_READY = 'Future<Map<String,dynamic>> _bridgePointBillingReadinessV220() async {'
BILLING_BANNER = 'class _BillingReadinessBannerV220 extends StatefulWidget'
TRACKERS = 'class _PersistentPropertyTrackersV212State extends State<_PersistentPropertyTrackersV212>'
COMMUNITY_3D = 'class _Community3DMapV255 extends StatefulWidget'


def canonical_source() -> str:
    return subprocess.check_output(
        ['git', 'show', 'HEAD:lib/main.dart'], text=True, encoding='utf-8'
    )


def anchored_span(value: str, start_token: str, end_token: str, label: str) -> tuple[int, int]:
    start = value.find(start_token)
    end = value.find(end_token, start + len(start_token)) if start >= 0 else -1
    if start < 0 or end < 0:
        raise SystemExit(f'v736: {label} anchors missing')
    return start, end


def dashboard_anchored_span(value: str, label: str) -> tuple[int, int]:
    dashboard = value.find(DASHBOARD)
    if dashboard < 0:
        raise SystemExit(f'v736: {label} DashboardScreenState anchor missing')
    start = value.find(NAV, dashboard)
    end = value.find(DISPOSE, start + len(NAV)) if start >= 0 else -1
    if start < 0 or end < 0:
        raise SystemExit(f'v736: {label} dashboard navigation/dispose anchors missing')
    return start, end


def edit_span(value: str, start_token: str, end_token: str, label: str, editor) -> str:
    start, end = anchored_span(value, start_token, end_token, label)
    segment = value[start:end]
    repaired = editor(segment)
    return value[:start] + repaired + value[end:]


body = PATH.read_text(encoding='utf-8')
source = canonical_source()

# V278/V312 and legacy offset patches can leave the ExperienceBackground/brand painter
# syntactically open. Restore that source-owned shell before any brace-based repair.
cs, ce = anchored_span(body, EXPERIENCE, OPEN_STRIPE, 'generated experience shell')
ss, se = anchored_span(source, EXPERIENCE, OPEN_STRIPE, 'canonical experience shell')
body = body[:cs] + source[ss:se] + body[ce:]

# Remove V318 access fields and package-map debris that old line-offset patches inserted
# into the legal acceptance method/widget. These declarations belong to Dashboard only.
def clean_legal(segment: str) -> str:
    for line in (
        '  bool _accessResolvedV318=false;\n',
        '  Set<String> _featuresV318=<String>{};\n',
        '  Set<String> _allowedModelKeysV318=<String>{};\n',
        '  Set<String> _activePackageKeysV318=<String>{};\n',
        "    'BridgePoint Company': 'all',\n",
    ):
        segment = segment.replace(line, '')
    return segment

body = edit_span(body, LEGAL_STATE, EXPERIENCE, 'legal acceptance', clean_legal)

# Remove a package-list entry that was injected as a statement into the billing-readiness
# function. The package remains represented in its real catalog/navigation structures.
def clean_billing(segment: str) -> str:
    return segment.replace("    'BridgePoint Company',\n", '')

if BILLING_READY in body and BILLING_BANNER in body:
    body = edit_span(body, BILLING_READY, BILLING_BANNER, 'billing readiness', clean_billing)

# A legacy weather update was injected in the middle of the compact-navigation constructor.
# Delete it and restore the constructor terminator so Dashboard can close normally.
compact_weather = re.compile(
    r"(?P<indent>\s*)onMoreTools:_openMoreToolsV248,\s*\n"
    r"\s*if\(mounted\)\{setState\(\(\)\{weatherEntitledV318=true;weatherEffect=kind;"
    r"weatherText=description\.isEmpty\?'Current weather':description;"
    r"weatherIntensity=\(pop/100\)\.clamp\(\.20,1\.0\)\.toDouble\(\);\}\);_syncWeatherMotion\(\);\}\s*\n"
)
body, compact_repairs = compact_weather.subn(
    lambda m: f"{m.group('indent')}onMoreTools:_openMoreToolsV248,\n{m.group('indent')}),\n",
    body,
)

# The same legacy weather/radar offsets landed inside the persistent property tracker:
# one fragment stole add()'s closing brace and another sits after the Card return. Repair
# that small region so Community 3D is top-level again instead of being parsed inside it.
def clean_trackers(segment: str) -> str:
    segment = re.sub(
        r"\n\s*if\(weatherEntitledV318\)_OpportunityChip\(label:'WEATHER • \$weatherText',"
        r"color:weatherEffect=='RAIN'\?AppTheme\.blue:weatherEffect=='SNOW'\?const Color\(0xFFBBDFFF\):AppTheme\.cyan\),?\s*\n",
        '\n',
        segment,
    )
    segment = re.sub(
        r"\n\s*if\(_nationalRadarFramesV287\.isNotEmpty\)\.\.\.\[const SizedBox\(height:7\),"
        r"const _RadarIntensityLegendV318\(compact:true\)\],?\s*\n",
        '\n',
        segment,
    )
    add_tail = "if(mounted)setState(()=>request=_callRpc('bridgepoint_my_property_trackers_v212',const {}));\n"
    remove_start = '  Future<void> remove(String id)async{'
    pos = segment.find(add_tail)
    remove = segment.find(remove_start, pos + len(add_tail)) if pos >= 0 else -1
    if pos >= 0 and remove >= 0:
        between = segment[pos + len(add_tail):remove]
        if '}' not in between:
            segment = segment[:pos + len(add_tail)] + '  }\n' + segment[remove:]
    return segment

if TRACKERS in body and COMMUNITY_3D in body:
    body = edit_span(body, TRACKERS, COMMUNITY_3D, 'persistent property trackers', clean_trackers)

# Restore Dashboard navigation/workspace initialization without requiring generated brace
# balance. This class anchor prevents any orphan navigation list from becoming the target.
cs, ce = dashboard_anchored_span(body, 'generated')
ss, se = dashboard_anchored_span(source, 'canonical')
body = body[:cs] + source[ss:se] + body[ce:]

# Legacy V318 can also leave executable helper calls at file/class scope. Remove all
# standalone invocations; v735 re-adds exactly one awaited call inside _configureFromServer.
body = re.sub(
    r'(?m)^\s*(?:await\s+|unawaited\s*\(\s*)?_configureAccessV318\(\)\s*\)?\s*;\s*\n?',
    '',
    body,
)

PATH.write_text(body, encoding='utf-8')

# With high-risk seams normalized, run the authoritative localization/national/access/
# remembered-auth/resilience repair and fail closed if any release contract regresses.
subprocess.run([sys.executable, 'tool/repair_generated_release_v735.py'], check=True)
print(f'BridgePoint v736 normalized legacy injection seams; compact navigation repairs={compact_repairs}; full v735 contract passed.')
