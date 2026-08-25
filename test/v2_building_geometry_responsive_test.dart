import 'package:bridgepoint_data_studio/v2/bridgepoint_building_geometry_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const widths = <double>[320, 360, 390, 430, 768];

  final payload = <String, dynamic>{
    'complete': true,
    'locked': false,
    'truth_notice':
        'Source-backed footprint/massing. Higher fidelity requires stronger evidence.',
    'geometry': [
      {
        'fidelity_level': 'L1_BUILDING_MASSING',
        'height_m': 8.6,
        'floors': 2,
        'source_provider': 'BridgePoint test source',
        'source_year': 2025,
        'match_method': 'PROPERTY_ID',
        'match_confidence': 0.98,
        'footprint_area_m2': 164.2,
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [-72.65, 41.55],
              [-72.6497, 41.55],
              [-72.6497, 41.5502],
              [-72.65, 41.5502],
              [-72.65, 41.55],
            ]
          ],
        },
      }
    ],
  };

  for (final width in widths) {
    testWidgets('building geometry is usable at ${width.toInt()}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: BridgePointBuildingGeometryV2(payload: payload),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Building Geometry'), findsOneWidget);
      expect(find.text('Footprint'), findsOneWidget);
      expect(find.text('Massing'), findsOneWidget);
      expect(find.textContaining('exact replica'), findsOneWidget);

      await tester.tap(find.text('Footprint'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Massing'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
