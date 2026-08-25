from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')

class_start = text.find('class _LegalAcceptanceScreenState extends State<_LegalAcceptanceScreen>')
class_end = text.find('class _LegalCenterDialog', class_start)
if class_start < 0 or class_end < 0:
    raise SystemExit('Legal acceptance screen block not found')

block = text[class_start:class_end]

# Match only the required-app-gate acceptance call. The separate
# FIELD_TRACKING_NOTICE consent must remain untouched.
pattern = re.compile(
    r"(?P<indent>[ \t]*)await\s+_callRpc\(\s*'bridgepoint_accept_legal_v82'\s*,\s*\{\s*"
    r"'p_document_keys'\s*:\s*\[\s*'TERMS'\s*,\s*'PRIVACY'\s*,\s*"
    r"'ACCEPTABLE_USE'\s*,\s*'DATA_DISCLAIMER'\s*,?\s*\]\s*,\s*"
    r"'p_acceptance_source'\s*:\s*'APP_REQUIRED_GATE'\s*,?\s*\}\s*\)\s*;\s*"
    r"widget\.onComplete\(\)\s*;",
    re.S,
)
match = pattern.search(block)
if match is None:
    # Idempotent/supersession guard: if the dynamic required-document logic is
    # already present, keep it rather than failing the release.
    if "final docs = widget.state['documents'];" in block or "final docs=widget.state['documents'];" in block:
        print('Legal acceptance gate dynamic required-document logic already present v810')
        raise SystemExit(0)
    raise SystemExit('Expected one formatted legal gate submit block, found 0')

indent = match.group('indent')
inner = indent
replacement = f"""{indent}final docs = widget.state['documents'];
{inner}final requiredKeys = <String>[];
{inner}if (docs is List) {{
{inner}  for (final item in docs) {{
{inner}    if (item is Map &&
{inner}        item['required'] == true &&
{inner}        item['accepted'] != true &&
{inner}        item['document_key'] != null) {{
{inner}      requiredKeys.add('${{item['document_key']}}');
{inner}    }}
{inner}  }}
{inner}}}
{inner}if (requiredKeys.isEmpty) {{
{inner}  widget.onComplete();
{inner}  return;
{inner}}}
{inner}final result = await _callRpc('bridgepoint_accept_legal_v82', {{
{inner}  'p_document_keys': requiredKeys,
{inner}  'p_acceptance_source': 'APP_REQUIRED_GATE',
{inner}}});
{inner}if (result['required_acceptance_missing'] == true) {{
{inner}  throw Exception(
{inner}    'BridgePoint still shows ${{result['missing_count'] ?? 1}} required legal document(s) as unaccepted. Please retry.',
{inner}  );
{inner}}}
{inner}widget.onComplete();"""

block = pattern.sub(replacement, block, count=1)
text = text[:class_start] + block + text[class_end:]

for marker in [
    "final docs = widget.state['documents'];",
    "'p_document_keys': requiredKeys",
    "result['required_acceptance_missing'] == true",
]:
    if marker not in text:
        raise SystemExit(f'Legal gate v810 marker missing: {marker}')

path.write_text(text, encoding='utf-8')
print('Legal acceptance gate now submits every currently required unaccepted document v810.')
