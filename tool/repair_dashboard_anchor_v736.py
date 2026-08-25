from pathlib import Path
import re
import subprocess
import sys

PATH = Path('lib/main.dart')
DASHBOARD = 'class _DashboardScreenState extends State<DashboardScreen>'
NAV = 'static const navigationItems = <_NavigationItem>['
DISPOSE = '  @override\n  void dispose()'


def canonical_source() -> str:
    return subprocess.check_output(
        ['git', 'show', 'HEAD:lib/main.dart'], text=True, encoding='utf-8'
    )


def dashboard_anchored_span(value: str, label: str) -> tuple[int, int]:
    dashboard = value.find(DASHBOARD)
    if dashboard < 0:
        raise SystemExit(f'v736: {label} DashboardScreenState anchor missing')
    start = value.find(NAV, dashboard)
    end = value.find(DISPOSE, start + len(NAV)) if start >= 0 else -1
    if start < 0 or end < 0:
        raise SystemExit(f'v736: {label} dashboard navigation/dispose anchors missing')
    return start, end


body = PATH.read_text(encoding='utf-8')
source = canonical_source()
cs, ce = dashboard_anchored_span(body, 'generated')
ss, se = dashboard_anchored_span(source, 'canonical')
body = body[:cs] + source[ss:se] + body[ce:]

# Legacy V318 generation can leave executable helper calls at file/class scope.
# Remove every standalone invocation here. The authoritative v735 repair detects the
# helper definition and re-adds exactly one awaited call inside _configureFromServer().
body = re.sub(
    r'(?m)^\s*(?:await\s+|unawaited\s*\(\s*)?_configureAccessV318\(\)\s*\)?\s*;\s*\n?',
    '',
    body,
)
PATH.write_text(body, encoding='utf-8')

# Now that legacy generation can no longer leave the Dashboard scope structurally
# ambiguous, run the full authoritative repair and all of its release-contract checks.
subprocess.run([sys.executable, 'tool/repair_generated_release_v735.py'], check=True)
print('BridgePoint v736 repaired dashboard anchors and orphan V318 calls, then passed the full v735 contract.')
