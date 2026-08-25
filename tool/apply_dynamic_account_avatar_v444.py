from pathlib import Path
import re
import subprocess
import sys

# These are the last additive owner overlays. Apply them first, then normalize the
# historically generated structural regions before validating/adding the avatar.
subprocess.run([sys.executable,'tool/apply_owner_ai_visibility_v602.py'],check=True)
subprocess.run([sys.executable,'tool/apply_owner_global_ai_v678.py'],check=True)
subprocess.run([sys.executable,'tool/repair_generated_release_v735.py'],check=True)
# v735 deliberately restores canonical auth structure. Re-apply only the approved
# secure remembered-email/nickname behavior afterward while retaining signup deeplinks.
subprocess.run([sys.executable,'tool/restore_remembered_auth_v735.py'],check=True)

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v444-dynamic-account-avatar'


def require_release_contract(value: str) -> None:
    start=value.find('class _TopBar extends StatelessWidget')
    end=value.find('class _LiveSyncStrip',start)
    if start<0 or end<0:
        raise SystemExit('v444 avatar: TopBar boundaries missing')
    top=value[start:end]
    checks={
        'release marker': marker in top,
        'dynamic profile metadata': "metadata['display_name']" in top,
        'shared avatar widget': top.count('_accountAvatar(context)')==2,
        '48px touch target': 'width: 48' in top and 'height: 48' in top,
        'account action': 'onTap: onAvatarTap' in top,
        'settings route': "onAvatarTap:()=>_navigateTrainingLabel('Settings')" in value,
        'no hard-coded KJ': "'KJ'" not in top,
        'localization marker': '// bridgepoint-localization-v711' in value,
        'first-entry language bootstrap': 'home: const _LanguageBootstrap(),' in value,
        'supported language RPC': 'bridgepoint_supported_languages_v711' in value,
        'locale persistence RPC': 'bridgepoint_save_locale_v711' in value,
        'local locale persistence': "package:shared_preferences/shared_preferences.dart" in value,
        'national visible marker': '// bridgepoint-visible-national-v728' in value,
        'national Properties copy': 'Authorized U.S. property universe' in value,
        'no CT-only Properties subtitle': 'Connecticut property universe • search, inspect, and open intelligence' not in value,
        'autocomplete enter selection': re.search(r'onSubmitted\s*:\s*\(_\)\s*\{\s*onFieldSubmitted\(\);\s*\}',value) is not None,
        'v602 owner workforce': 'bridgepoint-v602-owner-ai-workers-forgotten-work' in value,
        'v678 owner global controls': '// bridgepoint-v678-native-owner-global-ai' in value,
        'v735 resilience gate': 'bridgepoint_public_system_status_v320' in value,
        'secure remembered auth': 'bridgepoint-v735-secure-remembered-auth' in value,
        'remembered auth control': 'Save my info for next time' in value,
        'signup deeplink preserved': "create=mode=='signup'||mode=='create'||mode=='trial'" in value,
        'no password persistence': 'bridgepoint_remember_password' not in value,
    }
    missing=[label for label,passed in checks.items() if not passed]
    if missing:
        raise SystemExit(f'v444 final release contract incomplete: {missing}')


if marker in body:
    require_release_contract(body)
    print('BridgePoint v444 dynamic avatar + localization + national + owner-control + remembered-auth release contract verified after v735 normalization.')
    raise SystemExit(0)

start=body.find('class _TopBar extends StatelessWidget')
end=body.find('class _LiveSyncStrip',start)
if start<0 or end<0:
    raise SystemExit('v444 avatar: TopBar boundaries missing')
top=body[start:end]


def replace_top_once(old: str,new: str,label: str) -> None:
    global top
    count=top.count(old)
    if count!=1:
        raise SystemExit(f'v444 avatar {label}: expected exactly 1 match, found {count}')
    top=top.replace(old,new,1)


replace_top_once(
    '    required this.onTraining,\n  });',
    '    required this.onTraining,\n    required this.onAvatarTap,\n  });',
    'constructor',
)
replace_top_once(
    '  final VoidCallback onTraining;\n',
    '  final VoidCallback onTraining;\n  final VoidCallback onAvatarTap;\n',
    'callback field',
)

helpers=r'''  // bridgepoint-v444-dynamic-account-avatar
  String get _profileLabel {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final displayName = metadata == null
        ? ''
        : (metadata['display_name']?.toString().trim() ?? '');
    if (displayName.isNotEmpty) return displayName;
    final email = user?.email?.trim() ?? '';
    return email.isNotEmpty ? email : 'BridgePoint account';
  }

  String _profileInitials(String label) {
    if (label == 'BridgePoint account') return 'BP';
    final base = label.contains('@') ? label.split('@').first : label;
    final parts = base
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'BP';
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final only = parts.first;
    return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _accountAvatar(BuildContext context) {
    final label = _profileLabel;
    return Semantics(
      button: true,
      label: 'Open Account & Settings for $label',
      child: Tooltip(
        message: '$label • Account & Settings',
        child: InkWell(
          onTap: onAvatarTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: CircleAvatar(
                radius: desktop ? 19 : 18,
                backgroundColor: AppTheme.blue,
                child: Text(
                  _profileInitials(label),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: desktop ? 12 : 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

'''
replace_top_once(
    '  @override\n  Widget build(BuildContext context) {',
    helpers+'  @override\n  Widget build(BuildContext context) {',
    'helper insertion',
)


def replace_kj_avatar(value: str) -> tuple[str,bool]:
    target="'KJ'"
    kj=value.find(target)
    if kj<0:
        return value,False
    avatar=value.rfind('const CircleAvatar(',0,kj)
    if avatar<0:
        raise SystemExit('v444 avatar: CircleAvatar start missing')
    open_paren=value.find('(',avatar)
    depth=0
    quote=None
    escaped=False
    close=None
    for index in range(open_paren,len(value)):
        char=value[index]
        if quote is not None:
            if escaped:
                escaped=False
            elif char=='\\':
                escaped=True
            elif char==quote:
                quote=None
            continue
        if char in ("'",'"'):
            quote=char
            continue
        if char=='(':
            depth+=1
        elif char==')':
            depth-=1
            if depth==0:
                close=index+1
                break
    if close is None:
        raise SystemExit('v444 avatar: CircleAvatar did not balance')
    cursor=close
    while cursor<len(value) and value[cursor] in ' \t':
        cursor+=1
    if cursor<len(value) and value[cursor]==',':
        cursor+=1
    return value[:avatar]+'_accountAvatar(context),'+value[cursor:],True

replaced=0
while "'KJ'" in top and replaced<2:
    top,did=replace_kj_avatar(top)
    if not did:
        break
    replaced+=1

for placeholder in (
    'const Icon(Icons.account_circle_outlined, color: AppTheme.textMuted, size: 38)',
    'const Icon(Icons.account_circle_outlined, color: AppTheme.textMuted, size: 36)',
):
    if placeholder in top:
        top=top.replace(placeholder,'_accountAvatar(context)',1)
        replaced+=1

if "'KJ'" in top:
    raise SystemExit('v444 avatar: hard-coded initials remain')
if top.count('_accountAvatar(context)')!=2:
    raise SystemExit(
        f'v444 avatar: expected two dynamic account avatar placements, found {top.count("_accountAvatar(context)")}; replacements={replaced}'
    )

body=body[:start]+top+body[end:]
call_anchor='                        onTraining:()=>_openWalkthrough(),\n'
if "onAvatarTap:()=>_navigateTrainingLabel('Settings')" not in body:
    if body.count(call_anchor)!=1:
        raise SystemExit(f'v444 avatar callback: expected exactly 1 match, found {body.count(call_anchor)}')
    body=body.replace(
        call_anchor,
        call_anchor+"                        onAvatarTap:()=>_navigateTrainingLabel('Settings'),\n",
        1,
    )

path.write_text(body,encoding='utf-8')
# Re-run the authoritative structural contract after avatar mutation, then restore the
# narrowly approved remembered-email/nickname behavior that canonical auth intentionally omits.
subprocess.run([sys.executable,'tool/repair_generated_release_v735.py'],check=True)
subprocess.run([sys.executable,'tool/restore_remembered_auth_v735.py'],check=True)
body=path.read_text(encoding='utf-8')
require_release_contract(body)
print('Applied BridgePoint v444 dynamic account avatar after v735 normalization; final national/localization/owner/resilience/remembered-auth contract passed.')
