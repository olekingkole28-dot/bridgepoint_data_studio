from pathlib import Path
import re
import subprocess
import sys

PATH = Path('lib/main.dart')


def canonical_source() -> str:
    return subprocess.check_output(
        ['git', 'show', 'HEAD:lib/main.dart'],
        text=True,
        encoding='utf-8',
    )


def replace_between(current: str, source: str, start_token: str, end_token: str, label: str) -> str:
    cs = current.find(start_token)
    ce = current.find(end_token, cs + len(start_token)) if cs >= 0 else -1
    ss = source.find(start_token)
    se = source.find(end_token, ss + len(start_token)) if ss >= 0 else -1
    if min(cs, ce, ss, se) < 0:
        raise SystemExit(f'v735 repair: unable to locate {label} boundaries')
    return current[:cs] + source[ss:se] + current[ce:]


def block_bounds(text: str, signature: str) -> tuple[int, int]:
    start = text.find(signature)
    if start < 0:
        raise ValueError(signature)
    brace = text.find('{', start)
    if brace < 0:
        raise ValueError(f'{signature}: opening brace')
    depth = 0
    quote = None
    escaped = False
    line_comment = False
    block_comment = False
    i = brace
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''
        if line_comment:
            if ch == '\n':
                line_comment = False
            i += 1
            continue
        if block_comment:
            if ch == '*' and nxt == '/':
                block_comment = False
                i += 2
                continue
            i += 1
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch == '/' and nxt == '/':
            line_comment = True
            i += 2
            continue
        if ch == '/' and nxt == '*':
            block_comment = True
            i += 2
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return start, i + 1
        i += 1
    raise ValueError(f'{signature}: unbalanced block')


def replace_block(current: str, source: str, signature: str, label: str) -> str:
    try:
        cs, ce = block_bounds(current, signature)
        ss, se = block_bounds(source, signature)
    except ValueError as exc:
        raise SystemExit(f'v735 repair: unable to locate balanced {label}: {exc}') from exc
    return current[:cs] + source[ss:se] + current[ce:]


def count_auth_init_states(text: str) -> int:
    try:
        start, end = block_bounds(text, 'class _AuthScreenState extends State<_AuthScreen>')
    except ValueError:
        return -1
    return len(re.findall(r'\bvoid\s+initState\s*\(', text[start:end]))


def count_fallback_languages(text: str) -> int:
    start = text.find('const List<Map<String, String>> _bridgePointFallbackLanguages = [')
    end = text.find('];', start)
    if start < 0 or end < 0:
        return 0
    return len(re.findall(r"\{'locale':\s*'", text[start:end]))


def validate(text: str, require_resilience: bool = False) -> None:
    errors = []
    if text.count('class _AuthScreenState extends State<_AuthScreen>') != 1:
        errors.append('AuthScreenState class must exist exactly once')
    if count_auth_init_states(text) != 1:
        errors.append('AuthScreenState must contain exactly one initState()')
    if text.count('List<_NavigationItem> get visibleNavigationItems') != 1:
        errors.append('visibleNavigationItems must be defined exactly once')
    if text.count('static const navigationItems = <_NavigationItem>[') != 1:
        errors.append('navigationItems static list must be defined exactly once')
    if '// bridgepoint-localization-v711' not in text:
        errors.append('localization v711 marker missing')
    if 'home: const _LanguageBootstrap(),' not in text:
        errors.append('first-entry language bootstrap missing')
    if 'bridgepoint_supported_languages_v711' not in text:
        errors.append('supported-language RPC missing')
    if 'bridgepoint_save_locale_v711' not in text:
        errors.append('locale persistence RPC missing')
    languages = count_fallback_languages(text)
    if languages < 27:
        errors.append(f'language selector has only {languages} fallback languages; expected at least 27')
    if '// bridgepoint-visible-national-v728' not in text:
        errors.append('national-visible v728 marker missing')
    if 'Authorized U.S. property universe' not in text:
        errors.append('national Properties copy missing')
    if 'Connecticut property universe • search, inspect, and open intelligence' in text:
        errors.append('legacy CT-only Properties copy reintroduced')

    if require_resilience:
        if text.count('bridgepoint_public_system_status_v320') != 1:
            errors.append('live v320 public system-status RPC must be referenced exactly once')
        if text.count('class _SystemStatusGateV320 extends StatefulWidget') != 1:
            errors.append('v320 system-status gate must exist exactly once')
        if 'child: const _SystemStatusGateV320(child: _AuthGate()),' not in text:
            errors.append('language bootstrap must hand off through the v320 system-status gate')
        for marker in (
            'bridgepoint-v320-resilience-market-guard-service-credit',
            'bridgepoint-v320-unsupported-market-preview',
            'bridgepoint-v320-owner-resilience-metrics',
            'bridgepoint_user_market_context_v320',
            'bridgepoint-v319-owner-pattern-intelligence + iso-wms-preloaded-radar + municipal-permit-live',
        ):
            if marker not in text:
                errors.append(f'guarded generated capability missing after repair: {marker}')

    # The generated release may include V318 access logic, but it may never be left as
    # a free-standing executable statement at class/file scope. The canonical
    # _configureFromServer method below owns configuration structure.
    for match in re.finditer(r'(?m)^\s*(?:await\s+)?_configureAccessV318\(\);\s*$', text):
        before = text[:match.start()]
        if before.count('{') <= before.count('}'):
            errors.append('orphan _configureAccessV318() call remains outside a method')
            break

    if errors:
        raise SystemExit('v735 final generated contract failed: ' + '; '.join(errors))


canonical = canonical_source()
body = PATH.read_text(encoding='utf-8')

# 1) Auth is owned by the checked-in source. Older release layers may add behavior,
# but they may not create a second lifecycle method.
body = replace_block(
    body,
    canonical,
    'class _AuthScreenState extends State<_AuthScreen>',
    'AuthScreenState',
)

# 2) Localization/first-entry language selection is source-owned. Historical
# generators are not allowed to erase or partially preserve this region.
body = replace_between(
    body,
    canonical,
    '// bridgepoint-localization-v711',
    'class _AuthGate',
    'localization bootstrap',
)

# 3) Navigation ownership stays with canonical source through initState. This removes
# duplicate visibleNavigationItems declarations and functions accidentally injected
# into the static navigation list while preserving later generated owner widgets.
body = replace_between(
    body,
    canonical,
    'static const navigationItems = <_NavigationItem>[',
    '  @override\n  void dispose()',
    'navigation + workspace init',
)

# 4) Rebuild _configureFromServer from canonical source so v318/v325 cannot leave
# brace-corrupted method composition. If the generated release has a valid V318 access
# helper, call it from inside the canonical async method exactly once.
try:
    generated_has_v318 = 'Future<void> _configureAccessV318' in body
    body = replace_block(
        body,
        canonical,
        'Future<void> _configureFromServer() async',
        '_configureFromServer',
    )
    if generated_has_v318:
        ms, me = block_bounds(body, 'Future<void> _configureFromServer() async')
        method = body[ms:me]
        if '_configureAccessV318();' not in method:
            close = method.rfind('}')
            method = method[:close] + '    await _configureAccessV318();\n  ' + method[close:]
            body = body[:ms] + method + body[me:]
except SystemExit:
    raise
except Exception as exc:
    raise SystemExit(f'v735 repair: configure method repair failed: {exc}') from exc

# Validate the canonical structural recovery before layering the live resilience gate
# back into the localization handoff.
validate(body)
PATH.write_text(body, encoding='utf-8')

# The v320/v321 system-status contract is still live in Supabase. Re-apply its actual
# fail-open gate after canonical localization recovery so the first-entry language
# selector remains authoritative and system safeguards remain functional.
subprocess.run([sys.executable, 'tool/repair_v321_release_guard.py'], check=True)
body = PATH.read_text(encoding='utf-8')
validate(body, require_resilience=True)

print('BridgePoint v735 authoritative generated-release repair passed.')
print(' - auth lifecycle: single canonical initState')
print(' - navigation: single canonical list/getter region')
print(' - localization: 27-language first-entry selector preserved')
print(' - resilience: live v320 status gate preserved behind language bootstrap')
print(' - server configuration: canonical method structure restored')
