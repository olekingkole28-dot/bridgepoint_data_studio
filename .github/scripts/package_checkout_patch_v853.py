from pathlib import Path

path = Path('lib/v2/settings/bridgepoint_packages_v2.dart')
s = path.read_text(encoding='utf-8')

old = """  Future<void> _buy(Map<String, dynamic> package) async {
    final key = _key(package);
    if (key.isEmpty) return;
"""
new = """  Future<void> _buy(Map<String, dynamic> package, String interval) async {
    final key = _key(package);
    if (key.isEmpty || (interval != 'month' && interval != 'year')) return;
"""
if old not in s:
    raise SystemExit('V853: _buy signature marker not found')
s = s.replace(old, new, 1)

old = "body: {'package_key': key, 'interval': 'month'},"
new = "body: {'package_key': key, 'interval': interval},"
if old not in s:
    raise SystemExit('V853: fixed monthly checkout body marker not found')
s = s.replace(old, new, 1)

old = """        setState(() => _message =
            'Stripe checkout opened for ${package['package_name'] ?? key}.');
"""
new = """        final cadence = interval == 'year' ? 'annual' : 'monthly';
        setState(() => _message =
            'Stripe $cadence checkout opened for ${package['package_name'] ?? key}.');
"""
if old not in s:
    raise SystemExit('V853: checkout success message marker not found')
s = s.replace(old, new, 1)

old = """            if (action == 'BUY')
              FilledButton.icon(
                onPressed: _busy ? null : () => _buy(p),
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Start trial / Buy'),
              )
            else if (action == 'REQUEST')
"""
new = """            if (action == 'BUY')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _buy(p, 'month'),
                    icon: const Icon(Icons.credit_card_rounded),
                    label: const Text('Monthly checkout'),
                  ),
                  if (yearly != null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _buy(p, 'year'),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Annual checkout'),
                    ),
                ],
              )
            else if (action == 'REQUEST')
"""
if old not in s:
    raise SystemExit('V853: BUY button marker not found')
s = s.replace(old, new, 1)

path.write_text(s, encoding='utf-8')
print('V853 package monthly/annual checkout patch applied')
