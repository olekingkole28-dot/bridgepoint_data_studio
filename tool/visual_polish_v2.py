from pathlib import Path


def main() -> None:
    files = list(Path('lib/v2').rglob('*.dart'))
    files += list(Path('lib/screens').glob('bridgepoint_owner*.dart'))
    files += [
        Path('lib/bridgepoint_intelligence_studio_v790.dart'),
        Path('lib/bridgepoint_integrations_hub_v790.dart'),
    ]
    files = [p for p in files if p.exists()]

    palette = {
        '0xFF06111E': '0xFF040B14',
        '0xFF07111F': '0xFF06101F',
        '0xFF0D1A2B': '0xFF0E2035',
        '0xFF122238': '0xFF16324E',
        '0xFF35D2E8': '0xFF48E1FF',
        '0xFF4F7CFF': '0xFF6C83FF',
        '0xFF38D49A': '0xFF45E6A6',
        '0xFFFFC857': '0xFFFFC95E',
        '0xFF8FA5BF': '0xFFB5C6D9',
    }
    tiny_sizes = [
        ('fontSize: 7.5', 'fontSize: 10.5'),
        ('fontSize: 7,', 'fontSize: 10.5,'),
        ('fontSize: 8.5', 'fontSize: 11'),
        ('fontSize: 8,', 'fontSize: 10.5,'),
        ('fontSize: 9.5', 'fontSize: 11.5'),
        ('fontSize: 9,', 'fontSize: 11.5,'),
        ('fontSize: 10.5', 'fontSize: 12.5'),
        ('fontSize: 10,', 'fontSize: 12.5,'),
        ('fontSize: 11,', 'fontSize: 13,'),
    ]

    for path in files:
        source = path.read_text(encoding='utf-8')
        for old, new in palette.items():
            source = source.replace(old, new)
        for old, new in tiny_sizes:
            source = source.replace(old, new)
        source = source.replace('withValues(alpha: .07)', 'withValues(alpha: .12)')
        source = source.replace('withValues(alpha: .06)', 'withValues(alpha: .10)')
        path.write_text(source, encoding='utf-8')

    polish_app_theme()
    polish_chrome()
    polish_home()
    polish_properties()
    polish_release_workflow()
    print(f'Polished {len(files)} BridgePoint surfaces plus theme/chrome/release font pipeline.')


def polish_app_theme() -> None:
    app = Path('lib/v2/bridgepoint_app_v2.dart')
    source = app.read_text(encoding='utf-8')
    start = source.index('ThemeData _theme() {')
    end = source.index('\nclass _BridgePointRoot', start)
    theme = r'''ThemeData _theme() {
  const bg = Color(0xFF040B14);
  const panel = Color(0xFF0E2035);
  const panelRaised = Color(0xFF16324E);
  const cyan = Color(0xFF48E1FF);
  const blue = Color(0xFF6C83FF);
  const green = Color(0xFF45E6A6);
  const amber = Color(0xFFFFC95E);
  const muted = Color(0xFFB5C6D9);
  const ink = Color(0xFFF5F8FC);

  final scheme = const ColorScheme.dark(
    primary: cyan,
    onPrimary: Color(0xFF021018),
    secondary: blue,
    onSecondary: Colors.white,
    tertiary: amber,
    onTertiary: Color(0xFF1A1200),
    surface: panel,
    onSurface: ink,
    error: Color(0xFFFF7474),
    onError: Color(0xFF250000),
  );

  final baseText = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
  ).textTheme.apply(
        fontFamily: 'BridgePointGrotesk',
        bodyColor: ink,
        displayColor: Colors.white,
      );

  final textTheme = baseText.copyWith(
    displayLarge: baseText.displayLarge?.copyWith(
      fontSize: 46,
      fontWeight: FontWeight.w900,
      height: 1.02,
      letterSpacing: -1.4,
    ),
    displayMedium: baseText.displayMedium?.copyWith(
      fontSize: 38,
      fontWeight: FontWeight.w900,
      height: 1.04,
      letterSpacing: -1.0,
    ),
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      height: 1.08,
      letterSpacing: -.5,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      height: 1.1,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w900,
      height: 1.18,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.25,
    ),
    titleSmall: baseText.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w800,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      height: 1.45,
    ),
    bodySmall: baseText.bodySmall?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: muted,
      height: 1.4,
    ),
    labelLarge: baseText.labelLarge?.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w900,
      letterSpacing: .1,
    ),
    labelMedium: baseText.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: .2,
    ),
    labelSmall: baseText.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .25,
    ),
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'BridgePointGrotesk',
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    cardColor: panel,
    iconTheme: const IconThemeData(color: Color(0xFFDDE8F4), size: 23),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF209192A),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFFDDE8F4), size: 24),
    ),
    cardTheme: CardThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0x66000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cyan.withValues(alpha: .14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0B1B2D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(
        color: Color(0xFFC2D2E3),
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: TextStyle(
        color: muted.withValues(alpha: .82),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: cyan,
      suffixIconColor: const Color(0xFFDDE8F4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cyan, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        backgroundColor: cyan,
        foregroundColor: const Color(0xFF031018),
        textStyle: const TextStyle(
          fontFamily: 'BridgePointGrotesk',
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: const Color(0xFFF5F8FC),
        side: BorderSide(color: blue.withValues(alpha: .65), width: 1.2),
        textStyle: const TextStyle(
          fontFamily: 'BridgePointGrotesk',
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cyan,
        textStyle: const TextStyle(
          fontFamily: 'BridgePointGrotesk',
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: panelRaised.withValues(alpha: .78),
      selectedColor: blue.withValues(alpha: .22),
      side: BorderSide(color: cyan.withValues(alpha: .16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      labelStyle: const TextStyle(
        color: Color(0xFFF1F6FB),
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF8FEFFF),
      textColor: Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      backgroundColor: const Color(0xF209192A),
      indicatorColor: blue.withValues(alpha: .22),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'BridgePointGrotesk',
          color: selected ? Colors.white : muted,
          fontSize: selected ? 12.5 : 12,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? cyan : muted,
          size: selected ? 25 : 23,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xF209192A),
      indicatorColor: blue.withValues(alpha: .20),
      selectedIconTheme: const IconThemeData(color: cyan, size: 25),
      unselectedIconTheme: const IconThemeData(color: muted, size: 22),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cyan.withValues(alpha: .12),
      thickness: 1,
      space: 20,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0B1B2D),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFF6C83FF),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0B1B2D),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelRaised,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10243B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cyan.withValues(alpha: .18)),
      ),
    ),
  );
}
'''
    source = source[:start] + theme + source[end:]
    source = source.replace(
        "      theme: _theme(),\n      home: const _BridgePointRoot(),",
        "      theme: _theme(),\n      builder: (context, child) {\n        final media = MediaQuery.of(context);\n        final scale = media.size.width < 820 ? 1.06 : 1.04;\n        return MediaQuery(\n          data: media.copyWith(textScaler: TextScaler.linear(scale)),\n          child: child ?? const SizedBox.shrink(),\n        );\n      },\n      home: const _BridgePointRoot(),",
    )
    source = source.replace('height: 70,', 'height: 76,')
    source = source.replace('color: Color(0xE8091727),', 'color: Color(0xF209192A),')
    source = source.replace(
        'bottom: BorderSide(color: Color(0x2235D2E8)),',
        'bottom: BorderSide(color: Color(0x3348E1FF)),',
    )
    old_gradient = """gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.45,
          colors: [Color(0x1835D2E8), Color(0xFF040B14)],
        ),"""
    new_gradient = """gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x2448E1FF),
            Color(0x181E4FA6),
            Color(0x18281950),
            Color(0xFF040B14),
          ],
        ),"""
    source = source.replace(old_gradient, new_gradient)
    app.write_text(source, encoding='utf-8')


def polish_chrome() -> None:
    path = Path('lib/v2/bridgepoint_chrome_v2.dart')
    source = path.read_text(encoding='utf-8')
    marker = """  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;"""
    glow = """  void paint(Canvas canvas, Size size) {
    final glowRectA = Rect.fromCircle(
      center: Offset(size.width * .16, size.height * .12),
      radius: size.shortestSide * .38,
    );
    final glowRectB = Rect.fromCircle(
      center: Offset(size.width * .84, size.height * .18),
      radius: size.shortestSide * .34,
    );
    final glowRectC = Rect.fromCircle(
      center: Offset(size.width * .62, size.height * .82),
      radius: size.shortestSide * .30,
    );
    canvas.drawCircle(
      glowRectA.center,
      glowRectA.width / 2,
      Paint()..shader = const RadialGradient(
        colors: [Color(0x1748E1FF), Colors.transparent],
      ).createShader(glowRectA),
    );
    canvas.drawCircle(
      glowRectB.center,
      glowRectB.width / 2,
      Paint()..shader = const RadialGradient(
        colors: [Color(0x126C83FF), Colors.transparent],
      ).createShader(glowRectB),
    );
    canvas.drawCircle(
      glowRectC.center,
      glowRectC.width / 2,
      Paint()..shader = const RadialGradient(
        colors: [Color(0x118B5CF6), Colors.transparent],
      ).createShader(glowRectC),
    );

    final phase = progress * math.pi * 2;"""
    if marker not in source:
        raise SystemExit('Chrome paint marker missing')
    source = source.replace(marker, glow)
    source = source.replace('fontSize: 13,', 'fontSize: 15,', 1)
    path.write_text(source, encoding='utf-8')


def polish_home() -> None:
    path = Path('lib/v2/bridgepoint_home_live_v2.dart')
    source = path.read_text(encoding='utf-8')
    start = source.index('  void _showOpportunity(Map<String, dynamic> row) {')
    end = source.index('\n\n  @override\n  Widget build', start)
    method = r'''  void _showOpportunity(Map<String, dynamic> row) {
    final address = '${row['full_address'] ?? row['title'] ?? 'BridgePoint opportunity'}';
    final title = '${row['title'] ?? 'Ranked property opportunity'}';
    final explanation = '${row['explanation'] ?? ''}'.trim();
    final action = '${row['recommended_action'] ?? ''}'.trim();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ListView(
              children: [
                Text(
                  address,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (row['score'] != null) Chip(label: Text('Score ${row['score']}')),
                    if (row['priority'] != null) Chip(label: Text('${row['priority']}'.toUpperCase())),
                    if (row['confidence_score'] != null) Chip(label: Text('${row['confidence_score']}% confidence')),
                    Chip(label: Text('${row['signal_count'] ?? 0} signals')),
                    Chip(label: Text('${row['source_count'] ?? 0} sources')),
                  ],
                ),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'WHY IT RANKED',
                    style: TextStyle(
                      color: _amber,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    explanation,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (action.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'RECOMMENDED ACTION',
                    style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    if (row['municipality'] != null)
                      _Pill(Icons.location_city_outlined, '${row['municipality']}', _blue),
                    if (row['county'] != null)
                      _Pill(Icons.map_outlined, '${row['county']} County', _cyan),
                    if (row['property_type'] != null)
                      _Pill(Icons.home_work_outlined, '${row['property_type']}', _green),
                    if (row['year_built'] != null)
                      _Pill(Icons.history_rounded, 'Built ${row['year_built']}', _amber),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }'''
    source = source[:start] + method + source[end:]
    path.write_text(source, encoding='utf-8')


def polish_properties() -> None:
    path = Path('lib/v2/bridgepoint_properties_v2.dart')
    source = path.read_text(encoding='utf-8')
    source = source.replace(
        'style: const TextStyle(fontWeight: FontWeight.w900),',
        'style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),',
    )
    path.write_text(source, encoding='utf-8')


def polish_release_workflow() -> None:
    path = Path('.github/workflows/flutter-web-v2-production.yml')
    source = path.read_text(encoding='utf-8')
    if 'Prepare BridgePoint UI font' not in source:
        needle = '      - uses: subosito/flutter-action@v2\n'
        step = r'''      - name: Prepare BridgePoint UI font
        shell: bash
        run: |
          set -euo pipefail
          mkdir -p assets/fonts
          curl -fsSL --retry 5 --retry-delay 2 'https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf' -o assets/fonts/SpaceGrotesk.ttf
          curl -fsSL --retry 5 --retry-delay 2 'https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/OFL.txt' -o assets/fonts/OFL-SpaceGrotesk.txt
          test -s assets/fonts/SpaceGrotesk.ttf
          test -s assets/fonts/OFL-SpaceGrotesk.txt
          python - <<'PY'
          from pathlib import Path
          p=Path('pubspec.yaml')
          s=p.read_text(encoding='utf-8')
          if 'family: BridgePointGrotesk' not in s:
              s += "\n  fonts:\n    - family: BridgePointGrotesk\n      fonts:\n        - asset: assets/fonts/SpaceGrotesk.ttf\n"
          p.write_text(s,encoding='utf-8')
          PY

'''
        if needle not in source:
            raise SystemExit('Flutter action marker missing in release workflow')
        source = source.replace(needle, step + needle, 1)

    source = source.replace(
        "'BridgePointOwnerCommandCenter','BridgePointOwnerOverviewV2',",
        "'BridgePointOwnerCommandCenter','BridgePointOwnerOverviewV2','BridgePointGrotesk',",
    )
    source = source.replace(
        "test -s build/web/assets/fonts/MaterialIcons-Regular.otf\n",
        "test -s build/web/assets/fonts/MaterialIcons-Regular.otf\n          test -s build/web/assets/fonts/SpaceGrotesk.ttf\n          cp assets/fonts/OFL-SpaceGrotesk.txt build/web/assets/fonts/OFL-SpaceGrotesk.txt\n",
    )
    source = source.replace(
        '"current_icon_font":true}',
        '"current_icon_font":true,"visual_polish_v2":true,"brand_font":"SpaceGrotesk"}',
    )
    source = source.replace(
        '"material_icon_font_sha256":"${FONT_SHA}"}',
        '"material_icon_font_sha256":"${FONT_SHA}","visual_polish_v2":true,"brand_font":"SpaceGrotesk"}',
    )
    path.write_text(source, encoding='utf-8')


if __name__ == '__main__':
    main()
