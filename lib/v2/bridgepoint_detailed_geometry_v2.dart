import 'package:flutter/material.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_source_surface_model_v2.dart';

class BridgePointDetailedGeometryV2 extends StatelessWidget {
  const BridgePointDetailedGeometryV2({
    super.key,
    required this.geometryPayload,
    required this.sourceSurfacePayload,
  });

  final Map<String, dynamic> geometryPayload;
  final Map<String, dynamic> sourceSurfacePayload;

  @override
  Widget build(BuildContext context) {
    final detailed = sourceSurfacePayload['available'] == true &&
        sourceSurfacePayload['geometry_3d'] is Map;

    if (!detailed) {
      return BridgePointBuildingGeometryV2(payload: geometryPayload);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BridgePointSourceSurfaceModelV2(payload: sourceSurfacePayload),
        const SizedBox(height: 10),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text(
            'Footprint / schematic fallback',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text(
            'Compare the higher-fidelity source surface model with BridgePoint’s footprint/massing fallback.',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BridgePointBuildingGeometryV2(payload: geometryPayload),
            ),
          ],
        ),
      ],
    );
  }
}
