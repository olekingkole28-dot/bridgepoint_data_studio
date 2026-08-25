import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() => _BridgePointMapWeatherV2State();
}

class _BridgePointMapWeatherV2State extends State<BridgePointMapWeatherV2> {
  bool radar = true;
  bool satellite = true;
  bool playing = true;
  int frame = 48;
  Timer? timer;

  List<DateTime> get frames {
    final now = DateTime.now().toUtc();
    final rounded = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 5) * 5,
    );
    return List.generate(
      49,
      (i) => rounded.subtract(Duration(minutes: (48 - i) * 5)),
    );
  }

  DateTime get radarTime => frames[frame.clamp(0, 48)];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (mounted && radar && playing) {
        setState(() => frame = frame >= 48 ? 0 : frame + 1);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.hour}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height.clamp(520.0, 820.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Geospatial Intelligence',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'One map for weather, imagery, parcels, buildings, risks and intelligence. Provider layers stay source-aware and permission-aware instead of being treated as anonymous tiles.',
          style: TextStyle(color: Color(0xFF8FA5BF), height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: satellite,
              label: const Text('Satellite'),
              avatar: const Icon(Icons.satellite_alt_outlined, size: 18),
              onSelected: (value) => setState(() => satellite = value),
            ),
            FilterChip(
              selected: radar,
              label: const Text('NOAA radar'),
              avatar: const Icon(Icons.radar_rounded, size: 18),
              onSelected: (value) => setState(() => radar = value),
            ),
            ActionChip(
              avatar: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(playing ? 'Pause weather' : 'Play weather'),
              onPressed: () => setState(() => playing = !playing),
            ),
            const Chip(
              avatar: Icon(Icons.layers_outlined, size: 18),
              label: Text('Premium aerial / 3D via licensed connectors'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(39.5, -98.35),
                    initialZoom: 4,
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: satellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bridgepoint.data_studio',
                      maxNativeZoom: 19,
                    ),
                    if (satellite)
                      TileLayer(
                        urlTemplate:
                            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (radar)
                      TileLayer(
                        key: ValueKey(
                          'bp-radar-${radarTime.millisecondsSinceEpoch}',
                        ),
                        wmsOptions: WMSTileLayerOptions(
                          baseUrl:
                              'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                          layers: const ['0'],
                          format: 'image/png',
                          transparent: true,
                          version: '1.3.0',
                          otherParameters: {
                            'TIME': radarTime.toUtc().toIso8601String(),
                          },
                        ),
                        maxNativeZoom: 10,
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('NOAA / NWS MRMS'),
                        TextSourceAttribution('Esri / OpenStreetMap'),
                      ],
                    ),
                  ],
                ),
                if (radar)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      color: const Color(0xEE071321),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'NOAA MRMS • ~1 KM SOURCE',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF35D2E8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Slider(
                                    value: frame.toDouble(),
                                    min: 0,
                                    max: 48,
                                    divisions: 48,
                                    onChanged: (value) => setState(() {
                                      playing = false;
                                      frame = value.round();
                                    }),
                                  ),
                                ),
                                Text(
                                  _clock(radarTime),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Four-hour time-enabled radar • about 5-minute frames • raw reflectivity is regional weather context, not roof-level proof. Deep property zoom should rely on matched storm/event evidence, not stretched radar pixels.',
                              style: TextStyle(
                                color: Color(0xFF8FA5BF),
                                fontSize: 8.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Premium layer contract: Nearmap, EagleView, LiDAR/DSM, historical aerial, parcel/building geometry, roof/site change, zoning, infrastructure and hazard layers are enabled only when provider rights, resolution, coverage and readiness are verified.',
              style: TextStyle(color: Color(0xFF8FA5BF), fontSize: 10, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}
