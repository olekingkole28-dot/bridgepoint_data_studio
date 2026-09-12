part of 'main.dart';

// bridgepoint-launch-surfaces-v2876
class _PublicEntryRouter extends StatelessWidget {
  const _PublicEntryRouter();

  @override
  Widget build(BuildContext context) {
    final u = Uri.base;
    final launch = (u.queryParameters['launch'] ?? '').toLowerCase().trim();
    if (launch == 'intelligence' || launch == 'b2b') {
      return const _IntelligenceLaunchPage();
    }
    if (launch == 'horizon' || launch == 'game') {
      return const _HorizonLaunchPage();
    }
    return const _LanguageBootstrap();
  }
}

String _lc(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _launchRef() => (Uri.base.queryParameters['ref'] ?? '').trim().toUpperCase();

Future<void> _shareLaunch(BuildContext context, String title, String text, String url) async {
  try {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      title: title,
      subject: title,
      text: text + '\n' + url,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text + '\n' + url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share link copied.')),
      );
    }
  }
}

class _LaunchLanguage extends StatelessWidget {
  const _LaunchLanguage();

  Future<void> _pick(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0B1118),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Choose language', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _bridgePointFallbackLanguages.length,
                itemBuilder: (context, i) {
                  final x = _bridgePointFallbackLanguages[i];
                  final code = x['locale'] ?? 'en';
                  return ListTile(
                    title: Text(x['native_name'] ?? code),
                    subtitle: Text(x['english_name'] ?? ''),
                    onTap: () => Navigator.pop(context, code),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bridgePointLocalePreferenceKey, value);
    _bridgePointLocale.value = value;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language preference saved: ' + value)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => _pick(context),
    icon: const Icon(Icons.language_rounded, size: 17),
    label: const Text('Language'),
  );
}

class _LaunchBackdrop extends StatefulWidget {
  const _LaunchBackdrop({required this.horizon, required this.child});
  final bool horizon;
  final Widget child;

  @override
  State<_LaunchBackdrop> createState() => _LaunchBackdropState();
}

class _LaunchBackdropState extends State<_LaunchBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController c;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final t = c.value;
      final colors = widget.horizon
          ? const [Color(0xFF07020E), Color(0xFF17082D), Color(0xFF072A32), Color(0xFF03140F)]
          : const [Color(0xFF02070A), Color(0xFF061720), Color(0xFF0C1118), Color(0xFF180C04)];
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment(-1 + t * .35, -1), end: const Alignment(1, 1), colors: colors),
        ),
        child: Stack(fit: StackFit.expand, children: [
          Positioned(
            left: -130 + 280 * t,
            top: 60,
            child: _Glow(size: 360, color: widget.horizon ? const Color(0xFF8A5CFF) : AppTheme.cyan),
          ),
          Positioned(
            right: -150 + 250 * (1 - t),
            bottom: 40,
            child: _Glow(size: 420, color: widget.horizon ? const Color(0xFF41F2C0) : AppTheme.amber),
          ),
          widget.child,
        ]),
      );
    },
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withValues(alpha: .20),
          color.withValues(alpha: .04),
          Colors.transparent,
        ]),
      ),
    ),
  );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.accent = AppTheme.cyan});
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF071019).withValues(alpha: .86),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: accent.withValues(alpha: .25)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 28, offset: const Offset(0, 12))],
    ),
    child: child,
  );
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.target, required this.label, required this.accent});
  final DateTime target;
  final String label;
  final Color accent;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? timer;
  late Duration left;

  @override
  void initState() {
    super.initState();
    left = widget.target.difference(DateTime.now().toUtc());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => left = widget.target.difference(DateTime.now().toUtc()));
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = left.isNegative ? Duration.zero : left;
    final vals = [d.inDays, d.inHours.remainder(24), d.inMinutes.remainder(60), d.inSeconds.remainder(60)];
    const names = ['DAYS', 'HRS', 'MIN', 'SEC'];
    return _Glass(
      accent: widget.accent,
      child: Column(children: [
        Text(widget.label.toUpperCase(), style: TextStyle(color: widget.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          alignment: WrapAlignment.center,
          children: List.generate(4, (i) => Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(13)),
            child: Column(children: [
              Text(vals[i].toString().padLeft(2, '0'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(names[i], style: TextStyle(fontSize: 9, color: widget.accent, fontWeight: FontWeight.w900)),
            ]),
          )),
        ),
      ]),
    );
  }
}

class _LaunchHeader extends StatelessWidget {
  const _LaunchHeader({required this.horizon, required this.onShare});
  final bool horizon;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Row(children: [
    if (!horizon) const _BridgePointMark(size: 42) else Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8A5CFF), Color(0xFF41F2C0)])),
      child: const Icon(Icons.public_rounded, color: Colors.white),
    ),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.8)),
      Text(horizon ? 'HORIZON' : 'INTELLIGENCE', style: TextStyle(color: horizon ? const Color(0xFF8FEED6) : AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: horizon ? 3 : 2)),
    ])),
    const _LaunchLanguage(),
    const SizedBox(width: 7),
    IconButton.filledTonal(onPressed: onShare, tooltip: 'Share', icon: const Icon(Icons.ios_share_rounded)),
  ]);
}

Widget _pill(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
  decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .3))),
  child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
);

Widget _chip(IconData icon, String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white10)),
  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 7), Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
);

const _jurisdictions = [
  'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY','DC','PR','GU','VI','AS','MP'
];

class _IntelligenceLaunchPage extends StatefulWidget {
  const _IntelligenceLaunchPage();
  @override
  State<_IntelligenceLaunchPage> createState() => _IntelligenceLaunchPageState();
}

class _IntelligenceLaunchPageState extends State<_IntelligenceLaunchPage> {
  final email = TextEditingController();
  final business = TextEditingController();
  final useCase = TextEditingController();
  final team = TextEditingController();
  final referral = _launchRef();
  String jurisdiction = 'CT';
  Map<String, dynamic>? data;
  Map<String, dynamic>? joined;
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await _callRpc('bridgepoint_launch_status_v2875', {'p_surface':'INTELLIGENCE','p_jurisdiction_code':jurisdiction});
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> submit() async {
    setState(() { saving = true; error = null; });
    try {
      final x = await _callRpc('bridgepoint_join_intelligence_founding_v2875', {
        'p_email':email.text.trim(),
        'p_business_name':business.text.trim(),
        'p_use_case':useCase.text.trim(),
        'p_jurisdiction_code':jurisdiction,
        'p_company_size':team.text.trim(),
        'p_referral_code':referral,
        'p_locale':_bridgePointLocale.value,
        'p_source':'intelligence_launch_v2876',
      });
      if (mounted) setState(() => joined = x);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String get shareUrl {
    final code = (joined?['referral_code'] ?? '').toString();
    return _bridgePointLiveUrl + '/?launch=intelligence' + (code.isEmpty ? '' : '&ref=' + code);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 800;
    final target = DateTime.tryParse((data?['target_at'] ?? '').toString()) ?? DateTime.now().toUtc().add(const Duration(days: 20));
    final properties = (data?['canonical_properties'] as num?) ?? 0;
    final addresses = (data?['unique_addresses'] as num?) ?? 0;
    final remaining = data?['jurisdiction_remaining'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: _LaunchBackdrop(
        horizon: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 28, vertical: 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _LaunchHeader(
                    horizon: false,
                    onShare: () => _shareLaunch(context, 'BridgePoint Intelligence', 'Founding access is open for BridgePoint Intelligence.', shareUrl),
                  ),
                  const SizedBox(height: 38),
                  if (narrow) ...[
                    hero(target, properties, addresses),
                    const SizedBox(height: 20),
                    form(remaining),
                  ] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 6, child: hero(target, properties, addresses)),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: form(remaining)),
                  ]),
                  const SizedBox(height: 22),
                  _Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Live national scale', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('These numbers come directly from BridgePoint backend.', style: TextStyle(color: AppTheme.textMuted)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 14, runSpacing: 14, children: [
                      _stat(_lc(properties), 'Canonical properties', 'Unique property identities reconciled after source matching and deduplication.', AppTheme.cyan),
                      _stat(_lc(addresses), 'Unique addresses', 'Distinct address identities. Property identity and address identity are tracked separately.', AppTheme.amber),
                    ]),
                  ])),
                  const SizedBox(height: 20),
                  _featureSection(false),
                  const SizedBox(height: 20),
                  _faq(false),
                  const SizedBox(height: 42),
                  _crossLink(true, 'Curious what happens when the same spatial engine becomes a game?'),
                  const SizedBox(height: 26),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget hero(DateTime target, num properties, num addresses) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _pill('FOUNDING ACCESS - NATIONAL PROPERTY INTELLIGENCE', AppTheme.cyan),
    const SizedBox(height: 16),
    Text((data?['headline'] ?? 'Property intelligence built from the truth layer up.').toString(), style: const TextStyle(fontSize: 42, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
    const SizedBox(height: 13),
    Text((data?['subheadline'] ?? 'Join the founding cohort while BridgePoint finishes the living 3D property world and national coverage.').toString(), style: const TextStyle(color: Color(0xFFC7D5DF), fontSize: 16, height: 1.55)),
    const SizedBox(height: 18),
    Wrap(spacing: 9, runSpacing: 9, children: [
      _chip(Icons.hub_rounded, _lc(properties) + ' properties', AppTheme.cyan),
      _chip(Icons.location_on_outlined, _lc(addresses) + ' addresses', AppTheme.cyan),
      _chip(Icons.public_rounded, 'U.S. + jurisdictions', AppTheme.cyan),
    ]),
    const SizedBox(height: 22),
    _Countdown(target: target, label: (data?['countdown_label'] ?? 'Full launch target').toString(), accent: AppTheme.cyan),
  ]);

  Widget form(dynamic remaining) => _Glass(accent: AppTheme.amber, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('FOUNDING MEMBER ACCESS', style: TextStyle(color: AppTheme.amber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
    const SizedBox(height: 7),
    const Text('Reserve one of the first 100 spots in your market.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
    const SizedBox(height: 7),
    Text(remaining == null ? 'Choose a jurisdiction to see its real remaining count.' : remaining.toString() + ' of 100 founding spots remain in ' + jurisdiction + '.', style: const TextStyle(color: AppTheme.textMuted, height: 1.4)),
    const SizedBox(height: 15),
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.email_outlined))),
    const SizedBox(height: 9),
    TextField(controller: business, decoration: const InputDecoration(labelText: 'Business name', prefixIcon: Icon(Icons.business_outlined))),
    const SizedBox(height: 9),
    DropdownButtonFormField<String>(
      value: jurisdiction,
      decoration: const InputDecoration(labelText: 'State / jurisdiction', prefixIcon: Icon(Icons.map_outlined)),
      items: _jurisdictions.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
      onChanged: (x) async { if (x != null) { setState(() => jurisdiction = x); await load(); } },
    ),
    const SizedBox(height: 9),
    TextField(controller: useCase, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'What would you use BridgePoint for?', hintText: 'Roofing, restoration, adjusting, investing, insurance, field operations...', prefixIcon: Icon(Icons.auto_awesome_outlined))),
    const SizedBox(height: 9),
    TextField(controller: team, decoration: const InputDecoration(labelText: 'Team size (optional)', prefixIcon: Icon(Icons.groups_outlined))),
    if (error != null) ...[const SizedBox(height: 9), Text(error!, style: const TextStyle(color: Colors.redAccent))],
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: saving ? null : submit, icon: const Icon(Icons.lock_open_rounded), label: Text(saving ? 'Reserving...' : joined == null ? 'Reserve founding access' : 'Founding access reserved')),
    if (joined != null) ...[
      const SizedBox(height: 12),
      Text('Referral code: ' + (joined?['referral_code'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      OutlinedButton.icon(
        onPressed: () => _shareLaunch(context, 'BridgePoint Founding Access', 'I reserved founding access to BridgePoint Intelligence.', shareUrl),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Share my founding link'),
      ),
    ],
    const SizedBox(height: 9),
    const Text('A reservation is early-access priority, not a charge. Final pricing and terms are shown before payment.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4)),
  ]));

  @override
  void dispose() {
    email.dispose(); business.dispose(); useCase.dispose(); team.dispose();
    super.dispose();
  }
}

class _HorizonLaunchPage extends StatefulWidget {
  const _HorizonLaunchPage();
  @override
  State<_HorizonLaunchPage> createState() => _HorizonLaunchPageState();
}

class _HorizonLaunchPageState extends State<_HorizonLaunchPage> {
  final email = TextEditingController();
  final player = TextEditingController();
  final home = TextEditingController();
  final faction = TextEditingController();
  final referral = _launchRef();
  Map<String, dynamic>? data;
  Map<String, dynamic>? joined;
  String? error;
  bool saving = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final x = await _callRpc('bridgepoint_launch_status_v2875', {'p_surface':'HORIZON','p_jurisdiction_code':null});
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> submit() async {
    setState(() { saving = true; error = null; });
    try {
      final x = await _callRpc('bridgepoint_join_horizon_v2875', {
        'p_email':email.text.trim(),
        'p_display_name':player.text.trim(),
        'p_home_base_query':home.text.trim(),
        'p_faction_name':faction.text.trim(),
        'p_referral_code':referral,
        'p_locale':_bridgePointLocale.value,
        'p_source':'horizon_launch_v2876',
      });
      if (mounted) setState(() => joined = x);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String get shareUrl {
    final code = (joined?['referral_code'] ?? '').toString();
    return _bridgePointLiveUrl + '/?launch=horizon' + (code.isEmpty ? '' : '&ref=' + code);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 800;
    final target = DateTime.tryParse((data?['target_at'] ?? '').toString()) ?? DateTime.now().toUtc().add(const Duration(days: 27));
    final refs = (joined?['referral_count'] as num?)?.toInt() ?? 0;
    final goal = (data?['referral_goal'] as num?)?.toInt() ?? 3;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _LaunchBackdrop(
        horizon: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 28, vertical: 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _LaunchHeader(
                    horizon: true,
                    onShare: () => _shareLaunch(context, 'BridgePoint Horizon', 'Reserve your home base in BridgePoint Horizon and build your founding faction.', shareUrl),
                  ),
                  const SizedBox(height: 38),
                  if (narrow) ...[
                    hero(target),
                    const SizedBox(height: 20),
                    form(refs, goal),
                  ] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 6, child: hero(target)),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: form(refs, goal)),
                  ]),
                  const SizedBox(height: 22),
                  _featureSection(true),
                  const SizedBox(height: 20),
                  _Glass(accent: const Color(0xFF41F2C0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Founding faction rewards', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    _reward(1, 'Scout Founder', 'Founding badge + early claim priority'),
                    _reward(3, 'Faction Ready', 'Faction emblem + launch cosmetic pack'),
                    _reward(5, 'Stronghold', 'Home-base cosmetic set + founder banner'),
                    _reward(10, 'Regional Founder', 'Rare founder title + faction customization bundle'),
                    const SizedBox(height: 8),
                    const Text('Reward details may be tuned during alpha balance. Referrals never create real-world property rights.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ])),
                  const SizedBox(height: 20),
                  _faq(true),
                  const SizedBox(height: 42),
                  _crossLink(false, 'Building, insurance, restoration, investing, or field operations? See the enterprise platform underneath Horizon.'),
                  const SizedBox(height: 26),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget hero(DateTime target) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _pill('FOUNDING SEASON - REAL-WORLD SURVIVAL SANDBOX', const Color(0xFF8FEED6)),
    const SizedBox(height: 16),
    Text((data?['headline'] ?? 'Your real-world map becomes the survival world.').toString(), style: const TextStyle(fontSize: 43, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.7)),
    const SizedBox(height: 13),
    Text((data?['subheadline'] ?? 'Reserve a home base, build your faction momentum, and earn founding rewards before access opens.').toString(), style: const TextStyle(color: Color(0xFFD7D1E8), fontSize: 16, height: 1.55)),
    const SizedBox(height: 18),
    Wrap(spacing: 9, runSpacing: 9, children: [
      _chip(Icons.phone_iphone_rounded, 'Phone', const Color(0xFF8FEED6)),
      _chip(Icons.computer_rounded, 'Desktop', const Color(0xFF8FEED6)),
      _chip(Icons.sports_esports_rounded, 'Controller input', const Color(0xFF8FEED6)),
      _chip(Icons.public_rounded, 'Persistent world', const Color(0xFF8FEED6)),
    ]),
    const SizedBox(height: 22),
    _Countdown(target: target, label: (data?['countdown_label'] ?? 'Founding access opens').toString(), accent: const Color(0xFF8FEED6)),
    const SizedBox(height: 8),
    const Text('Founding access is the first playable/claim window. Full cross-platform release follows playable-alpha validation.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4)),
  ]);

  Widget form(int refs, int goal) => _Glass(accent: const Color(0xFF8A5CFF), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('RESERVE YOUR HOME BASE', style: TextStyle(color: Color(0xFF8FEED6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
    const SizedBox(height: 7),
    const Text('Start where your real-world story starts.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
    const SizedBox(height: 7),
    const Text('Enter the address you want matched to a canonical BridgePoint parcel. This is a game home-base reservation, not a legal ownership claim.', style: TextStyle(color: AppTheme.textMuted, height: 1.45)),
    const SizedBox(height: 15),
    TextField(controller: player, decoration: const InputDecoration(labelText: 'Player name', prefixIcon: Icon(Icons.person_outline_rounded))),
    const SizedBox(height: 9),
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
    const SizedBox(height: 9),
    TextField(controller: home, decoration: const InputDecoration(labelText: 'Home-base address', hintText: 'Street address, city, state', prefixIcon: Icon(Icons.home_work_outlined))),
    const SizedBox(height: 9),
    TextField(controller: faction, decoration: const InputDecoration(labelText: 'Faction name (optional)', prefixIcon: Icon(Icons.shield_outlined))),
    if (error != null) ...[const SizedBox(height: 9), Text(error!, style: const TextStyle(color: Colors.redAccent))],
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: saving ? null : submit, icon: const Icon(Icons.flag_rounded), label: Text(saving ? 'Reserving...' : joined == null ? 'Reserve my home base' : 'Home base reserved')),
    if (joined != null) ...[
      const SizedBox(height: 13),
      Text('Faction momentum: ' + refs.toString() + ' / ' + goal.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: goal == 0 ? 0 : (refs / goal).clamp(0.0, 1.0), minHeight: 10, color: const Color(0xFF41F2C0), backgroundColor: Colors.white10),
      const SizedBox(height: 9),
      Text('Referral code: ' + (joined?['referral_code'] ?? '').toString()),
      const SizedBox(height: 7),
      OutlinedButton.icon(onPressed: () => _shareLaunch(context, 'BridgePoint Horizon', 'I reserved my home base in BridgePoint Horizon. Join my founding faction.', shareUrl), icon: const Icon(Icons.share_rounded), label: const Text('Invite my faction')),
    ],
  ]));

  Widget _reward(int n, String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      CircleAvatar(backgroundColor: const Color(0x338A5CFF), child: Text(n.toString(), style: const TextStyle(color: Color(0xFF8FEED6), fontWeight: FontWeight.w900))),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), Text(body, style: const TextStyle(color: AppTheme.textMuted))])),
    ]),
  );

  @override
  void dispose() {
    email.dispose(); player.dispose(); home.dispose(); faction.dispose();
    super.dispose();
  }
}

Widget _stat(String value, String label, String body, Color color) => SizedBox(
  width: 285,
  child: Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: .22))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(color: color, fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
    ]),
  ),
);

Widget _featureSection(bool horizon) {
  final color = horizon ? const Color(0xFF8FEED6) : AppTheme.cyan;
  final items = horizon
      ? const [
          ['1:1 spatial substrate', 'Real parcel geography and real-world scale underpin the game world.'],
          ['Live environment', 'Weather, time, terrain and world-state systems can influence gameplay.'],
          ['Faction territory', 'Cooperate to secure game territory and build persistent regional strongholds.'],
          ['Home-base reservations', 'Reserve a game home base matched to a canonical property.'],
          ['Cross-platform target', 'Designed toward phone, desktop and controller input.'],
          ['Persistent survival', 'Long-form PvE progression, recovery missions and seasonal objectives.'],
        ]
      : const [
          ['Canonical property truth', 'Unique property identities reconciled across public and authoritative sources.'],
          ['Exact parcel boundaries', 'Authoritative geometry is being completed and continuously reconciled.'],
          ['Property timelines', 'Permits, sales, hazards, incidents, changes and evidence tied to properties.'],
          ['Living weather layer', 'Weather, fire and environmental context connected spatially to assets.'],
          ['3D buildings + terrain', 'Buildings, elevation, imagery and verified spatial layers in one world.'],
          ['Field intelligence', 'Opportunities, scores, explainable signals, notes and team workflows.'],
        ];
  return _Glass(
    accent: color,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(horizon ? 'One persistent survival world' : 'The living 3D property world', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      ...items.map((x) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.white, height: 1.45), children: [
            TextSpan(text: x[0] + ' - ', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: x[1], style: const TextStyle(color: AppTheme.textMuted)),
          ]))),
        ]),
      )),
    ]),
  );
}

Widget _faq(bool horizon) {
  final items = horizon
      ? const [
          ['Is this legal ownership of my house?', 'No. A Horizon home-base reservation is a game identity and does not alter ownership, title, access rights, or any legal interest.'],
          ['Will it work on phones?', 'Phone play is a design target alongside desktop and controller input. Device support expands through alpha testing.'],
          ['Do I have to invite friends?', 'No. Referrals are optional. They can unlock digital founding rewards and faction momentum.'],
          ['What comes before full release?', 'Founding access starts with home-base claims, factions, world previews and increasingly playable systems.'],
        ]
      : const [
          ['What is a canonical property?', 'A reconciled BridgePoint identity for a real property after normalization, source matching and deduplication.'],
          ['Why fewer addresses than properties?', 'Not every property has a situs or mailing address, and multi-unit or special land identities can have different address relationships.'],
          ['What is Founding Member access?', 'Early-access priority in your state/jurisdiction cohort. Final pricing and terms are shown before payment.'],
          ['Is the 3D world finished?', 'Not yet. The national spatial foundation is being completed while buildings, terrain, imagery, weather and interaction layers are assembled.'],
          ['Who is BridgePoint for?', 'Contractors, restoration teams, adjusters, investors, insurers, property operators and field teams.'],
        ];
  return _Glass(
    accent: horizon ? const Color(0xFF8A5CFF) : AppTheme.cyan,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Questions, answered', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...items.map((x) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(x[0], style: const TextStyle(fontWeight: FontWeight.w900)),
        children: [Padding(padding: const EdgeInsets.only(bottom: 12), child: Align(alignment: Alignment.centerLeft, child: Text(x[1], style: const TextStyle(color: AppTheme.textMuted, height: 1.45))))],
      )),
    ]),
  );
}

Widget _crossLink(bool horizonTarget, String text) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .3), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
  child: Column(children: [
    Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, height: 1.45)),
    const SizedBox(height: 10),
    TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(_bridgePointLiveUrl + '/?launch=' + (horizonTarget ? 'horizon' : 'intelligence')), mode: LaunchMode.externalApplication),
      icon: Icon(horizonTarget ? Icons.sports_esports_rounded : Icons.business_center_rounded),
      label: Text(horizonTarget ? 'Explore BridgePoint Horizon' : 'Explore BridgePoint Intelligence'),
    ),
  ]),
);
