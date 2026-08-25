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


body = PATH.read_text(encoding='utf-8')
source = canonical_source()

# V278/V312 and the V318/V319 legacy offset patches can leave the app-shell painter
# or ExperienceBackground syntactically open, causing every later top-level helper and
# class to be parsed as a child declaration. Restore this small source-owned shell as a
# whole using stable top-level anchors; this is deliberately done before brace parsing.
cs, ce = anchored_span(body, EXPERIENCE, OPEN_STRIPE, 'generated experience shell')
ss, se = anchored_span(source, EXPERIENCE, OPEN_STRIPE, 'canonical experience shell')
body = body[:cs] + source[ss:se] + body[ce:]

# Restore the Dashboard navigation/workspace initialization region without requiring the
# generated Dashboard to be brace-balanced yet. The class anchor prevents an orphan
# legacy navigation list elsewhere in the file from becoming the replacement target.
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

# With the high-risk legacy shell normalized, run the full authoritative repair and all
# of its localization, national visibility, remembered-auth, and resilience contracts.
subprocess.run([sys.executable, 'tool/repair_generated_release_v735.py'], check=True)
print('BridgePoint v736 restored the app shell, dashboard anchors and orphan V318 calls, then passed the full v735 contract.')
