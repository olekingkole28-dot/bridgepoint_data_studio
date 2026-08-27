import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import '../screens/bridgepoint_owner_command_center.dart';
import 'bridgepoint_ai_v2.dart';
import 'bridgepoint_buildings_v2.dart';
import 'bridgepoint_calendar_v2.dart';
import 'bridgepoint_chrome_v2.dart';
import 'bridgepoint_claims_v2.dart';
import 'bridgepoint_global_search_v2.dart';
import 'bridgepoint_home_v2.dart';
import 'bridgepoint_investor_v2.dart';
import 'bridgepoint_map_weather_v2.dart';
import 'bridgepoint_operations_workspace_v2.dart';
import 'bridgepoint_opportunities_v2.dart';
import 'bridgepoint_portfolio_risk_v2.dart';
import 'bridgepoint_products_settings_v2.dart';
import 'bridgepoint_properties_v2.dart';
import 'bridgepoint_property_360_v2.dart';
import 'bridgepoint_public_landing_v2.dart';
import 'bridgepoint_saved_alerts_v2.dart';
import 'settings/bridgepoint_account_support_v2.dart';

/// V946 customer-ready shell.
///
/// This intentionally reuses the existing production intelligence modules and
/// changes only the customer journey around them: authentication, recovery,
/// navigation, hierarchy, and owner/customer separation.
class BridgePointCustomerReadyApp extends StatelessWidget {
  const BridgePointCustomerReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _customerTheme(),
      home: const _CustomerRoot(),
    );
  }
}

ThemeData _customerTheme() {
  const bg = Color(0xFF030811);
  const panel = Color(0xFF0A192A);
  const cyan = Color(0xFF48E1FF);
  const blue = Color(0xFF6C83FF);
  const gold = Color(0xFFFFC95E);
  const ink = Color(0xFFF5F8FC);
  const muted = Color(0xFFB5C6D9);
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    fontFamily: 'BridgePointGrotesk',
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: cyan,
      onPrimary: Color(0xFF021018),
      secondary: blue,
      onSecondary: Colors.white,
      tertiary: gold,
      onTertiary: Color(0xFF1A1200),
      surface: panel,
      onSurface: ink,
      error: Color(0xFFFF7474),
      onError: Color(0xFF250000),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'BridgePointGrotesk',
      bodyColor: ink,
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF4071423),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cyan.withValues(alpha: .14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF09192A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cyan, width: 1.5),
      ),
      hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: cyan,
        foregroundColor: const Color(0xFF021018),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: ink,
        side: BorderSide(color: blue.withValues(alpha: .55)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: const Color(0xF4071423),
      indicatorColor: blue.withValues(alpha: .22),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? Colors.white : muted,
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w900
              : FontWeight.w700,
        ),
      ),
    ),
  );
}

class _CustomerRoot extends StatefulWidget {
  const _CustomerRoot();

  @override
  State<_CustomerRoot> createState() => _CustomerRootState();
}

class _CustomerRootState extends State<_CustomerRoot> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _showAuth = false;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          setState(() => _passwordRecovery = true);
        } else {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && _passwordRecovery) {
      return _PasswordRecoveryPage(
        onDone: () => setState(() => _passwordRecovery = false),
      );
    }
    if (session != null) return const _CustomerWorkspace();
    if (_showAuth) {
      return _CustomerAuthPage(
        onBack: () => setState(() => _showAuth = false),
      );
    }
    return BridgePointPublicLandingV2(
      onSignIn: () => setState(() => _showAuth = true),
    );
  }
}

class _CustomerAuthPage extends StatefulWidget {
  const _CustomerAuthPage({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_CustomerAuthPage> createState() => _CustomerAuthPageState();
}

class _CustomerAuthPageState extends State<_CustomerAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _busy = false;
  bool _showPassword = false;
  bool _awaitingConfirmation = false;
  bool _resendAvailable = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    if (_password.text.length < 8) {
      return 'Use at least 8 characters for your password.';
    }
    return null;
  }

  String _friendlyAuthError(Object error) {
    final raw = error is AuthException ? error.message : error.toString();
    final text = raw.toLowerCase();
    if (text.contains('email not confirmed')) {
      return 'Check your email and confirm your BridgePoint account before signing in.';
    }
    if (text.contains('invalid login credentials')) {
      return 'That email and password combination was not recognized.';
    }
    if (text.contains('rate limit') || text.contains('only request this after')) {
      return 'A confirmation message was just sent. Give it a moment before requesting another.';
    }
    if (text.contains('already registered')) {
      return 'An account already exists for that email. Sign in instead.';
    }
    if (text.contains('password')) {
      return 'That password does not meet the current security requirements.';
    }
    return 'BridgePoint could not complete that request just now. Try again.';
  }

  Future<void> _submit() async {
    final validation = _validate();
    if (validation != null) {
      setState(() {
        _message = validation;
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      if (_create) {
        final response = await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: 'https://bridgepointintelligence.online/app/',
          data: const {'signup_surface': 'bridgepoint_customer_web'},
        );
        if (response.session == null) {
          setState(() {
            _awaitingConfirmation = true;
            _resendAvailable = false;
            _message =
                'Confirmation sent. Open the BridgePoint email, confirm your account, then come back and sign in.';
            _messageIsError = false;
          });
          Future<void>.delayed(const Duration(seconds: 15), () {
            if (mounted && _awaitingConfirmation) {
              setState(() => _resendAvailable = true);
            }
          });
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _friendlyAuthError(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (!_resendAvailable || _email.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _email.text.trim(),
        emailRedirectTo: 'https://bridgepointintelligence.online/app/',
      );
      if (!mounted) return;
      setState(() {
        _resendAvailable = false;
        _message = 'A fresh confirmation email is on the way.';
        _messageIsError = false;
      });
      Future<void>.delayed(const Duration(seconds: 30), () {
        if (mounted && _awaitingConfirmation) {
          setState(() => _resendAvailable = true);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _friendlyAuthError(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || !email.contains('@')) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://bridgepointintelligence.online/app/',
      );
      if (!mounted) return;
      setState(() {
        _message =
            'If that email has a BridgePoint account, a secure password-reset link is on the way.';
        _messageIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'BridgePoint could not send the reset link just now. Try again.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BridgePointMotionBackgroundV2(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xF00A192A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x3348E1FF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x77000000),
                    blurRadius: 44,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: widget.onBack,
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const Center(child: BridgePointMarkV2(size: 68)),
                  const SizedBox(height: 13),
                  Text(
                    _awaitingConfirmation
                        ? 'Confirm your account'
                        : (_create ? 'Start with BridgePoint' : 'Welcome back'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _awaitingConfirmation
                        ? 'One quick email check, then your workspace is ready.'
                        : 'Property intelligence without the backend maze.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB5C6D9)),
                  ),
                  const SizedBox(height: 24),
                  if (!_awaitingConfirmation) ...[
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: _create
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      onSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: _create ? '8+ characters' : null,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    _AuthNotice(
                      text: _message!,
                      error: _messageIsError,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_awaitingConfirmation) ...[
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _awaitingConfirmation = false;
                                _create = false;
                                _message = null;
                              }),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('I confirmed — sign in'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy || !_resendAvailable ? null : _resend,
                      child: Text(
                        _resendAvailable
                            ? 'Resend confirmation email'
                            : 'Confirmation email sent',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _awaitingConfirmation = false;
                                _create = true;
                                _email.clear();
                                _password.clear();
                                _message = null;
                              }),
                      child: const Text('Use a different email'),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_create ? 'Create account' : 'Sign in'),
                    ),
                    if (!_create)
                      TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _create = !_create;
                                _message = null;
                                _messageIsError = false;
                              }),
                      child: Text(
                        _create
                            ? 'Already have an account? Sign in'
                            : 'New to BridgePoint? Create account',
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'Your access is package-scoped. Owner controls and internal diagnostics stay private.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8EA5BA),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFFF8585) : const Color(0xFF75E6C8);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRecoveryPage extends StatefulWidget {
  const _PasswordRecoveryPage({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<_PasswordRecoveryPage> {
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'BridgePoint could not update the password just now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BridgePointMotionBackgroundV2(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xF00A192A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x3348E1FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BridgePointMarkV2(size: 64)),
                  const SizedBox(height: 14),
                  const Text(
                    'Choose a new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _password,
                    obscureText: !_show,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      helperText: '8+ characters',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _show = !_show),
                        icon: Icon(
                          _show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _AuthNotice(text: _error!, error: true),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('Save new password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CustomerArea {
  home,
  map,
  opportunities,
  work,
  plans,
  properties,
  search,
  saved,
  claims,
  calendar,
  operations,
  portfolio,
  investor,
  property360,
  buildings,
  ai,
  integrations,
  account,
  owner,
}

class _CustomerWorkspace extends StatefulWidget {
  const _CustomerWorkspace();

  @override
  State<_CustomerWorkspace> createState() => _CustomerWorkspaceState();
}

class _CustomerWorkspaceState extends State<_CustomerWorkspace> {
  static const _cyan = Color(0xFF48E1FF);
  static const _gold = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  _CustomerArea _selected = _CustomerArea.home;
  String? _searchSeed;
  bool _owner = false;
  bool _ownerChecked = false;

  static const _primary = <_CustomerArea>[
    _CustomerArea.home,
    _CustomerArea.map,
    _CustomerArea.opportunities,
    _CustomerArea.work,
    _CustomerArea.plans,
  ];

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_owner_v2_requirements_v832',
        params: {'p_category': null, 'p_status': null, 'p_limit': 1},
      );
      _owner = true;
    } catch (_) {
      _owner = false;
    }
    if (mounted) setState(() => _ownerChecked = true);
  }

  void _open(_CustomerArea area) => setState(() => _selected = area);

  Future<void> _search() async {
    final controller = TextEditingController(text: _searchSeed ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search BridgePoint'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(
            labelText: 'Address, parcel, owner or municipality',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().length >= 2) {
      setState(() {
        _searchSeed = result.trim();
        _selected = _CustomerArea.search;
      });
    }
  }

  String _title() => switch (_selected) {
        _CustomerArea.home => 'BridgePoint Intelligence',
        _CustomerArea.map => 'Intelligence Map',
        _CustomerArea.opportunities => 'Opportunities',
        _CustomerArea.work => 'Work',
        _CustomerArea.plans => 'Plans & Access',
        _CustomerArea.properties => 'Properties',
        _CustomerArea.search => 'Search',
        _CustomerArea.saved => 'Saved & Alerts',
        _CustomerArea.claims => 'Claims',
        _CustomerArea.calendar => 'Calendar',
        _CustomerArea.operations => 'Operations',
        _CustomerArea.portfolio => 'Portfolio & Risk',
        _CustomerArea.investor => 'Investor Intelligence',
        _CustomerArea.property360 => 'Property Intelligence',
        _CustomerArea.buildings => 'Buildings & Structure 3D',
        _CustomerArea.ai => 'Ask BridgePoint AI',
        _CustomerArea.integrations => 'Integrations',
        _CustomerArea.account => 'Account & Help',
        _CustomerArea.owner => 'Owner Control',
      };

  Widget _page() => switch (_selected) {
        _CustomerArea.home => const BridgePointHomeV2(),
        _CustomerArea.map => const BridgePointMapWeatherV2(),
        _CustomerArea.opportunities => const BridgePointOpportunitiesV2(),
        _CustomerArea.work => _CustomerWorkHub(onOpen: _open),
        _CustomerArea.plans => const BridgePointProductsSettingsV2(),
        _CustomerArea.properties => const BridgePointPropertiesV2(),
        _CustomerArea.search => BridgePointGlobalSearchV2(
            key: ValueKey(_searchSeed),
            initialQuery: _searchSeed,
          ),
        _CustomerArea.saved => const BridgePointSavedAlertsV2(),
        _CustomerArea.claims => const BridgePointClaimsV2(),
        _CustomerArea.calendar => const BridgePointCalendarV2(),
        _CustomerArea.operations => const BridgePointOperationsWorkspaceV2(),
        _CustomerArea.portfolio => const BridgePointPortfolioRiskV2(),
        _CustomerArea.investor => const BridgePointInvestorV2(),
        _CustomerArea.property360 => const BridgePointProperty360V2(),
        _CustomerArea.buildings => const BridgePointBuildingsV2(),
        _CustomerArea.ai => const BridgePointAiV2(),
        _CustomerArea.integrations => const BridgePointIntegrationsHub(),
        _CustomerArea.account => const BridgePointAccountSupportV2(),
        _CustomerArea.owner => const BridgePointOwnerCommandCenter(),
      };

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .88,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
            children: [
              const BridgePointBrandLockupV2(),
              const SizedBox(height: 14),
              _MoreGroup(
                title: 'Find & evaluate',
                children: [
                  _moreItem(_CustomerArea.search, 'Search',
                      'Address, parcel, owner or municipality', Icons.search_rounded),
                  _moreItem(_CustomerArea.properties, 'Properties',
                      'Browse available property intelligence', Icons.holiday_village_outlined),
                  _moreItem(_CustomerArea.property360, 'Property Intelligence',
                      'Signals, evidence and property context', Icons.home_work_outlined),
                  _moreItem(_CustomerArea.buildings, 'Buildings & Structure 3D',
                      'Physical-property and geometry intelligence', Icons.view_in_ar_outlined),
                ],
              ),
              _MoreGroup(
                title: 'Act & manage',
                children: [
                  _moreItem(_CustomerArea.saved, 'Saved & Alerts',
                      'Keep important properties and changes together', Icons.bookmark_outline_rounded),
                  _moreItem(_CustomerArea.claims, 'Claims',
                      'Property and claim intelligence workflows', Icons.assignment_outlined),
                  _moreItem(_CustomerArea.calendar, 'Calendar',
                      'Plan follow-up and field work', Icons.calendar_month_outlined),
                  _moreItem(_CustomerArea.operations, 'Operations',
                      'Coordinate active work', Icons.route_outlined),
                ],
              ),
              _MoreGroup(
                title: 'Portfolio & decisions',
                children: [
                  _moreItem(_CustomerArea.portfolio, 'Portfolio & Risk',
                      'Risk context across groups of properties', Icons.analytics_outlined),
                  _moreItem(_CustomerArea.investor, 'Investor Intelligence',
                      'Ranked property and investment context', Icons.real_estate_agent_outlined),
                  _moreItem(_CustomerArea.ai, 'Ask BridgePoint AI',
                      'Ask about intelligence in plain English', Icons.auto_awesome_rounded),
                  _moreItem(_CustomerArea.integrations, 'Integrations',
                      'Connect supported workflows and data', Icons.cable_rounded),
                ],
              ),
              if (_owner)
                _MoreGroup(
                  title: 'Owner only',
                  accent: _gold,
                  children: [
                    _moreItem(_CustomerArea.owner, 'Owner Control',
                        'Automation, expansion and internal diagnostics', Icons.admin_panel_settings_outlined),
                  ],
                ),
              _MoreGroup(
                title: 'Account',
                children: [
                  _moreItem(_CustomerArea.account, 'Account / Billing / Help',
                      'Profile, billing and support', Icons.manage_accounts_outlined),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreItem(
    _CustomerArea area,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.pop(context);
        _open(area);
      },
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      titleSpacing: 14,
      title: Row(
        children: [
          const BridgePointMarkV2(size: 31),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _title(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: _search,
          icon: const Icon(Icons.search_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            tooltip: 'More',
            onPressed: _showMore,
            icon: const Icon(Icons.apps_rounded),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ownerChecked) {
      return const Scaffold(
        body: BridgePointMotionBackgroundV2(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final compact = MediaQuery.sizeOf(context).width < 900;
    final page = _selected == _CustomerArea.owner
        ? Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox.expand(child: _page()),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _page(),
          );
    final body = BridgePointMotionBackgroundV2(child: page);

    if (compact) {
      final selectedIndex = _primary.contains(_selected)
          ? _primary.indexOf(_selected)
          : 3;
      return Scaffold(
        appBar: _appBar(),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _open(_primary[index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.public_outlined),
              selectedIcon: Icon(Icons.public_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt_rounded),
              label: 'Leads',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline_rounded),
              selectedIcon: Icon(Icons.work_rounded),
              label: 'Work',
            ),
            NavigationDestination(
              icon: Icon(Icons.workspace_premium_outlined),
              selectedIcon: Icon(Icons.workspace_premium_rounded),
              label: 'Plans',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 238,
            decoration: const BoxDecoration(
              color: Color(0xF4071423),
              border: Border(right: BorderSide(color: Color(0x2248E1FF))),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 16, 14, 16),
                    child: BridgePointBrandLockupV2(),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  for (final area in _primary)
                    _DesktopNavItem(
                      selected: _selected == area,
                      label: _desktopLabel(area),
                      icon: _desktopIcon(area),
                      gold: area == _CustomerArea.plans,
                      onTap: () => _open(area),
                    ),
                  const SizedBox(height: 6),
                  _DesktopNavItem(
                    selected: !_primary.contains(_selected),
                    label: 'More tools',
                    icon: Icons.apps_rounded,
                    onTap: _showMore,
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Search property'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Scaffold(
              appBar: _appBar(),
              body: body,
            ),
          ),
        ],
      ),
    );
  }

  String _desktopLabel(_CustomerArea area) => switch (area) {
        _CustomerArea.home => 'Home',
        _CustomerArea.map => 'Map',
        _CustomerArea.opportunities => 'Opportunities',
        _CustomerArea.work => 'Work',
        _CustomerArea.plans => 'Plans & Access',
        _ => 'More',
      };

  IconData _desktopIcon(_CustomerArea area) => switch (area) {
        _CustomerArea.home => Icons.space_dashboard_rounded,
        _CustomerArea.map => Icons.public_rounded,
        _CustomerArea.opportunities => Icons.bolt_rounded,
        _CustomerArea.work => Icons.work_rounded,
        _CustomerArea.plans => Icons.workspace_premium_rounded,
        _ => Icons.apps_rounded,
      };
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    this.gold = false,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final accent = gold ? const Color(0xFFFFC95E) : const Color(0xFF48E1FF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? accent.withValues(alpha: .11) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected || gold ? accent : const Color(0xFFB5C6D9)),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected || gold ? Colors.white : const Color(0xFFB5C6D9),
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({
    required this.title,
    required this.children,
    this.accent,
  });

  final String title;
  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent ?? const Color(0xFF8FA8BE),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerWorkHub extends StatelessWidget {
  const _CustomerWorkHub({required this.onOpen});

  final void Function(_CustomerArea area) onOpen;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1180 ? 3 : (width >= 700 ? 2 : 1);
    final cards = <_WorkCardData>[
      const _WorkCardData(
        _CustomerArea.properties,
        'Properties',
        'Browse and evaluate available property intelligence.',
        Icons.holiday_village_outlined,
      ),
      const _WorkCardData(
        _CustomerArea.saved,
        'Saved & Alerts',
        'Keep priority properties and important changes together.',
        Icons.bookmark_outline_rounded,
      ),
      const _WorkCardData(
        _CustomerArea.claims,
        'Claims',
        'Move from property evidence into claim-focused workflows.',
        Icons.assignment_outlined,
      ),
      const _WorkCardData(
        _CustomerArea.calendar,
        'Calendar',
        'Schedule follow-up, visits and active work.',
        Icons.calendar_month_outlined,
      ),
      const _WorkCardData(
        _CustomerArea.operations,
        'Operations',
        'Coordinate active properties and field execution.',
        Icons.route_outlined,
      ),
      const _WorkCardData(
        _CustomerArea.portfolio,
        'Portfolio & Risk',
        'See risk and intelligence across groups of properties.',
        Icons.analytics_outlined,
      ),
      const _WorkCardData(
        _CustomerArea.investor,
        'Investor Intelligence',
        'Use property context to support investment decisions.',
        Icons.real_estate_agent_outlined,
      ),
      const _WorkCardData(
        _CustomerArea.ai,
        'Ask BridgePoint AI',
        'Ask questions about the intelligence in plain English.',
        Icons.auto_awesome_rounded,
      ),
      const _WorkCardData(
        _CustomerArea.integrations,
        'Integrations',
        'Connect supported systems and workflows.',
        Icons.cable_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your intelligence workspace',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find a property, understand what changed, decide what matters, then act — without digging through separate data tools.',
          style: TextStyle(color: Color(0xFFB5C6D9), height: 1.45),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 2.4 : 1.65,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final item in cards)
              _WorkCard(item: item, onTap: () => onOpen(item.area)),
          ],
        ),
      ],
    );
  }
}

class _WorkCardData {
  const _WorkCardData(this.area, this.title, this.subtitle, this.icon);

  final _CustomerArea area;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.item, required this.onTap});

  final _WorkCardData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: const Color(0xFF48E1FF), size: 28),
              const Spacer(),
              Text(
                item.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB5C6D9),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
