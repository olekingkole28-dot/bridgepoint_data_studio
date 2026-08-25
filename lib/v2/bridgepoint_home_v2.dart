import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/bridgepoint_owner_command_center.dart';
import 'bridgepoint_buildings_v2.dart';
import 'bridgepoint_home_live_v2.dart';
import 'bridgepoint_investor_v2.dart';
import 'bridgepoint_map_weather_v2.dart';
import 'bridgepoint_properties_v2.dart';

class BridgePointHomeV2 extends StatefulWidget {
  const BridgePointHomeV2({super.key});

  @override
  State<BridgePointHomeV2> createState() => _BridgePointHomeV2State();
}

class _BridgePointHomeV2State extends State<BridgePointHomeV2> {
  bool _owner = false;

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
    if (mounted) setState(() {});
  }

  void _open(String title, Widget child, {bool bounded = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: bounded
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox.expand(child: child),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: child,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BridgePointHomeLiveV2(
      owner: _owner,
      onMap: () => _open(
        'Geospatial Intelligence',
        const BridgePointMapWeatherV2(),
      ),
      onProperties: () => _open(
        'Properties',
        const BridgePointPropertiesV2(),
      ),
      onInvestor: () => _open(
        'BridgePoint Investor',
        const BridgePointInvestorV2(),
      ),
      onBuildings: () => _open(
        'Buildings & Digital Twin',
        const BridgePointBuildingsV2(),
      ),
      onOwner: _owner
          ? () => _open(
                'Owner Backend',
                const BridgePointOwnerCommandCenter(),
                bounded: true,
              )
          : () {},
    );
  }
}
