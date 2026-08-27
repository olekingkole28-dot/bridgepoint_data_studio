import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'v2/bridgepoint_app_v942.dart';

const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const BridgePointV942App());
}
