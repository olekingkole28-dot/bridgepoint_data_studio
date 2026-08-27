import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerOverviewV2 extends StatefulWidget {
  const BridgePointOwnerOverviewV2({super.key});
  @override
  State<BridgePointOwnerOverviewV2> createState() => _BridgePointOwnerOverviewV2State();
}

class _BridgePointOwnerOverviewV2State extends State<BridgePointOwnerOverviewV2> {
  static const _panel = Color(0xFF0B1A2B);
  static const _soft = Color(0xFF112B45);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  late Future<List<dynamic>> _request;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() => _request = _load()); });
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  Future<dynamic> _safe(String rpc) async { try { return await Supabase.instance.client.rpc(rpc); } catch (_) { return const <String, dynamic>{}; } }
  Future<List<dynamic>> _load() => Future.wait([_safe('bridgepoint_owner_parcel_progress_v942'),_safe('bridgepoint_owner_source_truth_v943'),_safe('bridgepoint_owner_system_health_v777')]);
  Map<String,dynamic> _map(dynamic v) => v is Map ? Map<String,dynamic>.from(v) : const {};
  List<Map<String,dynamic>> _rows(dynamic v) => v is List ? v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : const [];
  int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}'.replaceAll(',','')) ?? 0;
  String _number(dynamic v) { final n=_int(v); final s=n.abs().toString(); final b=StringBuffer(); for(var i=0;i<s.length;i++){if(i>0&&(s.length-i)%3==0)b.write(',');b.write(s[i]);} return '${n<0?'-':''}${b.toString()}'; }
  String _age(dynamic v) { final dt=DateTime.tryParse('${v ?? ''}')?.toLocal(); if(dt==null)return 'No recent receipt'; final d=DateTime.now().difference(dt); if(d.inSeconds<60)return '${d.inSeconds}s ago'; if(d.inMinutes<60)return '${d.inMinutes}m ago'; if(d.inHours<24)return '${d.inHours}h ago'; return '${d.inDays}d ago'; }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future:_request,
    builder:(context,snapshot){
      final data=snapshot.data??const <dynamic>[]; dynamic at(int i)=>i<data.length?data[i]:const <String,dynamic>{};
      final parcel=_map(at(0)); final source=_map(at(1)); final health=_map(at(2)); final accelerator=_map(parcel['accelerator']); final counties=_map(parcel['county_discovery']); final states=_rows(parcel['states']);
      final active='${parcel['system_state']??'CHECK'}'.toUpperCase(); final activeColor=active=='ACTIVE'?_green:active=='MOVING_SLOWLY'?_amber:_red;
      final candidateCount=_int(counties['CANDIDATE_FOUND'])+_int(counties['REVIEW_CANDIDATE']);
      final cards=<Widget>[
        _Metric('PARCEL EXPANSION',active,'${_number(parcel['active_lanes'])}/${_number(parcel['total_lanes'])} priority lanes active • ${_number(parcel['lane_successes'])} successful cycles',Icons.route_rounded,activeColor),
        _Metric('COUNTY DISCOVERY',_number(candidateCount),'${_number(counties['DISCOVERING'])} discovering • ${_number(counties['QUEUED'])} queued • ${_number(counties['NO_CANDIDATE'])} need a source',Icons.travel_explore_rounded,_cyan),
        _Metric('DISTINCT SOURCE ENDPOINTS',_number(source['distinct_endpoints']),'${_number(source['distinct_providers'])} providers • ${_number(source['distinct_categories'])} data categories',Icons.dataset_linked_rounded,_blue),
        _Metric('SOURCE HEALTH','${_number(source['healthy_routes'])} healthy','${_number(source['failing_routes'])} failing routes • ${_number(source['registry_routes'])} routing records total',Icons.monitor_heart_outlined,_green),
        _Metric('AUTHORITATIVE STATES',_number(accelerator['authoritative_states']),'${_number(accelerator['provisional_states'])} provisional • ${_number(accelerator['partial_states'])} partial • ${_number(accelerator['zero_foundation_states'])} zero-foundation',Icons.map_rounded,_amber),
        _Metric('LAST PARCEL ACTIVITY',_age(parcel['last_lane_activity_at']),'Real executor activity — maintenance does not fake this heartbeat',Icons.schedule_rounded,_cyan),
      ];
      return RefreshIndicator(onRefresh:() async=>setState(()=>_request=_load()),child:ListView(padding:const EdgeInsets.all(16),children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Owner Control',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),SizedBox(height:5),Text('Operational truth in plain English: parcel movement, source breadth, expansion state and system health. Raw payloads stay in Advanced.',style:TextStyle(color:_muted,height:1.45))])),IconButton.filledTonal(onPressed:()=>setState(()=>_request=_load()),icon:const Icon(Icons.refresh_rounded),tooltip:'Refresh owner truth')]),
        if(snapshot.connectionState==ConnectionState.waiting)...[const SizedBox(height:10),const LinearProgressIndicator()],
        const SizedBox(height:16),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1050?3:c.maxWidth>=620?2:1;final w=(c.maxWidth-(cols-1)*10)/cols;return Wrap(spacing:10,runSpacing:10,children:[for(final card in cards)SizedBox(width:w,child:card)]);}),
        const SizedBox(height:18),
        _Section(title:'Parcel foundation by state',subtitle:'What is actually moving now. No invented completion percentage when a statewide denominator is unknown.',icon:Icons.account_tree_rounded,child:states.isEmpty?const Text('State parcel progress is loading.',style:TextStyle(color:_muted)):Column(children:[for(final row in states.take(18))_StateRow(row:row)])),
        const SizedBox(height:14),
        _Section(title:'Source-count truth',subtitle:'BridgePoint separates unique source breadth from internal routing rows.',icon:Icons.hub_outlined,child:Wrap(spacing:8,runSpacing:8,children:[_Pill('${_number(source['distinct_endpoints'])} unique endpoints',_cyan),_Pill('${_number(source['distinct_providers'])} providers',_blue),_Pill('${_number(source['distinct_categories'])} categories',_green),_Pill('${_number(source['enabled_routes'])} enabled routes',_amber),_Pill('${_number(source['duplicate_routing_rows'])} duplicate routing aliases',_muted)])),
        const SizedBox(height:14),
        _Section(title:'System health',subtitle:'High-level owner status only. Detailed engine diagnostics are under Automation.',icon:Icons.health_and_safety_outlined,child:Text(health['summary']?.toString().trim().isNotEmpty==true?'${health['summary']}':'BridgePoint owner health is connected. Use Automation for worker-level diagnostics.',style:const TextStyle(color:_muted,height:1.45))),
      ]));
    },
  );
}

class _Metric extends StatelessWidget { const _Metric(this.label,this.value,this.detail,this.icon,this.color); final String label,value,detail; final IconData icon; final Color color; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_BridgePointOwnerOverviewV2State._panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:color.withValues(alpha:.20))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:40,height:40,decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:color,size:21)),const SizedBox(height:12),Text(label,style:const TextStyle(color:_BridgePointOwnerOverviewV2State._muted,fontSize:11.5,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(detail,style:const TextStyle(color:_BridgePointOwnerOverviewV2State._muted,fontSize:12.2,height:1.38))])); }
class _StateRow extends StatelessWidget { const _StateRow({required this.row}); final Map<String,dynamic> row; @override Widget build(BuildContext context){final state='${row['state_code']??''}'.trim();final status='${row['data_status']??row['run_status']??'BUILDING'}'.toUpperCase();final phase='${row['current_phase']??'PROPERTY FOUNDATION'}'.replaceAll('_',' ');final color=status=='LIVE'?_BridgePointOwnerOverviewV2State._green:status.contains('RUN')?_BridgePointOwnerOverviewV2State._cyan:_BridgePointOwnerOverviewV2State._blue;return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_BridgePointOwnerOverviewV2State._soft.withValues(alpha:.62),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withValues(alpha:.12))),child:Row(children:[Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Text(state,style:TextStyle(color:color,fontWeight:FontWeight.w900))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$status • $phase',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${row['canonical_property_count']??0} properties • ${row['property_queue_processing']??0} processing • ${row['property_queue_pending']??0} queued',style:const TextStyle(color:_BridgePointOwnerOverviewV2State._muted,fontSize:12))]))]));} }
class _Section extends StatelessWidget { const _Section({required this.title,required this.subtitle,required this.icon,required this.child}); final String title,subtitle; final IconData icon; final Widget child; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_BridgePointOwnerOverviewV2State._panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withValues(alpha:.08))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:_BridgePointOwnerOverviewV2State._cyan),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(color:_BridgePointOwnerOverviewV2State._muted,fontSize:12.2,height:1.35))]))]),const SizedBox(height:14),child])); }
class _Pill extends StatelessWidget { const _Pill(this.label,this.color); final String label; final Color color; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(999),border:Border.all(color:color.withValues(alpha:.18))),child:Text(label,style:TextStyle(color:color,fontSize:11.5,fontWeight:FontWeight.w900))); }
