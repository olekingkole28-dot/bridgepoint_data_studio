import 'package:supabase_flutter/supabase_flutter.dart';

/// Typed client for BridgePoint's partner-safe AI RPC surface.
///
/// All functions called here are authenticated public wrappers. The backend
/// remains responsible for package/state entitlements, tenant attribution,
/// usage metering, provenance policy, and model/data export boundaries.
class BridgePointAiService {
  BridgePointAiService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _rpc(
    String functionName, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) async {
    final dynamic result = await _client.rpc(functionName, params: params);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('Unexpected BridgePoint AI response.');
  }

  Future<Map<String, dynamic>> home() =>
      _rpc('bridgepoint_ai_home_v509');

  Future<Map<String, dynamic>> digitalTwinSummary(String propertyId) =>
      _rpc('bridgepoint_digital_twin_summary_v509', {
        'p_property_id': propertyId,
      });

  Future<Map<String, dynamic>> twinIngestionRequirements() =>
      _rpc('bridgepoint_twin_ingestion_requirements_v509');

  Future<Map<String, dynamic>> modelTransparency(String modelKey) =>
      _rpc('bridgepoint_model_transparency_v509', {
        'p_model_key': modelKey,
      });

  Future<Map<String, dynamic>> thermalWindowRetrofit({
    required double opaqueEnvelopeAreaSqFt,
    required double windowAreaSqFt,
    required double existingWindowU,
    required double proposedWindowU,
    required double indoorTempF,
    required double outdoorTempF,
    double otherEnvelopeUa = 0,
  }) =>
      _rpc('bridgepoint_thermal_window_retrofit_v509', {
        'p_opaque_envelope_area_sqft': opaqueEnvelopeAreaSqFt,
        'p_window_area_sqft': windowAreaSqFt,
        'p_existing_window_u': existingWindowU,
        'p_proposed_window_u': proposedWindowU,
        'p_indoor_temp_f': indoorTempF,
        'p_outdoor_temp_f': outdoorTempF,
        'p_other_envelope_ua': otherEnvelopeUa,
      });

  Future<Map<String, dynamic>> climateRiskScore({
    required String stateCode,
    required double exposureScore,
    required double vulnerabilityScore,
    double adaptiveCapacityScore = 50,
    double sourceConfidence = 0.7,
    int horizonYear = 2050,
    String scenarioKey = 'CMRA_MULTI_HAZARD',
  }) =>
      _rpc('bridgepoint_climate_risk_score_v509', {
        'p_state_code': stateCode,
        'p_exposure_score': exposureScore,
        'p_vulnerability_score': vulnerabilityScore,
        'p_adaptive_capacity_score': adaptiveCapacityScore,
        'p_source_confidence': sourceConfidence,
        'p_horizon_year': horizonYear,
        'p_scenario_key': scenarioKey,
      });

  Future<Map<String, dynamic>> portfolioClimateSummary({
    required List<double> propertyScores,
    required int horizonYear,
    String scenarioKey = 'CMRA_MULTI_HAZARD',
  }) =>
      _rpc('bridgepoint_portfolio_climate_summary_v509', {
        'p_scores': propertyScores
            .map((score) => <String, dynamic>{'score': score})
            .toList(growable: false),
        'p_horizon_year': horizonYear,
        'p_scenario_key': scenarioKey,
      });

  Future<Map<String, dynamic>> insuranceRoofWind({
    required String stateCode,
    required double gustMph,
    double? roofAgeYears,
    double? roofConditionScore,
    double? treeExposureScore,
    double? priorDamageScore,
    String? roofShape,
    String? roofMaterial,
  }) =>
      _rpc('bridgepoint_insurance_roof_wind_v509', {
        'p_state_code': stateCode,
        'p_gust_mph': gustMph,
        'p_roof_age_years': roofAgeYears,
        'p_roof_condition_score': roofConditionScore,
        'p_tree_exposure_score': treeExposureScore,
        'p_prior_damage_score': priorDamageScore,
        'p_roof_shape': roofShape,
        'p_roof_material': roofMaterial,
      });

  Future<Map<String, dynamic>> leaseOptimization({
    required double currentRent,
    required double marketMedianRent,
    required double occupancyRate,
    required double daysVacant,
    double leadVelocityIndex = 1,
    double renewalProbability = 0.5,
  }) =>
      _rpc('bridgepoint_lease_optimization_v509', {
        'p_current_rent': currentRent,
        'p_market_median_rent': marketMedianRent,
        'p_occupancy_rate': occupancyRate,
        'p_days_vacant': daysVacant,
        'p_lead_velocity_index': leadVelocityIndex,
        'p_renewal_probability': renewalProbability,
      });

  Future<Map<String, dynamic>> buildingAutomation({
    required double occupancyRate,
    required double indoorTempF,
    required double outdoorTempF,
    required double humidityPct,
    required double runtimeRatio,
    int activeFaults = 0,
    double tariffIndex = 1,
  }) =>
      _rpc('bridgepoint_building_automation_v509', {
        'p_occupancy_rate': occupancyRate,
        'p_indoor_temp_f': indoorTempF,
        'p_outdoor_temp_f': outdoorTempF,
        'p_humidity_pct': humidityPct,
        'p_runtime_ratio': runtimeRatio,
        'p_active_faults': activeFaults,
        'p_tariff_index': tariffIndex,
      });
}
