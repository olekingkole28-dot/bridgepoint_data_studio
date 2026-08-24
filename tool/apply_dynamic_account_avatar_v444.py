from pathlib import Path
import subprocess
import sys

subprocess.run([sys.executable,'tool/apply_owner_ai_visibility_v602.py'],check=True)
subprocess.run([sys.executable,'tool/apply_owner_global_ai_v678.py'],check=True)

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v444-dynamic-account-avatar'

def require_release_contract(value: str) -> None:
    start = value.find('class _TopBar extends StatelessWidget')
    end = value.find('class _LiveSyncStrip', start)
    if start < 0 or end < 0:
        raise SystemExit('v444 avatar: TopBar boundaries missing')
    top = value[start:end]
    checks = {
        'release marker': marker in top,
        'dynamic profile metadata': "metadata['display_name']" in top,
        'shared avatar widget': top.count('_accountAvatar(context)') == 2,
        '48px touch target': 'width: 48' in top and 'height: 48' in top,
        'account action': 'onTap: onAvatarTap' in top,
        'settings route': "onAvatarTap:()=>_navigateTrainingLabel('Settings')" in value,
        'no hard-coded KJ': "'KJ'" not in top,
        'localization marker': '// bridgepoint-localization-v711' in value,
        'first-entry language bootstrap': 'home: const _LanguageBootstrap(),' in value,
        'supported language RPC': 'bridgepoint_supported_languages_v711' in value,
        'locale persistence RPC': 'bridgepoint_save_locale_v711' in value,
        'local locale persistence': "package:shared_preferences/shared_preferences.dart" in value,
    }
    missing = [label for label, passed in checks.items() if not passed]
    if missing:
        raise SystemExit(f'v444 final release contract incomplete: {missing}')

if marker in body:
    require_release_contract(body)
    print('BridgePoint v444 dynamic account avatar and V720 localization release contract verified.')
    raise SystemExit(0)

start = body.find('class _TopBar extends StatelessWidget')
end = body.find('class _LiveSyncStrip', start)
if start < 0 or end < 0:
    raise SystemExit('v444 avatar: TopBar boundaries missing')
top = body[start:end]

def replace_top_once(old: str, new: str, label: str) -> None:
    global top
    count = top.count(old)
    if count != 1:
        raise SystemExit(f'v444 avatar {label}: expected exactly 1 match, found {count}')
    top = top.replace(old, new, 1)

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

helpers = r'''  // bridgepoint-v444-dynamic-account-avatar
  String get _profileLabel {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final displayName =
        metadata == null ? '' : (metadata['display_name']?.toString().trim() ?? '');
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
    helpers + '  @override\n  Widget build(BuildContext context) {',
    'helper insertion',
)

if top.count("'KJ'") != 2:
    raise SystemExit(f"v444 avatar: expected 2 hard-coded KJ avatars, found {top.count(chr(39) + 'KJ' + chr(39))}")

def replace_kj_avatar(value: str) -> str:
    target = "'KJ'"
    kj = value.find(target)
    if kj < 0:
        raise SystemExit('v444 avatar: KJ marker disappeared during replacement')
    avatar = value.rfind('const CircleAvatar(', 0, kj)
    if avatar < 0:
        raise SystemExit('v444 avatar: CircleAvatar start missing')
    open_paren = value.find('(', avatar)
    depth = 0
    quote = None
    escaped = False
    close = None
    for index in range(open_paren, len(value)):
        char = value[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in ("'", '"'):
            quote = char
            continue
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                close = index + 1
                break
    if close is None:
        raise SystemExit('v444 avatar: CircleAvatar did not balance')
    cursor = close
    while cursor < len(value) and value[cursor] in ' \t':
        cursor += 1
    if cursor < len(value) and value[cursor] == ',':
        cursor += 1
    line_start = value.rfind('\n', 0, avatar) + 1
    indent = value[line_start:avatar]
    return value[:avatar] + '_accountAvatar(context),' + value[cursor:]

top = replace_kj_avatar(top)
top = replace_kj_avatar(top)
if "'KJ'" in top:
    raise SystemExit('v444 avatar: hard-coded initials remain')

body = body[:start] + top + body[end:]
call_anchor = '                        onTraining:()=>_openWalkthrough(),\n'
if body.count(call_anchor) != 1:
    raise SystemExit(f'v444 avatar callback: expected exactly 1 match, found {body.count(call_anchor)}')
body = body.replace(
    call_anchor,
    call_anchor + "                        onAvatarTap:()=>_navigateTrainingLabel('Settings'),\n",
    1,
)

require_release_contract(body)
path.write_text(body, encoding='utf-8')
print('Applied BridgePoint v444 dynamic, accessible account avatar with V720 localization release guard.')
