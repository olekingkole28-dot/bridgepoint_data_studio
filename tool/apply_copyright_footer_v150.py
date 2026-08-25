from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

# v804: wrap the selected workspace page structurally so dart-format or earlier
# page insertions cannot break the legal footer install.
pattern = re.compile(
    r"(?P<indent>[ \t]*)child:\s*KeyedSubtree\(\s*"
    r"key:\s*ValueKey\(_liveRefreshTick\),\s*"
    r"child:\s*_buildSelectedPage\(\),\s*"
    r"\),",
    re.S,
)
match = pattern.search(text)
if match is None:
    raise SystemExit('workspace page wrapper: selected page KeyedSubtree not found')
indent = match.group('indent')
replacement = f"""{indent}child: Column(
{indent}  crossAxisAlignment: CrossAxisAlignment.stretch,
{indent}  children: [
{indent}    KeyedSubtree(
{indent}      key: ValueKey(_liveRefreshTick),
{indent}      child: _buildSelectedPage(),
{indent}    ),
{indent}    const SizedBox(height: 30),
{indent}    const _BridgePointLegalFooter(),
{indent}  ],
{indent}),"""
text = pattern.sub(replacement, text, count=1)

# Accept both historical compact and current formatted class declarations.
markers = [
    'class _WorkspaceAtmosphere extends StatelessWidget {',
    'class _WorkspaceAtmosphere extends StatelessWidget{',
]
marker = next((m for m in markers if text.count(m) == 1), None)
if marker is None:
    raise SystemExit('Workspace atmosphere marker missing or duplicated')

footer = r'''class _BridgePointLegalFooter extends StatelessWidget {
  const _BridgePointLegalFooter();

  Future<void> _callSupport(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '2036052389');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        _showInfoDialog(
          context,
          'Questions or Concerns',
          'Call BridgePoint support at 203-605-2389.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'BridgePoint copyright and legal information',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(.07))),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              '© 2026 BridgePoint Intelligence. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .15,
              ),
            ),
            const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: const Size(0, 28),
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _PublicLegalSummaryDialog(),
              ),
              child: const Text('Terms & Privacy', style: TextStyle(fontSize: 9)),
            ),
            const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: const Size(0, 28),
              ),
              onPressed: () => _callSupport(context),
              child: const Text(
                'Questions or Concerns: 203-605-2389',
                style: TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

'''
text = text.replace(marker, footer + marker, 1)

for required in ['© 2026 BridgePoint Intelligence. All rights reserved.',
                 'Questions or Concerns: 203-605-2389',
                 'const _BridgePointLegalFooter()']:
    if required not in text:
        raise SystemExit(f'v804 legal footer marker missing: {required}')

if text == original:
    raise SystemExit('No copyright footer changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint copyright/legal footer v150/v804')
