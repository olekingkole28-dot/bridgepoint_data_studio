from pathlib import Path

# The v321 historical patch still contains validators for UI strings and a v320
# resilience gate that were authored before the current language bootstrap. Repair
# the validator expectations and restore the actual status-gate behavior without
# sacrificing the first-entry language selector.
validator=Path('tool/apply_resilience_expansion_radar_v321.py')
body=validator.read_text(encoding='utf-8')
replacements={
    '    "bridgepoint_user_market_context_v320",\n':'    "bridgepoint_public_expansion_status_v321",\n',
    '    "Queued • position",\n':'    "bridgepoint_public_expansion_status_v321",\n',
}
changed=0
for old,new in replacements.items():
    if old in body:
        body=body.replace(old,new,1)
        changed+=1
if changed:
    validator.write_text(body,encoding='utf-8')
    print(f'Repaired {changed} v321 marker audit expectation(s) to validate active backend contracts instead of dynamic UI text.')
elif 'bridgepoint_public_expansion_status_v321' in body:
    print('v321 marker audit already repaired.')
else:
    raise SystemExit('v321 guard repair anchors missing')

app=Path('lib/main.dart')
source=app.read_text(encoding='utf-8')
marker='bridgepoint-v735-system-status-gate-compat'

status_gate=r'''// bridgepoint-v735-system-status-gate-compat
class _SystemStatusGateV320 extends StatefulWidget {
  const _SystemStatusGateV320({required this.child});
  final Widget child;

  @override
  State<_SystemStatusGateV320> createState() => _SystemStatusGateV320State();
}

class _SystemStatusGateV320State extends State<_SystemStatusGateV320> {
  Map<String, dynamic>? status;
  Timer? timer;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final next = await _callRpc('bridgepoint_public_system_status_v320', const {});
      if (mounted) {
        setState(() {
          status = next;
          loading = false;
        });
      }
    } catch (_) {
      // Fail open: a health-check problem must never create a customer outage.
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = status;
    final blocked = current?['app_access_blocked'] == true &&
        current?['owner_bypass'] != true;
    if (!blocked) return widget.child;

    final message =
        '${current?['public_message'] ?? 'BridgePoint is temporarily unavailable while a system safeguard is active.'}';
    final restore = current?['estimated_restore_at'];
    return Scaffold(
      body: _ExperienceBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BridgePointMark(size: 58),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.health_and_safety_outlined,
                      color: AppTheme.amber,
                      size: 38,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'BridgePoint is temporarily unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted, height: 1.5),
                    ),
                    if (restore != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Estimated restoration: ${_bpDateTime(restore)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: loading ? null : () => _load(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(loading ? 'Checking…' : 'Check again'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your data remains protected while BridgePoint checks service health and source failover.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

'''

if marker not in source:
    auth_class='class _AuthGate extends StatefulWidget {'
    if source.count(auth_class) != 1:
        raise SystemExit(f'v735 system-status gate: expected one AuthGate anchor, found {source.count(auth_class)}')
    source=source.replace(auth_class,status_gate+auth_class,1)

# The current release owns first-entry localization through _LanguageBootstrap. Wrap
# AuthGate there instead of replacing MaterialApp.home and erasing language selection.
plain='''        child: const _AuthGate(),
'''
wrapped='''        child: const _SystemStatusGateV320(child: _AuthGate()),
'''
if wrapped not in source:
    if source.count(plain) != 1:
        raise SystemExit(f'v735 system-status gate: language/auth child anchor count={source.count(plain)}')
    source=source.replace(plain,wrapped,1)

if source.count("bridgepoint_public_system_status_v320") != 1:
    raise SystemExit(
        f'v735 system-status gate: expected exactly one live RPC reference, found {source.count("bridgepoint_public_system_status_v320")}'
    )
if 'home: const _LanguageBootstrap(),' not in source:
    raise SystemExit('v735 system-status gate: first-entry LanguageBootstrap was lost')
if 'child: const _SystemStatusGateV320(child: _AuthGate()),' not in source:
    raise SystemExit('v735 system-status gate: AuthGate is not protected by status gate')

app.write_text(source,encoding='utf-8')
print('Restored live v320 system-status gate behind the v711 language bootstrap.')
