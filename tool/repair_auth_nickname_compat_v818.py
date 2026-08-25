from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

# v181b was authored against compact generated Dart. Normalize only the parser
# boundaries it consumes; behavior remains unchanged until v181b applies the
# remembered-info and nickname feature.

auth_start = text.find('class _AuthScreenState extends State<_AuthScreen> {')
auth_end = text.find('class _PublicLegalSummaryDialog', auth_start)
if auth_start < 0 or auth_end < 0:
    raise SystemExit('v818 auth screen state block missing')
auth = text[auth_start:auth_end]

expected_fields = """  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;
"""
if expected_fields not in auth:
    fields_pattern = re.compile(
        r"(?P<indent>[ \t]*)final displayName\s*=\s*TextEditingController\(\);\s*"
        r"final email\s*=\s*TextEditingController\(\);\s*"
        r"final password\s*=\s*TextEditingController\(\);\s*"
        r"bool create\s*=\s*false\s*,\s*loading\s*=\s*false\s*,\s*"
        r"showPassword\s*=\s*false\s*,\s*acceptTerms\s*=\s*false\s*;\s*"
        r"String\? error\s*;",
        re.S,
    )
    if len(fields_pattern.findall(auth)) != 1:
        raise SystemExit(f'v818 auth fields expected 1 match, found {len(fields_pattern.findall(auth))}')
    auth = fields_pattern.sub(expected_fields.rstrip('\n'), auth, count=1)

expected_submit = """        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
"""
if expected_submit not in auth:
    submit_pattern = re.compile(
        r"(?P<indent>[ \t]*)final response\s*=\s*await Supabase\.instance\.client\.auth\s*"
        r"\.signUp\(\s*email:\s*email\.text\.trim\(\)\s*,\s*password:\s*password\.text\s*,\s*data:\s*\{\s*"
        r"'display_name'\s*:\s*displayName\.text\.trim\(\)\s*,\s*"
        r"'legal_accepted'\s*:\s*true\s*,\s*'legal_version'\s*:\s*'2026-08-15'\s*,?\s*\}\s*\)\s*;\s*"
        r"if\s*\(response\.session\s*==\s*null\s*&&\s*mounted\)\s*"
        r"setState\(\(\)\s*=>\s*error\s*=\s*'Check your email to confirm the account, then sign in\.'\s*\)\s*;\s*"
        r"\}\s*else\s*\{\s*await Supabase\.instance\.client\.auth\.signInWithPassword\(\s*"
        r"email:\s*email\.text\.trim\(\)\s*,\s*password:\s*password\.text\s*\)\s*;\s*\}",
        re.S,
    )
    m = submit_pattern.search(auth)
    if m is None:
        raise SystemExit('v818 auth signup/signin block not found')
    auth = submit_pattern.sub(expected_submit.rstrip('\n'), auth, count=1)

# Normalize the password -> create-account legal checkbox boundary exactly as
# v181b expects. Keep the actual legal checkbox content after its opening paren.
expected_checkbox = """      ),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
"""
if expected_checkbox not in auth:
    checkbox_pattern = re.compile(
        r"(?P<close>[ \t]*\),)\s*"
        r"if\s*\(create\)\s*\.\.\.\[\s*const SizedBox\(height:\s*10\),\s*CheckboxListTile\(",
        re.S,
    )
    candidates = list(checkbox_pattern.finditer(auth))
    # Restrict to the match following the password visibility icon so another
    # create-only block can never be normalized accidentally.
    visibility = auth.find('Icons.visibility_rounded')
    match = next((m for m in candidates if m.start() > visibility >= 0), None)
    if match is None:
        raise SystemExit('v818 remember-info placement boundary not found')
    auth = auth[:match.start()] + expected_checkbox.rstrip('\n') + auth[match.end():]

text = text[:auth_start] + auth + text[auth_end:]

settings_start = text.find('class _SettingsPageState extends State<_SettingsPage> {')
settings_end = text.find('class _SettingsSection extends StatelessWidget', settings_start)
if settings_start < 0 or settings_end < 0:
    raise SystemExit('v818 settings state block missing')
settings = text[settings_start:settings_end]

# Compact settings state boundary.
if '  bool _savingAccessibility=false;\n' not in settings:
    pattern = re.compile(r"[ \t]*bool _savingAccessibility\s*=\s*false\s*;\s*\n")
    if len(pattern.findall(settings)) != 1:
        raise SystemExit(f'v818 settings accessibility field expected 1 match, found {len(pattern.findall(settings))}')
    settings = pattern.sub('  bool _savingAccessibility=false;\n', settings, count=1)

if '    _accessibility=_displayPreferences.value;\n' not in settings:
    pattern = re.compile(r"[ \t]*_accessibility\s*=\s*_displayPreferences\.value\s*;\s*\n")
    if len(pattern.findall(settings)) != 1:
        raise SystemExit(f'v818 settings accessibility init expected 1 match, found {len(pattern.findall(settings))}')
    settings = pattern.sub('    _accessibility=_displayPreferences.value;\n', settings, count=1)

expected_dispose = '  @override void dispose(){_feedback.dispose();super.dispose();}\n'
if expected_dispose not in settings:
    dispose_pattern = re.compile(
        r"[ \t]*@override\s*void dispose\(\)\s*\{\s*_feedback\.dispose\(\);\s*super\.dispose\(\);\s*\}\s*\n",
        re.S,
    )
    if len(dispose_pattern.findall(settings)) != 1:
        raise SystemExit(f'v818 settings dispose expected 1 match, found {len(dispose_pattern.findall(settings))}')
    settings = dispose_pattern.sub(expected_dispose, settings, count=1)

expected_feedback = '  Future<void> _sendFeedback() async{\n'
if expected_feedback not in settings:
    feedback_pattern = re.compile(r"[ \t]*Future<void> _sendFeedback\(\)\s*async\s*\{\s*\n")
    if len(feedback_pattern.findall(settings)) != 1:
        raise SystemExit(f'v818 feedback method expected 1 match, found {len(feedback_pattern.findall(settings))}')
    settings = feedback_pattern.sub(expected_feedback, settings, count=1)

# Normalize the account section header only; all current account/trial rows stay.
expected_account = """                        title: 'Account & trial',
                        subtitle: 'New accounts start in a scoped BridgePoint trial workspace.',
                        children: [
"""
expected_account_alt = """                        title: 'Account & trial',
                        subtitle: 'Every new account receives BridgePoint All Intelligence.',
                        children: [
"""
if expected_account not in settings and expected_account_alt not in settings:
    account_pattern = re.compile(
        r"(?P<indent>[ \t]*)title:\s*'Account & trial'\s*,\s*"
        r"subtitle:\s*'(?P<subtitle>New accounts start in a scoped BridgePoint trial workspace\.|Every new account receives BridgePoint All Intelligence\.)'\s*,\s*"
        r"children:\s*\[",
        re.S,
    )
    m = account_pattern.search(settings)
    if m is None:
        raise SystemExit('v818 account settings header not found')
    subtitle = m.group('subtitle')
    normalized = ("                        title: 'Account & trial',\n"
                  f"                        subtitle: '{subtitle}',\n"
                  "                        children: [")
    settings = account_pattern.sub(normalized, settings, count=1)

text = text[:settings_start] + settings + text[settings_end:]

for required in [
    expected_fields.rstrip('\n'),
    "data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'}",
    expected_checkbox.rstrip('\n'),
    '  bool _savingAccessibility=false;',
    '    _accessibility=_displayPreferences.value;',
    expected_dispose.rstrip('\n'),
    expected_feedback.rstrip('\n'),
    "title: 'Account & trial'",
]:
    if required not in text:
        raise SystemExit(f'v818 compatibility marker missing: {required[:90]}')

if text == original:
    print('Auth/nickname v181b compatibility already normalized v818')
else:
    path.write_text(text, encoding='utf-8')
    print('Normalized auth + Settings boundaries for remembered sign-in/nickname v181b/v818')
