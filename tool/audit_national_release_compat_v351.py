from __future__ import annotations

from collections import deque
from pathlib import Path
import re

WORKFLOW = Path('.github/workflows/flutter-web.yml')
GENERATED = Path('lib/main.dart')
FORBIDDEN_SCRIPT = 'tool/apply_national_app_contracts_v345.py'
DEFERRED_MARKER = 'v345 broad app migration retained for dedicated compatibility validation'
BROAD_OUTPUT_MARKER = 'bridgepoint-v345-national-app-contracts'

workflow = WORKFLOW.read_text(encoding='utf-8')

# Keep the deprecated source available only as reference material for extracting
# one compatible surface at a time. Deleting it would hide the migration history;
# activating it would reintroduce the known release breakage.
if not Path(FORBIDDEN_SCRIPT).exists():
    raise SystemExit('v351 release compatibility audit: isolated v345 source unexpectedly missing')

# Start from every Python release layer executed by the production Flutter workflow.
# Then recursively follow runpy/subprocess-style references so a nested helper cannot
# silently re-chain the deprecated broad v345 migration later.
roots = set(re.findall(r'\bpython(?:3)?\s+(tool/[A-Za-z0-9_.\-/]+\.py)\b', workflow))
if not roots:
    raise SystemExit('v351 release compatibility audit: no Python release roots found')

visited: set[str] = set()
parents: dict[str, str | None] = {root: None for root in roots}
queue = deque(sorted(roots))

child_patterns = (
    re.compile(r"runpy\.run_path\(\s*['\"](tool/[^'\"]+\.py)['\"]"),
    re.compile(r"\bpython(?:3)?\s+(tool/[A-Za-z0-9_.\-/]+\.py)\b"),
)

while queue:
    rel = queue.popleft()
    if rel in visited:
        continue
    visited.add(rel)
    path = Path(rel)
    if not path.exists():
        raise SystemExit(f'v351 release compatibility audit: active release script missing: {rel}')
    source = path.read_text(encoding='utf-8')
    for pattern in child_patterns:
        for child in pattern.findall(source):
            if child not in parents:
                parents[child] = rel
            if child not in visited:
                queue.append(child)

if FORBIDDEN_SCRIPT in visited:
    chain = []
    node: str | None = FORBIDDEN_SCRIPT
    while node is not None:
        chain.append(node)
        node = parents.get(node)
    chain.reverse()
    raise SystemExit(
        'v351 release compatibility audit: deprecated broad v345 migration is active in release graph: '
        + ' -> '.join(chain)
    )

body = GENERATED.read_text(encoding='utf-8')
if BROAD_OUTPUT_MARKER in body:
    raise SystemExit(
        'v351 release compatibility audit: generated Flutter source contains broad v345 marker; '
        'the migration must remain isolated until migrated surface-by-surface'
    )
if DEFERRED_MARKER not in body:
    raise SystemExit(
        'v351 release compatibility audit: generated source lost the explicit v345 deferred-compatibility marker'
    )

# Guard the validated national map release while other surfaces migrate incrementally.
for marker in (
    'bridgepoint-v341-national-customer-surfaces',
    'national intelligence coverage',
    'live ranked property intelligence',
    'bridgepoint-v352-national-dashboard-low-io',
    '_DashboardStateSelectorV352',
    '_StateTruthBannerV352',
    'bridgepoint_flutter_map_state_status_v349',
    "'live_count_rpc_used':false",
):
    if marker not in body:
        raise SystemExit(f'v351 release compatibility audit: national customer compatibility marker missing: {marker}')

# Daily Brief must not fall back to the legacy CT-only dashboard payload. V345 live
# counts remain permitted because V352 gates them behind actual LIVE/customer-visible truth.
if '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_dashboard_v57' in body:
    raise SystemExit('v351 release compatibility audit: legacy CT-only dashboard RPC returned after V352')

print('BRIDGEPOINT NATIONAL RELEASE COMPATIBILITY V351 PASSED')
print(f' - traced {len(visited)} active Python release scripts from workflow roots')
print(' - deprecated broad v345 migration source is retained but unreachable from production')
print(' - generated Flutter source does not contain the broad v345 migration marker')
print(' - V352 Daily Brief is national and low-I/O while later surfaces remain isolated')
