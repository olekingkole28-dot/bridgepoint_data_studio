from pathlib import Path

p = Path('lib/v2/bridgepoint_app_v2.dart')
s = p.read_text(encoding='utf-8')


def once(old: str, new: str, label: str) -> None:
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected 1 match, found {n}')
    s = s.replace(old, new, 1)

# Idempotent success check.
if (
    'work,' in s.split('enum _AreaV2 {', 1)[1].split('}', 1)[0]
    and "_AreaSpecV2(_AreaV2.work, 'Work', Icons.workspaces_outline)" in s
    and "_AreaV2.work => _WorkHubV940" in s
    and "label: 'Work'" in s
    and "tooltip: 'Explore all capabilities'" in s
):
    print('V940 already applied.')
    raise SystemExit(0)

once(
    '  opportunities,\n  investment,',
    '  opportunities,\n  work,\n  investment,',
    'enum work area',
)

once(
    "  _AreaSpecV2(_AreaV2.opportunities, 'Opportunities', Icons.bolt_rounded),\n  _AreaSpecV2(\n    _AreaV2.investor,",
    "  _AreaSpecV2(_AreaV2.opportunities, 'Opportunities', Icons.bolt_rounded),\n  _AreaSpecV2(_AreaV2.work, 'Work', Icons.workspaces_outline),\n  _AreaSpecV2(\n    _AreaV2.investor,",
    'work area spec',
)

once(
    "  List<_AreaV2> get _primary => const [\n        _AreaV2.home,\n        _AreaV2.map,\n        _AreaV2.properties,\n        _AreaV2.investor,\n      ];",
    "  List<_AreaV2> get _primary => const [\n        _AreaV2.home,\n        _AreaV2.map,\n        _AreaV2.properties,\n        _AreaV2.work,\n      ];",
    'four primary destinations',
)

once(
    "        _AreaV2.opportunities => const BridgePointOpportunitiesV2(),\n        _AreaV2.investment => const BridgePointInvestmentValuationV2(),",
    "        _AreaV2.opportunities => const BridgePointOpportunitiesV2(),\n        _AreaV2.work => _WorkHubV940(\n            onOpen: (area) => setState(() => selected = area),\n          ),\n        _AreaV2.investment => const BridgePointInvestmentValuationV2(),",
    'work page route',
)

once(
    "      final current = primary.contains(selected) ? primary.indexOf(selected) : 4;",
    "      final current = primary.contains(selected)\n          ? primary.indexOf(selected)\n          : primary.indexOf(_AreaV2.work);",
    'mobile selected index',
)

once(
    "            IconButton(\n              tooltip: 'Ask BridgePoint AI',\n              onPressed: () => setState(() => selected = _AreaV2.ai),\n              icon: const Icon(Icons.auto_awesome_rounded),\n            ),\n          ],",
    "            IconButton(\n              tooltip: 'Ask BridgePoint AI',\n              onPressed: () => setState(() => selected = _AreaV2.ai),\n              icon: const Icon(Icons.auto_awesome_rounded),\n            ),\n            IconButton(\n              tooltip: 'Explore all capabilities',\n              onPressed: _showMore,\n              icon: const Icon(Icons.apps_rounded),\n            ),\n          ],",
    'mobile explore action',
)

once(
    "          onDestinationSelected: (index) {\n            if (index == 4) {\n              _showMore();\n            } else {\n              setState(() => selected = primary[index]);\n            }\n          },",
    "          onDestinationSelected: (index) =>\n              setState(() => selected = primary[index]),",
    'mobile nav selection',
)

once(
    "            NavigationDestination(\n              icon: Icon(\n                owner ? Icons.show_chart_rounded : Icons.real_estate_agent_rounded,\n              ),\n              label: owner ? 'Worth' : 'Investor',\n            ),\n            const NavigationDestination(\n              icon: Icon(Icons.apps_rounded),\n              label: 'More',\n            ),",
    "            const NavigationDestination(\n              icon: Icon(Icons.workspaces_outline),\n              label: 'Work',\n            ),",
    'mobile work destination',
)

once(
    "    final specs = areas;\n    final selectedIndex = specs.indexWhere((x) => x.area == selected);",
    "    final specs = _primary\n        .map((area) => areas.firstWhere((spec) => spec.area == area))\n        .toList(growable: false);\n    final selectedIndex = specs.indexWhere((x) => x.area == selected);\n    final railIndex =\n        selectedIndex < 0 ? _primary.indexOf(_AreaV2.work) : selectedIndex;",
    'desktop primary specs',
)

once(
    "            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,",
    "            selectedIndex: railIndex,",
    'desktop rail selected index',
)

once(
    "            trailing: Expanded(\n              child: Align(\n                alignment: Alignment.bottomCenter,\n                child: Padding(\n                  padding: const EdgeInsets.only(bottom: 12),\n                  child: IconButton(\n                    tooltip: 'Sign out',\n                    onPressed: () => Supabase.instance.client.auth.signOut(),\n                    icon: const Icon(Icons.logout_rounded),\n                  ),\n                ),\n              ),\n            ),",
    "            trailing: Expanded(\n              child: Align(\n                alignment: Alignment.bottomCenter,\n                child: Padding(\n                  padding: const EdgeInsets.only(bottom: 12),\n                  child: Column(\n                    mainAxisSize: MainAxisSize.min,\n                    children: [\n                      IconButton(\n                        tooltip: 'Explore all capabilities',\n                        onPressed: _showMore,\n                        icon: const Icon(Icons.apps_rounded),\n                      ),\n                      const SizedBox(height: 4),\n                      IconButton(\n                        tooltip: 'Sign out',\n                        onPressed: () => Supabase.instance.client.auth.signOut(),\n                        icon: const Icon(Icons.logout_rounded),\n                      ),\n                    ],\n                  ),\n                ),\n              ),\n            ),",
    'desktop rail explore action',
)

once(
    "                      TextButton.icon(\n                        onPressed: () => setState(() => selected = _AreaV2.ai),\n                        icon: const Icon(\n                          Icons.auto_awesome_rounded,\n                          color: Color(0xFF48E1FF),\n                        ),\n                        label: const Text('Ask AI'),\n                      ),\n                      const SizedBox(width: 6),\n                      const _LiveBadgeV2(),",
    "                      TextButton.icon(\n                        onPressed: () => setState(() => selected = _AreaV2.ai),\n                        icon: const Icon(\n                          Icons.auto_awesome_rounded,\n                          color: Color(0xFF48E1FF),\n                        ),\n                        label: const Text('Ask AI'),\n                      ),\n                      IconButton(\n                        tooltip: 'Explore all capabilities',\n                        onPressed: _showMore,\n                        icon: const Icon(Icons.apps_rounded),\n                      ),\n                      const SizedBox(width: 6),\n                      const _LiveBadgeV2(),",
    'desktop header explore action',
)

once(
    "      _AreaV2.opportunities => 'Opportunities',\n      _AreaV2.investment => 'Investment / BridgePoint Worth',",
    "      _AreaV2.opportunities => 'Opportunities',\n      _AreaV2.work => 'Work',\n      _AreaV2.investment => 'Investment / BridgePoint Worth',",
    'work title',
)

work_hub = r'''

class _WorkHubV940 extends StatelessWidget {
  const _WorkHubV940({required this.onOpen});

  final ValueChanged<_AreaV2> onOpen;

  @override
  Widget build(BuildContext context) {
    const items = <_AreaSpecV2>[
      _AreaSpecV2(_AreaV2.opportunities, 'Opportunities', Icons.bolt_rounded),
      _AreaSpecV2(
        _AreaV2.savedAlerts,
        'Saved & Alerts',
        Icons.bookmark_added_outlined,
      ),
      _AreaSpecV2(_AreaV2.calendar, 'Calendar', Icons.calendar_month_rounded),
      _AreaSpecV2(_AreaV2.operations, 'Operations', Icons.track_changes_rounded),
      _AreaSpecV2(_AreaV2.claims, 'Claims', Icons.assignment_outlined),
      _AreaSpecV2(
        _AreaV2.portfolio,
        'Portfolio & Risk',
        Icons.account_tree_outlined,
      ),
      _AreaSpecV2(
        _AreaV2.investor,
        'Property Investor',
        Icons.real_estate_agent_rounded,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: [
        Text(
          'Your work, in one place',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          'Opportunities, saved properties, follow-ups, claims and portfolio workflows stay available without becoming permanent navigation tabs.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFB5C6D9),
              ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 3
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onOpen(item.area),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                item.icon,
                                color: const Color(0xFF48E1FF),
                                size: 29,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
'''

marker = '\nString _title(_AreaV2 area) => switch (area) {'
if marker not in s:
    raise SystemExit('work hub insertion marker missing')
s = s.replace(marker, work_hub + marker, 1)

p.write_text(s, encoding='utf-8')

# Source contract guards.
enum_block = s.split('enum _AreaV2 {', 1)[1].split('}', 1)[0]
assert 'work,' in enum_block
primary = s.split('List<_AreaV2> get _primary => const [', 1)[1].split('];', 1)[0]
assert primary.count('_AreaV2.') == 4
assert all(x in primary for x in ['_AreaV2.home', '_AreaV2.map', '_AreaV2.properties', '_AreaV2.work'])
assert '_AreaV2.investor' not in primary
assert "label: 'More'" not in s
assert "label: 'Work'" in s
assert 'class _WorkHubV940' in s
assert s.count("tooltip: 'Explore all capabilities'") >= 2
print('V940 four-entrance navigation patch applied.')
