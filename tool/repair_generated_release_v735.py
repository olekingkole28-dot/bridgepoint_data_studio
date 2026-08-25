from pathlib import Path
import re
import subprocess
import sys

PATH = Path('lib/main.dart')
DASHBOARD_STATE = 'class _DashboardScreenState extends State<DashboardScreen>'


def canonical_source() -> str:
    return subprocess.check_output(['git','show','HEAD:lib/main.dart'],text=True,encoding='utf-8')


def replace_between(current: str, source: str, start_token: str, end_token: str, label: str) -> str:
    cs=current.find(start_token); ce=current.find(end_token,cs+len(start_token)) if cs>=0 else -1
    ss=source.find(start_token); se=source.find(end_token,ss+len(start_token)) if ss>=0 else -1
    if min(cs,ce,ss,se)<0: raise SystemExit(f'v735 repair: unable to locate {label} boundaries')
    return current[:cs]+source[ss:se]+current[ce:]


def block_bounds(text: str, signature: str) -> tuple[int,int]:
    start=text.find(signature)
    if start<0: raise ValueError(signature)
    brace=text.find('{',start)
    if brace<0: raise ValueError(f'{signature}: opening brace')
    depth=0; quote=None; escaped=False; line_comment=False; block_comment=False; i=brace
    while i<len(text):
        ch=text[i]; nxt=text[i+1] if i+1<len(text) else ''
        if line_comment:
            if ch=='\n': line_comment=False
            i+=1; continue
        if block_comment:
            if ch=='*' and nxt=='/': block_comment=False; i+=2; continue
            i+=1; continue
        if quote is not None:
            if escaped: escaped=False
            elif ch=='\\': escaped=True
            elif ch==quote: quote=None
            i+=1; continue
        if ch=='/' and nxt=='/': line_comment=True; i+=2; continue
        if ch=='/' and nxt=='*': block_comment=True; i+=2; continue
        if ch in ("'",'"'): quote=ch; i+=1; continue
        if ch=='{': depth+=1
        elif ch=='}':
            depth-=1
            if depth==0: return start,i+1
        i+=1
    raise ValueError(f'{signature}: unbalanced block')


def replace_block(current: str, source: str, signature: str, label: str) -> str:
    try:
        cs,ce=block_bounds(current,signature); ss,se=block_bounds(source,signature)
    except ValueError as exc:
        raise SystemExit(f'v735 repair: unable to locate balanced {label}: {exc}') from exc
    return current[:cs]+source[ss:se]+current[ce:]


def replace_scoped_between(current: str, source: str, scope_signature: str, start_token: str, end_token: str, label: str) -> str:
    try:
        cscope_start,cscope_end=block_bounds(current,scope_signature)
        sscope_start,sscope_end=block_bounds(source,scope_signature)
    except ValueError as exc:
        raise SystemExit(f'v735 repair: unable to locate {label} scope: {exc}') from exc
    cs=current.find(start_token,cscope_start,cscope_end)
    ce=current.find(end_token,cs+len(start_token),cscope_end) if cs>=0 else -1
    ss=source.find(start_token,sscope_start,sscope_end)
    se=source.find(end_token,ss+len(start_token),sscope_end) if ss>=0 else -1
    if min(cs,ce,ss,se)<0:
        raise SystemExit(f'v735 repair: unable to locate scoped {label} boundaries')
    return current[:cs]+source[ss:se]+current[ce:]


def declaration_bounds(text: str, signature: str, start: int) -> tuple[int,int]:
    sig=text.find(signature,start)
    if sig<0: raise ValueError(signature)
    cursor=sig+len(signature)
    while cursor<len(text) and text[cursor].isspace(): cursor+=1
    if cursor<len(text) and text[cursor]=='{':
        rel_start,rel_end=block_bounds(text[sig:],signature); return rel_start+sig,rel_end+sig
    paren=bracket=brace=0; quote=None; escaped=False; line_comment=False; block_comment=False; i=cursor
    while i<len(text):
        ch=text[i]; nxt=text[i+1] if i+1<len(text) else ''
        if line_comment:
            if ch=='\n': line_comment=False
            i+=1; continue
        if block_comment:
            if ch=='*' and nxt=='/': block_comment=False; i+=2; continue
            i+=1; continue
        if quote is not None:
            if escaped: escaped=False
            elif ch=='\\': escaped=True
            elif ch==quote: quote=None
            i+=1; continue
        if ch=='/' and nxt=='/': line_comment=True; i+=2; continue
        if ch=='/' and nxt=='*': block_comment=True; i+=2; continue
        if ch in ("'",'"'): quote=ch; i+=1; continue
        if ch=='(': paren+=1
        elif ch==')': paren-=1
        elif ch=='[': bracket+=1
        elif ch==']': bracket-=1
        elif ch=='{': brace+=1
        elif ch=='}': brace-=1
        elif ch==';' and paren==0 and bracket==0 and brace==0: return sig,i+1
        i+=1
    raise ValueError(f'{signature}: declaration terminator')


def remove_declarations_outside_scope(text: str, signature: str, scope_signature: str) -> str:
    try:
        scope_start,scope_end=block_bounds(text,scope_signature)
    except ValueError as exc:
        raise SystemExit(f'v735 repair: scope missing while cleaning {signature}: {exc}') from exc
    starts=[m.start() for m in re.finditer(re.escape(signature),text)]
    outside=[start for start in starts if not (scope_start<=start<scope_end)]
    ranges=[]
    for start in outside:
        try:ranges.append(declaration_bounds(text,signature,start))
        except ValueError as exc: raise SystemExit(f'v735 repair: cannot remove orphan {signature}: {exc}') from exc
    for start,end in reversed(ranges):
        while end<len(text) and text[end] in ' \t': end+=1
        if end<len(text) and text[end]=='\n': end+=1
        text=text[:start]+text[end:]
    return text


def paren_call_bounds(text: str, call_start: int) -> tuple[int,int]:
    open_paren=text.find('(',call_start)
    if open_paren<0: raise ValueError('call opening paren')
    depth=0; quote=None; escaped=False; line_comment=False; block_comment=False; i=open_paren
    while i<len(text):
        ch=text[i]; nxt=text[i+1] if i+1<len(text) else ''
        if line_comment:
            if ch=='\n': line_comment=False
            i+=1; continue
        if block_comment:
            if ch=='*' and nxt=='/': block_comment=False; i+=2; continue
            i+=1; continue
        if quote is not None:
            if escaped: escaped=False
            elif ch=='\\': escaped=True
            elif ch==quote: quote=None
            i+=1; continue
        if ch=='/' and nxt=='/': line_comment=True; i+=2; continue
        if ch=='/' and nxt=='*': block_comment=True; i+=2; continue
        if ch in ("'",'"'): quote=ch; i+=1; continue
        if ch=='(': depth+=1
        elif ch==')':
            depth-=1
            if depth==0:return call_start,i+1
        i+=1
    raise ValueError('unbalanced call')


def restore_properties_heading(current: str, source: str) -> str:
    class_sig='class _PropertiesPageState extends State<_PropertiesPage>'
    title_needles=("title: 'Properties'","title:'Properties'")
    def locate(value: str) -> tuple[int,int]:
        start,end=block_bounds(value,class_sig); segment=value[start:end]; title=-1
        for needle in title_needles:
            pos=segment.find(needle)
            if pos>=0:title=start+pos;break
        if title<0:raise ValueError('Properties PageHeading title')
        call=value.rfind('_PageHeading(',start,title)
        if call<0:raise ValueError('Properties PageHeading call')
        return paren_call_bounds(value,call)
    try:cs,ce=locate(current);ss,se=locate(source)
    except ValueError as exc:raise SystemExit(f'v735 repair: unable to restore national Properties heading: {exc}') from exc
    return current[:cs]+source[ss:se]+current[ce:]


def count_auth_init_states(text: str) -> int:
    try:start,end=block_bounds(text,'class _AuthScreenState extends State<_AuthScreen>')
    except ValueError:return -1
    return len(re.findall(r'\bvoid\s+initState\s*\(',text[start:end]))


def count_fallback_languages(text: str) -> int:
    start=text.find('const List<Map<String, String>> _bridgePointFallbackLanguages = [');end=text.find('];',start)
    if start<0 or end<0:return 0
    return len(re.findall(r"\{'locale':\s*'",text[start:end]))


def count_in_scope(text: str, scope_signature: str, needle: str) -> int:
    try:start,end=block_bounds(text,scope_signature)
    except ValueError:return -1
    return text[start:end].count(needle)


def validate(text: str, require_resilience: bool=False) -> None:
    errors=[]
    if text.count('class _AuthScreenState extends State<_AuthScreen>')!=1:errors.append('AuthScreenState class must exist exactly once')
    if count_auth_init_states(text)!=1:errors.append('AuthScreenState must contain exactly one initState()')
    if count_in_scope(text,DASHBOARD_STATE,'List<_NavigationItem> get visibleNavigationItems')!=1:errors.append('dashboard visibleNavigationItems must be defined exactly once')
    if count_in_scope(text,DASHBOARD_STATE,'static const navigationItems = <_NavigationItem>[')!=1:errors.append('dashboard navigationItems static list must be defined exactly once')
    if text.count('List<_NavigationItem> get visibleNavigationItems')!=1:errors.append('orphan visibleNavigationItems declaration exists outside dashboard')
    if text.count('static const navigationItems = <_NavigationItem>[')!=1:errors.append('orphan navigationItems declaration exists outside dashboard')
    if text.count('class _BridgePointMarkPainter extends CustomPainter')!=1:errors.append('BridgePointMarkPainter must exist exactly once')
    if '// bridgepoint-localization-v711' not in text:errors.append('localization v711 marker missing')
    if 'home: const _LanguageBootstrap(),' not in text:errors.append('first-entry language bootstrap missing')
    if 'bridgepoint_supported_languages_v711' not in text:errors.append('supported-language RPC missing')
    if 'bridgepoint_save_locale_v711' not in text:errors.append('locale persistence RPC missing')
    languages=count_fallback_languages(text)
    if languages<27:errors.append(f'language selector has only {languages} fallback languages; expected at least 27')
    if '// bridgepoint-visible-national-v728' not in text:errors.append('national-visible v728 marker missing')
    if 'Authorized U.S. property universe' not in text:errors.append('national Properties copy missing')
    if 'Connecticut property universe • search, inspect, and open intelligence' in text:errors.append('legacy CT-only Properties copy reintroduced')
    if 'Save my info for next time' not in text:errors.append('secure remembered email/nickname control missing')
    if 'BridgePoint never stores your password here.' not in text:errors.append('remembered-info password-safety disclosure missing')
    if require_resilience:
        status_refs=text.count('bridgepoint_public_system_status_v320')
        if status_refs<1 or status_refs>3:errors.append(f'v320 public system-status RPC reference count suspicious: {status_refs}')
        if text.count('class _SystemStatusGateV320 extends StatefulWidget')!=1:errors.append('v320 system-status gate must exist exactly once')
        if 'child: const _SystemStatusGateV320(child: _AuthGate()),' not in text:errors.append('language bootstrap must hand off through the v320 system-status gate')
        for marker in ('bridgepoint-v320-resilience-market-guard-service-credit','bridgepoint-v320-unsupported-market-preview','bridgepoint-v320-owner-resilience-metrics','bridgepoint_public_expansion_status_v321','bridgepoint-v319-owner-pattern-intelligence + iso-wms-preloaded-radar + municipal-permit-live'):
            if marker not in text:errors.append(f'guarded generated capability missing after repair: {marker}')
    for match in re.finditer(r'(?m)^\s*(?:await\s+|unawaited\s*\(\s*)?_configureAccessV318\(\)\s*\)?\s*;\s*$',text):
        try:ds,de=block_bounds(text,DASHBOARD_STATE)
        except ValueError:ds=de=-1
        if not(ds<=match.start()<de):errors.append('orphan _configureAccessV318() call remains outside dashboard');break
    if errors:raise SystemExit('v735 final generated contract failed: '+'; '.join(errors))


canonical=canonical_source();body=PATH.read_text(encoding='utf-8')

# Source-owned auth. Merge secure remembered email/nickname back below.
body=replace_block(body,canonical,'class _AuthScreenState extends State<_AuthScreen>','AuthScreenState')

# First-entry localization is source-owned.
body=replace_between(body,canonical,'// bridgepoint-localization-v711','class _AuthGate','localization bootstrap')

# Critical structural recovery: old V318 patches have historically injected dashboard
# access/navigation declarations into the logo CustomPainter. Restore the painter from
# source before touching dashboard navigation so a global first-match can never delete
# the classes/helpers between the logo and dashboard again.
body=replace_block(body,canonical,'class _BridgePointMarkPainter extends CustomPainter','BridgePointMarkPainter')

# Preserve the evolved Dashboard whenever it is already structurally valid. Older repair
# logic replaced everything from navigation through dispose() with the raw source version,
# which silently erased newer access, owner, global-search and premium-navigation fields.
# Fall back to canonical replacement only when generation is still structurally damaged.
try:
    ds,de=block_bounds(body,DASHBOARD_STATE)
    dashboard=body[ds:de]
    evolved_dashboard_ok=(
        dashboard.count('static const navigationItems = <_NavigationItem>[')==1
        and dashboard.count('List<_NavigationItem> get visibleNavigationItems')==1
        and '  @override\n  void dispose()' in dashboard
    )
except ValueError:
    evolved_dashboard_ok=False

if not evolved_dashboard_ok:
    body=replace_scoped_between(
        body,canonical,DASHBOARD_STATE,
        'static const navigationItems = <_NavigationItem>[',
        '  @override\n  void dispose()',
        'dashboard navigation + workspace init',
    )
else:
    print('v735: preserving structurally valid evolved Dashboard navigation/workspace capabilities')

body=remove_declarations_outside_scope(body,'List<_NavigationItem> get visibleNavigationItems',DASHBOARD_STATE)
body=remove_declarations_outside_scope(body,'static const navigationItems = <_NavigationItem>[',DASHBOARD_STATE)

# Current national public copy is source-owned.
body=restore_properties_heading(body,canonical)

# Server settings method structure is source-owned; V318 is allowed only as an in-method
# helper call, never as a class/file-scope executable statement.
try:
    generated_has_v318='Future<void> _configureAccessV318' in body
    body=replace_block(body,canonical,'Future<void> _configureFromServer() async','_configureFromServer')
    if generated_has_v318:
        ms,me=block_bounds(body,'Future<void> _configureFromServer() async');method=body[ms:me]
        if '_configureAccessV318();' not in method:
            close=method.rfind('}');method=method[:close]+'    await _configureAccessV318();\n  '+method[close:];body=body[:ms]+method+body[me:]
except SystemExit:raise
except Exception as exc:raise SystemExit(f'v735 repair: configure method repair failed: {exc}') from exc

PATH.write_text(body,encoding='utf-8')
subprocess.run([sys.executable,'tool/repair_remembered_auth_v735.py'],check=True)
body=PATH.read_text(encoding='utf-8')
validate(body)

subprocess.run([sys.executable,'tool/repair_v321_release_guard.py'],check=True)
body=PATH.read_text(encoding='utf-8')
validate(body,require_resilience=True)

print('BridgePoint v735 authoritative generated-release repair passed.')
print(' - auth lifecycle: single canonical initState + secure remembered email/nickname')
print(' - logo painter: canonical structure restored; no dashboard access code may live inside paint()')
print(' - navigation: evolved Dashboard preserved when structurally valid; canonical fallback only on corruption')
print(' - national Properties heading: canonical U.S. truth restored')
print(' - localization: 27-language first-entry selector preserved')
print(' - resilience: live v320/v321 status + expansion contracts preserved behind language bootstrap')
print(' - server configuration: canonical method structure restored')
