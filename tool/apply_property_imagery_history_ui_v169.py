from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
"""        'bridgepoint_property_media_v137',
        {'p_property_id': widget.propertyId},
""",
"""        'bridgepoint_property_media_bundle_v169',
        {'p_property_id': widget.propertyId},
""",
'history-media-bundle')

replace_once(
"""        final captured = primary['captured_at'] == null
            ? 'Date not available'
            : _bpDateTime(primary['captured_at']);

        return Container(
""",
"""        final captured = primary['captured_at'] == null
            ? 'Date not available'
            : _bpDateTime(primary['captured_at']);
        final aerialHistory = _bpRows(data['aerial_history']);

        return Container(
""",
'history-data')

replace_once(
"""                    if (fallback) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'BridgePoint did not find a higher-priority displayable exterior or field photo, so it is showing the authoritative aerial reference instead.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 8.5,
                          height: 1.35,
                        ),
                      ),
                    ],
""",
"""                    if (fallback) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'BridgePoint did not find a higher-priority displayable exterior or field photo, so it is showing the authoritative aerial reference instead.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 8.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (aerialHistory.length > 1) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showPropertyImageHistory(context, aerialHistory),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: Text('Image history • ${aerialHistory.length} dates'),
                      ),
                    ],
""",
'history-button')

marker='class _PropertyMediaCard extends StatefulWidget {'
if text.count(marker)!=1:
    raise SystemExit('Property media class marker missing')
helper=r'''
Future<void> _showPropertyImageHistory(
  BuildContext context,
  List<Map<String, dynamic>> history,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.cyan),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Property Image History',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Compare dated source imagery. A visual difference is context until BridgePoint corroborates an actual property change.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    childAspectRatio: 1.28,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final url = '${item['thumbnail_url'] ?? item['media_url'] ?? ''}';
                    final year = '${item['captured_year'] ?? 'Unknown date'}';
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: url.isEmpty
                                ? const _PropertyMediaMissing(
                                    message: 'Image not available',
                                    compact: true,
                                  )
                                : Image.network(
                                    url,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const _PropertyMediaMissing(
                                      message: 'Image not available',
                                      compact: true,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$year Aerial',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['source_name'] ?? 'Source imagery'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

'''
text=text.replace(marker,helper+marker,1)

if text==original:
    raise SystemExit('No property image history UI changes applied')
path.write_text(text,encoding='utf-8')
print('Applied lazy historical property imagery UI v169')
