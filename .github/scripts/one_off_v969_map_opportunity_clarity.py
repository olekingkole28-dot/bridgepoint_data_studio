from pathlib import Path
import re

map_path = Path('lib/v2/bridgepoint_map_weather_v2.dart')
src = map_path.read_text(encoding='utf-8')

icon_pattern = r"^  IconData _opportunityIcon\(Map<String, dynamic> row\) \{.*$"
icon_replacement = r'''  String _categoryText(Map<String, dynamic> row) => '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''} ${row['model_key'] ?? ''}'.toLowerCase();
  String _signalText(Map<String, dynamic> row) => '${row['signal_type'] ?? ''} ${row['signal_key'] ?? ''} ${row['event_type'] ?? ''} ${row['title'] ?? ''} ${row['description'] ?? ''}'.toLowerCase();

  IconData _categoryIconFromText(String text) {
    if (text.contains('roof')) return Icons.roofing_rounded;
    if (text.contains('storm') || text.contains('hail') || text.contains('wind') || text.contains('weather')) return Icons.thunderstorm_rounded;
    if (text.contains('fire') || text.contains('smoke')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) return Icons.water_drop_rounded;
    if (text.contains('solar')) return Icons.solar_power_rounded;
    if (text.contains('sale') || text.contains('transfer') || text.contains('owner') || text.contains('deed')) return Icons.key_rounded;
    if (text.contains('invest') || text.contains('distress') || text.contains('foreclos')) return Icons.real_estate_agent_rounded;
    if (text.contains('develop') || text.contains('construction')) return Icons.construction_rounded;
    if (text.contains('permit') || text.contains('code')) return Icons.fact_check_outlined;
    if (text.contains('environment') || text.contains('spill') || text.contains('tank')) return Icons.eco_rounded;
    if (text.contains('claim') || text.contains('insurance')) return Icons.shield_outlined;
    if (text.contains('utility') || text.contains('infrastructure')) return Icons.electrical_services_rounded;
    return Icons.location_on_rounded;
  }

  String _categoryLabelFromText(String text) {
    if (text.contains('roof')) return 'Roofing';
    if (text.contains('storm') || text.contains('hail') || text.contains('wind') || text.contains('weather')) return 'Storm / hail / wind';
    if (text.contains('fire') || text.contains('smoke')) return 'Fire';
    if (text.contains('flood') || text.contains('water')) return 'Flood / water';
    if (text.contains('solar')) return 'Solar';
    if (text.contains('sale') || text.contains('transfer') || text.contains('owner') || text.contains('deed')) return 'Ownership / sale';
    if (text.contains('invest') || text.contains('distress') || text.contains('foreclos')) return 'Investment / distress';
    if (text.contains('develop') || text.contains('construction')) return 'Development';
    if (text.contains('permit') || text.contains('code')) return 'Permit / code';
    if (text.contains('environment') || text.contains('spill') || text.contains('tank')) return 'Environmental';
    if (text.contains('claim') || text.contains('insurance')) return 'Claims / insurance';
    if (text.contains('utility') || text.contains('infrastructure')) return 'Infrastructure';
    return 'Other property intelligence';
  }

  IconData _opportunityIcon(Map<String, dynamic> row) => _categoryIconFromText(_categoryText(row));
  String _opportunityLabel(Map<String, dynamic> row) => _categoryLabelFromText(_categoryText(row));
  IconData _signalIcon(Map<String, dynamic> row) => _categoryIconFromText(_signalText(row));
  String _signalLabel(Map<String, dynamic> row) => _categoryLabelFromText(_signalText(row));

  String _propertyLabel(Map<String, dynamic> row) {
    final address = '${row['full_address'] ?? ''}'.trim();
    final location = '${row['location_label'] ?? ''}'.trim();
    final parcel = '${row['parcel_number'] ?? ''}'.trim();
    final type = '${row['property_type_display'] ?? row['property_type'] ?? ''}'.trim();
    final owner = '${row['current_owner_name'] ?? ''}'.trim();
    final lines = <String>[
      if (address.isNotEmpty) address else if (location.isNotEmpty) location else 'Street address unavailable',
      if (type.isNotEmpty) type,
      if (owner.isNotEmpty) 'Owner: $owner',
      if (parcel.isNotEmpty) 'Parcel: $parcel',
    ];
    return lines.join('\n');
  }'''
src, n = re.subn(icon_pattern, icon_replacement, src, count=1, flags=re.M)
assert n == 1, f'opportunity icon helper replacement count={n}'

property_marker = r'''  List<Marker> _propertyMarkers() => _properties.map((row) { final lat=_double(row['latitude']); final lng=_double(row['longitude']); if(lat==null||lng==null)return null; return Marker(point:LatLng(lat,lng),width:28,height:28,child:Tooltip(message:_propertyLabel(row),child:Container(decoration:BoxDecoration(color:const Color(0xEA071321),borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.white,width:1.2)),child:const Icon(Icons.home_rounded,size:15,color:Colors.white)))); }).whereType<Marker>().toList();'''
src, n = re.subn(r'^  List<Marker> _propertyMarkers\(\) => .*$', property_marker, src, count=1, flags=re.M)
assert n == 1, f'property marker replacement count={n}'

signal_marker = r'''  List<Marker> _signalMarkers() => _signals.map((row) { final lat=_double(row['latitude']); final lng=_double(row['longitude']); if(lat==null||lng==null)return null; final label=_signalLabel(row); return Marker(point:LatLng(lat,lng),width:28,height:28,child:Tooltip(message:'Supporting signal • $label',child:Container(decoration:BoxDecoration(color:const Color(0xF2071321),shape:BoxShape.circle,border:Border.all(color:_cyan,width:1.5)),child:Icon(_signalIcon(row),color:_cyan,size:15)))); }).whereType<Marker>().toList();'''
src, n = re.subn(r'^  List<Marker> _signalMarkers\(\) => .*$', signal_marker, src, count=1, flags=re.M)
assert n == 1, f'signal marker replacement count={n}'

opportunity_marker = r'''  List<Marker> _opportunityMarkers() => _opportunities.map((row) { final lat=_double(row['latitude']); final lng=_double(row['longitude']); if(lat==null||lng==null)return null; final color=_opportunityColor(row); final label=_opportunityLabel(row); final address='${row['full_address'] ?? row['location_label'] ?? row['title'] ?? 'Property'}'; return Marker(point:LatLng(lat,lng),width:40,height:40,child:Tooltip(message:'Opportunity • $label\n$address',child:Container(decoration:BoxDecoration(color:const Color(0xF5071321),borderRadius:BorderRadius.circular(12),border:Border.all(color:color,width:2.2),boxShadow:[BoxShadow(color:color.withValues(alpha:.22),blurRadius:9)]),child:Icon(_opportunityIcon(row),color:color,size:21)))); }).whereType<Marker>().toList();'''
src, n = re.subn(r'^  List<Marker> _opportunityMarkers\(\) => .*$', opportunity_marker, src, count=1, flags=re.M)
assert n == 1, f'opportunity marker replacement count={n}'

src = src.replace("FilterChip(selected:opportunities,label:const Text('Opportunities'),avatar:const Icon(Icons.location_searching_rounded,size:16)", "FilterChip(selected:opportunities,label:const Text('Opportunities'),avatar:const Icon(Icons.stars_rounded,size:16)")
src = src.replace("FilterChip(selected:signals,label:const Text('Signals'),avatar:const Icon(Icons.bolt_rounded,size:16)", "FilterChip(selected:signals,label:const Text('Signals'),avatar:const Icon(Icons.sensors_rounded,size:16)")
src = src.replace("Text('🏠 Property  •  ◈ Opportunity  •  ⚡ Signal',style:TextStyle(fontSize:9.5))", "Text('House = property  •  outlined icon = opportunity  •  round icon = supporting signal',style:TextStyle(fontSize:9.5))")
assert 'Icons.bolt_rounded,size:16' not in src
assert 'Icons.location_searching_rounded,size:16' not in src
assert 'String _opportunityLabel(' in src and 'String _propertyLabel(' in src
map_path.write_text(src, encoding='utf-8')

opp_path = Path('lib/v2/bridgepoint_opportunities_v2.dart')
opp = opp_path.read_text(encoding='utf-8')
helper_anchor = "import 'package:supabase_flutter/supabase_flutter.dart';\n"
helpers = r'''

String _opportunityKindText(Map<String, dynamic> row) =>
    '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''} ${row['model_key'] ?? ''}'.toLowerCase();

IconData _opportunityIconFor(Map<String, dynamic> row) {
  final text = _opportunityKindText(row);
  if (text.contains('roof')) return Icons.roofing_rounded;
  if (text.contains('storm') || text.contains('hail') || text.contains('wind') || text.contains('weather')) return Icons.thunderstorm_rounded;
  if (text.contains('fire') || text.contains('smoke')) return Icons.local_fire_department_rounded;
  if (text.contains('flood') || text.contains('water')) return Icons.water_drop_rounded;
  if (text.contains('solar')) return Icons.solar_power_rounded;
  if (text.contains('sale') || text.contains('transfer') || text.contains('owner') || text.contains('deed')) return Icons.key_rounded;
  if (text.contains('invest') || text.contains('distress') || text.contains('foreclos')) return Icons.real_estate_agent_rounded;
  if (text.contains('develop') || text.contains('construction')) return Icons.construction_rounded;
  if (text.contains('permit') || text.contains('code')) return Icons.fact_check_outlined;
  if (text.contains('environment') || text.contains('spill') || text.contains('tank')) return Icons.eco_rounded;
  if (text.contains('claim') || text.contains('insurance')) return Icons.shield_outlined;
  if (text.contains('utility') || text.contains('infrastructure')) return Icons.electrical_services_rounded;
  return Icons.location_on_rounded;
}

String _opportunityLabelFor(Map<String, dynamic> row) {
  final text = _opportunityKindText(row);
  if (text.contains('roof')) return 'Roofing';
  if (text.contains('storm') || text.contains('hail') || text.contains('wind') || text.contains('weather')) return 'Storm / hail / wind';
  if (text.contains('fire') || text.contains('smoke')) return 'Fire';
  if (text.contains('flood') || text.contains('water')) return 'Flood / water';
  if (text.contains('solar')) return 'Solar';
  if (text.contains('sale') || text.contains('transfer') || text.contains('owner') || text.contains('deed')) return 'Ownership / sale';
  if (text.contains('invest') || text.contains('distress') || text.contains('foreclos')) return 'Investment / distress';
  if (text.contains('develop') || text.contains('construction')) return 'Development';
  if (text.contains('permit') || text.contains('code')) return 'Permit / code';
  if (text.contains('environment') || text.contains('spill') || text.contains('tank')) return 'Environmental';
  if (text.contains('claim') || text.contains('insurance')) return 'Claims / insurance';
  if (text.contains('utility') || text.contains('infrastructure')) return 'Infrastructure';
  return 'Other property intelligence';
}
'''
assert '_opportunityIconFor' not in opp
opp = opp.replace(helper_anchor, helper_anchor + helpers, 1)
opp = opp.replace("'${row['full_address'] ?? row['title'] ?? 'BridgePoint opportunity'}'", "'${row['full_address'] ?? row['location_label'] ?? row['title'] ?? 'BridgePoint opportunity'}'")
opp = opp.replace("child: Icon(Icons.bolt_rounded, color: color),", "child: Tooltip(message: _opportunityLabelFor(row), child: Icon(_opportunityIconFor(row), color: color)),")
score_chip = "                          _Mini('Score ${row['score'] ?? '—'}'),"
assert score_chip in opp
opp = opp.replace(score_chip, "                          _Mini(_opportunityLabelFor(row)),\n" + score_chip, 1)
type_fact = "                      _Fact('Type', row['property_type']),"
assert type_fact in opp
opp = opp.replace(type_fact, type_fact + "\n                      _Fact('Owner', row['current_owner_name']),\n                      _Fact('Owner as of', row['owner_as_of_date']),\n                      _Fact('Owner source', row['owner_source_name']),\n                      _Fact('Identity', row['identity_quality']),", 1)
assert 'Icon(Icons.bolt_rounded, color: color)' not in opp
assert '_Mini(_opportunityLabelFor(row))' in opp
opp_path.write_text(opp, encoding='utf-8')
