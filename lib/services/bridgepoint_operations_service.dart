import 'package:supabase_flutter/supabase_flutter.dart';

/// Typed client for BridgePoint's operational intelligence surface.
///
/// The database remains authoritative for authentication, entitlements,
/// organization tenancy, state access, consent, human-review gates and
/// proprietary model/data boundaries.
class BridgePointOperationsService {
  BridgePointOperationsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _rpc(
    String functionName, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) async {
    final dynamic result = await _client.rpc(functionName, params: params);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('Unexpected BridgePoint response.');
  }

  Future<Map<String, dynamic>> addPreStormClient({
    required String propertyId,
    required String phoneE164,
    String? clientName,
    String relationshipType = 'PAST_CLIENT',
    Map<String, dynamic> roofProfile = const <String, dynamic>{},
    String localTimezone = 'America/New_York',
  }) =>
      _rpc('bridgepoint_prestorm_upsert_client_v520', {
        'p_property_id': propertyId,
        'p_phone_e164': phoneE164,
        'p_client_name': clientName,
        'p_relationship_type': relationshipType,
        'p_roof_profile': roofProfile,
        'p_local_timezone': localTimezone,
      });

  Future<Map<String, dynamic>> recordPreStormConsent({
    required String phoneE164,
    required String sellerIdentity,
    required String consentStatus,
    required String consentSource,
    required String exactConsentText,
  }) =>
      _rpc('bridgepoint_prestorm_record_consent_v520', {
        'p_phone_e164': phoneE164,
        'p_seller_identity': sellerIdentity,
        'p_consent_status': consentStatus,
        'p_consent_source': consentSource,
        'p_consent_text': exactConsentText,
      });

  Future<Map<String, dynamic>> microHailScore({
    required String propertyId,
    required double meshMm,
    double nativeResolutionM = 1000,
    double roofExposure = 0.5,
    double windAlignment = 0.5,
    double localValidation = 0.5,
  }) =>
      _rpc('bridgepoint_micro_hail_score_v519', {
        'p_property_id': propertyId,
        'p_mesh_mm': meshMm,
        'p_native_resolution_m': nativeResolutionM,
        'p_roof_exposure': roofExposure,
        'p_wind_alignment': windAlignment,
        'p_local_validation': localValidation,
      });

  Future<Map<String, dynamic>> createThermalScan({
    required String propertyId,
    required String capturePlatform,
    required DateTime capturedAt,
    String? cameraMakeModel,
    bool radiometric = false,
    double? ambientTempC,
    double? referenceTempC,
    double? humidityPct,
    double? windMps,
    String? solarLoadingContext,
    String? roofSystem,
    double? spatialResolutionCm,
    String calibrationStatus = 'UNVERIFIED',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) =>
      _rpc('bridgepoint_create_thermal_scan_v520', {
        'p_property_id': propertyId,
        'p_capture_platform': capturePlatform,
        'p_captured_at': capturedAt.toUtc().toIso8601String(),
        'p_camera_make_model': cameraMakeModel,
        'p_radiometric': radiometric,
        'p_ambient_temp_c': ambientTempC,
        'p_reference_temp_c': referenceTempC,
        'p_humidity_pct': humidityPct,
        'p_wind_mps': windMps,
        'p_solar_loading_context': solarLoadingContext,
        'p_roof_system': roofSystem,
        'p_spatial_resolution_cm': spatialResolutionCm,
        'p_calibration_status': calibrationStatus,
        'p_metadata': metadata,
      });

  Future<Map<String, dynamic>> assessThermalMoisture({
    required String propertyId,
    required double deltaTempC,
    required bool radiometric,
    required bool calibrated,
    double? windMps,
    double? humidityPct,
    double? confirmedMoisturePct,
  }) =>
      _rpc('bridgepoint_thermal_moisture_assess_v519', {
        'p_property_id': propertyId,
        'p_delta_temp_c': deltaTempC,
        'p_radiometric': radiometric,
        'p_calibrated': calibrated,
        'p_wind_mps': windMps,
        'p_humidity_pct': humidityPct,
        'p_confirmed_moisture_pct': confirmedMoisturePct,
      });

  Future<Map<String, dynamic>> propertyHealth(String propertyId) =>
      _rpc('bridgepoint_property_health_v519', {
        'p_property_id': propertyId,
      });

  Future<Map<String, dynamic>> createReconstruction({
    required String propertyId,
    List<String> requestedOutputs = const <String>['DXF', 'IFC'],
    List<String> sourceTypes = const <String>['DRONE_IMAGERY'],
    bool rtkEnabled = false,
    int gcpCount = 0,
    bool lidarAvailable = false,
    double? groundSampleDistanceCm,
    double? forwardOverlapPct,
    double? sideOverlapPct,
    double? controlRmsCm,
    String? coordinateReferenceSystem,
    String? verticalDatum,
  }) =>
      _rpc('bridgepoint_create_reconstruction_v520', {
        'p_property_id': propertyId,
        'p_requested_outputs': requestedOutputs,
        'p_source_types': sourceTypes,
        'p_rtk_enabled': rtkEnabled,
        'p_gcp_count': gcpCount,
        'p_lidar_available': lidarAvailable,
        'p_gsd_cm': groundSampleDistanceCm,
        'p_forward_overlap_pct': forwardOverlapPct,
        'p_side_overlap_pct': sideOverlapPct,
        'p_control_rms_cm': controlRmsCm,
        'p_crs': coordinateReferenceSystem,
        'p_vertical_datum': verticalDatum,
      });

  Future<Map<String, dynamic>> reassessReconstruction(String jobId) =>
      _rpc('bridgepoint_reconstruction_assess_v519', {
        'p_reconstruction_job_id': jobId,
      });

  Future<Map<String, dynamic>> createDroneDispatch({
    required String propertyId,
    required String jobType,
    String urgency = 'STANDARD',
    DateTime? targetStartAt,
    List<String> requiredCapabilities = const <String>[],
    Map<String, dynamic> captureSpec = const <String, dynamic>{},
    double? budgetAmount,
  }) =>
      _rpc('bridgepoint_create_drone_dispatch_v520', {
        'p_property_id': propertyId,
        'p_job_type': jobType,
        'p_urgency': urgency,
        'p_target_start_at': targetStartAt?.toUtc().toIso8601String(),
        'p_required_capabilities': requiredCapabilities,
        'p_capture_spec': captureSpec,
        'p_budget_amount': budgetAmount,
      });

  Future<Map<String, dynamic>> supplementGaps(String claimId) =>
      _rpc('bridgepoint_supplement_gap_v519', {
        'p_claim_id': claimId,
      });

  Future<Map<String, dynamic>> createSupplementPacket(String claimId) =>
      _rpc('bridgepoint_create_supplement_packet_v520', {
        'p_claim_id': claimId,
      });

  Future<Map<String, dynamic>> createIoTIntegration({
    required String providerName,
    required String protocol,
    List<String> allowedMeasurements = const <String>[],
    Map<String, dynamic> retentionPolicy = const <String, dynamic>{},
  }) =>
      _rpc('bridgepoint_iot_create_integration_v519', {
        'p_provider_name': providerName,
        'p_protocol': protocol,
        'p_allowed_measurements': allowedMeasurements,
        'p_retention_policy': retentionPolicy,
      });

  Future<Map<String, dynamic>> registerIoTDevice({
    required String integrationId,
    required String propertyId,
    required String externalDeviceId,
    required String deviceType,
    String? manufacturer,
    String? model,
    String? locationLabel,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) =>
      _rpc('bridgepoint_iot_register_device_v519', {
        'p_integration_id': integrationId,
        'p_property_id': propertyId,
        'p_external_device_id': externalDeviceId,
        'p_device_type': deviceType,
        'p_manufacturer': manufacturer,
        'p_model': model,
        'p_location_label': locationLabel,
        'p_metadata': metadata,
      });

  Future<Map<String, dynamic>> draftMaterialPurchaseOrder({
    required String quoteId,
    required Map<String, dynamic> shipTo,
    String? deliveryInstructions,
  }) =>
      _rpc('bridgepoint_material_po_draft_v519', {
        'p_quote_id': quoteId,
        'p_ship_to': shipTo,
        'p_delivery_instructions': deliveryInstructions,
      });

  Future<Map<String, dynamic>> createEvidenceScene({
    required String propertyId,
    String? claimId,
    Map<String, dynamic> sourceManifest = const <String, dynamic>{},
    Map<String, dynamic> timelineManifest = const <String, dynamic>{},
    Map<String, dynamic> uncertaintyManifest = const <String, dynamic>{},
    String? coordinateReferenceSystem,
  }) =>
      _rpc('bridgepoint_create_evidence_scene_v520', {
        'p_property_id': propertyId,
        'p_claim_id': claimId,
        'p_source_manifest': sourceManifest,
        'p_timeline_manifest': timelineManifest,
        'p_uncertainty_manifest': uncertaintyManifest,
        'p_crs': coordinateReferenceSystem,
      });

  Future<Map<String, dynamic>> sealEvidenceScene(String sceneId) =>
      _rpc('bridgepoint_evidence_scene_seal_v519', {
        'p_scene_id': sceneId,
      });

  Future<Map<String, dynamic>> authorizeCarrierPacket({
    required String carrierPacketId,
    bool autoFollowup = true,
  }) =>
      _rpc('bridgepoint_authorize_carrier_packet_v520', {
        'p_carrier_packet_id': carrierPacketId,
        'p_auto_followup': autoFollowup,
      });
}
