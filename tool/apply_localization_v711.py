from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')

marker = '// bridgepoint-localization-v711'
if marker in text:
    print('Localization V711 already applied.')
    raise SystemExit(0)

if "import 'package:shared_preferences/shared_preferences.dart';" not in text:
    anchor = "import 'package:share_plus/share_plus.dart';\n"
    if anchor not in text:
        raise SystemExit('shared_preferences import anchor not found')
    text = text.replace(anchor, anchor + "import 'package:shared_preferences/shared_preferences.dart';\n", 1)

old_home = '        home: const _AuthGate(),'
if old_home not in text:
    raise SystemExit('MaterialApp home anchor not found')
text = text.replace(old_home, '        home: const _LanguageBootstrap(),', 1)

anchor = 'class _AuthGate extends StatelessWidget {\n'
if anchor not in text:
    raise SystemExit('AuthGate anchor not found')

block = r'''// bridgepoint-localization-v711
const _bridgePointLocalePreferenceKey = 'bridgepoint_preferred_locale_v711';
final ValueNotifier<String> _bridgePointLocale = ValueNotifier<String>('en');

const List<Map<String, String>> _bridgePointFallbackLanguages = [
  {'locale': 'en', 'native_name': 'English', 'english_name': 'English', 'direction': 'LTR'},
  {'locale': 'es', 'native_name': 'Español', 'english_name': 'Spanish', 'direction': 'LTR'},
  {'locale': 'fr', 'native_name': 'Français', 'english_name': 'French', 'direction': 'LTR'},
  {'locale': 'pt-BR', 'native_name': 'Português (Brasil)', 'english_name': 'Portuguese (Brazil)', 'direction': 'LTR'},
  {'locale': 'de', 'native_name': 'Deutsch', 'english_name': 'German', 'direction': 'LTR'},
  {'locale': 'it', 'native_name': 'Italiano', 'english_name': 'Italian', 'direction': 'LTR'},
  {'locale': 'nl', 'native_name': 'Nederlands', 'english_name': 'Dutch', 'direction': 'LTR'},
  {'locale': 'pl', 'native_name': 'Polski', 'english_name': 'Polish', 'direction': 'LTR'},
  {'locale': 'ro', 'native_name': 'Română', 'english_name': 'Romanian', 'direction': 'LTR'},
  {'locale': 'ru', 'native_name': 'Русский', 'english_name': 'Russian', 'direction': 'LTR'},
  {'locale': 'uk', 'native_name': 'Українська', 'english_name': 'Ukrainian', 'direction': 'LTR'},
  {'locale': 'tr', 'native_name': 'Türkçe', 'english_name': 'Turkish', 'direction': 'LTR'},
  {'locale': 'ar', 'native_name': 'العربية', 'english_name': 'Arabic', 'direction': 'RTL'},
  {'locale': 'he', 'native_name': 'עברית', 'english_name': 'Hebrew', 'direction': 'RTL'},
  {'locale': 'hi', 'native_name': 'हिन्दी', 'english_name': 'Hindi', 'direction': 'LTR'},
  {'locale': 'bn', 'native_name': 'বাংলা', 'english_name': 'Bengali', 'direction': 'LTR'},
  {'locale': 'pa', 'native_name': 'ਪੰਜਾਬੀ', 'english_name': 'Punjabi', 'direction': 'LTR'},
  {'locale': 'ur', 'native_name': 'اردو', 'english_name': 'Urdu', 'direction': 'RTL'},
  {'locale': 'zh-Hans', 'native_name': '简体中文', 'english_name': 'Chinese (Simplified)', 'direction': 'LTR'},
  {'locale': 'zh-Hant', 'native_name': '繁體中文', 'english_name': 'Chinese (Traditional)', 'direction': 'LTR'},
  {'locale': 'ja', 'native_name': '日本語', 'english_name': 'Japanese', 'direction': 'LTR'},
  {'locale': 'ko', 'native_name': '한국어', 'english_name': 'Korean', 'direction': 'LTR'},
  {'locale': 'vi', 'native_name': 'Tiếng Việt', 'english_name': 'Vietnamese', 'direction': 'LTR'},
  {'locale': 'id', 'native_name': 'Bahasa Indonesia', 'english_name': 'Indonesian', 'direction': 'LTR'},
  {'locale': 'tl', 'native_name': 'Filipino / Tagalog', 'english_name': 'Filipino / Tagalog', 'direction': 'LTR'},
  {'locale': 'th', 'native_name': 'ไทย', 'english_name': 'Thai', 'direction': 'LTR'},
  {'locale': 'ht', 'native_name': 'Kreyòl ayisyen', 'english_name': 'Haitian Creole', 'direction': 'LTR'},
];

String _bridgePointDeviceLocaleGuess() {
  final locale = ui.PlatformDispatcher.instance.locale;
  final language = locale.languageCode.toLowerCase();
  final country = (locale.countryCode ?? '').toUpperCase();
  if (language == 'zh') {
    return const {'TW', 'HK', 'MO'}.contains(country) ? 'zh-Hant' : 'zh-Hans';
  }
  if (language == 'pt') return 'pt-BR';
  for (final option in _bridgePointFallbackLanguages) {
    final code = option['locale'] ?? 'en';
    if (code.toLowerCase() == language || code.toLowerCase().startsWith('$language-')) return code;
  }
  return 'en';
}

bool _bridgePointRtl(String locale) => const {'ar', 'he', 'ur'}.contains(locale);

Future<void> _syncBridgePointLocaleToAccount() async {
  if (Supabase.instance.client.auth.currentSession == null) return;
  final prefs = await SharedPreferences.getInstance();
  final locale = prefs.getString(_bridgePointLocalePreferenceKey);
  if (locale == null || locale.isEmpty) return;
  _bridgePointLocale.value = locale;
  try {
    await _callRpc('bridgepoint_save_locale_v711', {'p_locale': locale});
  } catch (_) {
    // The local preference remains authoritative for UI startup; account sync retries next session.
  }
}

class _LanguageBootstrap extends StatefulWidget {
  const _LanguageBootstrap();

  @override
  State<_LanguageBootstrap> createState() => _LanguageBootstrapState();
}

class _LanguageBootstrapState extends State<_LanguageBootstrap> {
  bool loading = true;
  bool complete = false;
  bool saving = false;
  String selected = 'en';
  String? error;
  List<Map<String, dynamic>> languages = _bridgePointFallbackLanguages
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
  Map<String, dynamic> strings = const {
    'language_picker.title': 'Choose your language',
    'language_picker.subtitle': 'Use BridgePoint in the language you understand best.',
    'language_picker.continue': 'Continue',
    'language_picker.change_later': 'You can change this later in Settings.',
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_bridgePointLocalePreferenceKey);
    if (saved != null && _bridgePointFallbackLanguages.any((x) => x['locale'] == saved)) {
      _bridgePointLocale.value = saved;
      if (!mounted) return;
      setState(() {
        selected = saved;
        complete = true;
        loading = false;
      });
      return;
    }

    selected = _bridgePointDeviceLocaleGuess();
    await _loadCatalog(selected, firstLoad: true);
  }

  Future<void> _loadCatalog(String locale, {bool firstLoad = false}) async {
    if (!firstLoad && mounted) setState(() => loading = true);
    try {
      final result = await _callRpc('bridgepoint_supported_languages_v711', {'p_locale': locale});
      final rawLanguages = result['languages'];
      final rawStrings = result['strings'];
      if (!mounted) return;
      setState(() {
        selected = (result['selected_locale'] ?? locale).toString();
        if (rawLanguages is List && rawLanguages.isNotEmpty) {
          languages = rawLanguages.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (rawStrings is Map && rawStrings.isNotEmpty) {
          strings = {...strings, ...Map<String, dynamic>.from(rawStrings)};
        }
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          selected = locale;
          error = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _choose(String locale) async {
    setState(() => selected = locale);
    await _loadCatalog(locale);
  }

  Future<void> _continue() async {
    setState(() => saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bridgePointLocalePreferenceKey, selected);
    _bridgePointLocale.value = selected;
    try {
      if (Supabase.instance.client.auth.currentSession != null) {
        await _callRpc('bridgepoint_save_locale_v711', {'p_locale': selected});
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      saving = false;
      complete = true;
    });
  }

  String _s(String key, String fallback) => (strings[key] ?? fallback).toString();

  @override
  Widget build(BuildContext context) {
    if (complete) {
      return Directionality(
        textDirection: _bridgePointRtl(selected) ? TextDirection.rtl : TextDirection.ltr,
        child: const _AuthGate(),
      );
    }

    return Directionality(
      textDirection: _bridgePointRtl(selected) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: _ExperienceBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Container(
                    width: 760,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: _BridgePointMark(size: 62)),
                        const SizedBox(height: 16),
                        Text(
                          _s('language_picker.title', 'Choose your language'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _s('language_picker.subtitle', 'Use BridgePoint in the language you understand best.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textMuted, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                        if (loading)
                          const LinearProgressIndicator(color: AppTheme.cyan, backgroundColor: Colors.white12)
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 430),
                            child: GridView.builder(
                              shrinkWrap: true,
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 230,
                                mainAxisExtent: 72,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: languages.length,
                              itemBuilder: (context, index) {
                                final language = languages[index];
                                final locale = (language['locale'] ?? 'en').toString();
                                final active = locale == selected;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: saving ? null : () => _choose(locale),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: active ? AppTheme.cyan : Colors.white12, width: active ? 1.8 : 1),
                                      color: active ? AppTheme.cyan.withValues(alpha: .10) : Colors.white.withValues(alpha: .035),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text((language['native_name'] ?? locale).toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 2),
                                              Text((language['english_name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                            ],
                                          ),
                                        ),
                                        if (active) const Icon(Icons.check_circle_rounded, color: AppTheme.cyan, size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.amber, fontSize: 11)),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: loading || saving ? null : _continue,
                          icon: const Icon(Icons.language_rounded),
                          label: Text(saving ? '…' : _s('language_picker.continue', 'Continue')),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _s('language_picker.change_later', 'You can change this later in Settings.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
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
text = text.replace(anchor, block + anchor, 1)

old_load = "  Future<Map<String,dynamic>> _load()async{\n    final results=await Future.wait(["
new_load = "  Future<Map<String,dynamic>> _load()async{\n    await _syncBridgePointLocaleToAccount();\n    final results=await Future.wait(["
if old_load not in text:
    raise SystemExit('Workspace locale sync anchor not found')
text = text.replace(old_load, new_load, 1)

path.write_text(text, encoding='utf-8')
print('Applied BridgePoint localization V711 bootstrap.')
