from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

old_preview="""                                Image.network(
                                  'https://radar.weather.gov/ridge/standard/NORTHEAST_loop.gif?bp=$_radarRevision',
                                  fit:BoxFit.cover,gaplessPlayback:true,
                                  errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.radar_rounded,color:AppTheme.cyan)),
                                ),
"""
new_preview="""                                FlutterMap(
                                  options:const MapOptions(
                                    initialCenter:LatLng(42.05,-72.75),
                                    initialZoom:5.2,
                                    interactionOptions:InteractionOptions(flags:InteractiveFlag.none),
                                  ),
                                  children:[
                                    TileLayer(
                                      urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:'com.bridgepoint.data_studio',
                                    ),
                                    TileLayer(
                                      key:ValueKey('noaa-radar-preview-$_radarRevision'),
                                      wmsOptions:WMSTileLayerOptions(
                                        baseUrl:'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?_bp=$_radarRevision&',
                                        layers:const ['conus_bref_qcd'],
                                        format:'image/png',
                                        transparent:true,
                                        version:'1.3.0',
                                      ),
                                      maxNativeZoom:12,
                                      userAgentPackageName:'com.bridgepoint.data_studio',
                                    ),
                                  ],
                                ),
"""
if old_preview not in text:
    raise SystemExit('radar preview image block missing')
text=text.replace(old_preview,new_preview,1)

old_modal="""        Expanded(child:InteractiveViewer(
          minScale:.8,maxScale:7,boundaryMargin:const EdgeInsets.all(120),
          child:Center(child:Image.network(
            'https://radar.weather.gov/ridge/standard/NORTHEAST_loop.gif?bp=$revision',
            fit:BoxFit.contain,gaplessPlayback:true,
            errorBuilder:(_,__,___)=>const _InlineError(message:'The animated NOAA radar loop is temporarily unavailable.'),
          )),
        )),
"""
new_modal="""        Expanded(child:ClipRRect(
          borderRadius:BorderRadius.circular(12),
          child:FlutterMap(
            options:const MapOptions(
              initialCenter:LatLng(42.05,-72.75),
              initialZoom:6.0,
              minZoom:3,
              maxZoom:14,
            ),
            children:[
              TileLayer(
                urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:'com.bridgepoint.data_studio',
              ),
              TileLayer(
                key:ValueKey('noaa-radar-dialog-$revision'),
                wmsOptions:WMSTileLayerOptions(
                  baseUrl:'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?_bp=$revision&',
                  layers:const ['conus_bref_qcd'],
                  format:'image/png',
                  transparent:true,
                  version:'1.3.0',
                ),
                maxNativeZoom:12,
                userAgentPackageName:'com.bridgepoint.data_studio',
              ),
            ],
          ),
        )),
"""
if old_modal not in text:
    raise SystemExit('radar modal image block missing')
text=text.replace(old_modal,new_modal,1)

text=text.replace('LIVE NOAA LOOP • TAP TO ZOOM','LIVE NOAA RADAR • TAP TO ZOOM')
text=text.replace('Animated NOAA Radar Loop','Live NOAA Radar')
text=text.replace('Official Northeast radar loop. The main map keeps the georeferenced MRMS current layer underneath.','Official georeferenced NOAA/NWS reflectivity. Pan and zoom without relying on a separate animated GIF endpoint.')

for needle in ['LIVE NOAA RADAR • TAP TO ZOOM','noaa-radar-preview-','noaa-radar-dialog-']:
    if needle not in text:
        raise SystemExit(f'missing radar v177 marker: {needle}')
if 'NORTHEAST_loop.gif' in text:
    raise SystemExit('legacy NOAA GIF dependency still present')
if text==original:
    raise SystemExit('no radar v177 changes applied')
path.write_text(text,encoding='utf-8')
print('Replaced fragile NOAA GIF loop with live WMS radar v177')
