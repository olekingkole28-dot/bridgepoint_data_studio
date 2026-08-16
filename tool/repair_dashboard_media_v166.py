from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

text=text.replace(
    "child:Container(minHeight:112,padding:",
    "child:Container(constraints:const BoxConstraints(minHeight:112),padding:",
    1,
)
text=text.replace(
    "return Container(minHeight:112,padding:",
    "return Container(constraints:const BoxConstraints(minHeight:112),padding:",
    1,
)

start=text.find('class _PropertyMediaCard extends StatefulWidget{')
end=text.find('class _FieldNoteCard extends StatelessWidget{',start)
if start<0 or end<0:
    raise SystemExit('Property media repair block not found')

replacement=r'''class _PropertyMediaCard extends StatefulWidget {
  const _PropertyMediaCard({required this.propertyId});
  final String propertyId;

  @override
  State<_PropertyMediaCard> createState() => _PropertyMediaCardState();
}

class _PropertyMediaCardState extends State<_PropertyMediaCard> {
  late Future<Map<String, dynamic>> request;

  @override
  void initState() {
    super.initState();
    request = _load();
  }

  Future<Map<String, dynamic>> _load() => _callRpc(
        'bridgepoint_property_media_v137',
        {'p_property_id': widget.propertyId},
      );

  @override
  void didUpdateWidget(covariant _PropertyMediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.propertyId != widget.propertyId) {
      request = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.panelSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(
              color: AppTheme.cyan,
              strokeWidth: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return const _PropertyMediaMissing(
            message: 'Property photo not available yet',
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final primary = _bpMap(data['primary']);
        final url = '${primary['media_url'] ?? ''}'.trim();
        if (url.isEmpty) {
          return _PropertyMediaMissing(
            message: '${data['display_message'] ?? 'Property photo not available yet'}',
          );
        }

        final fallback = '${data['fallback_kind'] ?? ''}' == 'AERIAL';
        final label = '${primary['display_label'] ?? (fallback ? 'Aerial View' : 'Property Photo')}';
        final source = '${primary['source_name'] ?? primary['provider'] ?? 'BridgePoint property media'}';
        final captured = primary['captured_at'] == null
            ? 'Date not available'
            : _bpDateTime(primary['captured_at']);

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.panelSoft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.cyan.withOpacity(.13)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 260,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const _PropertyMediaMissing(
                        message: 'Property photo not available yet',
                        compact: true,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _OpportunityChip(
                      label: label.toUpperCase(),
                      color: fallback ? AppTheme.blue : AppTheme.green,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$captured${fallback ? ' • automatic aerial fallback' : ''}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 8.5,
                      ),
                    ),
                    if (fallback) ...[
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PropertyMediaMissing extends StatelessWidget {
  const _PropertyMediaMissing({required this.message, this.compact = false});
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: compact ? 260 : 190,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_outlined, color: AppTheme.textMuted, size: 34),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

'''
text=text[:start]+replacement+text[end:]

if text==original:
    raise SystemExit('No dashboard/media repairs applied')
path.write_text(text,encoding='utf-8')
print('Repaired dashboard widget sizing and property media card syntax v166')
