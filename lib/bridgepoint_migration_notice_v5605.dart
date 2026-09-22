import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointMigrationNoticeV5605 extends StatefulWidget {
  const BridgePointMigrationNoticeV5605({super.key});
  @override
  State<BridgePointMigrationNoticeV5605> createState() =>
      _BridgePointMigrationNoticeV5605State();
}

class _BridgePointMigrationNoticeV5605State
    extends State<BridgePointMigrationNoticeV5605> {
  Timer? _timer;
  Map<String, dynamic>? _data;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('bridgepoint_public_migration_notice_v5605');
      if (!mounted) return;
      setState(() {
        _data = raw is Map ? Map<String, dynamic>.from(raw) : null;
        _failures = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failures++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteShow = _data?['show_notice'] == true;
    final fallbackShow = _failures >= 2;
    if (!remoteShow && !fallbackShow) return const SizedBox.shrink();

    final title = fallbackShow
        ? 'BridgePoint maintenance in progress'
        : (_data?['title'] ?? 'Infrastructure migration in progress').toString();
    final message = fallbackShow
        ? 'Our infrastructure migration is still underway. Some live map or account features may be temporarily unavailable; please retry shortly.'
        : (_data?['message'] ??
                'Some live features may briefly retry while BridgePoint moves infrastructure.')
            .toString();

    return Material(
      color: const Color(0xFF10283A),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.settings_backup_restore_rounded,
                size: 18, color: Color(0xFF55DDF8)),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF55DDF8),
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                        color: Color(0xFFC2D5DE), fontSize: 10.5, height: 1.35)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
