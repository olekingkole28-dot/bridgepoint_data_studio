import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_property_dossier_recovered_v4.dart' as recovered_v4;

/// Recovery V5 adds current map imagery context without caching or claiming
/// ownership of third-party basemap imagery. Historical/detailed media still
/// comes from BridgePoint's separate verified property-media pipelines.
class BridgePointPropertyDossierV2 extends StatefulWidget {
  const BridgePointPropertyDossierV2({
    super.key,
    required this.propertyId,
    required this.seed,
    this.asPage = false,
  });

  final String propertyId;
  final Map<String, dynamic> seed;
  final bool asPage;

  @override
  State<BridgePointPropertyDossierV2> createState() =>
      _BridgePointPropertyDossierRecoveryV5State();
}

class _BridgePointPropertyDossierRecoveryV5State
    extends State<BridgePointPropertyDossierV2> {
  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);
  static const _amber = Color(0xFFFFC95E);

  late Future<_VisualContext?> _context;

  @override
  void initState() {
    super.initState();
    _context = _loadContext();
  }

  @override
  void didUpdateWidget(covariant BridgePointPropertyDossierV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.propertyId != widget.propertyId) {
      _context = _loadContext();
    }
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Future<_VisualContext?> _loadContext() async {
    var property = Map<String, dynamic>.from(widget.seed);
    var lat = _double(property['latitude'] ?? property['lat']);
    var lng = _double(property['longitude'] ?? property['lng'] ?? property['lon']);

    if (lat == null || lng == null) {
      try {
        final raw = await Supabase.instance.client.rpc(
          'bridgepoint_flutter_property_detail_v344',
          params: {'p_property_id': widget.propertyId},
        );
        final detail = _map(raw);
        final nested = _map(detail['property']);
        if (nested.isNotEmpty) property = {...property, ...nested};
        lat = _double(property['latitude']);
        lng = _double(property['longitude']);
      } catch (_) {
        return null;
      }
    }

    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }

    final address = '${property['full_address'] ?? property['address'] ?? ''}'.trim();
    return _VisualContext(
      point: LatLng(lat, lng),
      label: address.isEmpty ? 'Property imagery context' : address,
    );
  }

  Future<void> _openImagery(_VisualContext visual) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF040B14),
      barrierColor: Colors.black.withValues(alpha: .74),
      builder: (context) => FractionallySizedBox(
        heightFactor: .90,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.satellite_alt_rounded, color: _cyan),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current imagery context',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visual.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: visual.point,
                        initialZoom: 18,
                        minZoom: 3,
                        maxZoom: 20,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'com.bridgepoint.intelligence',
                          maxNativeZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: visual.point,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xDD071321),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _cyan, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cyan.withValues(alpha: .28),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.home_work_rounded, color: _cyan),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xE6071321),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: .12)),
                        ),
                        child: const Text(
                          'Current visual context only — not BridgePoint-owned imagery and not proof of condition or damage. Source/attribution: Esri World Imagery; Esri, Vantor, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, OpenStreetMap contributors, TomTom, Garmin, FAO, NOAA and the GIS User Community. Data providers vary by location.',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, height: 1.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                color: const Color(0xFF071321),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: _amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Historical/datetime aerials, BridgePoint-linked street imagery and property-specific media remain separate evidence sources. This live basemap is only orientation and present-day visual context.',
                        style: TextStyle(color: _amber, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        recovered_v4.BridgePointPropertyDossierV2(
          propertyId: widget.propertyId,
          seed: widget.seed,
          asPage: widget.asPage,
        ),
        Positioned(
          right: 16,
          bottom: 92,
          child: SafeArea(
            top: false,
            child: FutureBuilder<_VisualContext?>(
              future: _context,
              builder: (context, snapshot) {
                final visual = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 42,
                    height: 42,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (visual == null) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  heroTag: 'property-current-imagery-${widget.propertyId}',
                  onPressed: () => _openImagery(visual),
                  backgroundColor: const Color(0xEE0B1B2C),
                  foregroundColor: _cyan,
                  elevation: 8,
                  icon: const Icon(Icons.satellite_alt_rounded),
                  label: const Text(
                    'Current imagery',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _VisualContext {
  const _VisualContext({required this.point, required this.label});
  final LatLng point;
  final String label;
}
