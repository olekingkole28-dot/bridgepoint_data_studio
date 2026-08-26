import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'v2/bridgepoint_recovery_shell_v3.dart';

const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';

// Recovery branch only: keep production untouched until this V3 shell passes
// analysis and the core property/map flows are verified end to end.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const BridgePointRecoveryV3App());
}
