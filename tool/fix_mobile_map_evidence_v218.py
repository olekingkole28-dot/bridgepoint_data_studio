from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
original=s
edits=0

def once(old,new,label):
    global s,edits
    n=s.count(old)
    if n!=1:
        raise SystemExit(f'{label}: expected 1 match, found {n}')
    s=s.replace(old,new,1)
    edits+=1

# ---------------------------------------------------------------------------
# Customer-facing evidence: never pretty-print raw evidence_summary JSON.
# ---------------------------------------------------------------------------
anchor='class _JsonIntelligenceList extends StatelessWidget {'
if anchor not in s:
    raise SystemExit('Missing JSON intelligence renderer anchor')

if '_bridgePointReadableEvidenceV218' not in s:
    helper=r'''bool _bridgePointInternalLookingTextV218(String value){
  final v=value.toLowerCase().trim();
  const blocked=[
    'case when','coalesce(','greatest(','least(','jsonb_','::numeric','::text',
    'score_breakdown','component_score','raw_positive','raw_negative','formula',
    'rule_expression','model_definition','detector_definition','weight=',
    'coefficient','dedupe_key','storage_mode','matching_precision',
  ];
  return blocked.any(v.contains) ||
      (v.startsWith('{')&&v.endsWith('}')) ||
      (v.startsWith('[')&&v.endsWith(']'));
}

String _bridgePointFriendlyLabelV218(dynamic value){
  final raw='${value??''}'.trim();
  if(raw.isEmpty)return '';
  return raw.replaceAll('_',' ').toLowerCase().split(' ').where((p)=>p.isNotEmpty).map((p)=>p.length<3?p:'${p[0].toUpperCase()}${p.substring(1)}').join(' ');
}

String _bridgePointReadableEvidenceV218(Map<String,dynamic> signal){
  final title='${signal['signal_name']??signal['title']??'Property signal'}'.trim();
  final description='${signal['description']??''}'.trim();
  if(description.isNotEmpty&&!_bridgePointInternalLookingTextV218(description))return description;

  final raw=signal['evidence_summary'];
  if(raw is String){
    final text=raw.trim();
    if(text.isNotEmpty&&!_bridgePointInternalLookingTextV218(text))return text;
  }
  final evidence=raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};
  final provider=_bridgePointFriendlyLabelV218(evidence['provider']??evidence['source']??signal['source_name']??signal['signal_family']);
  final precision='${evidence['matching_precision']??''}'.toUpperCase();
  final storage='${evidence['storage_mode']??''}'.toLowerCase();
  final contextual=precision.startsWith('AREA_')||storage.contains('area_context');
  final geos=evidence['geography_types'];
  final geo=geos is List&&geos.isNotEmpty?_bridgePointFriendlyLabelV218(geos.first):'';
  final records=(evidence['area_source_records']??evidence['source_record_count']??evidence['supporting_rows']??evidence['event_count']??evidence['exposure_count']) as num?;
  final amount=(evidence['area_monetary_total']??evidence['total_reported_loss']??evidence['total_incentive_amount']??evidence['total_system_cost']) as num?;
  final distance=(evidence['nearest_distance_meters']) as num?;
  final first='${evidence['first_event_at']??evidence['first_recorded_at']??evidence['first_exposure_at']??evidence['first_release_at']??''}'.trim();
  final latest='${evidence['latest_event_at']??evidence['latest_recorded_at']??evidence['latest_exposure_at']??evidence['latest_release_at']??''}'.trim();

  final parts=<String>[];
  if(contextual){
    parts.add('$title was found in ${geo.isEmpty?'surrounding-area':geo} records${provider.isEmpty?'':' from $provider'}. This is area-level context and does not mean the event or claim occurred at this individual property.');
  }else{
    parts.add('BridgePoint linked $title to this property${provider.isEmpty?'':' using $provider records'}.');
  }
  if(records!=null&&records>0)parts.add('${records.toInt()} supporting source record${records.toInt()==1?'':'s'} were found.');
  if(distance!=null&&distance>=0)parts.add('Nearest supporting activity was about ${distance<1000?'${distance.round()} m':'${(distance/1609.344).toStringAsFixed(1)} mi'} away.');
  if(amount!=null&&amount>0&&contextual)parts.add('The surrounding records report about \$${amount.toStringAsFixed(0)} in associated activity; this is not a property-level loss amount.');
  if(first.isNotEmpty&&latest.isNotEmpty&&first!=latest)parts.add('Supporting activity spans ${first.split('T').first} through ${latest.split('T').first}.');
  else if(latest.isNotEmpty)parts.add('Latest supporting activity: ${latest.split('T').first}.');
  if(parts.length==1)parts.add('Open the property timeline to review timing, source, match quality, and limitations.');
  return parts.join(' ');
}

bool _bridgePointCustomerSafeValueV218(dynamic value){
  if(value==null)return false;
  final text='$value'.trim();
  return text.isNotEmpty&&!_bridgePointInternalLookingTextV218(text);
}

'''
    s=s.replace(anchor,helper+anchor,1)
    edits+=1

old_evidence="""  final evidence = signal['evidence_summary'];
  final evidenceText = evidence is Map
      ? const JsonEncoder.withIndent('  ').convert(evidence)
      : (evidence?.toString() ?? 'No evidence summary.');
"""
new_evidence="""  final evidenceText = _bridgePointReadableEvidenceV218(signal);
"""
once(old_evidence,new_evidence,'raw evidence JSON dialog')

# Existing v193 blocks dangerous keys. v218 also blocks formula-looking scalar values.
old_filter="""          return _bridgePointCustomerSafeKey(entry.key) &&
              value != null &&
              '$value'.trim().isNotEmpty &&
              value is! Map &&
              value is! List;
"""
new_filter="""          return _bridgePointCustomerSafeKey(entry.key) &&
              _bridgePointCustomerSafeValueV218(value) &&
              value is! Map &&
              value is! List;
"""
once(old_filter,new_filter,'generic customer-safe value filter')

# ---------------------------------------------------------------------------
# Mobile map: fewer expensive markers, no automatic weather animation, no
# decorative scan animation, and a gesture set tuned for touch screens.
# ---------------------------------------------------------------------------
old_fields="""  String _visibleLayer=_displayPreferences.value.simplifiedViews?'opportunities':'both';
  bool _showRadar=true;
  bool _showClouds=true;
"""
new_fields="""  String _visibleLayer=_displayPreferences.value.simplifiedViews?'opportunities':'both';
  bool _showRadar=true;
  bool _showClouds=true;
  bool _compactMapV218=false;
  bool _mobileDefaultsAppliedV218=false;
"""
once(old_fields,new_fields,'mobile map fields')

init_anchor="""  @override
  void initState() {
    super.initState();
"""
mobile_lifecycle="""  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    final compact=MediaQuery.sizeOf(context).width<700;
    _compactMapV218=compact;
    if(compact&&!_mobileDefaultsAppliedV218){
      _mobileDefaultsAppliedV218=true;
      _visibleLayer='opportunities';
      _showRadar=false;
      _showClouds=false;
      _showExpansion=false;
      _radarPlaying=false;
    }
  }

  @override
  void initState() {
    super.initState();
"""
# Only patch the intelligence map class's initState: insert after unique fields block.
pos=s.find(new_fields)
if pos<0: raise SystemExit('Map field block disappeared after replacement')
init_pos=s.find(init_anchor,pos)
if init_pos<0: raise SystemExit('Map initState anchor missing')
s=s[:init_pos]+mobile_lifecycle+s[init_pos+len(init_anchor):]
edits+=1

once("if(_visibleLayer!='signals')for (final point in points) {","if(_visibleLayer!='signals')for (final point in (_compactMapV218?points.take(140):points)) {",'mobile opportunity marker cap')
once("if(_visibleLayer!='opportunities')for(final signal in signalPoints){","if(_visibleLayer!='opportunities')for(final signal in (_compactMapV218?signalPoints.take(50):signalPoints)){",'mobile signal marker cap')

old_options="""                        options: const MapOptions(
                          initialCenter: LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 4,
                          maxZoom: 18,
                          interactionOptions: InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom,
                          ),
                        ),
"""
new_options="""                        options: MapOptions(
                          initialCenter: const LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 4,
                          maxZoom: 18,
                          interactionOptions: InteractionOptions(
                            flags: _compactMapV218
                                ? (InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom)
                                : (InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom),
                          ),
                        ),
"""
once(old_options,new_options,'touch map interaction options')

once("if(!loading&&!_displayPreferences.value.reducedMotion)const Positioned.fill(child:IgnorePointer(child:_MapScanOverlay())),","if(!loading&&!_compactMapV218&&!_displayPreferences.value.reducedMotion)const Positioned.fill(child:IgnorePointer(child:_MapScanOverlay())),",'disable mobile scan animation')

# Make the main basemap less eager to retain offscreen tiles on constrained devices.
base_tile="""                          TileLayer(
                            urlTemplate: _bridgePointBaseMapUrl(),
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
"""
if base_tile in s:
    s=s.replace(base_tile,"""                          TileLayer(
                            urlTemplate: _bridgePointBaseMapUrl(),
                            panBuffer:_compactMapV218?0:1,
                            keepBuffer:_compactMapV218?1:2,
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
""",1)
    edits+=1

marker="const String _bridgePointV217ClarityMarker='bridgepoint-v217-cloud-clarity';"
if marker in s:
    s=s.replace(marker,"const String _bridgePointV218MobileEvidenceMarker='bridgepoint-v218-mobile-map-readable-evidence';\n"+marker,1)
    edits+=1
else:
    # v217 marker is created by the immediately preceding release script; fail if missing.
    raise SystemExit('Missing v217 release marker')

for required in [
  '_bridgePointReadableEvidenceV218',
  '_compactMapV218?points.take(140):points',
  '_compactMapV218?signalPoints.take(50):signalPoints',
  "_showRadar=false;\n      _showClouds=false;",
  'bridgepoint-v218-mobile-map-readable-evidence',
]:
    if required not in s: raise SystemExit(f'Missing v218 guard: {required}')

if s==original: raise SystemExit('No v218 changes applied')
p.write_text(s,encoding='utf-8')
print(f'Applied BridgePoint v218 mobile map + readable evidence repair ({edits} guarded edits).')
