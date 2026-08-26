from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

# Normalize only formatting boundaries expected by the historical v157
# generator. Behavior remains unchanged until v157 applies its connection and
# offline-route implementation.

old_rpc = """Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
  final response = await http.post(
    Uri.parse('$_supabaseUrl/rest/v1/rpc/$name'),
    headers: _apiHeaders(),
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) throw const FormatException('Unexpected BridgePoint response.');
  return Map<String, dynamic>.from(decoded);
}
"""

if old_rpc not in text:
    rpc_pattern = re.compile(
        r"Future<Map<String, dynamic>> _callRpc\(\s*String name,\s*Map<String, dynamic> body\) async \{.*?\n\}\n\nMap<String, dynamic> _edgeFunctionPayload",
        re.S,
    )
    match = rpc_pattern.search(text)
    if match is None:
        raise SystemExit('v807 could not isolate canonical _callRpc')
    text = rpc_pattern.sub(old_rpc + "\nMap<String, dynamic> _edgeFunctionPayload", text, count=1)

# Secure sign-out matcher expected by v157.
if "onPressed:()=>Supabase.instance.client.auth.signOut()," not in text:
    signout_pattern = re.compile(
        r"onPressed:\s*\(\)\s*=>\s*Supabase\.instance\.client\.auth\.signOut\(\),"
    )
    matches = signout_pattern.findall(text)
    if len(matches) != 1:
        raise SystemExit(f'v807 sign-out boundary expected 1 match, found {len(matches)}')
    text = signout_pattern.sub("onPressed:()=>Supabase.instance.client.auth.signOut(),", text, count=1)

# Live sync strip boundary expected by v157. Use the historical generator's
# exact indentation because its matcher compares the complete literal block.
sync_expected = """                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
"""
if sync_expected not in text:
    sync_pattern = re.compile(
        r"[ \t]*_LiveSyncStrip\(\s*secondsRemaining:\s*_secondsToRefresh,\s*refreshSeconds:\s*_refreshSeconds,\s*\),",
        re.S,
    )
    matches = list(sync_pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f'v807 live sync strip boundary expected 1 match, found {len(matches)}')
    text = sync_pattern.sub(sync_expected.rstrip('\n'), text, count=1)

# My Work insertion boundary expected by v157. Preserve the exact banner copy
# and layout behavior; only collapse this small boundary to the historical form.
mywork_expected = """      const SizedBox(height:10),const _ExplainerBanner(icon:Icons.policy_rounded,title:'From first signal through paid claim',message:'Save a promising opportunity, qualify it, open a private claim workflow, record each milestone, attach notes and schedule the next action. Public evidence updates automatically; carrier details appear only when you enter them or authorize an integration.'),
      const SizedBox(height:18),LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
if mywork_expected not in text:
    start_token = "title: 'From first signal through paid claim'"
    start_idx = text.find(start_token)
    if start_idx < 0:
        raise SystemExit('v807 My Work banner not found')
    block_start = text.rfind('const SizedBox(height: 10),', 0, start_idx)
    if block_start < 0:
        raise SystemExit('v807 My Work starting spacer not found')
    layout_idx = text.find('LayoutBuilder(builder:', start_idx)
    if layout_idx < 0:
        raise SystemExit('v807 My Work LayoutBuilder not found')
    children_idx = text.find('children: [', layout_idx)
    if children_idx < 0:
        raise SystemExit('v807 My Work Wrap children boundary not found')
    children_end = children_idx + len('children: [')
    text = text[:block_start] + mywork_expected + text[children_end:]

# v157's class insertion marker predates dart format.
if 'class _WorkspaceAtmosphere extends StatelessWidget{' not in text:
    formatted = 'class _WorkspaceAtmosphere extends StatelessWidget {'
    if text.count(formatted) != 1:
        raise SystemExit(f'v807 WorkspaceAtmosphere expected 1 formatted marker, found {text.count(formatted)}')
    text = text.replace(formatted, 'class _WorkspaceAtmosphere extends StatelessWidget{', 1)

for required in [old_rpc,
                 "onPressed:()=>Supabase.instance.client.auth.signOut(),",
                 sync_expected.rstrip('\n'),
                 "title:'From first signal through paid claim'",
                 'class _WorkspaceAtmosphere extends StatelessWidget{']:
    if required not in text:
        raise SystemExit(f'v807 compatibility marker missing: {required[:70]}')

if text == original:
    print('Routes/offline v807 compatibility already normalized')
else:
    path.write_text(text, encoding='utf-8')
    print('Normalized release boundaries for Routes & Offline Mode v157/v807')
