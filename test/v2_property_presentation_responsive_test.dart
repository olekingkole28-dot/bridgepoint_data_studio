import 'package:bridgepoint_data_studio/v2/bridgepoint_property_presentation_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const widths = <double>[320, 360, 390, 430, 768];

  final detail = <String, dynamic>{
    'complete': true,
    'locked': false,
    'property': {
      'property_id': '00000000-0000-0000-0000-000000000001',
      'full_address': '123 BridgePoint Test Lane',
      'parcel_number': 'TEST-001',
      'assessor_account_number': 'A-1001',
      'municipality': 'Middletown',
      'county': 'Middlesex',
      'state_code': 'CT',
      'postal_code': '06457',
      'property_type': 'Residential',
      'land_use_description': 'Single Family',
      'year_built': 1998,
      'building_count': 1,
      'assessed_total_value': 275000,
      'market_total_value': 395000,
      'canonical_confidence': .98,
      'updated_at': '2026-08-25T12:00:00Z',
    },
    'intelligence': {
      'available': true,
      'opportunities': [
        {
          'title': 'Exterior property review',
          'score': 84,
          'priority': 'HIGH',
          'confidence_percent': 91,
          'direct_signal_count': 6,
          'direct_source_count': 4,
          'independent_evidence_families': 3,
          'latest_evidence_at': '2026-08-25T10:00:00Z',
          'why_now': 'Recent corroborated property evidence crossed the strict review threshold.',
          'recommended_action': 'Review the evidence timeline and verify current condition.',
        }
      ],
    },
  };

  final timeline = <String, dynamic>{
    'complete': true,
    'explanation': 'Source-aware chronological property story.',
    'timeline': [
      {
        'timeline_type': 'SIGNAL',
        'timeline_at': '2026-08-25T09:00:00Z',
        'title': 'Severe wind exposure',
        'description': 'A source observation was linked to the canonical property.',
        'source_label': 'NOAA',
        'support_level': 'DIRECT_MODEL_EVIDENCE',
        'confidence': .93,
        'severity': 78,
        'match_method': 'PROPERTY_RECORD_LINK',
        'why_it_matters': 'Recent exposure can justify a timely inspection.',
        'limitations': 'Weather exposure is not verified property damage.',
      },
      {
        'timeline_type': 'PATTERN',
        'timeline_at': '2026-08-24T09:00:00Z',
        'title': 'Compound exterior change pattern',
        'description': 'Multiple observations formed a corroborating sequence.',
        'source_label': 'Property change',
        'support_level': 'CORROBORATING_PATTERN',
        'confidence': .86,
      },
    ],
  };

  final climate = <String, dynamic>{
    'status': 'READY',
    'observed_hazards': {
      'WIND': {
        'coverage_status': 'OBSERVED_HISTORY_AVAILABLE',
        'observed_exposure_score': 71,
        'recurrence_count': 4,
        'latest_observed_at': '2026-08-25T09:00:00Z',
      },
      'HAIL': {
        'coverage_status': 'NO_PROPERTY_LEVEL_OBSERVATIONS_YET',
        'recurrence_count': 0,
      },
    },
    'structural_sensitivity': {
      'screening_score': 61,
      'building_age_years': 28,
      'interpretation': 'Asset sensitivity screening feature; not an engineering condition assessment.',
    },
    'coverage': {
      'observed_signal_count': 4,
      'historical_hazard_evidence': 'AVAILABLE',
    },
    'future_scenario': {
      'status': 'PROJECTION_BINDING_REQUIRED',
      'reason': 'Future climate scenario must be spatially bound first.',
    },
  };

  final twin = <String, dynamic>{
    'status': 'READY',
    'twin_status': 'PARTIAL',
    'fidelity_level': 'L1_BUILDING_MASSING',
    'overall_confidence': .84,
    'exact_replica_claim_allowed': false,
    'simulation_readiness': {
      'wind_envelope': {'ready': false, 'reason': 'Higher-fidelity envelope evidence required'},
      'roof_water_pooling': {'ready': false, 'reason': 'Roof/drainage geometry required'},
    },
  };

  final permits = <String, dynamic>{
    'complete': true,
    'granularity': 'MUNICIPALITY_YEAR',
    'property_specific': false,
    'rows': [
      {
        'report_year': 2025,
        'municipality': 'Middletown',
        'total_units': 122,
        'one_unit': 80,
        'two_unit': 10,
        'three_four_units': 12,
        'five_plus_units': 20,
        'demolitions': 6,
      }
    ],
  };

  final media = <String, dynamic>{
    'complete': true,
    'available': true,
    'display_message': null,
    'priority_rule': 'Exterior media first; aerial fallback.',
    'items': [
      {
        'media_type': 'EXTERIOR',
        'display_label': 'Property Photo',
        'source_name': 'BridgePoint test evidence',
        'captured_at': '2026-08-20T12:00:00Z',
      }
    ],
    'aerial_history': [
      {
        'media_type': 'AERIAL',
        'display_label': 'Historical Aerial',
        'provider': 'Test imagery source',
        'capture_date': '2023-06-01',
      }
    ],
  };

  for (final width in widths) {
    testWidgets('structured Property 360 is usable at ${width.toInt()}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1200);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BridgePointPropertyOverviewV2(payload: detail),
                  const SizedBox(height: 12),
                  BridgePointPropertyTimelineV2(payload: timeline),
                  const SizedBox(height: 12),
                  BridgePointClimateProfileV2(payload: climate),
                  const SizedBox(height: 12),
                  BridgePointTwinSummaryV2(payload: twin),
                  const SizedBox(height: 12),
                  BridgePointPermitContextV2(payload: permits),
                  const SizedBox(height: 12),
                  BridgePointMediaHistoryV2(payload: media),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Canonical identity'), findsOneWidget);
      expect(find.text('Property DNA'), findsOneWidget);
      expect(find.text('Climate / peril profile'), findsOneWidget);
      expect(find.text('Digital Twin fidelity'), findsOneWidget);
      expect(find.text('Permit / municipal context'), findsOneWidget);
      expect(find.text('Imagery / media history'), findsOneWidget);

      final evidenceEvent = find.text('Severe wind exposure');
      await tester.ensureVisible(evidenceEvent);
      await tester.pumpAndSettle();
      await tester.tap(evidenceEvent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('not verified property damage'), findsOneWidget);
      expect(find.textContaining('never labeled an exact replica'), findsOneWidget);
    });
  }
}
