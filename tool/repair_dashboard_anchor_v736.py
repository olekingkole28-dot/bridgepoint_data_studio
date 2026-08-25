from pathlib import Path
import re
import subprocess
import sys

PATH = Path('lib/main.dart')
DASHBOARD = 'class _DashboardScreenState extends State<DashboardScreen>'
NAV = 'static const navigationItems = <_NavigationItem>['
DISPOSE = '  @override\n  void dispose()'
EXPERIENCE = 'class _ExperienceBackground extends StatelessWidget'
BRAND_MARK = 'class _BridgePointMark extends StatelessWidget'
LEGAL_STATE = 'class _LegalAcceptanceScreenState extends State<_LegalAcceptanceScreen>'
BILLING_READY = 'Future<Map<String,dynamic>> _bridgePointBillingReadinessV220() async {'
BILLING_BANNER = 'class _BillingReadinessBannerV220 extends StatefulWidget'
TRACKERS = 'class _PersistentPropertyTrackersV212State extends State<_PersistentPropertyTrackersV212>'
COMMUNITY_3D = 'class _Community3DMapV255 extends StatefulWidget'
AFTER_DASHBOARD = 'class _BridgePointSetupChecklistV215 extends StatefulWidget'


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


def dashboard_anchor_health(value: str) -> bool:
    dashboard=value.find(DASHBOARD)
    if dashboard<0:return False
    nav=value.find(NAV,dashboard)
    dispose=value.find(DISPOSE,nav+len(NAV)) if nav>=0 else -1
    return nav>=0 and dispose>=0


def edit_span(value: str, start_token: str, end_token: str, label: str, editor) -> str:
    start, end = anchored_span(value, start_token, end_token, label)
    segment = value[start:end]
    repaired = editor(segment)
    return value[:start] + repaired + value[end:]


def brace_depth_by_line(segment: str) -> list[tuple[int,int,str]]:
    depth=0
    quote=None
    escaped=False
    line_comment=False
    block_comment=False
    line=1
    rows=[]
    current=[]
    i=0
    while i<len(segment):
        ch=segment[i]
        nxt=segment[i+1] if i+1<len(segment) else ''
        current.append(ch)
        if line_comment:
            if ch=='\n':
                line_comment=False
                rows.append((line,depth,''.join(current).rstrip()))
                current=[];line+=1
            i+=1;continue
        if block_comment:
            if ch=='*' and nxt=='/':
                current.append(nxt);block_comment=False;i+=2;continue
            if ch=='\n':
                rows.append((line,depth,''.join(current).rstrip()));current=[];line+=1
            i+=1;continue
        if quote is not None:
            if escaped:escaped=False
            elif ch=='\\':escaped=True
            elif ch==quote:quote=None
            if ch=='\n':
                rows.append((line,depth,''.join(current).rstrip()));current=[];line+=1
            i+=1;continue
        if ch=='/' and nxt=='/':
            current.append(nxt);line_comment=True;i+=2;continue
        if ch=='/' and nxt=='*':
            current.append(nxt);block_comment=True;i+=2;continue
        if ch in ("'",'\"'):
            quote=ch;i+=1;continue
        if ch=='{':depth+=1
        elif ch=='}':depth-=1
        if ch=='\n':
            rows.append((line,depth,''.join(current).rstrip()));current=[];line+=1
        i+=1
    if current:rows.append((line,depth,''.join(current).rstrip()))
    return rows


def print_dashboard_diagnostics(value: str) -> None:
    start=value.find(DASHBOARD)
    end=value.find(AFTER_DASHBOARD,start+len(DASHBOARD)) if start>=0 else -1
    if start<0 or end<0:
        print(f'v736 dashboard diagnostics unavailable: start={start} end={end}',file=sys.stderr)
        return
    segment=value[start:end]
    rows=brace_depth_by_line(segment)
    final_depth=rows[-1][1] if rows else 0
    print(f'v736 dashboard diagnostics: lines={len(rows)} final_relative_depth={final_depth}',file=sys.stderr)
    # Show member-looking lines that are suspiciously deeper than class depth 1, plus
    # the last 90 lines. This pinpoints where a method/widget stopped closing.
    suspicious=[]
    member=re.compile(r'^\s{2}(?:@override|Future<|Future<void>|void |Widget |bool |int |String |List<|Map<|Set<|static |final |late |Timer\?|double )')
    for number,depth,text in rows:
        if depth>1 and member.search(text):
            suspicious.append((number,depth,text))
    print('v736 suspicious dashboard member-depth lines:',file=sys.stderr)
    for number,depth,text in suspicious[-60:]:
        print(f'  D{depth} L{number}: {text[:220]}',file=sys.stderr)
    print('v736 dashboard tail:',file=sys.stderr)
    for number,depth,text in rows[-90:]:
        print(f'  D{depth} L{number}: {text[:260]}',file=sys.stderr)


body = PATH.read_text(encoding='utf-8')
source = canonical_source()

# Repair only ExperienceBackground itself. Earlier v736 versions restored everything
# through billing, which accidentally deleted evolved top-level helpers and UI types that
# later generators intentionally inserted between the logo and billing functions.
cs, ce = anchored_span(body, EXPERIENCE, BRAND_MARK, 'generated ExperienceBackground')
ss, se = anchored_span(source, EXPERIENCE, BRAND_MARK, 'canonical ExperienceBackground')
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

# Remove a package-list entry that was injected as a statement into billing readiness.
def clean_billing(segment: str) -> str:
    return segment.replace("    'BridgePoint Company',\n", '')

if BILLING_READY in body and BILLING_BANNER in body:
    body = edit_span(body, BILLING_READY, BILLING_BANNER, 'billing readiness', clean_billing)

# A legacy weather update was injected into the compact-navigation constructor. Delete it
# and restore the constructor terminator without replacing the evolved Dashboard region.
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

# Legacy weather/radar offsets also landed inside the persistent property tracker. Repair
# that small region so Community 3D remains a top-level component.
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

# Remove executable V318 helper calls that leaked to file/class scope. The authoritative
# repair will keep/reinsert the legitimate access call inside server configuration.
body = re.sub(
    r'(?m)^\s*(?:await\s+|unawaited\s*\(\s*)?_configureAccessV318\(\)\s*\)?\s*;\s*\n?',
    '',
    body,
)

PATH.write_text(body, encoding='utf-8')

if not dashboard_anchor_health(body):
    print_dashboard_diagnostics(body)
    raise SystemExit('v736: targeted seam repair did not recover Dashboard anchors; refusing to downgrade evolved Dashboard')

# Always emit depth diagnostics before the v735 parser runs. This is compact enough for
# CI logs and identifies the exact still-open method if the class remains unbalanced.
print_dashboard_diagnostics(body)
subprocess.run([sys.executable, 'tool/repair_generated_release_v735.py'], check=True)
print(f'BridgePoint v736 repaired targeted legacy seams without deleting evolved helpers/dashboard; compact navigation repairs={compact_repairs}; full v735 contract passed.')
