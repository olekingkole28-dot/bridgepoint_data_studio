from pathlib import Path

MAIN = Path('lib/main.dart')
RELEASE = Path('tool/apply_launch_v94.py')
OWNER = Path('lib/screens/bridgepoint_owner_command_center.dart')


def patch_release() -> bool:
    text = RELEASE.read_text(encoding='utf-8')
    marker = '# bridgepoint-release-idempotency-v768'
    if marker in text:
        return False
    old = '''replace_once(
"""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show Northeast expansion',onTap:()=>_mapController.move(const LatLng(42.15,-72.90),6.3)),
""",
"""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.2)),
""",
'map-us-weather-button')'''
    new = '''# bridgepoint-release-idempotency-v768
_old_us_weather = """                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show Northeast expansion',onTap:()=>_mapController.move(const LatLng(42.15,-72.90),6.3)),
"""
_new_us_weather = """                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.2)),
"""
if text.count(_old_us_weather) == 1:
    text = text.replace(_old_us_weather, _new_us_weather, 1)
elif text.count(_new_us_weather) >= 1:
    print('map-us-weather-button: already applied by a newer canonical source; continuing')
else:
    raise SystemExit('map-us-weather-button: neither historical nor current control found')'''
    if old not in text:
        raise SystemExit('Legacy map-us-weather-button patch block not found.')
    RELEASE.write_text(text.replace(old, new, 1), encoding='utf-8')
    print('v768: legacy U.S. weather release patch is now idempotent.')
    return True


def compact_navigation() -> str:
    return r'''// bridgepoint-mobile-nav-v767
class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({required this.items, required this.selectedIndex, required this.onSelected});
  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  Future<void> _showAllDestinations(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return SizedBox(
          height: height * .72,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Everything BridgePoint', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Choose any workspace destination', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ])),
                IconButton(tooltip: 'Close navigation', onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Divider(height: 1, color: Colors.white.withOpacity(.07)),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisExtent: 82, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () { Navigator.of(sheetContext).pop(); onSelected(index); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.cyan.withOpacity(.13) : AppTheme.panelSoft.withOpacity(.62),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: selected ? AppTheme.cyan.withOpacity(.35) : Colors.white.withOpacity(.07)),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(item.icon, color: selected ? AppTheme.cyan : Colors.white70, size: 23),
                        const SizedBox(height: 7),
                        Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                          style: TextStyle(color: selected ? Colors.white : AppTheme.textMuted, fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryCount = items.length > 4 ? 4 : items.length;
    final hasMore = items.length > primaryCount;
    final selectedDestination = selectedIndex < primaryCount ? selectedIndex : (hasMore ? primaryCount : 0);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 3, 10, 8),
      decoration: BoxDecoration(
        color: AppTheme.panel.withOpacity(.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      clipBehavior: Clip.antiAlias,
      child: NavigationBar(
        height: 68,
        selectedIndex: selectedDestination,
        backgroundColor: Colors.transparent,
        indicatorColor: AppTheme.cyan.withOpacity(.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) { if (index < primaryCount) { onSelected(index); } else { _showAllDestinations(context); } },
        destinations: [
          for (var index = 0; index < primaryCount; index++)
            NavigationDestination(icon: Icon(items[index].icon, size: 20), selectedIcon: Icon(items[index].icon, color: AppTheme.cyan, size: 21), label: items[index].label, tooltip: items[index].label),
          if (hasMore)
            NavigationDestination(icon: const Icon(Icons.grid_view_rounded, size: 20), selectedIcon: const Icon(Icons.grid_view_rounded, color: AppTheme.cyan, size: 21), label: selectedIndex >= primaryCount ? items[selectedIndex].label : 'More', tooltip: 'All BridgePoint destinations'),
        ],
      ),
    );
  }
}
'''


def patch_main() -> bool:
    text = MAIN.read_text(encoding='utf-8')
    original = text

    if '// bridgepoint-mobile-nav-v767' not in text:
        start_marker = 'class _CompactNavigation extends StatelessWidget {'
        end_marker = '\nclass _DailyBriefPage'
        start = text.find(start_marker)
        end = text.find(end_marker, start)
        if start < 0 or end < 0:
            raise SystemExit('Could not isolate the current compact-navigation class.')
        text = text[:start] + compact_navigation() + text[end:]
        print('v767: replaced horizontal mobile chip scroller with labeled primary navigation + More sheet.')

    owner_import = "import 'screens/bridgepoint_owner_command_center.dart';"
    if owner_import not in text:
        anchor = "import 'package:url_launcher/url_launcher.dart';"
        if text.count(anchor) != 1:
            raise SystemExit(f'Owner command-center import anchor count={text.count(anchor)}')
        text = text.replace(anchor, anchor + '\n\n' + owner_import, 1)
        print('v769: imported owner command center.')

    old_route = 'if(widget.ownerMode)return const _OwnerCenterPage();'
    new_route = 'if(widget.ownerMode)return const BridgePointOwnerCommandCenter();'
    if old_route in text:
        text = text.replace(old_route, new_route, 1)
        print('v769: Owner Center now opens completion + AI + global + operations control.')
    elif new_route not in text:
        raise SystemExit('Owner Center route was not found.')

    if text == original:
        return False
    MAIN.write_text(text, encoding='utf-8')
    return True


def patch_owner_command_center() -> bool:
    text = OWNER.read_text(encoding='utf-8')
    original = text
    text = text.replace(
        'BridgePointOwnerCommandCenter._',
        '_BridgePointOwnerCommandCenterState._',
    )
    if text == original:
        return False
    OWNER.write_text(text, encoding='utf-8')
    print('v771: fixed owner command-center theme constant ownership.')
    return True


def main() -> None:
    changed = patch_release()
    changed = patch_main() or changed
    changed = patch_owner_command_center() or changed
    print('BridgePoint UI v771 changed=' + str(changed).lower())


if __name__ == '__main__':
    main()
