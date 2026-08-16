from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

old = """                            child: KeyedSubtree(
                              key: ValueKey(_liveRefreshTick),
                              child: _buildSelectedPage(),
                            ),
"""
new = """                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                KeyedSubtree(
                                  key: ValueKey(_liveRefreshTick),
                                  child: _buildSelectedPage(),
                                ),
                                const SizedBox(height: 30),
                                const _BridgePointLegalFooter(),
                              ],
                            ),
"""
if text.count(old) != 1:
    raise SystemExit(f'workspace page wrapper: expected 1 match, found {text.count(old)}')
text = text.replace(old, new, 1)

marker = "class _WorkspaceAtmosphere extends StatelessWidget{"
if text.count(marker) != 1:
    raise SystemExit('Workspace atmosphere marker missing')

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

if text == original:
    raise SystemExit('No copyright footer changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint copyright/legal footer v150')
