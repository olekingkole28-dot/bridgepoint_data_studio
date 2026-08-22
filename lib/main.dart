import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';
const _bridgePointShareSubject = 'Try BridgePoint Intelligence';
const _bridgePointShareMessage =
    'See property opportunities, live weather context, explainable evidence, maps, timelines, and field tools in one place. Try BridgePoint Intelligence free for 7 days: $_bridgePointLiveUrl';
// Supabase publishable keys are intentionally safe for client applications.
// Never place a service_role or sb_secret key in Flutter source code.
const _supabasePublishableKey =
    'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';

@immutable
class _DisplayPreferences {
  const _DisplayPreferences({
    this.largeText = false,
    this.highContrast = false,
    this.reducedMotion = false,
    this.simplifiedViews = false,
  });

  final bool largeText;
  final bool highContrast;
  final bool reducedMotion;
  final bool simplifiedViews;

  _DisplayPreferences copyWith({
    bool? largeText,
    bool? highContrast,
    bool? reducedMotion,
    bool? simplifiedViews,
  }) => _DisplayPreferences(
    largeText: largeText ?? this.largeText,
    highContrast: highContrast ?? this.highContrast,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    simplifiedViews: simplifiedViews ?? this.simplifiedViews,
  );
}

final ValueNotifier<_DisplayPreferences> _displayPreferences =
    ValueNotifier(const _DisplayPreferences());

class _BridgePointScrollBehavior extends MaterialScrollBehavior {
  const _BridgePointScrollBehavior();

  @override
  Set<ui.PointerDeviceKind> get dragDevices => const {
    ui.PointerDeviceKind.touch,
    ui.PointerDeviceKind.mouse,
    ui.PointerDeviceKind.trackpad,
    ui.PointerDeviceKind.stylus,
    ui.PointerDeviceKind.unknown,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

void _applyDisplayPreferences(Map<String,dynamic> value){
  _displayPreferences.value=_DisplayPreferences(
    largeText:value['large_text']==true,
    highContrast:value['high_contrast']==true,
    reducedMotion:value['reduced_motion']==true,
    simplifiedViews:value['simplified_views']==true,
  );
}

Map<String, String> _apiHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return {
    'apikey': _supabasePublishableKey,
    if (token != null) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabasePublishableKey,
  );
  runApp(const BridgePointApp());
}

class BridgePointApp extends StatelessWidget {
  const BridgePointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_DisplayPreferences>(
      valueListenable: _displayPreferences,
      builder: (context, preferences, _) => MaterialApp(
        title: 'BridgePoint Intelligence',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const _BridgePointScrollBehavior(),
        theme: preferences.highContrast
            ? AppTheme.highContrastTheme
            : AppTheme.darkTheme,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(preferences.largeText ? 1.18 : 1),
              disableAnimations: preferences.reducedMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, _) => Supabase.instance.client.auth.currentSession == null
        ? const _AuthScreen()
        : const _WorkspaceGate(),
  );
}

Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
  final response = await http.post(
    Uri.parse('$_supabaseUrl/rest/v1/rpc/$name'),
    headers: _apiHeaders(),
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) throw const FormatException('Unexpected BridgePoint response.');
  return Map<String, dynamic>.from(decoded);
}

Map<String,dynamic> _edgeFunctionPayload(dynamic data){
  if(data is Map)return Map<String,dynamic>.from(data);
  if(data is String){
    final decoded=jsonDecode(data);
    if(decoded is Map)return Map<String,dynamic>.from(decoded);
  }
  return <String,dynamic>{'complete':false,'error':'The server returned an unreadable response.'};
}

class _WorkspaceGate extends StatefulWidget {
  const _WorkspaceGate();
  @override State<_WorkspaceGate> createState()=>_WorkspaceGateState();
}
class _WorkspaceGateState extends State<_WorkspaceGate> {
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load()async{
    final results=await Future.wait([
      _callRpc('bridgepoint_onboarding_state_v70',const {}),
      _callRpc('bridgepoint_display_preferences_v80',const {}),
      _callRpc('bridgepoint_legal_state_v82',const {}),
    ]);
    _applyDisplayPreferences(results[1]);
    return results[0]..['legal_state']=results[2];
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting)return const Scaffold(body:_ExperienceBackground(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[_BridgePointMark(size:64),SizedBox(height:18),Text('Preparing your intelligence workspace',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),SizedBox(height:14),SizedBox(width:220,child:LinearProgressIndicator(color:AppTheme.cyan,backgroundColor:Colors.white12))]))));
      if(snapshot.hasError)return Scaffold(body:Center(child:_DashboardError(message:snapshot.error.toString(),onRetry:()=>setState(()=>request=_load()))));
      final legal=snapshot.data?['legal_state'];
      if(legal is Map&&legal['required_acceptance_missing']==true)return _LegalAcceptanceScreen(state:Map<String,dynamic>.from(legal),onComplete:()=>setState(()=>request=_load()));
      if(snapshot.data?['onboarding_complete']!=true)return _OnboardingScreen(onComplete:()=>setState(()=>request=_load()));
      return DashboardScreen(ownerMode:snapshot.data?['owner_bypass']==true);
    },
  );
}

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({required this.onComplete});
  final VoidCallback onComplete;
  @override State<_OnboardingScreen> createState()=>_OnboardingScreenState();
}
class _OnboardingScreenState extends State<_OnboardingScreen>{
  String industry='Roofing',role='Owner',goal='Find the best leads',territory='Statewide Connecticut',experience='Growing business';
  bool loading=false; String? error;
  Future<void> submit() async {setState(()=>loading=true);try{
    final result=await _callRpc('bridgepoint_complete_onboarding_v70',{
      'p_industry':industry,'p_role_name':role,'p_primary_goal':goal,'p_territory':territory,'p_experience_level':experience});
    if(!mounted)return;
    await showDialog(context:context,builder:(context)=>AlertDialog(
      title:const Row(children:[Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan),SizedBox(width:10),Text('Your recommended workspace')]),
      content:Text('${_packageName(result['recommended_package_key'])}\n\n${result['reason']}',style:const TextStyle(height:1.5)),
      actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Open my workspace'))],));
    widget.onComplete();
  }catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>loading=false);}}
  static String _packageName(dynamic key)=>const {
    'homeowner':'BridgePoint Homeowner',
    'roofing_opportunity':'Roofing Opportunity','bridgepoint_commercial':'BridgePoint Commercial',
    'property_investor':'Property Investor','solar_opportunity':'Solar Opportunity',
    'development_opportunity':'Development Opportunity','bridgepoint_home':'BridgePoint Home','all':'BridgePoint Intelligence Suite'
  }[key]??'BridgePoint Intelligence Suite';
  Widget drop(String label,String value,List<String> options,ValueChanged<String?> change)=>DropdownButtonFormField<String>(
    value:value,dropdownColor:AppTheme.panel,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
    items:options.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:loading?null:change);
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Card(child:Container(
    width:680,padding:const EdgeInsets.all(30),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Center(child:_BridgePointMark(size:56)),const SizedBox(height:12),
      const Text('Let’s build the right BridgePoint workspace',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),const Text('Choose the answers that fit you best. BridgePoint will recommend the package and intelligence most useful for your work.',textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textMuted,height:1.5)),
      const SizedBox(height:24),drop('What kind of work do you do?',industry,const ['Homeowner','Roofing','Home services','Restoration','Public adjusting','Commercial real estate','Property investing','Development','Solar','Other'],(v)=>setState(()=>industry=v??industry)),
      const SizedBox(height:12),drop('What is your role?',role,const ['Property owner','Owner','Sales manager','Sales representative','Estimator','Investor','Developer','Operations','Other'],(v)=>setState(()=>role=v??role)),
      const SizedBox(height:12),drop('What is your main goal?',goal,const ['Find the best leads','Prioritize my current leads','Monitor properties','Plan field visits','Find development opportunities','Track customer follow-ups'],(v)=>setState(()=>goal=v??goal)),
      const SizedBox(height:12),drop('Where do you work?',territory,const ['Statewide Connecticut','One municipality','One county','Multiple counties','New England'],(v)=>setState(()=>territory=v??territory)),
      const SizedBox(height:12),drop('Which best describes your business?',experience,const ['Just getting started','Growing business','Established team','Multi-location operation'],(v)=>setState(()=>experience=v??experience)),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber))],
      const SizedBox(height:20),FilledButton.icon(onPressed:loading?null:submit,icon:const Icon(Icons.auto_awesome_rounded),label:Text(loading?'Building recommendation…':'Show my recommendation')),
    ]),
  ))))));
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen();
  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;
  Future<void> submit() async {
    setState(()=>loading=true); error=null;
    try {
      if(create) {
        if(!acceptTerms)throw Exception('Review and accept the Terms, Privacy Notice, Acceptable Use rules, and Data Disclaimer to create an account.');
        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
    } catch(e) { if(mounted) setState(()=>error=e.toString()); }
    finally { if(mounted) setState(()=>loading=false); }
  }
  @override void dispose(){displayName.dispose();email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(child:Card(child:Container(
    width:430,padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Center(child:_BridgePointMark(size:58)),const SizedBox(height:14),
      const Text('BRIDGEPOINT INTELLIGENCE',textAlign:TextAlign.center,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,letterSpacing:1)),
      const SizedBox(height:8),Text(create?'Create your 7-day trial':'Sign in to live property intelligence',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted)),
      const SizedBox(height:24),if(create)...[TextField(controller:displayName,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Profile name',hintText:'How BridgePoint should welcome you',border:OutlineInputBorder())),const SizedBox(height:12)],TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
      const SizedBox(height:12),TextField(
        controller:password,obscureText:!showPassword,onSubmitted:(_)=>submit(),
        decoration:InputDecoration(
          labelText:'Password',border:const OutlineInputBorder(),
          suffixIcon:IconButton(
            tooltip:showPassword?'Hide password':'Show password',
            onPressed:()=>setState(()=>showPassword=!showPassword),
            icon:Icon(showPassword?Icons.visibility_off_rounded:Icons.visibility_rounded),
          ),
        ),
      ),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
        contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,value:acceptTerms,
        onChanged:loading?null:(v)=>setState(()=>acceptTerms=v==true),
        title:const Text('I agree to the Terms, Privacy Notice, Acceptable Use rules, and Data & Scoring Disclaimer.',style:TextStyle(fontSize:10,height:1.4)),
        subtitle:TextButton(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _PublicLegalSummaryDialog()),child:const Align(alignment:Alignment.centerLeft,child:Text('Review before creating account'))),
      )],
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:11))],
      const SizedBox(height:18),FilledButton(onPressed:loading?null:submit,child:Text(loading?'Please wait…':create?'Start free trial':'Sign in')),
      TextButton(onPressed:loading?null:()=>setState(()=>create=!create),child:Text(create?'Already have an account? Sign in':'New here? Start 7-day trial')),
    ]),
  ))))));
}

class _PublicLegalSummaryDialog extends StatelessWidget{
  const _PublicLegalSummaryDialog();
  @override Widget build(BuildContext context)=>AlertDialog(
    backgroundColor:AppTheme.panel,title:const Row(children:[Icon(Icons.gavel_outlined,color:AppTheme.cyan),SizedBox(width:9),Expanded(child:Text('BridgePoint Legal & Trust Summary'))]),
    content:const SizedBox(width:650,child:SingleChildScrollView(child:Text(
      'Terms: BridgePoint is a property-intelligence and workflow tool, not professional advice or proof of damage, coverage, a permit, customer intent, or a guaranteed outcome.\n\nPrivacy: BridgePoint uses account, workspace, security, and source data to provide the service. Precise location is collected only after a Company user explicitly starts a field shift, is never sold, and is deleted after seven days.\n\nAcceptable Use: No discrimination, harassment, trespass, deceptive claims, hidden monitoring, unlawful solicitation, credential sharing, scraping, or resale. Users must follow licensing, do-not-call, email, text, field-safety, and property-access laws.\n\nData & Scoring: Sources can be delayed or imperfect. Scores prioritize investigation and include visible negative adjustments. NOAA radar is weather context—not property-level proof.\n\nThe full versioned documents appear immediately after sign-in and remain available in Settings → Legal & Trust Center.',
      style:TextStyle(color:AppTheme.textMuted,height:1.55),))),
    actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))],
  );
}

class _LegalAcceptanceScreen extends StatefulWidget{
  const _LegalAcceptanceScreen({required this.state,required this.onComplete});
  final Map<String,dynamic> state;final VoidCallback onComplete;
  @override State<_LegalAcceptanceScreen> createState()=>_LegalAcceptanceScreenState();
}
class _LegalAcceptanceScreenState extends State<_LegalAcceptanceScreen>{
  bool accepted=false,busy=false;String? error;
  Future<void> submit()async{
    if(!accepted)return;
    setState(()=>busy=true);
    try{await _callRpc('bridgepoint_accept_legal_v82',{'p_document_keys':['TERMS','PRIVACY','ACCEPTABLE_USE','DATA_DISCLAIMER'],'p_acceptance_source':'APP_REQUIRED_GATE'});widget.onComplete();}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final docs=(widget.state['documents'] as List? ?? const []).whereType<Map>().where((e)=>e['required']==true).map((e)=>Map<String,dynamic>.from(e)).toList();
    return Scaffold(body:_ExperienceBackground(child:Center(child:Card(child:Container(width:760,constraints:const BoxConstraints(maxHeight:820),padding:const EdgeInsets.all(26),child:Column(children:[
      const _BridgePointMark(size:54),const SizedBox(height:10),const Text('Legal & Trust Center',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      const SizedBox(height:5),const Text('Please review the current documents before continuing.',style:TextStyle(color:AppTheme.textMuted)),const SizedBox(height:14),
      Expanded(child:ListView.separated(itemCount:docs.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(context,i){final d=docs[i];return Card(color:AppTheme.panelSoft.withOpacity(.8),child:ExpansionTile(
        leading:const Icon(Icons.verified_user_outlined,color:AppTheme.cyan),title:Text('${d['title']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Version ${d['document_version']} • ${d['summary']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
        children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,18),child:SelectableText('${d['content_markdown']}'.replaceAll('# ',''),style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.55)))],
      ));})),
      CheckboxListTile(value:accepted,onChanged:busy?null:(v)=>setState(()=>accepted=v==true),controlAffinity:ListTileControlAffinity.leading,title:const Text('I have reviewed and agree to these current documents.',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800))),
      if(error!=null)Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:10)),const SizedBox(height:8),
      SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:accepted&&!busy?submit:null,icon:const Icon(Icons.check_circle_outline_rounded),label:Text(busy?'Saving acceptance…':'Accept and continue'))),
    ]))))));
  }
}

class _ExperienceBackground extends StatelessWidget {
  const _ExperienceBackground({required this.child});
  final Widget child;
  @override Widget build(BuildContext context)=>Container(
    decoration:const BoxDecoration(image:DecorationImage(
      image:AssetImage('assets/images/bridgepoint-intelligence-background-v1.webp'),fit:BoxFit.cover)),
    child:Container(
      decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[AppTheme.navy.withOpacity(.30),AppTheme.navy.withOpacity(.72)])),
      child:child,
    ),
  );
}

class _BridgePointMark extends StatelessWidget{
  const _BridgePointMark({this.size=42});
  final double size;
  @override Widget build(BuildContext context)=>Container(
    width:size,height:size,
    decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue],begin:Alignment.topLeft,end:Alignment.bottomRight),
      borderRadius:BorderRadius.circular(size*.28),
      boxShadow:[BoxShadow(color:AppTheme.cyan.withOpacity(.20),blurRadius:size*.38,spreadRadius:1)],
    ),
    child:CustomPaint(painter:_BridgePointMarkPainter()),
  );
}

class _BridgePointMarkPainter extends CustomPainter{
  @override void paint(Canvas canvas,Size size){
    final shadow=Paint()..color=const Color(0xFF05101F).withOpacity(.20)
      ..style=PaintingStyle.stroke..strokeWidth=size.width*.16
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    final stroke=Paint()..color=Colors.white..style=PaintingStyle.stroke
      ..strokeWidth=size.width*.075..strokeCap=StrokeCap.round
      ..strokeJoin=StrokeJoin.round;
    final monogram=ui.Path()
      ..moveTo(size.width*.27,size.height*.23)
      ..lineTo(size.width*.27,size.height*.77)
      ..moveTo(size.width*.29,size.height*.25)
      ..cubicTo(size.width*.68,size.height*.17,size.width*.79,size.height*.33,size.width*.72,size.height*.43)
      ..cubicTo(size.width*.68,size.height*.49,size.width*.59,size.height*.51,size.width*.47,size.height*.51)
      ..cubicTo(size.width*.72,size.height*.49,size.width*.83,size.height*.61,size.width*.76,size.height*.72)
      ..cubicTo(size.width*.70,size.height*.81,size.width*.48,size.height*.80,size.width*.29,size.height*.76);
    canvas.drawPath(monogram,shadow);
    canvas.drawPath(monogram,stroke);

    final route=Paint()..color=Colors.white.withOpacity(.72)
      ..style=PaintingStyle.stroke..strokeWidth=size.width*.032
      ..strokeCap=StrokeCap.round;
    canvas.drawLine(
      Offset(size.width*.18,size.height*.83),
      Offset(size.width*.84,size.height*.83),
      route,
    );
    final node=Paint()..color=Colors.white;
    canvas.drawCircle(Offset(size.width*.18,size.height*.83),size.width*.035,node);
    canvas.drawCircle(Offset(size.width*.84,size.height*.83),size.width*.035,node);
    canvas.drawCircle(Offset(size.width*.53,size.height*.51),size.width*.11,node);
    canvas.drawCircle(
      Offset(size.width*.53,size.height*.51),
      size.width*.042,
      Paint()..color=const Color(0xFF0A2C5C),
    );
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

Future<void> _openStripeFlow(BuildContext context,String functionName,Map<String,dynamic> body) async {
  final session=Supabase.instance.client.auth.currentSession;
  if(session==null){_showInfoDialog(context,'Sign in required','Please sign in before managing billing.');return;}
  try{
    final response=await http.post(Uri.parse('$_supabaseUrl/functions/v1/$functionName'),headers:{
      'apikey':_supabasePublishableKey,'Authorization':'Bearer ${session.accessToken}','Content-Type':'application/json'
    },body:jsonEncode(body)).timeout(const Duration(seconds:30));
    final decoded=jsonDecode(response.body);
    if(response.statusCode<200||response.statusCode>=300||decoded is! Map||decoded['url']==null) throw Exception(decoded is Map?decoded['error']:'Billing request failed');
    if(!await launchUrl(Uri.parse(decoded['url'].toString()),mode:LaunchMode.externalApplication)) throw Exception('Could not open Stripe');
  }catch(e){if(context.mounted)_showInfoDialog(context,'Billing unavailable',e.toString());}
}

Future<void> _startCheckout(BuildContext context,Map<String,dynamic> package,String interval)=>
  _openStripeFlow(context,'bridgepoint-checkout-v67',{'package_key':package['package_key'],'interval':interval});

Future<void> _openBillingPortal(BuildContext context)=>
  _openStripeFlow(context,'bridgepoint-billing-portal-v66',const {});

Future<void> _openOwnerPayoutSettings(BuildContext context) async {
  final uri=Uri.parse('https://dashboard.stripe.com/test/settings/payouts');
  if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&context.mounted){
    _showInfoDialog(context,'Could not open Stripe','Open Stripe Dashboard → Settings → Bank accounts and scheduling. Enter bank information only inside Stripe.');
  }
}

Future<void> _launchBridgePointShareTarget(BuildContext context,Uri uri,{required String label})async{
  try{
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw Exception('No compatible app or browser was available.');
  }catch(error){
    await Clipboard.setData(const ClipboardData(text:_bridgePointLiveUrl));
    if(context.mounted)_showInfoDialog(context,'Could not open $label','$error\n\nThe BridgePoint link was copied so you can paste it anywhere.');
  }
}

Future<void> _shareBridgePointNatively(BuildContext context)async{
  try{
    final box=context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      title:'BridgePoint Intelligence',subject:_bridgePointShareSubject,text:_bridgePointShareMessage,
      sharePositionOrigin:box==null?null:box.localToGlobal(Offset.zero)&box.size,
    ));
  }catch(error){if(context.mounted)_showInfoDialog(context,'Share menu unavailable','$error\n\nUse Copy link, Email, Text, or a social button below.');}
}

void _showShareBridgePointDialog(BuildContext context)=>showDialog<void>(context:context,builder:(context)=>const _ShareBridgePointDialog());

class _ShareBridgePointDialog extends StatelessWidget{
  const _ShareBridgePointDialog();
  Future<void> _copy(BuildContext context)async{
    await Clipboard.setData(const ClipboardData(text:_bridgePointLiveUrl));
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('BridgePoint link copied.')));
  }
  Widget _action(IconData icon,String label,VoidCallback onPressed,{Color color=AppTheme.cyan})=>SizedBox(width:218,child:OutlinedButton.icon(onPressed:onPressed,icon:Icon(icon,color:color),label:Text(label)));
  @override Widget build(BuildContext context)=>AlertDialog(
    backgroundColor:AppTheme.panel,
    title:const Row(children:[Icon(Icons.ios_share_rounded,color:AppTheme.cyan),SizedBox(width:10),Expanded(child:Text('Share BridgePoint'))]),
    content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Invite a customer, teammate, friend, or organization. Every option uses the permanent BridgePoint link.',style:TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.45)),
      const SizedBox(height:14),Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.07))),child:const SelectableText(_bridgePointLiveUrl,style:TextStyle(color:AppTheme.cyan,fontWeight:FontWeight.w800))),
      const SizedBox(height:14),Wrap(spacing:9,runSpacing:9,children:[
        _action(Icons.share_rounded,'Device share menu',()=>_shareBridgePointNatively(context)),
        _action(Icons.content_copy_rounded,'Copy link',()=>_copy(context)),
        _action(Icons.email_outlined,'Email it',()=>_launchBridgePointShareTarget(context,Uri(scheme:'mailto',queryParameters:{'subject':_bridgePointShareSubject,'body':_bridgePointShareMessage}),label:'email')),
        _action(Icons.sms_outlined,'Send as text',()=>_launchBridgePointShareTarget(context,Uri(scheme:'sms',queryParameters:{'body':_bridgePointShareMessage}),label:'text messages')),
        _action(Icons.chat_rounded,'WhatsApp',()=>_launchBridgePointShareTarget(context,Uri.https('wa.me','/',{'text':_bridgePointShareMessage}),label:'WhatsApp'),color:AppTheme.green),
        _action(Icons.alternate_email_rounded,'Post to X',()=>_launchBridgePointShareTarget(context,Uri.https('twitter.com','/intent/tweet',{'text':'Property intelligence that explains what changed and what to do next.','url':_bridgePointLiveUrl}),label:'X')),
        _action(Icons.business_center_outlined,'Share on LinkedIn',()=>_launchBridgePointShareTarget(context,Uri.https('www.linkedin.com','/sharing/share-offsite/',{'url':_bridgePointLiveUrl}),label:'LinkedIn'),color:AppTheme.blue),
        _action(Icons.people_alt_outlined,'Share on Facebook',()=>_launchBridgePointShareTarget(context,Uri.https('www.facebook.com','/sharer/sharer.php',{'u':_bridgePointLiveUrl}),label:'Facebook'),color:AppTheme.blue),
      ]),
      const SizedBox(height:14),const Text('Email and text open your device composer so you choose the recipient and approve the message before it is sent.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Done'))],
  );
}

class AppTheme {
  static const Color navy = Color(0xFF07111F);
  static const Color panel = Color(0xFF0D1A2B);
  static const Color panelSoft = Color(0xFF122238);
  static const Color cyan = Color(0xFF35D2E8);
  static const Color blue = Color(0xFF4F7CFF);
  static const Color green = Color(0xFF38D49A);
  static const Color amber = Color(0xFFFFC857);
  static const Color red = Color(0xFFFF6B6B);
  static const Color textMuted = Color(0xFF8FA5BF);

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      surface: panel,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: navy,
      fontFamily: 'Segoe UI',
      dividerColor: Colors.white.withOpacity(0.08),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
    );
  }

  static ThemeData get highContrastTheme => darkTheme.copyWith(
    scaffoldBackgroundColor: const Color(0xFF02060B),
    cardTheme: CardThemeData(
      color: const Color(0xFF081727),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF5CEBFF), width: 1.25),
      ),
    ),
    dividerColor: Colors.white38,
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key,this.ownerMode=false});
  final bool ownerMode;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedNavigation = 0;
  String selectedPackage = 'BridgePoint Home';
  late Future<Map<String, dynamic>> dashboardRequest;
  late Future<Map<String, dynamic>> sourcesRequest;
  late Future<Map<String, dynamic>> settingsRequest;
  late Future<Map<String, dynamic>> healthRequest;
  Timer? _liveRefreshTimer;
  Timer? _liveCountdownTimer;
  int _liveRefreshTick = 0;
  int _refreshSeconds = 120;
  int _secondsToRefresh = 120;
  final ScrollController _workspaceScrollController = ScrollController();
  final Map<int, double> _pageScrollOffsets = <int, double>{};
  late final String _activitySessionKey =
      'bp84:${Supabase.instance.client.auth.currentUser?.id ?? 'unknown'}:${DateTime.now().microsecondsSinceEpoch}';

  static const packageModelKeys = <String, String>{
    'Owner Full Platform': 'all',
    'BridgePoint Homeowner': 'bridgepoint_home',
    'BridgePoint Home': 'bridgepoint_home',
    'BridgePoint Commercial': 'bridgepoint_commercial',
    'Roofing Opportunity': 'roofing_opportunity',
    'BridgePoint General': 'bridgepoint_general_v1',
    'Property Investor': 'property_investor',
    'Development Opportunity': 'development_opportunity',
    'Solar Opportunity': 'solar_opportunity',
  };

  static const navigationItems = <_NavigationItem>[
    _NavigationItem('Daily Brief', Icons.wb_sunny_outlined),
    _NavigationItem('Opportunities', Icons.bolt_rounded),
    _NavigationItem('Field Mode', Icons.directions_walk_rounded),
    _NavigationItem('Intelligence Map', Icons.map_rounded),
    _NavigationItem('Properties', Icons.home_work_rounded),
    _NavigationItem('Signals', Icons.radar_rounded),
    _NavigationItem('Sources', Icons.hub_rounded),
    _NavigationItem('My Work', Icons.work_history_rounded),
    _NavigationItem('Permit Context', Icons.construction_rounded),
    _NavigationItem('Coverage', Icons.public_rounded),
    _NavigationItem('Packages', Icons.inventory_2_outlined),
    _NavigationItem('Models', Icons.psychology_alt_rounded),
    _NavigationItem('Settings', Icons.settings_rounded),
  ];

  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(widget.ownerMode)
      const _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
  ];

  static const customerPackages = <String>[
    'BridgePoint Homeowner',
    'BridgePoint Home',
    'BridgePoint Commercial',
    'Roofing Opportunity',
    'BridgePoint General',
    'Property Investor',
    'Development Opportunity',
    'Solar Opportunity',
  ];

  List<String> get packages => <String>[
    if (widget.ownerMode) 'Owner Full Platform',
    ...customerPackages,
  ];

  @override
  void initState() {
    super.initState();
    if(widget.ownerMode)selectedPackage='Owner Full Platform';
    dashboardRequest = _loadDashboard();
    sourcesRequest = _loadSources();
    settingsRequest = _loadRuntimeSettings();
    healthRequest = _loadSystemHealth();
    _scheduleLiveRefresh(_refreshSeconds);
    _configureFromServer();
    unawaited(_recordAppActivity('SESSION_START', 'Daily Brief'));
    if(!widget.ownerMode){
      WidgetsBinding.instance.addPostFrameCallback((_)=>_maybeOfferWalkthrough());
    }
  }

  Future<void> _maybeOfferWalkthrough() async {
    try {
      final state=await _callRpc('bridgepoint_walkthrough_state_v73',const {});
      if(!mounted||state['should_offer']!=true)return;
      final start=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
        backgroundColor:AppTheme.panel,
        title:const Text('Want a 2-minute guided tour?'),
        content:const Text('We will show you how to read an opportunity, use the map, save leads, plan follow-ups, and control alerts. You can skip this and reopen it later in Settings.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Not now')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Show me around')),
        ],
      ));
      if(start==true){
        await _callRpc('bridgepoint_set_walkthrough_v73',{'p_status':'STARTED'});
        if(!mounted)return;
        await showDialog<void>(context:context,builder:(context)=>const _WalkthroughDialog());
        await _callRpc('bridgepoint_set_walkthrough_v73',{'p_status':'COMPLETED'});
      }else{
        await _callRpc('bridgepoint_set_walkthrough_v73',{'p_status':'DISMISSED'});
      }
    }catch(_){/* Never block the workspace if the optional tour is unavailable. */}
  }

  @override
  void dispose() {
    unawaited(_recordAppActivity(
      'SESSION_END',
      visibleNavigationItems[selectedNavigation].label,
    ));
    _liveRefreshTimer?.cancel();
    _liveCountdownTimer?.cancel();
    _workspaceScrollController.dispose();
    super.dispose();
  }

  Future<void> _recordAppActivity(String eventType, String pageName) async {
    try {
      await _callRpc('bridgepoint_record_app_activity_v84', {
        'p_session_key': _activitySessionKey,
        'p_event_type': eventType,
        'p_page_name': pageName,
        'p_platform': 'flutter_web',
        'p_app_version': '0.85.0+85',
        'p_metadata': const <String, dynamic>{},
      });
    } catch (_) {
      // Operational counters must never interrupt a customer's workspace.
    }
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_dashboard_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_model_key': packageModelKeys[selectedPackage] ?? 'all',
            'p_limit': 10,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint API response.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _loadSources() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_sources',
          ),
          headers: _apiHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Sources API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Sources response.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _loadSimpleRpc(String functionName) async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/$functionName'),
      headers: _apiHeaders(),
      body: '{}',
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Unexpected API response.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _loadRuntimeSettings() =>
      _loadSimpleRpc('bridgepoint_flutter_settings_v59');

  Future<Map<String, dynamic>> _loadSystemHealth() =>
      _loadSimpleRpc('bridgepoint_flutter_system_health_v59');

  Future<void> _configureFromServer() async {
    try {
      final payload = await settingsRequest;
      final settings = payload['settings'];
      if (settings is Map) {
        final seconds = (settings['auto_refresh_seconds'] as num?)?.toInt();
        if (seconds != null && seconds >= 30 && mounted) {
          _scheduleLiveRefresh(seconds);
          setState(() => _refreshSeconds = seconds);
        }
      }
    } catch (_) {
      // The workspace remains usable with the safe 120-second default.
    }
  }

  void _scheduleLiveRefresh(int seconds) {
    _liveRefreshTimer?.cancel();
    _liveCountdownTimer?.cancel();
    _secondsToRefresh=seconds;
    _liveRefreshTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) {
        _secondsToRefresh=seconds;
        _refreshLiveWorkspace();
      },
    );
    _liveCountdownTimer=Timer.periodic(const Duration(seconds:1),(_){
      if(!mounted)return;
      setState(()=>_secondsToRefresh=_secondsToRefresh<=1?seconds:_secondsToRefresh-1);
    });
  }

  void _setRefreshSeconds(int seconds) {
    _scheduleLiveRefresh(seconds);
    setState(() => _refreshSeconds = seconds);
  }

  void _selectPackage(String value) {
    setState(() {
      selectedPackage = value;
      dashboardRequest = _loadDashboard();
    });
  }

  void _refreshDashboard() {
    final nextDashboard = _loadDashboard();
    final nextSources = _loadSources();
    setState(() {
      dashboardRequest = nextDashboard;
      sourcesRequest = nextSources;
    });
  }

  void _refreshLiveWorkspace() {
    if (!mounted) return;
    final nextDashboard = _loadDashboard();
    final nextSources = _loadSources();
    setState(() {
      dashboardRequest = nextDashboard;
      sourcesRequest = nextSources;
      healthRequest = _loadSystemHealth();
      _liveRefreshTick++;
    });
    unawaited(_recordAppActivity(
      'HEARTBEAT',
      visibleNavigationItems[selectedNavigation].label,
    ));
  }

  void _navigateTo(int index) {
    if (index == selectedNavigation) {
      if (_workspaceScrollController.hasClients) {
        if (_displayPreferences.value.reducedMotion) {
          _workspaceScrollController.jumpTo(0);
        } else {
          _workspaceScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      }
      return;
    }
    if (_workspaceScrollController.hasClients) {
      _pageScrollOffsets[selectedNavigation] =
          _workspaceScrollController.offset;
    }
    setState(() {
      selectedNavigation = index;
      _liveRefreshTick++;
    });
    unawaited(_recordAppActivity(
      'PAGE_VIEW',
      visibleNavigationItems[index].label,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_workspaceScrollController.hasClients) return;
      final requested = _pageScrollOffsets[index] ?? 0;
      final target = requested.clamp(
        0.0,
        _workspaceScrollController.position.maxScrollExtent,
      ).toDouble();
      _workspaceScrollController.jumpTo(target);
    });
  }

  Widget _buildSelectedPage() {
    switch (selectedNavigation) {
      case 0:
        return _DailyBriefPage(
          key:ValueKey('brief-$_liveRefreshTick-$selectedPackage'),
          overview:_OverviewContent(
            selectedPackage: selectedPackage,
            dashboardRequest: dashboardRequest,
            sourcesRequest: sourcesRequest,
            onRefresh: _refreshDashboard,
            onNavigate: _navigateTo,
          ),
        );
      case 1:
        return _OpportunitiesPage(
          modelKey: packageModelKeys[selectedPackage] ?? 'all',
          packageName: selectedPackage,
        );
      case 2:
        return _FieldModePage(
          modelKey: packageModelKeys[selectedPackage] ?? 'all',
          packageName: selectedPackage,
        );
      case 3:
        return _IntelligenceMapPage(
          modelKey: packageModelKeys[selectedPackage] ?? 'all',
          packageName: selectedPackage,
        );
      case 4:
        return const _PropertiesPage();
      case 5:
        return const _SignalsPage();
      case 6:
        return _SourcesPage(
          sourcesRequest: sourcesRequest,
          onRefresh: _refreshDashboard,
        );
      case 7:
        return const _MyWorkPage();
      case 8:
        return const _PermitContextPage();
      case 9:
        return const _CoveragePage();
      case 10:
        return const _PackagesPage();
      case 11:
        return const _ModelsPage();
      case 12:
        return _SettingsPage(
          ownerMode:widget.ownerMode,
          settingsRequest: settingsRequest,
          healthRequest: healthRequest,
          refreshSeconds: _refreshSeconds,
          onRefreshSecondsChanged: _setRefreshSeconds,
          onRefresh: () {
            setState(() {
              settingsRequest = _loadRuntimeSettings();
              healthRequest = _loadSystemHealth();
            });
          },
        );
      case 13:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );
      default:
        return _ComingSoonPage(
          title: visibleNavigationItems[selectedNavigation].label,
          icon: visibleNavigationItems[selectedNavigation].icon,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1100;

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  _SideNavigation(
                    items: visibleNavigationItems,
                    selectedIndex: selectedNavigation,
                    onSelected: _navigateTo,
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child:_WorkspaceAtmosphere(pageIndex:selectedNavigation)),
                      Column(children: [
                      _TopBar(
                        desktop: desktop,
                        package: selectedPackage,
                        packages: packages,
                        onPackageChanged: (value) {
                          if (value != null) {
                            _selectPackage(value);
                          }
                        },
                        onSearch: (_) => _navigateTo(4),
                        onPropertySelected: (property) =>
                            _showPropertyInventoryDetail(context, property),
                        onNotifications: () => showDialog<void>(
                          context:context,
                          builder:(context)=>const _NotificationCenterDialog(),
                        ),
                      ),
                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
                      if (!desktop)
                        _CompactNavigation(
                          items: visibleNavigationItems,
                          selectedIndex: selectedNavigation,
                          onSelected: _navigateTo,
                        ),
                      Expanded(
                        child: Scrollbar(
                          controller: _workspaceScrollController,
                          thumbVisibility: desktop,
                          trackVisibility: desktop,
                          interactive: true,
                          thickness: 8,
                          radius: const Radius.circular(8),
                          child: SingleChildScrollView(
                            controller: _workspaceScrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              desktop ? 28 : 16,
                              8,
                              desktop ? 34 : 16,
                              52,
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(_liveRefreshTick),
                              child: _buildSelectedPage(),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceAtmosphere extends StatelessWidget{
  const _WorkspaceAtmosphere({required this.pageIndex});
  final int pageIndex;
  @override Widget build(BuildContext context){
    final daily=pageIndex==0||pageIndex==9||pageIndex==10||pageIndex==12||pageIndex==13;
    final map=pageIndex==2||pageIndex==3||pageIndex==8;
    final asset=daily
      ?'assets/images/bridgepoint-daily-brief-background-v2.webp'
      :map?'assets/images/bridgepoint-map-background-v2.webp'
      :'assets/images/bridgepoint-intelligence-background-v1.webp';
    return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
      Image.asset(asset,fit:BoxFit.cover,alignment:map?Alignment.center:Alignment.topCenter,
        color:Colors.white.withOpacity(daily ? .18 : map ? .16 : .11),colorBlendMode:BlendMode.modulate),
      DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
        begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[AppTheme.navy.withOpacity(.70),AppTheme.navy.withOpacity(.90),AppTheme.navy.withOpacity(.97)]))),
    ]));
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: const Color(0xFF091525),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 18, 28),
            child: _Brand(),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.cyan.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.cyan.withOpacity(0.25)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: selected ? AppTheme.cyan : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 13),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? Colors.white : AppTheme.textMuted,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.green.withOpacity(0.18)),
            ),
            child: const Row(
              children: [
                _PulseDot(color: AppTheme.green),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSTEM ONLINE',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Background scoring active',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BridgePointMark(),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BRIDGEPOINT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'INTELLIGENCE',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 2.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.desktop,
    required this.package,
    required this.packages,
    required this.onPackageChanged,
    required this.onSearch,
    required this.onPropertySelected,
    required this.onNotifications,
  });

  final bool desktop;
  final String package;
  final List<String> packages;
  final ValueChanged<String?> onPackageChanged;
  final ValueChanged<String> onSearch;
  final ValueChanged<Map<String, dynamic>> onPropertySelected;
  final VoidCallback onNotifications;

  Widget _packageSelector() => Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: package,
        dropdownColor: AppTheme.panelSoft,
        icon: const Icon(Icons.expand_more_rounded),
        isExpanded: true,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        items: packages
            .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onPackageChanged,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: _Brand()),
                const SizedBox(width: 8),
                _IconButton(
                  icon: Icons.help_outline_rounded,
                  onTap: () => _showFaqDialog(context),
                ),
                const SizedBox(width: 7),
                _IconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: onNotifications,
                ),
                const SizedBox(width: 7),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.blue,
                  child: Text(
                    'KJ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: _packageSelector()),
                const SizedBox(width: 8),
                _IconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _showShareBridgePointDialog(context),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(
            child: _SearchBox(
              onSubmitted: onSearch,
              onPropertySelected: onPropertySelected,
            ),
          ),
          const SizedBox(width: 16),
          _packageSelector(),
          const SizedBox(width: 12),
          _IconButton(
            icon: Icons.ios_share_rounded,
            onTap: () => _showShareBridgePointDialog(context),
          ),
          const SizedBox(width: 10),
          _IconButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _showFaqDialog(context),
          ),
          const SizedBox(width: 10),
          _IconButton(
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 19,
            backgroundColor: AppTheme.blue,
            child: Text(
              'KJ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSyncStrip extends StatelessWidget{
  const _LiveSyncStrip({required this.secondsRemaining,required this.refreshSeconds});
  final int secondsRemaining,refreshSeconds;
  @override Widget build(BuildContext context){
    final progress=refreshSeconds<=0?0.0:(1-(secondsRemaining/refreshSeconds)).clamp(0.0,1.0);
    return Container(
      height:24,
      padding:const EdgeInsets.symmetric(horizontal:18),
      child:Row(children:[
        const _PulseDot(color:AppTheme.green),const SizedBox(width:8),
        const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8)),
        const SizedBox(width:10),
        Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(
          value:progress,minHeight:3,backgroundColor:Colors.white10,valueColor:const AlwaysStoppedAnimation(AppTheme.cyan),
        ))),
        const SizedBox(width:10),
        Text('Next sync ${secondsRemaining}s',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),
      ]),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.onSubmitted,
    required this.onPropertySelected,
  });

  final ValueChanged<String> onSubmitted;
  final ValueChanged<Map<String, dynamic>> onPropertySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (option) => '${option['full_address'] ?? ''}',
        optionsBuilder: (value) async {
          final query=value.text.trim();
          if(query.length<2)return const <Map<String,dynamic>>[];
          try{
            final result=await _callRpc('bridgepoint_flutter_property_suggestions_v77',{
              'p_query':query,'p_state_code':'CT','p_limit':8,
            });
            return _detailList(result['suggestions']);
          }catch(_){return const <Map<String,dynamic>>[];}
        },
        onSelected: onPropertySelected,
        fieldViewBuilder:(context,controller,focusNode,onFieldSubmitted)=>TextField(
          controller:controller,
          focusNode:focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted:(value){onSubmitted(value);onFieldSubmitted();},
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted),
            hintText: 'Start typing an address or parcel',
            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        optionsViewBuilder:(context,onSelected,options)=>Align(
          alignment:Alignment.topLeft,
          child:Material(
            color:AppTheme.panel,
            elevation:18,
            borderRadius:BorderRadius.circular(13),
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:480,maxHeight:330),
              child:ListView.separated(
                padding:const EdgeInsets.all(7),
                shrinkWrap:true,
                itemCount:options.length,
                separatorBuilder:(_,__)=>Divider(height:1,color:Colors.white.withOpacity(.05)),
                itemBuilder:(context,index){
                  final option=options.elementAt(index);
                  return InkWell(
                    onTap:()=>onSelected(option),
                    borderRadius:BorderRadius.circular(9),
                    child:Padding(
                      padding:const EdgeInsets.symmetric(horizontal:11,vertical:10),
                      child:Row(children:[
                        Container(width:34,height:34,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.09),borderRadius:BorderRadius.circular(9)),child:const Icon(Icons.home_work_outlined,color:AppTheme.cyan,size:18)),
                        const SizedBox(width:10),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text('${option['full_address']??'Property'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
                          const SizedBox(height:3),
                          Text('${option['municipality']??'Connecticut'} • Parcel ${option['parcel_number']??'not listed'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
                        ])),
                        if(option['top_score']!=null)_OpportunityChip(label:'${option['top_score']}',color:AppTheme.green),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(index),
            avatar: Icon(item.icon, size: 17),
            label: Text(item.label),
          );
        },
      ),
    );
  }
}

class _DailyBriefPage extends StatefulWidget{
  const _DailyBriefPage({super.key,required this.overview});
  final Widget overview;
  @override State<_DailyBriefPage> createState()=>_DailyBriefPageState();
}

class _DailyBriefPageState extends State<_DailyBriefPage>{
  late Future<Map<String,dynamic>> request;
  late Future<Map<String,dynamic>> fieldNoteRequest;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final overnight=data['overnight'] is Map?Map<String,dynamic>.from(data['overnight'] as Map):const <String,dynamic>{};
      final top=(data['top_opportunities'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:46,height:46,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.wb_sunny_outlined,color:Colors.white)),
            const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Welcome to BridgePoint Intelligence, ${data['display_name']??'there'}',style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
              const SizedBox(height:4),Text(snapshot.connectionState==ConnectionState.waiting?'Building your live Daily Brief…':'Here is what changed in the last 24 hours and what deserves attention now.',style:const TextStyle(color:AppTheme.textMuted,fontSize:11)),
            ])),
            IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState((){request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});}),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
          ]),
          if(snapshot.hasError)...[const SizedBox(height:12),Text('The Daily Brief could not load yet. Your main workspace is still available.',style:TextStyle(color:AppTheme.amber))],
          if(snapshot.hasData)...[const SizedBox(height:18),Wrap(spacing:10,runSpacing:10,children:[
            _MiniStat(label:'NEW EVIDENCE',value:_compactNumber(overnight['new_signals'])),
            _MiniStat(label:'SOURCES REFRESHED',value:_compactNumber(overnight['refreshed_sources'])),
            _MiniStat(label:'OPPORTUNITY UPDATES',value:_compactNumber(overnight['strict_opportunity_updates'])),
            _MiniStat(label:'FOLLOW-UPS DUE',value:_compactNumber(overnight['follow_ups_due'])),
            _MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
          ]),
          if(top.isNotEmpty)...[const SizedBox(height:18),const Text('Start here today',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:8),
            ...top.take(3).map((o)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12)),child:Row(children:[
              Icon(_opportunityTypeIcon(o),color:_opportunityTypeColor(o),size:20),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${o['full_address']??o['title']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:11)),Text('${o['title']} • ${o['recommended_action']??'Review the evidence'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.35))])),Text('${(o['score'] as num?)?.toStringAsFixed(1)??'—'}',style:const TextStyle(color:AppTheme.green,fontWeight:FontWeight.w900,fontSize:16)),
            ])))),
          ],
          ],
        ]))),
        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:fieldNoteRequest,builder:(context,noteSnapshot){
            final note=noteSnapshot.data;
            if(note==null||note['enabled']!=true)return const SizedBox.shrink();
            return _FieldNoteCard(note:note);
          },
        ),
        const SizedBox(height:18),const _BridgePointDifferencePanel(),
        const SizedBox(height:18),widget.overview,
      ]);
    });
}

class _FieldNoteCard extends StatelessWidget{
  const _FieldNoteCard({required this.note});
  final Map<String,dynamic> note;
  @override Widget build(BuildContext context){
    final category='${note['category']??'FIELD NOTE'}'.replaceAll('_',' ');
    final safety=category=='SAFETY';
    final accent=safety?AppTheme.amber:AppTheme.cyan;
    return Transform.rotate(
      angle:-.006,
      child:Container(
        width:double.infinity,
        padding:const EdgeInsets.fromLTRB(22,20,22,20),
        decoration:BoxDecoration(
          color:const Color(0xFFF7EFCB),
          borderRadius:BorderRadius.circular(4),
          boxShadow:[BoxShadow(color:Colors.black.withOpacity(.28),blurRadius:18,offset:const Offset(0,8))],
          border:Border(left:BorderSide(color:accent,width:5)),
        ),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(safety?Icons.health_and_safety_outlined:Icons.edit_note_rounded,color:const Color(0xFF23375B),size:30),
          const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('FIELD NOTE OF THE DAY • $category',style:const TextStyle(color:Color(0xFF826C2B),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8)),
            const SizedBox(height:6),Text('${note['title']??'A useful reminder'}',style:const TextStyle(color:Color(0xFF172441),fontSize:16,fontWeight:FontWeight.w900)),
            const SizedBox(height:6),Text('${note['message']??''}',style:const TextStyle(color:Color(0xFF34415B),fontSize:11,height:1.5,fontStyle:FontStyle.italic)),
            const SizedBox(height:10),Text('— ${note['signed_by']??'Kole Johnson, Founder'}',style:const TextStyle(color:Color(0xFF172441),fontSize:10,fontWeight:FontWeight.w900,fontStyle:FontStyle.italic)),
          ])),
          Tooltip(message:'Original BridgePoint guidance. Company owners and co-owners can turn Field Notes off in Team settings.',child:Icon(Icons.info_outline_rounded,color:const Color(0xFF826C2B).withOpacity(.75),size:18)),
        ]),
      ),
    );
  }
}

class _BridgePointDifferencePanel extends StatelessWidget{
  const _BridgePointDifferencePanel();
  @override Widget build(BuildContext context)=>Card(child:Padding(
    padding:const EdgeInsets.all(18),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _PanelHeader(title:'Why BridgePoint feels different',subtitle:'One explainable workflow from changing evidence to real field action',action:'Tap to learn'),
      const SizedBox(height:12),
      LayoutBuilder(builder:(context,c){final width=c.maxWidth>=850?(c.maxWidth-24)/4:c.maxWidth>=520?(c.maxWidth-8)/2:c.maxWidth;return Wrap(spacing:8,runSpacing:8,children:[
        _DifferenceItem(width:width,icon:Icons.fact_check_outlined,title:'Strict evidence',body:'Corroboration, recency, confidence and source diversity must clear the model gate before a lead ranks.'),
        _DifferenceItem(width:width,icon:Icons.timeline_rounded,title:'One property story',body:'Signals, transfers, claims, notes and actions stay organized on a single property timeline.'),
        _DifferenceItem(width:width,icon:Icons.radar_rounded,title:'Live context',body:'Official radar and changing source evidence sit beside property-level intelligence instead of in another app.'),
        _DifferenceItem(width:width,icon:Icons.directions_walk_rounded,title:'Field-ready action',body:'Save the best properties, build a route, record a visit and schedule the next action without losing context.'),
      ]);}),
    ]),
  ));
}

class _DifferenceItem extends StatelessWidget{
  const _DifferenceItem({required this.width,required this.icon,required this.title,required this.body});
  final double width;final IconData icon;final String title,body;
  @override Widget build(BuildContext context)=>SizedBox(width:width,child:InkWell(
    borderRadius:BorderRadius.circular(12),
    onTap:()=>_showInfoDialog(context,title,body),
    child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.58),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.06))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:AppTheme.cyan,size:21),const SizedBox(height:8),Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:4),Text(body,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
    ])),
  ));
}

class _WalkthroughDialog extends StatefulWidget{
  const _WalkthroughDialog();
  @override State<_WalkthroughDialog> createState()=>_WalkthroughDialogState();
}
class _WalkthroughDialogState extends State<_WalkthroughDialog>{
  int step=0;
  static const steps=<({IconData icon,String title,String body})>[
    (icon:Icons.wb_sunny_outlined,title:'Start with your Daily Brief',body:'BridgePoint welcomes you by profile name and summarizes new evidence, refreshed sources, opportunity changes, alerts, and follow-ups from the last 24 hours.'),
    (icon:Icons.map_rounded,title:'See different opportunities instantly',body:'Map colors identify the opportunity: amber for roofing, red for fire, purple for storms, blue for flood/FEMA, green for solar or investment, and cyan for commercial or development.'),
    (icon:Icons.psychology_alt_rounded,title:'Understand why—without jargon',body:'Opportunity score ranks potential. Confidence measures evidence reliability. “Why this property,” “Why now,” evidence counts, and a suggested next action explain every lead.'),
    (icon:Icons.bookmark_add_outlined,title:'Turn intelligence into work',body:'Save an opportunity, choose a lead stage, add a preset or custom note, and schedule the next action. My Work keeps the pipeline and calendar together.'),
    (icon:Icons.notifications_active_outlined,title:'Stay ahead automatically',body:'Choose which alerts you want. BridgePoint refreshes in the background and keeps your Daily Brief and notification history synchronized across devices.'),
  ];
  @override Widget build(BuildContext context){final s=steps[step];return Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:620),child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Skip tour'))),
    Container(width:70,height:70,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.12),shape:BoxShape.circle),child:Icon(s.icon,color:AppTheme.cyan,size:34)),const SizedBox(height:18),
    Text(s.title,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text(s.body,textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted,height:1.55,fontSize:12)),const SizedBox(height:22),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(steps.length,(i)=>Container(width:i==step?24:8,height:8,margin:const EdgeInsets.symmetric(horizontal:3),decoration:BoxDecoration(color:i==step?AppTheme.cyan:AppTheme.panelSoft,borderRadius:BorderRadius.circular(9))))),const SizedBox(height:22),
    Row(children:[if(step>0)OutlinedButton(onPressed:()=>setState(()=>step--),child:const Text('Back')),const Spacer(),FilledButton.icon(onPressed:(){if(step==steps.length-1){Navigator.pop(context);}else{setState(()=>step++);}},icon:Icon(step==steps.length-1?Icons.check_rounded:Icons.arrow_forward_rounded),label:Text(step==steps.length-1?'Finish':'Next'))]),
  ]))));}
}

class _NotificationCenterDialog extends StatefulWidget{
  const _NotificationCenterDialog();
  @override State<_NotificationCenterDialog> createState()=>_NotificationCenterDialogState();
}
class _NotificationCenterDialogState extends State<_NotificationCenterDialog>{
  late Future<Map<String,dynamic>> request;
  bool inApp=true,device=false,critical=true,followUps=true,sourceHealth=true,daily=true;
  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load() async{final d=await _callRpc('bridgepoint_notifications_v74',{'p_limit':50});final p=d['preferences'];if(p is Map){inApp=p['in_app_enabled']!=false;device=p['device_push_enabled']==true;critical=p['critical_opportunities']!=false;followUps=p['saved_follow_ups']!=false;sourceHealth=p['source_health']!=false;daily=p['daily_brief']!=false;}return d;}
  Future<void> _save() async{await _callRpc('bridgepoint_update_notification_preferences_v74',{'p_in_app_enabled':inApp,'p_device_push_enabled':device,'p_critical_opportunities':critical,'p_saved_follow_ups':followUps,'p_source_health':sourceHealth,'p_daily_brief':daily});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Notification preferences saved.')));}
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760,maxHeight:720),child:FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){final d=snapshot.data??const <String,dynamic>{};final items=(d['notifications'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();return Padding(padding:const EdgeInsets.all(22),child:Column(children:[
    Row(children:[const Icon(Icons.notifications_active_outlined,color:AppTheme.cyan),const SizedBox(width:10),const Expanded(child:Text('Notification Center',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900))),Text('${d['unread_count']??0} unread',style:const TextStyle(color:AppTheme.cyan,fontSize:11)),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
    const SizedBox(height:8),Wrap(spacing:8,runSpacing:4,children:[FilterChip(label:const Text('Daily Brief'),selected:daily,onSelected:(v)=>setState(()=>daily=v)),FilterChip(label:const Text('Critical opportunities'),selected:critical,onSelected:(v)=>setState(()=>critical=v)),FilterChip(label:const Text('Saved follow-ups'),selected:followUps,onSelected:(v)=>setState(()=>followUps=v)),FilterChip(label:const Text('Source health'),selected:sourceHealth,onSelected:(v)=>setState(()=>sourceHealth=v)),FilterChip(label:const Text('In-app alerts'),selected:inApp,onSelected:(v)=>setState(()=>inApp=v)),FilterChip(label:const Text('Device push'),selected:device,onSelected:(v)=>setState(()=>device=v))]),
    const SizedBox(height:10),Row(children:[FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),const SizedBox(width:8),TextButton(onPressed:()async{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':null});if(mounted)setState(()=>request=_load());},child:const Text('Mark all read'))]),const Divider(),
    Expanded(child:snapshot.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('No alerts yet. BridgePoint will add them as your intelligence changes.',style:TextStyle(color:AppTheme.textMuted))):ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i){final n=items[i];final unread=n['read_at']==null;return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),leading:CircleAvatar(backgroundColor:(unread?AppTheme.cyan:AppTheme.textMuted).withOpacity(.12),child:Icon(_notificationIcon('${n['notification_type']}'),color:unread?AppTheme.cyan:AppTheme.textMuted,size:20)),title:Text('${n['title']}',style:TextStyle(color:Colors.white,fontWeight:unread?FontWeight.w800:FontWeight.w500)),subtitle:Text('${n['message']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),trailing:unread?const Icon(Icons.circle,color:AppTheme.cyan,size:8):null);}))
  ]));})));
}

IconData _notificationIcon(String type){if(type.contains('CRITICAL'))return Icons.bolt_rounded;if(type.contains('FOLLOW'))return Icons.event_available_outlined;if(type.contains('SOURCE'))return Icons.hub_outlined;return Icons.wb_sunny_outlined;}

Future<bool> _ensureFieldTrackingConsent(BuildContext context)async{
  final legal=await _callRpc('bridgepoint_legal_state_v82',const {});
  final documents=(legal['documents'] as List? ?? const [])
      .whereType<Map>()
      .map((d)=>Map<String,dynamic>.from(d))
      .toList();
  final notice=documents.firstWhere(
    (d)=>d['document_key']=='FIELD_TRACKING_NOTICE',
    orElse:()=>const <String,dynamic>{},
  );
  if(notice['accepted']==true)return true;
  if(!context.mounted)return false;
  var checked=false;
  final agreed=await showDialog<bool>(context:context,barrierDismissible:false,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
    backgroundColor:AppTheme.panel,title:const Row(children:[Icon(Icons.share_location_rounded,color:AppTheme.cyan),SizedBox(width:9),Expanded(child:Text('Live Field Assist consent'))]),
    content:SizedBox(width:680,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SelectableText('${notice['content_markdown']??'Location is shared only during an active field shift, is visible to authorized company supervisors, and is deleted after seven days.'}'.replaceAll('# ',''),style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.55)),
      const SizedBox(height:12),CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,value:checked,onChanged:(v)=>setLocal(()=>checked=v==true),title:const Text('I understand and choose to share my location for this field shift.',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800))),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Not now')),FilledButton(onPressed:checked?()=>Navigator.pop(dialogContext,true):null,child:const Text('Accept & continue'))],
  )));
  if(agreed!=true)return false;
  await _callRpc('bridgepoint_accept_legal_v82',{'p_document_keys':['FIELD_TRACKING_NOTICE'],'p_acceptance_source':'FIELD_SHIFT_CONSENT'});
  return true;
}

void _showFaqDialog(BuildContext context)=>showDialog<void>(
  context:context,builder:(context)=>const _FaqDialog(),
);

class _FaqDialog extends StatefulWidget{
  const _FaqDialog();
  @override State<_FaqDialog> createState()=>_FaqDialogState();
}

class _FaqDialogState extends State<_FaqDialog>{
  String query='';
  static const entries=<({String question,String answer})>[
    (question:'What does an opportunity score mean?',answer:'The score ranks how actionable a property looks after BridgePoint checks evidence strength, recency, confidence, source diversity, property fit, and the model’s strict gates. It is a prioritization tool—not a guarantee of a sale, loss, permit, or claim.'),
    (question:'What is confidence, and how is it different from score?',answer:'Score estimates opportunity priority. Confidence estimates how reliable and well-supported the evidence is. A high score with weak confidence should not clear the strict ranking gate.'),
    (question:'Why do matches, signals, and patterns show different counts?',answer:'A signal is one supporting observation. A pattern connects multiple observations over time. A model match is direct evidence that satisfies a specific opportunity rule. Patterns can add context, but a property with no qualifying direct match should not outrank corroborated opportunities in strict mode.'),
    (question:'Can a score go down?',answer:'Yes. BridgePoint V81 uses negative scoring. Missing direct matches, missing corroboration, weak source diversity, older evidence, and lower confidence subtract visible points. The intelligence suite also keeps only the best qualifying opportunity per property, so the lead list stays finite and useful.'),
    (question:'What do the map colors and symbols mean?',answer:'The same intelligence type always keeps the same color and icon. Round markers are ranked opportunities. Diamond markers are supporting signals. Tap any marker or legend item for the source, timing, evidence, confidence, and next step.'),
    (question:'Is the radar live?',answer:'The radar layer uses the official NOAA/NWS Multi-Radar Multi-Sensor reflectivity service. It is live weather context, not a meteorologist-verified hail swath or proof that a specific property was damaged.'),
    (question:'How often does BridgePoint update?',answer:'The workspace refreshes on the interval selected in Settings. Each source also follows its own lawful source schedule. The live strip shows the next app sync; source cards show their health and refresh behavior.'),
    (question:'How do I save an opportunity and follow up?',answer:'Open an opportunity, choose Save opportunity, add a preset or custom note, and set the lead stage or next action. My Work keeps saved properties, follow-ups, claim tasks, and calendar work together.'),
    (question:'How does the Company plan work?',answer:'BridgePoint Company includes five seats, All Intelligence models, shared opportunities, shared notes and field visits, and owner/manager/member/viewer roles. Claims remain private unless a customer explicitly authorizes sharing.'),
    (question:'How does Live Field Assist protect privacy?',answer:'Field tracking is never hidden. A Company-plan user must explicitly start a field shift, sees a permanent sharing indicator, and can stop at any time. Owners, co-owners, and managers can see active teammates. Locations disappear from the live view after 15 minutes and are deleted after seven days.'),
    (question:'What is a co-owner?',answer:'A co-owner is a separate verified backup account for a trusted person. They can manage the company workspace and help when the primary owner is unavailable. Only the primary owner can appoint a co-owner or change the primary owner.'),
    (question:'Can I change my plan later?',answer:'Yes. Open Settings and choose Change plan / manage billing. Stripe securely handles plan changes, monthly or annual billing, payment methods, invoices, and cancellation.'),
    (question:'How does the 7-day free trial work?',answer:'Eligible new customers can explore the included package for seven days. A payment method is not required to begin the trial. The first ten paying customers also receive 50% off their selected plan for the first six monthly payments when eligible.'),
    (question:'How do notifications work?',answer:'Use the bell or Settings to choose Daily Brief, critical opportunity, saved follow-up, source-health, in-app, and device-push preferences. Device push also requires browser or operating-system permission.'),
    (question:'What is the property timeline?',answer:'It is a chronological property story combining source evidence, signals, transitions, saved work, notes, and authorized claim events so users can understand what changed and when.'),
    (question:'Why are other states visible but locked?',answer:'BridgePoint shows planned markets so customers can request them. A state cannot be sold or unlocked until its property inventory, automatic source pipelines, scoring, legal access, and quality checks are live.'),
    (question:'What is the Homeowner plan?',answer:'BridgePoint Homeowner is a lower-cost workspace for monitoring one home with plain-language property context, live weather, a property timeline, maintenance or claim reminders, notes, and alerts.'),
    (question:'Can I install BridgePoint on my device?',answer:'Yes. The hosted web app is installable from Chrome, Edge, and supported mobile browsers using Install app or Add to Home Screen. Native store releases require the normal Apple and Google signing and review steps.'),
    (question:'What should I do if information looks old or wrong?',answer:'Open the source and timeline details first to check the source date. Then use Settings → Suggestions & feedback and choose Data request or Something is not working. Include the property and the field that needs review.'),
    (question:'How does BridgePoint protect customer data?',answer:'Customer work is available only through authenticated, checked APIs. Direct access to private workspace tables is denied. Team roles control company access, and sensitive claim details remain private by default.'),
  ];
  @override Widget build(BuildContext context){
    final needle=query.trim().toLowerCase();
    final visible=entries.where((e)=>needle.isEmpty||e.question.toLowerCase().contains(needle)||e.answer.toLowerCase().contains(needle)).toList();
    return Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:820,maxHeight:760),child:Padding(
      padding:const EdgeInsets.all(22),child:Column(children:[
        Row(children:[const Icon(Icons.help_center_outlined,color:AppTheme.cyan),const SizedBox(width:10),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Help & Frequently Asked Questions',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),
          SizedBox(height:3),Text('Plain-language answers for customers, teams, and homeowners.',style:TextStyle(color:AppTheme.textMuted,fontSize:10)),
        ])),IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
        const SizedBox(height:14),TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Search questions',hintText:'Try “score,” “team,” “radar,” or “plan”',border:OutlineInputBorder())),
        const SizedBox(height:12),Expanded(child:visible.isEmpty?const Center(child:Text('No matching question. Send your question from Settings → Suggestions & feedback.',textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textMuted))):ListView.separated(
          itemCount:visible.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(context,i){final item=visible[i];return Card(color:AppTheme.panelSoft.withOpacity(.7),child:ExpansionTile(
            leading:const Icon(Icons.question_answer_outlined,color:AppTheme.cyan,size:19),title:Text(item.question,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),
            children:[Padding(padding:const EdgeInsets.fromLTRB(18,0,18,16),child:Align(alignment:Alignment.centerLeft,child:Text(item.answer,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.55))))],
          ));},
        )),
      ]),
    )));
  }
}

class _LegalCenterDialog extends StatefulWidget{
  const _LegalCenterDialog();
  @override State<_LegalCenterDialog> createState()=>_LegalCenterDialogState();
}
class _LegalCenterDialogState extends State<_LegalCenterDialog>{
  late Future<Map<String,dynamic>> request;
  String privacyType='ACCESS';final privacyMessage=TextEditingController();bool sending=false;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_legal_state_v82',const {});}
  @override void dispose(){privacyMessage.dispose();super.dispose();}
  Future<void> sendPrivacyRequest()async{
    setState(()=>sending=true);
    try{await _callRpc('bridgepoint_submit_privacy_request_v82',{'p_request_type':privacyType,'p_message':privacyMessage.text.trim()});privacyMessage.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Privacy request received. BridgePoint will verify identity before acting.')));}
    catch(e){if(mounted)_showInfoDialog(context,'Could not submit privacy request',e.toString());}
    finally{if(mounted)setState(()=>sending=false);}
  }
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900,maxHeight:800),child:FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final docs=(snapshot.data?['documents'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      return Padding(padding:const EdgeInsets.all(22),child:Column(children:[
        Row(children:[const Icon(Icons.policy_outlined,color:AppTheme.cyan),const SizedBox(width:10),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Legal & Trust Center',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('Plain-language controls backed by versioned acceptance records.',style:TextStyle(color:AppTheme.textMuted,fontSize:10))])),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
        const SizedBox(height:12),Expanded(child:snapshot.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):ListView(children:[
          ...docs.map((d)=>Card(color:AppTheme.panelSoft.withOpacity(.72),child:ExpansionTile(
            leading:Icon(d['accepted']==true?Icons.verified_user_rounded:Icons.policy_outlined,color:d['accepted']==true?AppTheme.green:AppTheme.amber),
            title:Text('${d['title']}',style:const TextStyle(fontWeight:FontWeight.w900)),
            subtitle:Text('Version ${d['document_version']} • ${d['accepted']==true?'Accepted':'Not accepted'}\n${d['summary']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
            children:[Padding(padding:const EdgeInsets.fromLTRB(18,0,18,18),child:SelectableText('${d['content_markdown']}'.replaceAll('# ',''),style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.55)))],
          ))),
          const SizedBox(height:10),Card(color:AppTheme.cyan.withOpacity(.05),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Privacy request',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Request access, correction, deletion, a portable copy, or appeal a prior decision. We verify identity before changing or releasing data.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),const SizedBox(height:12),
            DropdownButtonFormField<String>(value:privacyType,decoration:const InputDecoration(labelText:'Request type',border:OutlineInputBorder()),dropdownColor:AppTheme.panelSoft,items:const [
              DropdownMenuItem(value:'ACCESS',child:Text('Access my data')),DropdownMenuItem(value:'CORRECTION',child:Text('Correct my data')),DropdownMenuItem(value:'DELETION',child:Text('Delete my data')),DropdownMenuItem(value:'PORTABILITY',child:Text('Portable copy')),DropdownMenuItem(value:'APPEAL',child:Text('Appeal a decision')),DropdownMenuItem(value:'OTHER',child:Text('Other privacy question')),
            ],onChanged:sending?null:(v)=>setState(()=>privacyType=v??'ACCESS')),
            const SizedBox(height:9),TextField(controller:privacyMessage,maxLines:3,decoration:const InputDecoration(labelText:'Details (optional)',border:OutlineInputBorder())),const SizedBox(height:9),FilledButton.icon(onPressed:sending?null:sendPrivacyRequest,icon:const Icon(Icons.send_outlined),label:Text(sending?'Sending…':'Submit verified request')),
          ]))),
          const SizedBox(height:12),const Text('Important: these safeguards reduce risk but are not a substitute for review by a licensed attorney familiar with your launch states, contracts, insurance workflows, privacy practices, and outreach methods.',style:TextStyle(color:AppTheme.amber,fontSize:10,height:1.5)),
        ])),
      ]));
    },
  )));
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.selectedPackage,
    required this.dashboardRequest,
    required this.sourcesRequest,
    required this.onRefresh,
    required this.onNavigate,
  });

  final String selectedPackage;
  final Future<Map<String, dynamic>> dashboardRequest;
  final Future<Map<String, dynamic>> sourcesRequest;
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: dashboardRequest,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 18,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Intelligence Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$selectedPackage • Connecticut statewide',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.green.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (loading)
                            const SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.green,
                              ),
                            )
                          else
                            const _PulseDot(color: AppTheme.green),
                          const SizedBox(width: 8),
                          Text(
                            loading ? 'SYNCING LIVE DATA' : 'LIVE DATA',
                            style: const TextStyle(
                              color: AppTheme.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: Icons.refresh_rounded,
                      onTap: loading ? () {} : onRefresh,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: onRefresh,
              )
            else ...[
              _MetricGrid(
                data: data,
                loading: loading,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 20),
              _MainDashboardRow(data: data, loading: loading),
              const SizedBox(height: 20),
              _SourcesPanel(sourcesRequest: sourcesRequest),
            ],
          ],
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.data,
    required this.loading,
    required this.onNavigate,
  });

  final Map<String, dynamic>? data;
  final bool loading;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050 ? 4 : (width >= 620 ? 2 : 1);
        const gap = 14.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _MetricCard(
              width: itemWidth,
              label: 'CT PROPERTIES',
              value: loading
                  ? '—'
                  : _formatInteger(data?['property_count_estimate']),
              detail: 'Imported CT CAMA / parcel inventory',
              icon: Icons.home_work_outlined,
              accent: AppTheme.cyan,
              onTap: () => onNavigate(4),
            ),
            _MetricCard(
              width: itemWidth,
              label: 'INTELLIGENCE SOURCES',
              value: loading
                  ? '—'
                  : _formatInteger(data?['connected_source_families']),
              detail: 'Storm • Fire • FEMA • Grid • Transitions',
              icon: Icons.hub_outlined,
              accent: AppTheme.blue,
              onTap: () => onNavigate(6),
            ),
            _MetricCard(
              width: itemWidth,
              label: 'ACTIVE PATTERNS',
              value: loading
                  ? '—'
                  : _formatInteger(data?['active_patterns']),
              detail: 'V36 compound property intelligence',
              icon: Icons.account_tree_outlined,
              accent: AppTheme.amber,
              onTap: () => onNavigate(5),
            ),
            _MetricCard(
              width: itemWidth,
              label: 'AUTOMATION',
              value: loading ? 'SYNCING' : 'ACTIVE',
              detail: loading
                  ? 'Loading current intelligence'
                  : '${_formatInteger(data?['active_opportunities'])} active opportunities',
              icon: Icons.sync_rounded,
              accent: AppTheme.green,
              onTap: () => onNavigate(1),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? ()=>_showInfoDialog(
            context,
            label.replaceAll('_',' '),
            '$detail\n\nCurrent value: $value\n\nThis card summarizes the live data shown on this page. Refreshing the page asks BridgePoint for the newest available result.',
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  Icon(
                    onTap==null?Icons.info_outline_rounded:Icons.arrow_forward_rounded,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainDashboardRow extends StatelessWidget {
  const _MainDashboardRow({required this.data, required this.loading});

  final Map<String, dynamic>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              _OpportunityPanel(data: data, loading: loading),
              const SizedBox(height: 20),
              _CoveragePanel(data: data, loading: loading),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _OpportunityPanel(data: data, loading: loading),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _CoveragePanel(data: data, loading: loading),
            ),
          ],
        );
      },
    );
  }
}

class _OpportunityPanel extends StatelessWidget {
  const _OpportunityPanel({required this.data, required this.loading});

  final Map<String, dynamic>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final rawRows = data?['ranked_opportunities'];
    final opportunities = rawRows is List
        ? rawRows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : <Map<String, dynamic>>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              title: 'Ranked Opportunities',
              subtitle: 'Highest-value properties from active models',
              action: 'View all',
            ),
            const SizedBox(height: 18),
            if (loading)
              const _OpportunityLoading()
            else if (opportunities.isEmpty)
              const _OpportunityEmpty()
            else
              ...opportunities.take(5).toList().asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == opportunities.take(5).length - 1
                            ? 0
                            : 10,
                      ),
                      child: _OpportunityRow(
                        rank: entry.key + 1,
                        opportunity: entry.value,
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            _ModelProgress(
              label: 'Property matching',
              status: loading ? 'Connecting…' : 'Connected',
              color: AppTheme.cyan,
              value: loading ? null : 1,
            ),
            const SizedBox(height: 12),
            _ModelProgress(
              label: 'Live opportunity feed',
              status: loading
                  ? 'Loading…'
                  : '${opportunities.length} ranked rows loaded',
              color: AppTheme.blue,
              value: loading ? null : 1,
            ),
            const SizedBox(height: 12),
            _ModelProgress(
              label: 'Package filter',
              status: loading ? 'Loading…' : 'Active',
              color: AppTheme.green,
              value: loading ? null : 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({
    required this.rank,
    required this.opportunity,
  });

  final int rank;
  final Map<String, dynamic> opportunity;

  @override
  Widget build(BuildContext context) {
    final priority = (opportunity['priority'] ?? 'monitor').toString();
    final priorityColor = _priorityColor(priority);
    final score = _formatDecimal(opportunity['score']);
    final confidence = _formatDecimal(opportunity['confidence_score']);
    final address = (opportunity['full_address'] ?? 'Address unavailable')
        .toString();
    final signal = (opportunity['top_signal_type'] ?? 'intelligence signal')
        .toString()
        .replaceAll('_', ' ');

    return InkWell(
      onTap: () => _showPropertyInventoryDetail(context, opportunity),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppTheme.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_titleCase(signal)} • $confidence% confidence',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: priorityColor.withOpacity(0.25)),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _OpportunityLoading extends StatelessWidget {
  const _OpportunityLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 2.5),
          SizedBox(height: 13),
          Text(
            'Loading ranked opportunities…',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OpportunityEmpty extends StatelessWidget {
  const _OpportunityEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.radar_rounded, color: AppTheme.cyan, size: 34),
            SizedBox(height: 10),
            Text(
              'No active opportunities in this package yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'BridgePoint will display them here as scoring completes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppTheme.red),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live dashboard could not load',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.data, required this.loading});

  final Map<String, dynamic>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              title: 'Connecticut Coverage',
              subtitle: 'Current intelligence foundation',
              action: 'Map',
            ),
            const SizedBox(height: 18),
            Container(
              height: 164,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.blue.withOpacity(0.17),
                    AppTheme.cyan.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.cyan.withOpacity(0.14)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.cyan,
                          size: 38,
                        ),
                        SizedBox(height: 7),
                        Text(
                          'STATEWIDE CT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '8 counties • 169 municipalities',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CoverageRow(
              'Property records',
              loading
                  ? '—'
                  : _formatCompact(data?['property_count_estimate']),
              AppTheme.cyan,
            ),
            _CoverageRow(
              'Active source families',
              loading
                  ? '—'
                  : _formatInteger(data?['connected_source_families']),
              AppTheme.blue,
            ),
            _CoverageRow(
              'Intelligence packages',
              loading
                  ? '—'
                  : _formatInteger(data?['active_property_packages']),
              AppTheme.green,
            ),
            const _CoverageRow('Grid source records', '175', AppTheme.amber),
          ],
        ),
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.sourcesRequest});

  final Future<Map<String, dynamic>> sourcesRequest;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: sourcesRequest,
      builder: (context, snapshot) {
        final raw = snapshot.data?['sources'];
        final sources = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeader(
                  title: 'Connected Intelligence Sources',
                  subtitle: 'Live source registry • Connecticut intelligence',
                  action: 'Source health',
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(
                    height: 110,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.cyan,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  _InlineError(message: snapshot.error.toString())
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 980
                          ? 3
                          : (constraints.maxWidth >= 560 ? 2 : 1);
                      const gap = 12.0;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) / columns;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: sources
                            .map(
                              (source) => _LiveSourceCard(
                                width: width,
                                source: source,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}







class _ModelsPage extends StatefulWidget {
  const _ModelsPage();

  @override
  State<_ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<_ModelsPage> {
  late Future<Map<String, dynamic>> _request;
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_models'),
          headers: _apiHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Models API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Models response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['models'];
        final allModels = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        final categories = <String>{
          'all',
          ...allModels.map((m) => '${m['model_category'] ?? 'other'}'),
        }.toList();

        final models = _category == 'all'
            ? allModels
            : allModels
                .where((m) => '${m['model_category'] ?? 'other'}' == _category)
                .toList();

        final loading = snapshot.connectionState == ConnectionState.waiting;
        final propertyModels = allModels
            .where((m) => '${m['target_entity_type']}' == 'property')
            .length;
        final unbundled =
            allModels.where((m) => (m['package_count'] as num? ?? 0) == 0).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Models',
              subtitle:
                  'The questions BridgePoint asks of every property • explained plainly',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height:10),
            const _ExplainerBanner(icon:Icons.psychology_alt_rounded,title:'A model is a question—not a prediction of a guaranteed sale',message:'Each model asks whether a property has enough recent, reliable and diverse evidence for a specific customer need. Confidence measures evidence reliability. The strict score prioritizes qualified properties. Only scores of 78+ enter the published queue.'),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE MODELS',
                      value: '${data?['active_model_count'] ?? allModels.length}',
                      detail: 'Live intelligence engines',
                      icon: Icons.psychology_alt_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PROPERTY MODELS',
                      value: '$propertyModels',
                      detail: 'Models targeting properties',
                      icon: Icons.home_work_outlined,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PACKAGE LINKS',
                      value: '${data?['active_package_model_links'] ?? 0}',
                      detail: '$unbundled active model${unbundled == 1 ? '' : 's'} not bundled',
                      icon: Icons.account_tree_outlined,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 280,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: AppTheme.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CATEGORY',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: categories.map((category) {
                            final selected = category == _category;
                            return ChoiceChip(
                              label: Text(
                                category.replaceAll('_', ' ').toUpperCase(),
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                              labelStyle: TextStyle(
                                color:
                                    selected ? Colors.white : AppTheme.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1100
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth >= 720
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: models
                        .map(
                          (model) => SizedBox(
                            width: cardWidth,
                            child: _LiveModelCard(model: model),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LiveModelCard extends StatelessWidget {
  const _LiveModelCard({required this.model});

  final Map<String, dynamic> model;

  @override
  Widget build(BuildContext context) {
    final rawPackages = model['packages'];
    final packages = rawPackages is List
        ? rawPackages
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final category = '${model['model_category'] ?? 'intelligence'}';
    final target = '${model['target_entity_type'] ?? 'entity'}';

    return Card(
      child: InkWell(
        onTap: () => _showModelDetail(context, model),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _modelIcon(category),
                      color: AppTheme.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${category.toUpperCase()} • ${target.toUpperCase()}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OpportunityChip(
                    label: model['active'] == true ? 'ACTIVE' : 'INACTIVE',
                    color: model['active'] == true
                        ? AppTheme.green
                        : AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                '${model['customer_outcome'] ?? model['description'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _ModelThreshold(
                      label: 'PUBLISHED',
                      value: 78,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModelThreshold(
                      label: 'HIGH',
                      value: 82,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModelThreshold(
                      label: 'CRITICAL',
                      value: 85,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModelThreshold(
                      label: 'CONFIDENCE',
                      value: '85%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'AVAILABLE IN',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 7),
              if (packages.isEmpty)
                const Text(
                  'Internal / not currently bundled',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: packages
                      .map(
                        (p) => _OpportunityChip(
                          label: '${p['package_name'] ?? p['package_key']}',
                          color: p['featured'] == true
                              ? AppTheme.cyan
                              : AppTheme.blue,
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 13),
              Row(children:[
                Expanded(child:Text('${model['strict_qualified_count']??0} strict live result${model['strict_qualified_count']==1?'':'s'}',style:const TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w800))),
                if(model['strict_top_score']!=null)Text('Top ${model['strict_top_score']}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w800)),
              ]),
              const SizedBox(height:10),
              Row(
                children: [
                  Text(
                    '${packages.length} package${packages.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Inspect model',
                    style: TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.cyan,
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelThreshold extends StatelessWidget {
  const _ModelThreshold({
    required this.label,
    required this.value,
  });

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(.55),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Column(
        children: [
          Text(
            '${value ?? '—'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _modelIcon(String category) {
  switch (category) {
    case 'residential':
      return Icons.home_outlined;
    case 'commercial':
    case 'business':
      return Icons.business_center_outlined;
    case 'contractor':
      return Icons.roofing_outlined;
    case 'development':
      return Icons.location_city_outlined;
    case 'energy':
      return Icons.solar_power_outlined;
    case 'infrastructure':
      return Icons.construction_outlined;
    case 'investment':
      return Icons.trending_up_rounded;
    case 'custom':
      return Icons.tune_rounded;
    default:
      return Icons.psychology_alt_outlined;
  }
}

void _showModelDetail(
  BuildContext context,
  Map<String, dynamic> model,
) {
  final rawPackages = model['packages'];
  final packages = rawPackages is List
      ? rawPackages
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _modelIcon('${model['model_category'] ?? ''}'),
                      color: AppTheme.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${model['customer_outcome'] ?? model['description'] ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                _ExplainerBanner(icon:Icons.fact_check_outlined,title:'What must be true before this model publishes a result',message:'${model['evidence_requirement']??'The property must clear BridgePoint’s strict evidence, confidence, source-diversity and recency gates.'}'),
                const SizedBox(height:18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'CATEGORY',
                      value: '${model['model_category'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'TARGET',
                      value: '${model['target_entity_type'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'PACKAGES',
                      value: '${model['package_count'] ?? packages.length}',
                    ),
                    _MiniStat(
                      label: 'STRICT RESULTS',
                      value: '${model['strict_qualified_count']??0}',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Strict score guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ModelThreshold(
                        label: 'PUBLISHED',
                        value: 78,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModelThreshold(
                        label: 'HIGH',
                        value: 82,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModelThreshold(
                        label: 'CRITICAL',
                        value: 85,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModelThreshold(
                        label: 'CONFIDENCE',
                        value: '85%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height:18),
                Text('Best for',style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w800)),
                const SizedBox(height:6),
                Text('${model['best_for']??'Property professionals reviewing evidence-backed opportunities'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.5)),
                const SizedBox(height: 22),
                const Text(
                  'Package coverage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (packages.isEmpty)
                  const Text(
                    'This active model is not currently linked to a customer-facing package.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  )
                else
                  ...packages.map(
                    (p) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft.withOpacity(.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: AppTheme.cyan,
                            size: 17,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '${p['package_name'] ?? p['package_key'] ?? 'Package'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${p['package_type'] ?? ''}'.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Model key: ${model['model_key'] ?? '—'}\n'
                  'Model ID: ${model['model_id'] ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.30),
                    fontSize: 9,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CoveragePage extends StatefulWidget{
  const _CoveragePage();
  @override State<_CoveragePage> createState()=>_CoveragePageState();
}

class _CoveragePageState extends State<_CoveragePage>{
  late Future<Map<String,dynamic>> request;
  String region='Northeast';
  @override void initState(){super.initState();request=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {});}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}));
  Future<void> register({String? state,String? bundle})async{
    try{
      final result=await _callRpc('bridgepoint_register_geographic_interest_v77',{
        'p_state_code':state,'p_bundle_key':bundle,
      });
      if(!mounted)return;
      _showInfoDialog(context,'Expansion request saved','${result['message']??'We saved your request.'}');
      refresh();
    }catch(e){if(mounted)_showInfoDialog(context,'Could not save request',e.toString());}
  }
  List<Map<String,dynamic>> rows(dynamic value)=>value is List
      ?value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList()
      :<Map<String,dynamic>>[];

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final markets=rows(data['markets']),bundles=rows(data['bundles']);
      final regions=<String>{'Northeast',...markets.map((m)=>'${m['region_name']}')}.toList();
      final filtered=markets.where((m)=>m['region_name']==region).toList();
      final live=markets.where((m)=>m['data_status']=='LIVE').length;
      final requested=markets.where((m)=>m['interest_registered']==true).length;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PageHeading(title:'Coverage',subtitle:'See what is live now and what BridgePoint can unlock next',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
        const SizedBox(height:10),
        const _ExplainerBanner(icon:Icons.public_rounded,title:'Built for expansion without hiding what is unavailable',message:'Connecticut is live and included. Every other state remains visible, labeled and locked until its property data, automatic sources and billing are fully activated. Requesting a state never charges you.'),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=900?3:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
          _MetricCard(width:w,label:'LIVE STATES',value:'$live',detail:'Connecticut • 1,282,833 active properties',icon:Icons.verified_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'VISIBLE EXPANSION',value:'${markets.length-live}',detail:'Locked markets customers can see and request',icon:Icons.lock_open_rounded,accent:AppTheme.cyan),
          _MetricCard(width:w,label:'YOUR REQUESTS',value:'$requested',detail:'No charge until a live market is purchased',icon:Icons.notifications_active_outlined,accent:AppTheme.amber),
        ]);}),
        const SizedBox(height:18),
        const _PanelHeader(title:'Expansion bundles',subtitle:'Future package deals activate only when every included state is live',action:'Best value'),
        const SizedBox(height:10),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=640?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:bundles.map((b)=>SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.travel_explore_rounded,color:AppTheme.cyan)),const SizedBox(width:10),Expanded(child:Text('${b['bundle_name']}',style:const TextStyle(fontWeight:FontWeight.w900))),_OpportunityChip(label:b['can_purchase']==true?'AVAILABLE':'PLANNED',color:b['can_purchase']==true?AppTheme.green:AppTheme.amber)]),
          const SizedBox(height:10),Text('${b['description']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
          const SizedBox(height:12),Text('\$${b['monthly_price']}/month when live',style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),
          const SizedBox(height:4),Text('${b['live_state_count']??0} of ${b['state_count']??0} states live',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
          const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:b['interest_registered']==true?null:()=>register(bundle:'${b['bundle_key']}'),icon:Icon(b['interest_registered']==true?Icons.check_rounded:Icons.add_alert_rounded),label:Text(b['interest_registered']==true?'REQUESTED':'REQUEST BUNDLE'))),
        ]))))).toList());}),
        const SizedBox(height:20),
        Row(children:[const Expanded(child:_PanelHeader(title:'State markets',subtitle:'Customers can see the growth path before purchasing',action:'50 states')),DropdownButton<String>(value:region,dropdownColor:AppTheme.panel,items:regions.map((r)=>DropdownMenuItem(value:r,child:Text(r))).toList(),onChanged:(v){if(v!=null)setState(()=>region=v);})]),
        const SizedBox(height:10),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1100?4:c.maxWidth>=720?3:c.maxWidth>=480?2:1;const gap=10.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:filtered.map((m){
          final isLive=m['data_status']=='LIVE';final interested=m['interest_registered']==true;final owner=data['is_owner']==true;
          final color=isLive?AppTheme.green:interested?AppTheme.cyan:AppTheme.amber;
          return SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:color.withOpacity(.1),borderRadius:BorderRadius.circular(9)),child:Icon(isLive?Icons.verified_rounded:Icons.lock_outline_rounded,color:color,size:18)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['state_name']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),Text('${m['state_code']} • ${m['data_status']}',style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w800))]))]),
            const SizedBox(height:9),Text(isLive?'Included with every BridgePoint package':owner?'Owner access reserved when this market goes live':'Future add-on from \$${m['monthly_price']}/month',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
            const SizedBox(height:10),if(isLive)const _OpportunityChip(label:'LIVE DATA',color:AppTheme.green)else SizedBox(width:double.infinity,child:TextButton.icon(onPressed:interested?null:()=>register(state:'${m['state_code']}'),icon:Icon(interested?Icons.check_rounded:Icons.add_alert_rounded,size:16),label:Text(interested?'REQUESTED':'NOTIFY ME'))),
          ]))));
        }).toList());}),
        if(snapshot.hasError)...[const SizedBox(height:14),_DashboardError(message:snapshot.error.toString(),onRetry:refresh)],
      ]);
    },
  );
}

class _PackagesPage extends StatefulWidget {
  const _PackagesPage();

  @override
  State<_PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<_PackagesPage> {
  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_packages'),
          headers: _apiHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Packages API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Packages response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['packages'];
        final packages = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final featured =
            packages.where((p) => p['featured'] == true).length;
        final modelCount = (data?['active_model_count'] as num?)?.toInt() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Packages',
              subtitle:
                  'Live BridgePoint product catalog • models • trials • intelligence scope',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE PACKAGES',
                      value: '${data?['active_package_count'] ?? packages.length}',
                      detail: 'Live product catalog',
                      icon: Icons.inventory_2_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE MODELS',
                      value: '$modelCount',
                      detail: 'Intelligence models available',
                      icon: Icons.psychology_alt_outlined,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'FEATURED',
                      value: '$featured',
                      detail: 'Primary BridgePoint packages',
                      icon: Icons.star_outline_rounded,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1150
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth >= 760
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: packages
                        .map(
                          (package) => SizedBox(
                            width: cardWidth,
                            child: _LivePackageCard(package: package),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _LivePackageCard extends StatelessWidget {
  const _LivePackageCard({required this.package});

  final Map<String, dynamic> package;

  @override
  Widget build(BuildContext context) {
    final rawModels = package['models'];
    final models = rawModels is List
        ? rawModels.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final featured = package['featured'] == true;
    final trialDays = (package['trial_days'] as num?)?.toInt();
    final monthly = package['monthly_price'] as num?;
    final yearly = package['yearly_price'] as num?;
    final type = '${package['package_type'] ?? 'standard'}';

    return Card(
      child: InkWell(
        onTap: () => _showPackageDetail(context, package),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: AppTheme.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${package['package_name'] ?? 'BridgePoint Package'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (featured)
                    const _OpportunityChip(
                      label: 'FEATURED',
                      color: AppTheme.green,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${package['description'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OpportunityChip(
                    label: '${models.length} MODEL${models.length == 1 ? '' : 'S'}',
                    color: AppTheme.blue,
                  ),
                  if (trialDays != null)
                    _OpportunityChip(
                      label: '$trialDays DAY TRIAL',
                      color: AppTheme.cyan,
                    ),
                  _OpportunityChip(
                    label: package['active'] == true ? 'ACTIVE' : 'INACTIVE',
                    color: package['active'] == true
                        ? AppTheme.green
                        : AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (models.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.panelSoft.withOpacity(.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Custom intelligence model builder',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                )
              else
                ...models.take(4).map(
                  (model) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppTheme.green,
                          size: 14,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (models.length > 4)
                Text(
                  '+ ${models.length - 4} more models',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      monthly == null && yearly == null
                          ? 'Pricing not configured'
                          : monthly != null
                              ? '\$${monthly.toStringAsFixed(0)} / month'
                              : '\$${yearly!.toStringAsFixed(0)} / year',
                      style: TextStyle(
                        color: monthly == null && yearly == null
                            ? AppTheme.textMuted
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _packageIcon(String key) {
  switch (key) {
    case 'company':
      return Icons.groups_2_outlined;
    case 'homeowner':
      return Icons.cottage_outlined;
    case 'home':
      return Icons.home_work_outlined;
    case 'commercial':
      return Icons.business_outlined;
    case 'solar':
      return Icons.solar_power_outlined;
    case 'investor':
      return Icons.trending_up_rounded;
    case 'infrastructure':
      return Icons.construction_outlined;
    case 'custom_model':
      return Icons.tune_rounded;
    case 'all_intelligence':
      return Icons.all_inclusive_rounded;
    default:
      return Icons.inventory_2_outlined;
  }
}

void _showPackageDetail(
  BuildContext context,
  Map<String, dynamic> package,
) {
  final rawModels = package['models'];
  final models = rawModels is List
      ? rawModels.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: AppTheme.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${package['package_name'] ?? 'BridgePoint Package'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${package['description'] ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'MODELS',
                      value: '${models.length}',
                    ),
                    _MiniStat(
                      label: 'TRIAL',
                      value: '${package['trial_days'] ?? '—'} days',
                    ),
                    _MiniStat(
                      label: 'TYPE',
                      value: '${package['package_type'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'STATUS',
                      value: package['active'] == true ? 'Active' : 'Inactive',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Included intelligence models',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (models.isEmpty)
                  const Text(
                    'This add-on creates personalized intelligence models rather than bundling a fixed prebuilt model.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  )
                else
                  ...models.map(
                    (model) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft.withOpacity(.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${model['description'] ?? ''}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${model['model_category'] ?? 'intelligence'} • ${model['target_entity_type'] ?? 'entity'} • priority ${model['priority_threshold'] ?? '—'}',
                            style: const TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cyan.withOpacity(.16)),
                  ),
                  child: const Text(
                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',
                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:const Icon(Icons.bolt_rounded),
                    label:Text(package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FieldModePage extends StatefulWidget {
  const _FieldModePage({required this.modelKey,required this.packageName});
  final String modelKey;
  final String packageName;
  @override State<_FieldModePage> createState()=>_FieldModePageState();
}

class _FieldModePageState extends State<_FieldModePage>{
  late Future<Map<String,dynamic>> request;
  late Future<Map<String,dynamic>> teamRequest;
  final Set<String> selected=<String>{};
  StreamSubscription<Position>? locationStream;
  Timer? teamTimer;
  Timer? locationHeartbeat;
  String? shiftId;
  bool sharingLocation=false;
  bool locationBusy=false;
  String? locationError;
  @override void initState(){
    super.initState();request=_load();teamRequest=_loadTeam();
    teamTimer=Timer.periodic(const Duration(seconds:20),(_){if(mounted)setState(()=>teamRequest=_loadTeam());});
  }
  @override void didUpdateWidget(covariant _FieldModePage oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.modelKey!=widget.modelKey){selected.clear();request=_load();}}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_flutter_opportunities_v57',{
    'p_model_key':widget.modelKey,'p_limit':30,'p_offset':0,'p_priority':null,'p_stage':null,
  });
  Future<Map<String,dynamic>> _loadTeam()=>_callRpc('bridgepoint_field_team_v81',const {});
  void _reload()=>setState(()=>request=_load());
  String _key(Map<String,dynamic> o)=>'${o['opportunity_id']??o['property_id']}';
  Future<void> _openRoute(List<Map<String,dynamic>> opportunities)async{
    final chosen=opportunities.where((o)=>selected.contains(_key(o))).take(9).toList();
    final addresses=chosen.map((o)=>'${o['full_address']??''}'.trim()).where((v)=>v.isNotEmpty).toList();
    if(addresses.isEmpty){_showInfoDialog(context,'Choose route stops','Select at least one property with an address.');return;}
    final destination=addresses.removeLast();
    final uri=Uri.parse('https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${Uri.encodeComponent(destination)}${addresses.isEmpty?'':'&waypoints=${Uri.encodeComponent(addresses.join('|'))}'}');
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted){_showInfoDialog(context,'Directions unavailable','Could not open the device maps experience.');}
  }
  Future<void> _markVisited(Map<String,dynamic> opportunity)async{
    try{
      await _callRpc('bridgepoint_save_customer_note_v70',{
        'p_property_id':opportunity['property_id'],'p_opportunity_id':opportunity['opportunity_id'],
        'p_preset_key':'VISIT','p_note_text':'Field visit completed from Field Mode.','p_follow_up_at':null,
      });
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Visit saved to the property timeline.')));
    }catch(e){if(mounted)_showInfoDialog(context,'Could not mark visited',e.toString());}
  }

  Future<void> _recordPosition(Position position)async{
    final activeShift=shiftId;
    if(activeShift==null)return;
    try{
      await _callRpc('bridgepoint_record_field_location_v81',{
        'p_field_shift_id':activeShift,'p_latitude':position.latitude,'p_longitude':position.longitude,
        'p_accuracy_m':position.accuracy,'p_heading_degrees':position.heading.isFinite?position.heading:null,
        'p_speed_mps':position.speed.isFinite&&position.speed>=0?position.speed:null,
        'p_captured_at':position.timestamp.toUtc().toIso8601String(),
      });
      if(mounted)setState((){locationError=null;teamRequest=_loadTeam();});
    }catch(e){if(mounted)setState(()=>locationError='Location could not sync: $e');}
  }

  Future<void> _startTracking()async{
    setState((){locationBusy=true;locationError=null;});
    try{
      if(!await _ensureFieldTrackingConsent(context)){return;}
      if(!await Geolocator.isLocationServiceEnabled())throw Exception('Turn on Location Services, then try again.');
      var permission=await Geolocator.checkPermission();
      if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();
      if(permission==LocationPermission.denied)throw Exception('Location permission was not granted.');
      if(permission==LocationPermission.deniedForever)throw Exception('Location is blocked for BridgePoint. Open this device’s site or app settings to allow it.');
      final started=await _callRpc('bridgepoint_start_field_shift_v81',{'p_shift_label':'Field Mode'});
      shiftId='${started['field_shift_id']}';
      final first=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:20)));
      await _recordPosition(first);
      await locationStream?.cancel();
      locationStream=Geolocator.getPositionStream(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:25)).listen(_recordPosition,onError:(Object error){if(mounted)setState(()=>locationError='Location update paused: $error');});
      locationHeartbeat?.cancel();
      locationHeartbeat=Timer.periodic(const Duration(seconds:60),(_)async{
        if(!sharingLocation)return;
        try{await _recordPosition(await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:20))));}catch(_){ }
      });
      if(mounted)setState((){sharingLocation=true;teamRequest=_loadTeam();});
    }catch(e){if(mounted)setState(()=>locationError=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>locationBusy=false);}
  }

  Future<void> _stopTracking({bool silent=false})async{
    final activeShift=shiftId;
    await locationStream?.cancel();locationStream=null;
    locationHeartbeat?.cancel();locationHeartbeat=null;
    shiftId=null;
    if(activeShift!=null){try{await _callRpc('bridgepoint_stop_field_shift_v81',{'p_field_shift_id':activeShift});}catch(e){if(!silent&&mounted)_showInfoDialog(context,'Could not stop field shift',e.toString());}}
    if(mounted)setState((){sharingLocation=false;locationBusy=false;teamRequest=_loadTeam();});
  }

  @override void dispose(){
    teamTimer?.cancel();locationHeartbeat?.cancel();locationStream?.cancel();
    final activeShift=shiftId;if(activeShift!=null)unawaited(_callRpc('bridgepoint_stop_field_shift_v81',{'p_field_shift_id':activeShift}));
    super.dispose();
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final raw=snapshot.data?['opportunities'];
      final opportunities=raw is List?raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
      if(selected.isEmpty&&opportunities.isNotEmpty){for(final o in opportunities.take(8)){selected.add(_key(o));}}
      final loading=snapshot.connectionState==ConnectionState.waiting;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PageHeading(title:'Field Mode',subtitle:'${widget.packageName} • top houses • simple routing • fast follow-up',onRefresh:_reload,loading:loading),
        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:teamRequest,builder:(context,teamSnapshot)=>_LiveFieldAssistPanel(
            data:teamSnapshot.data,loading:teamSnapshot.connectionState==ConnectionState.waiting,
            sharing:sharingLocation,busy:locationBusy,error:locationError,
            onStart:_startTracking,onStop:()=>_stopTracking(),onRefresh:(){setState(()=>teamRequest=_loadTeam());},
          ),
        ),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,constraints){final columns=constraints.maxWidth>=900?3:1;const gap=14.0;final width=(constraints.maxWidth-gap*(columns-1))/columns;return Wrap(spacing:gap,runSpacing:gap,children:[
          _MetricCard(width:width,label:'TOP HOUSES',value:'${opportunities.length}',detail:'Strictly ranked for field work',icon:Icons.home_work_rounded,accent:AppTheme.cyan),
          _MetricCard(width:width,label:'ROUTE STOPS',value:'${selected.length}',detail:'Choose up to 9 stops per route',icon:Icons.route_rounded,accent:AppTheme.blue),
          _MetricCard(width:width,label:'FIELD WORKFLOW',value:'READY',detail:'Open • save • visit • follow up',icon:Icons.directions_walk_rounded,accent:AppTheme.green),
        ]);}),
        const SizedBox(height:16),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          const Expanded(child:Text('Select the best houses, then open a driving route. Every card opens the evidence and reasoning first.',style:TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.45))),
          const SizedBox(width:12),FilledButton.icon(onPressed:opportunities.isEmpty?null:()=>_openRoute(opportunities),icon:const Icon(Icons.navigation_rounded),label:const Text('Start route')),
        ]))),
        const SizedBox(height:16),
        if(snapshot.hasError)_DashboardError(message:snapshot.error.toString(),onRetry:_reload)
        else if(loading&&opportunities.isEmpty)const Card(child:SizedBox(height:250,child:Center(child:CircularProgressIndicator(color:AppTheme.cyan))))
        else if(opportunities.isEmpty)const Card(child:SizedBox(height:220,child:Center(child:Text('No strict opportunities are ready for field work.',style:TextStyle(color:AppTheme.textMuted)))))
        else Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(children:opportunities.map((o){
          final key=_key(o);final checked=selected.contains(key);final color=_opportunityTypeColor(o);
          return Container(margin:const EdgeInsets.only(bottom:10),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.6),borderRadius:BorderRadius.circular(14),border:Border.all(color:checked?color.withOpacity(.6):Colors.white10)),child:InkWell(
            onTap:()=>_showOpportunityDetail(context,o),borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
              Checkbox(value:checked,activeColor:color,onChanged:(v)=>setState((){if(v==true){if(selected.length<9)selected.add(key);}else{selected.remove(key);}})),
              Container(width:42,height:42,decoration:BoxDecoration(color:color.withOpacity(.14),borderRadius:BorderRadius.circular(11)),child:Icon(_opportunityMapIcon(o),color:color,size:21)),
              const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${o['full_address']??'Address unavailable'}',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(_opportunityWhyThisProperty(o),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.35))])),
              Text('${(o['score'] as num?)?.toStringAsFixed(1)??'—'}',style:TextStyle(color:color,fontSize:17,fontWeight:FontWeight.w900)),
              const SizedBox(width:8),PopupMenuButton<String>(tooltip:'Field actions',onSelected:(action){if(action=='open')_showOpportunityDetail(context,o);if(action=='save')_saveOpportunity(context,o);if(action=='note')_showAddNoteDialog(context,o);if(action=='visited')_markVisited(o);if(action=='directions')_openRoute([o]);},itemBuilder:(context)=>const [
                PopupMenuItem(value:'open',child:Text('Explain this opportunity')),PopupMenuItem(value:'directions',child:Text('Directions')),
                PopupMenuItem(value:'save',child:Text('Save to My Work')),PopupMenuItem(value:'note',child:Text('Add follow-up note')),PopupMenuItem(value:'visited',child:Text('Mark visited')),
              ]),
            ]))),
          );
        }).toList()))),
      ]);
    },
  );
}

class _LiveFieldAssistPanel extends StatelessWidget{
  const _LiveFieldAssistPanel({required this.data,required this.loading,required this.sharing,required this.busy,required this.error,required this.onStart,required this.onStop,required this.onRefresh});
  final Map<String,dynamic>? data;
  final bool loading,sharing,busy;
  final String? error;
  final VoidCallback onStart,onStop,onRefresh;
  @override Widget build(BuildContext context){
    final eligible=data?['eligible']==true;
    final canView=data?['can_view_team']==true;
    final teammates=(data?['team'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
    final points=teammates.where((e)=>e['latitude'] is num&&e['longitude'] is num).toList();
    if(loading&&data==null)return const Card(child:Padding(padding:EdgeInsets.all(18),child:LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)));
    if(!eligible)return Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
      Container(width:48,height:48,decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.10),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.location_off_outlined,color:AppTheme.amber)),
      const SizedBox(width:13),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Live Field Assist • Company plan',style:TextStyle(fontWeight:FontWeight.w900)),SizedBox(height:4),Text('Company teams can voluntarily share active field locations so supervisors can see who is nearby, coordinate help, and avoid duplicate visits.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45))])),
      OutlinedButton.icon(onPressed:()=>_openBillingPortal(context),icon:const Icon(Icons.lock_outline_rounded),label:const Text('Company plan')),
    ])));
    return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Container(width:48,height:48,decoration:BoxDecoration(color:(sharing?AppTheme.green:AppTheme.cyan).withOpacity(.11),borderRadius:BorderRadius.circular(13)),child:Icon(sharing?Icons.share_location_rounded:Icons.location_searching_rounded,color:sharing?AppTheme.green:AppTheme.cyan)),
        const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(sharing?'Sharing your field location':'Live Field Assist',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14)),
          const SizedBox(height:4),Text(sharing?'Visible to company owners, co-owners, and managers while Field Mode is open.':'Start a field shift only when you want company supervisors to see and assist you.',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
        ])),
        IconButton(tooltip:'Refresh active team',onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded,color:AppTheme.textMuted)),
        const SizedBox(width:4),FilledButton.icon(
          style:sharing?FilledButton.styleFrom(backgroundColor:AppTheme.red):null,
          onPressed:busy?null:(sharing?onStop:onStart),icon:Icon(sharing?Icons.stop_circle_outlined:Icons.play_circle_outline_rounded),
          label:Text(busy?'Starting…':sharing?'Stop sharing':'Start field shift'),
        ),
      ]),
      if(error!=null)...[const SizedBox(height:10),_InlineError(message:error!)],
      const SizedBox(height:12),Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.05),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.cyan.withOpacity(.12))),child:const Row(children:[
        Icon(Icons.privacy_tip_outlined,color:AppTheme.cyan,size:18),SizedBox(width:9),Expanded(child:Text('Consent-based: no hidden tracking. Live locations leave the team view after 15 minutes and are permanently deleted after seven days. Leaving Field Mode ends sharing.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45))),
      ])),
      if(canView&&points.isNotEmpty)...[
        const SizedBox(height:14),SizedBox(height:220,child:ClipRRect(borderRadius:BorderRadius.circular(13),child:FlutterMap(
          options:MapOptions(initialCenter:LatLng((points.first['latitude'] as num).toDouble(),(points.first['longitude'] as num).toDouble()),initialZoom:11),
          children:[
            TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.bridgepointintelligence.app'),
            MarkerLayer(markers:points.map((member){
              final status='${member['location_status']??'RECENT'}';final color=status=='LIVE'?AppTheme.green:AppTheme.amber;
              final name='${member['display_name']??'Team member'}';final initial=name.isEmpty?'?':name.substring(0,1).toUpperCase();
              return Marker(point:LatLng((member['latitude'] as num).toDouble(),(member['longitude'] as num).toDouble()),width:52,height:52,child:Tooltip(message:'$name • $status',child:Container(decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.35),blurRadius:8)]),child:Center(child:Text(initial,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))))));
            }).toList()),
          ],
        ))),
        const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:points.map((member){final live=member['location_status']=='LIVE';return _OpportunityChip(label:'${member['display_name']??'Teammate'} • ${live?'LIVE':'RECENT'}',color:live?AppTheme.green:AppTheme.amber);}).toList()),
      ] else if(canView)...[const SizedBox(height:12),const Text('No teammate is actively sharing a field location.',style:TextStyle(color:AppTheme.textMuted,fontSize:10))],
    ])));
  }
}

class _IntelligenceMapPage extends StatefulWidget {
  const _IntelligenceMapPage({
    required this.modelKey,
    required this.packageName,
  });

  final String modelKey;
  final String packageName;

  @override
  State<_IntelligenceMapPage> createState() => _IntelligenceMapPageState();
}

class _IntelligenceMapPageState extends State<_IntelligenceMapPage> {
  late Future<Map<String, dynamic>> _request;
  final MapController _mapController = MapController();
  double? _minimumScore;
  String _visibleLayer=_displayPreferences.value.simplifiedViews?'opportunities':'both';
  bool _showRadar=true;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void didUpdateWidget(covariant _IntelligenceMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelKey != widget.modelKey) {
      _request = _load();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final results=await Future.wait<Object>([
      http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_intelligence_map_v57'),
        headers: _apiHeaders(),
        body: jsonEncode({
          'p_model_key': widget.modelKey,
          'p_min_lat': null,'p_max_lat': null,'p_min_lng': null,'p_max_lng': null,
          'p_min_score': _minimumScore,'p_limit': 500,
        }),
      ).timeout(const Duration(seconds: 30)),
      _callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}),
      _callRpc('bridgepoint_flutter_signal_map_v80',{
        'p_min_lat':null,'p_max_lat':null,'p_min_lng':null,'p_max_lng':null,'p_limit':240,
      }),
    ]);
    final response=results[0] as http.Response;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Intelligence Map API ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected Intelligence Map response.');
    }
    return <String,dynamic>{
      ...Map<String,dynamic>.from(decoded),
      'coverage_catalog':results[1],
      'signal_map':results[2],
    };
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['points'];
        final points = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final signalMap=data?['signal_map'] is Map
            ?Map<String,dynamic>.from(data!['signal_map'] as Map)
            :<String,dynamic>{};
        final signalRaw=signalMap['signals'];
        final signalPoints=signalRaw is List
            ?signalRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList()
            :<Map<String,dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final coverage=data?['coverage_catalog'] is Map
            ?Map<String,dynamic>.from(data!['coverage_catalog'] as Map)
            :<String,dynamic>{};
        final coverageMarkets=_detailList(coverage['markets']);
        final highPriority = points.where((p) {
          final v = '${p['priority']}'.toLowerCase();
          return v == 'critical' || v == 'high';
        }).length;
        final avgScore = points.isEmpty
            ? 0.0
            : points.fold<double>(
                    0,
                    (sum, p) =>
                        sum + ((p['opportunity_score'] as num?)?.toDouble() ?? 0),
                  ) /
                  points.length;

        final markers = <Marker>[];
        if(_visibleLayer!='signals')for (final point in points) {
          final lat = (point['latitude'] as num?)?.toDouble();
          final lng = (point['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final priority = '${point['priority'] ?? 'medium'}';
          final typeColor=_opportunityTypeColor(point);
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 34,
              height: 34,
              child: Tooltip(
                message: '${point['full_address'] ?? point['municipality'] ?? 'Opportunity'}',
                child: GestureDetector(
                  onTap: () => _showMapOpportunityDetail(context, point),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:typeColor.withOpacity(.94),
                      border:Border.all(color:_opportunityPriorityColor(priority),width:2.4),
                      boxShadow: [
                        BoxShadow(
                          color:typeColor.withOpacity(.38),blurRadius:11,spreadRadius:1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _opportunityMapIcon(point),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if(_visibleLayer!='opportunities')for(final signal in signalPoints){
          final lat=(signal['latitude'] as num?)?.toDouble();
          final lng=(signal['longitude'] as num?)?.toDouble();
          if(lat==null||lng==null)continue;
          final color=_opportunityTypeColor(signal);
          markers.add(Marker(point:LatLng(lat,lng),width:30,height:30,child:Tooltip(
            message:'${signal['signal_name']??signal['title']??'Signal'} • ${signal['full_address']??signal['municipality']??''}',
            child:GestureDetector(onTap:()=>_showSignalDetail(context,signal),child:Transform.rotate(angle:.785398,child:Container(
              decoration:BoxDecoration(color:color.withOpacity(.92),borderRadius:BorderRadius.circular(7),border:Border.all(color:Colors.white.withOpacity(.82),width:1.4),boxShadow:[BoxShadow(color:color.withOpacity(.33),blurRadius:9)]),
              child:Transform.rotate(angle:-.785398,child:Icon(_opportunityMapIcon(signal),color:Colors.white,size:15)),
            ))),
          )));
        }
        const nearbyCentroids=<String,LatLng>{
          'MA':LatLng(42.30,-71.80),'RI':LatLng(41.70,-71.55),
          'NY':LatLng(42.80,-75.20),'NJ':LatLng(40.10,-74.50),
          'PA':LatLng(41.00,-77.50),'VT':LatLng(44.00,-72.70),
          'NH':LatLng(43.80,-71.60),'ME':LatLng(45.20,-69.00),
        };
        if(_showExpansion)for(final market in coverageMarkets){
          final code='${market['state_code']}';final center=nearbyCentroids[code];
          if(center==null||market['data_status']=='LIVE')continue;
          final requested=market['interest_registered']==true;
          markers.add(Marker(point:center,width:74,height:56,child:Tooltip(
            message:'${market['state_name']} • ${market['data_status']}',
            child:GestureDetector(onTap:()=>_showStateCoverageDialog(context,market,_reload),child:Container(
              padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),
              decoration:BoxDecoration(color:AppTheme.panel.withOpacity(.93),borderRadius:BorderRadius.circular(12),border:Border.all(color:(requested?AppTheme.cyan:AppTheme.amber).withOpacity(.8)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.28),blurRadius:8)]),
              child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(requested?Icons.notifications_active_rounded:Icons.lock_outline_rounded,color:requested?AppTheme.cyan:AppTheme.amber,size:18),Text(code,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))]),
            )),
          )));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Intelligence Map',
              subtitle:
                  '${widget.packageName} • live Connecticut intelligence with visible expansion markets',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'MAPPED',
                      value: '${markers.length}',
                      detail: data?['has_more'] == true
                          ? '${points.length} opportunities • ${signalPoints.length} signals • more available'
                          : '${points.length} opportunities • ${signalPoints.length} signals',
                      icon: Icons.map_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'HIGH PRIORITY',
                      value: '$highPriority',
                      detail: 'Critical + high strict opportunities',
                      icon: Icons.priority_high_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'AVG SCORE',
                      value: points.isEmpty ? '—' : avgScore.toStringAsFixed(1),
                      detail: '${signalMap['signal_type_count']??0} signal types represented',
                      icon: Icons.analytics_outlined,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.layers_outlined, color: AppTheme.cyan, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _visibleLayer.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                      _MapLegendDot(color:_categoryColor('roofing'),label:'Roofing',icon:Icons.roofing_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('fire'),label:'Fire',icon:Icons.local_fire_department_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('severe_weather'),label:'Storm / hail',icon:Icons.thunderstorm_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('flood'),label:'Flood / FEMA',icon:Icons.flood_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('solar'),label:'Solar',icon:Icons.solar_power_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('investment'),label:'Investor',icon:Icons.real_estate_agent_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('commercial'),label:'Commercial',icon:Icons.business_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('environmental'),label:'Environmental',icon:Icons.science_rounded),const SizedBox(width:12),
                      _MapLegendDot(color:_categoryColor('property_transition'),label:'Transfer',icon:Icons.swap_horizontal_circle_rounded),
                    ]))),
                    const SizedBox(width:12),
                    PopupMenuButton<String>(tooltip:'Choose visible intelligence',onSelected:(value)=>setState(()=>_visibleLayer=value),itemBuilder:(context)=>const [
                      PopupMenuItem(value:'both',child:Text('Opportunities + signals')),PopupMenuItem(value:'opportunities',child:Text('Opportunities only')),PopupMenuItem(value:'signals',child:Text('Signals only')),
                    ],child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(borderRadius:BorderRadius.circular(9),border:Border.all(color:Colors.white12)),child:Row(children:[const Icon(Icons.layers_rounded,size:15,color:AppTheme.cyan),const SizedBox(width:5),Text(_visibleLayer=='both'?'Both':_visibleLayer=='signals'?'Signals':'Opportunities',style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700))]))),
                    const SizedBox(width:8),
                    PopupMenuButton<double?>(
                      tooltip: 'Minimum opportunity score',
                      onSelected: (value) {
                        _minimumScore = value;
                        _reload();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: null, child: Text('All scores')),
                        PopupMenuItem(value: 50.0, child: Text('Score 50+')),
                        PopupMenuItem(value: 70.0, child: Text('Score 70+')),
                        PopupMenuItem(value: 85.0, child: Text('Score 85+')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _minimumScore == null
                              ? 'All scores'
                              : '${_minimumScore!.toStringAsFixed(0)}+ score',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _DashboardError(message: snapshot.error.toString(), onRetry: _reload)
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 610,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 4,
                          maxZoom: 18,
                          interactionOptions: InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.bridgepoint.data_studio',
                          ),
                          if(_showRadar)TileLayer(
                            wmsOptions:WMSTileLayerOptions(
                              baseUrl:'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?',
                              layers:const ['conus_bref_qcd'],format:'image/png',transparent:true,version:'1.3.0',
                            ),
                            maxNativeZoom:12,
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
                          MarkerLayer(markers: markers),
                          RichAttributionWidget(
                            attributions: const [
                              TextSourceAttribution('OpenStreetMap contributors'),
                            ],
                          ),
                        ],
                      ),
                      if(!loading&&!_displayPreferences.value.reducedMotion)const Positioned.fill(child:IgnorePointer(child:_MapScanOverlay())),
                      if (loading)
                        Positioned.fill(
                          child: Container(
                            color: AppTheme.panel.withOpacity(.45),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.cyan,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Column(
                          children: [
                            _MapControlButton(
                              icon: Icons.add_rounded,
                              tooltip: 'Zoom in',
                              onTap: () {
                                final camera = _mapController.camera;
                                _mapController.move(
                                  camera.center,
                                  camera.zoom + 1,
                                );
                              },
                            ),
                            const SizedBox(height: 7),
                            _MapControlButton(
                              icon: Icons.remove_rounded,
                              tooltip: 'Zoom out',
                              onTap: () {
                                final camera = _mapController.camera;
                                _mapController.move(
                                  camera.center,
                                  camera.zoom - 1,
                                );
                              },
                            ),
                            const SizedBox(height: 7),
                            _MapControlButton(
                              icon: Icons.center_focus_strong_rounded,
                              tooltip: 'Reset Connecticut',
                              onTap: () => _mapController.move(
                                const LatLng(41.60, -72.70),
                                8.2,
                              ),
                            ),
                            const SizedBox(height:7),
                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show Northeast expansion',onTap:()=>_mapController.move(const LatLng(42.15,-72.90),6.3)),
                            const SizedBox(height:7),
                            _MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide live NOAA radar':'Show live NOAA radar',onTap:()=>setState(()=>_showRadar=!_showRadar)),
                            const SizedBox(height:7),
                            _MapControlButton(icon:_showExpansion?Icons.lock_outline_rounded:Icons.lock_open_rounded,tooltip:_showExpansion?'Hide future states':'Show future states',onTap:()=>setState(()=>_showExpansion=!_showExpansion)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  const _MapLegendDot({required this.color, required this.label,this.icon=Icons.circle});
  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:'Explain $label markers',
      child:InkWell(
        borderRadius:BorderRadius.circular(8),
        onTap:()=>_showInfoDialog(context,'$label map intelligence','Every $label marker uses this same color and symbol throughout BridgePoint. Round markers are ranked opportunities; diamond markers are supporting signals. Tap any marker to see the property, source, timing, evidence, confidence, and recommended next step.'),
        child:Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:5),child:Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,color:color,size:13),
            const SizedBox(width: 5),
            Text(label,style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          ],
        )),
      ),
    );
  }
}

void _showStateCoverageDialog(BuildContext context,Map<String,dynamic> market,VoidCallback refresh){
  final live=market['data_status']=='LIVE';final requested=market['interest_registered']==true;
  showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
    backgroundColor:AppTheme.panel,
    title:Row(children:[Icon(live?Icons.verified_rounded:Icons.lock_outline_rounded,color:live?AppTheme.green:AppTheme.amber),const SizedBox(width:9),Expanded(child:Text('${market['state_name']} coverage'))]),
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      _OpportunityChip(label:'${market['data_status']}',color:live?AppTheme.green:AppTheme.amber),
      const SizedBox(height:12),
      Text(live?'This market is live and available to this account.':'This market is visible so customers understand where BridgePoint is going. Data remains locked until the full property inventory and automatic intelligence pipeline are live.',style:const TextStyle(color:AppTheme.textMuted,height:1.5)),
      if(!live)...[const SizedBox(height:12),Text('Future state add-on from \$${market['monthly_price']}/month. Requesting it today does not charge you.',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,height:1.4))],
    ]),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Close')),
      if(!live)FilledButton.icon(onPressed:requested?null:()async{
        try{await _callRpc('bridgepoint_register_geographic_interest_v77',{'p_state_code':market['state_code'],'p_bundle_key':null});if(dialogContext.mounted)Navigator.pop(dialogContext);refresh();}
        catch(e){if(dialogContext.mounted)_showInfoDialog(dialogContext,'Could not save request',e.toString());}
      },icon:Icon(requested?Icons.check_rounded:Icons.notifications_active_outlined),label:Text(requested?'Requested':'Notify me')),
    ],
  ));
}

class _MapScanOverlay extends StatefulWidget{
  const _MapScanOverlay();
  @override State<_MapScanOverlay> createState()=>_MapScanOverlayState();
}
class _MapScanOverlayState extends State<_MapScanOverlay> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  @override void initState(){super.initState();controller=AnimationController(vsync:this,duration:const Duration(seconds:6))..repeat();}
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:controller,builder:(context,_)=>
    Align(alignment:Alignment(0,-1+controller.value*2),child:Container(height:2,decoration:BoxDecoration(
      gradient:LinearGradient(colors:[Colors.transparent,AppTheme.cyan.withOpacity(.34),Colors.transparent]),
      boxShadow:[BoxShadow(color:AppTheme.cyan.withOpacity(.16),blurRadius:12,spreadRadius:4)],
    ))));
}

String _mapCategoryKey(Map<String,dynamic> item){
  final value=[item['vertical_key'],item['opportunity_key'],item['model_key'],item['title'],item['model_name'],item['top_signal_type'],item['signal_key'],item['signal_name'],item['signal_family'],item['detector_key']].map((v)=>'$v'.toLowerCase()).join(' ');
  if(value.contains('fire'))return 'fire';
  if(value.contains('roof')||value.contains('restoration')||value.contains('contractor'))return 'roofing';
  if(value.contains('hail')||value.contains('storm')||value.contains('wind')||value.contains('lightning')||value.contains('tornado')||value.contains('hurricane')||value.contains('winter weather'))return 'severe_weather';
  if(value.contains('flood')||value.contains('fema')||value.contains('nfip')||value.contains('hydrolog')||value.contains('water'))return 'flood';
  if(value.contains('solar'))return 'solar';
  if(value.contains('foreclos')||value.contains('distress')||value.contains('invest')||value.contains('probate')||value.contains('estate transfer'))return 'investment';
  if(value.contains('business')||value.contains('commercial'))return 'commercial';
  if(value.contains('development')||value.contains('permit')||value.contains('construction'))return 'development';
  if(value.contains('environment')||value.contains('remediation')||value.contains('cleanup')||value.contains('petroleum')||value.contains('spill')||value.contains(' ust'))return 'environmental';
  if(value.contains('transfer')||value.contains('ownership')||value.contains('property change')||value.contains('property improvement'))return 'property_transition';
  if(value.contains('grid')||value.contains('utility')||value.contains('outage')||value.contains('infrastructure'))return 'infrastructure';
  if(value.contains('claim')||value.contains('insurance')||value.contains('adjust'))return 'claims';
  final explicit='${item['signal_family']??item['vertical_key']??item['model_key']??'other'}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_');
  return explicit.isEmpty?'other':explicit;
}

int _stableTypeHash(String value){var hash=2166136261;for(final code in value.codeUnits){hash^=code;hash=(hash*16777619)&0x7fffffff;}return hash;}

Color _categoryColor(String category)=>switch(category){
  'roofing'=>AppTheme.amber,'fire'=>AppTheme.red,'severe_weather'=>const Color(0xFF9B7BFF),
  'flood'=>AppTheme.blue,'solar'=>AppTheme.green,'investment'=>const Color(0xFF49D17D),
  'commercial'=>AppTheme.cyan,'development'=>const Color(0xFFFF9557),
  'environmental'=>const Color(0xFFB7D84B),'property_transition'=>const Color(0xFFFF78C6),
  'infrastructure'=>const Color(0xFFE1D85A),'claims'=>const Color(0xFFD96BFF),
  _=>HSLColor.fromAHSL(1,(_stableTypeHash(category)%360).toDouble(),.68,.56).toColor(),
};

IconData _categoryIcon(String category)=>switch(category){
  'roofing'=>Icons.roofing_rounded,'fire'=>Icons.local_fire_department_rounded,
  'severe_weather'=>Icons.thunderstorm_rounded,'flood'=>Icons.flood_rounded,
  'solar'=>Icons.solar_power_rounded,'investment'=>Icons.real_estate_agent_rounded,
  'commercial'=>Icons.business_rounded,'development'=>Icons.location_city_rounded,
  'environmental'=>Icons.science_rounded,'property_transition'=>Icons.swap_horizontal_circle_rounded,
  'infrastructure'=>Icons.electrical_services_rounded,'claims'=>Icons.policy_rounded,
  _=>Icons.bolt_rounded,
};

IconData _opportunityMapIcon(Map<String,dynamic> item)=>_categoryIcon(_mapCategoryKey(item));

Color _opportunityTypeColor(Map<String,dynamic> item)=>_categoryColor(_mapCategoryKey(item));

IconData _opportunityTypeIcon(Map<String,dynamic> opportunity)=>_opportunityMapIcon(opportunity);

int _opportunityCount(Map<String,dynamic> opportunity,List<String> keys){
  for(final key in keys){
    final value=opportunity[key];
    if(value is num)return value.toInt();
  }
  return 0;
}

List<Map<String,dynamic>> _opportunityDirectEvidence(Map<String,dynamic> opportunity){
  final raw=opportunity['direct_evidence'];
  if(raw is! List)return const [];
  return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
}

String _formatEvidenceDate(Object value){
  final raw='$value'.trim();
  final parsed=DateTime.tryParse(raw)?.toLocal();
  if(parsed==null)return raw;
  const months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[parsed.month-1]} ${parsed.day}, ${parsed.year}';
}

String _opportunityEvidenceNames(Map<String,dynamic> opportunity){
  final names=_opportunityDirectEvidence(opportunity)
      .map((e)=>'${e['title']??e['signal_title']??e['name']??''}'.trim())
      .where((name)=>name.isNotEmpty)
      .toSet()
      .take(3)
      .toList();
  return names.isEmpty?'the named evidence in the property timeline':names.join(', ');
}

String _opportunityWhyThisProperty(Map<String,dynamic> opportunity){
  final model='${opportunity['model_name']??opportunity['title']??opportunity['model_key']??'This opportunity'}'.trim();
  final signals=_opportunityCount(opportunity,const ['direct_signal_count','matched_signal_count','distinct_signal_count']);
  final sources=_opportunityCount(opportunity,const ['direct_source_count','verified_event_count']);
  if(signals<=0||sources<=0){
    return '$model is being held for review because the current card does not show enough direct property-level evidence. Open the timeline and verify a named source before taking action.';
  }
  return '$model was surfaced because BridgePoint matched $signals direct property-level signal${signals==1?'':'s'} from $sources direct source${sources==1?'':'s'}: ${_opportunityEvidenceNames(opportunity)}. Supporting patterns can strengthen the story, but they are not counted as direct matches.';
}

String _opportunityWhyNow(Map<String,dynamic> opportunity){
  final stage='${opportunity['stage']??opportunity['intelligence_stage']??'active review'}'.replaceAll('_',' ').toLowerCase();
  final score=opportunity['score']??opportunity['opportunity_score']??opportunity['final_score'];
  final negative=opportunity['negative_score'];
  final latest=opportunity['latest_evidence_at']??opportunity['latest_direct_evidence_at']??opportunity['last_detected_at'];
  final scoreText=score is num?' Its current strict score is ${score.toStringAsFixed(1)}/100${negative is num?' after ${negative.toStringAsFixed(1)} negative points':''}.':'';
  final dateText=latest==null?' The card does not provide a current evidence date, so verify the timeline before outreach.':' The newest linked evidence is dated ${_formatEvidenceDate(latest)}.';
  return 'The property is in the $stage stage.$scoreText$dateText';
}

String _opportunityLimitations(Map<String,dynamic> opportunity){
  final limitations=_opportunityDirectEvidence(opportunity)
      .map((e)=>'${e['limitation']??e['limitations']??''}'.trim())
      .where((value)=>value.isNotEmpty)
      .toSet()
      .take(2)
      .toList();
  if(limitations.isNotEmpty)return limitations.join(' ');
  return 'This is a ranked reason to investigate, not proof of damage, customer intent, claim coverage, a permit, or a guaranteed sale. Confirm the source dates and property conditions before outreach.';
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.panel.withOpacity(.94),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatelessWidget{
  const _ReasoningPanel({required this.opportunity});
  final Map<String,dynamic> opportunity;
  Widget line(IconData icon,String title,String body,Color color)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:18),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5))]))]));
  @override Widget build(BuildContext context){
    final whyProperty=_opportunityWhyThisProperty(opportunity);
    final whyNow=_opportunityWhyNow(opportunity);
    final directSignals=opportunity['direct_signal_count']??opportunity['matched_signal_count']??opportunity['distinct_signal_count']??0;
    final allSignals=opportunity['event_count']??opportunity['signal_count']??directSignals;
    final patterns=opportunity['matched_pattern_count']??opportunity['pattern_count']??0;
    final directSources=opportunity['direct_source_count']??opportunity['verified_event_count']??0;
    final action='${opportunity['recommended_action']??'Review the evidence, confirm property fit, and choose the next customer action.'}';
    return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.psychology_alt_rounded,color:AppTheme.cyan,size:20),SizedBox(width:8),Text('BridgePoint Reasoning',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:13))]),
      const SizedBox(height:5),const Text('Score ranks the opportunity. Confidence tells you how reliable and consistent the supporting evidence is.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const Divider(height:22),
      line(Icons.home_work_outlined,'Why this property',whyProperty,AppTheme.cyan),
      line(Icons.schedule_rounded,'Why now',whyNow,AppTheme.amber),
      line(Icons.fact_check_outlined,'Direct evidence you can verify','$directSignals named property-level signals from $directSources direct source(s). Open the property timeline to see each title, source, date, match method, and limitation.',AppTheme.blue),
      line(Icons.schema_outlined,'Supporting context','$allSignals total property-linked observations and $patterns corroborating patterns help explain the property story. Area context and pattern volume never replace the required direct evidence.',const Color(0xFF9B7BFF)),
      line(Icons.report_gmailerrorred_rounded,'What this does not prove',_opportunityLimitations(opportunity),AppTheme.red),
      line(Icons.arrow_circle_right_outlined,'Suggested next step',action,AppTheme.green),
    ]));
  }
}

void _showMapOpportunityDetail(
  BuildContext context,
  Map<String, dynamic> point,
) {
  final score = (point['opportunity_score'] as num?)?.toDouble();
  final confidence =
      (point['opportunity_confidence_percent'] as num?)?.toDouble();

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppTheme.cyan),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${point['full_address'] ?? point['municipality'] ?? 'Opportunity'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'OPPORTUNITY',
                      value: score?.toStringAsFixed(1) ?? '—',
                    ),
                    _MiniStat(
                      label: 'PRIORITY',
                      value: '${point['priority'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'CONFIDENCE',
                      value: confidence == null
                          ? '—'
                          : '${confidence.toStringAsFixed(0)}%',
                    ),
                    _MiniStat(
                      label: 'DIRECT SIGNALS',
                      value: '${point['direct_signal_count'] ?? point['matched_signal_count'] ?? point['distinct_signal_count'] ?? 0}',
                    ),
                    _MiniStat(
                      label: 'DIRECT SOURCES',
                      value: '${point['direct_source_count'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ReasoningPanel(opportunity:point),
                const SizedBox(height: 18),
                Text(
                  'Model: ${point['model_name'] ?? point['model_key'] ?? '—'}\n'
                  'Property: ${point['property_type'] ?? '—'}\n'
                  'Municipality: ${point['municipality'] ?? '—'}\n'
                  'County: ${point['county'] ?? '—'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SignalsPage extends StatefulWidget {
  const _SignalsPage();

  @override
  State<_SignalsPage> createState() => _SignalsPageState();
}

class _SignalsPageState extends State<_SignalsPage> {
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  late Future<Map<String, dynamic>> _request;
  int _offset = 0;
  String? _search;
  String? _family;
  String? _status;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _familyController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  String? _clean(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_signals'),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_search': _search,
            'p_signal_family': _family,
            'p_status': _status,
            'p_limit': _pageSize,
            'p_offset': _offset,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Signals API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Signals response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() {
    setState(() => _request = _load());
  }

  void _applyFilters() {
    _offset = 0;
    _search = _clean(_searchController.text);
    _family = _clean(_familyController.text);
    _status = _clean(_statusController.text);
    _reload();
  }

  void _clearFilters() {
    _searchController.clear();
    _familyController.clear();
    _statusController.clear();
    _offset = 0;
    _search = null;
    _family = null;
    _status = null;
    _reload();
  }

  void _previous() {
    if (_offset <= 0) return;
    _offset = (_offset - _pageSize).clamp(0, 1 << 30);
    _reload();
  }

  void _next() {
    _offset += _pageSize;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['signals'];
        final signals = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasMore = data?['has_more'] == true;

        final activeCount =
            signals.where((s) => '${s['status']}'.toLowerCase() == 'active').length;
        final highCount = signals.where((s) {
          final sev = s['severity'];
          return sev is num && sev >= 80;
        }).length;
        final avgConfidence = signals.isEmpty
            ? 0.0
            : signals.fold<double>(
                  0,
                  (sum, s) => sum + ((s['confidence'] as num?)?.toDouble() ?? 0),
                ) /
                signals.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Signals',
              subtitle:
                  'Live property intelligence • evidence • strength • confidence',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE ON PAGE',
                      value: '$activeCount',
                      detail: '${signals.length} signals returned',
                      icon: Icons.radar_rounded,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'HIGH SEVERITY',
                      value: '$highCount',
                      detail: 'Severity 80+ on this page',
                      icon: Icons.warning_amber_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'AVG CONFIDENCE',
                      value: signals.isEmpty
                          ? '—'
                          : '${(avgConfidence * 100).toStringAsFixed(0)}%',
                      detail: 'Current page evidence confidence',
                      icon: Icons.verified_outlined,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = [
                          _signalField(
                            controller: _searchController,
                            label: 'Signal, detector, or description',
                            icon: Icons.search_rounded,
                          ),
                          _signalField(
                            controller: _familyController,
                            label: 'Signal family',
                            icon: Icons.account_tree_outlined,
                          ),
                          _signalField(
                            controller: _statusController,
                            label: 'Status',
                            icon: Icons.toggle_on_outlined,
                          ),
                        ];
                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 10),
                              fields[1],
                              const SizedBox(height: 10),
                              fields[2],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 2, child: fields[0]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[1]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[2]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: loading ? null : _applyFilters,
                          icon: const Icon(Icons.filter_alt_rounded, size: 17),
                          label: const Text('Apply'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: loading ? null : _clearFilters,
                          icon: const Icon(Icons.clear_rounded, size: 17),
                          label: const Text('Clear'),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Newest signals first',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.38),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (signals.isEmpty)
              const Card(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No signals match these filters.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Signal Intelligence',
                        subtitle:
                            'Property-linked detections and supporting evidence',
                        action: 'Inspect signal',
                      ),
                      const SizedBox(height: 14),
                      ...signals.map((signal) => _SignalListCard(signal: signal)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _offset > 0 && !loading ? _previous : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: hasMore && !loading ? _next : null,
                            icon:
                                const Icon(Icons.chevron_right_rounded, size: 18),
                            label: const Text('Next'),
                          ),
                          const Spacer(),
                          Text(
                            'Page ${(_offset ~/ _pageSize) + 1} • ${signals.length} returned',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _signalField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => _applyFilters(),
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
        isDense: true,
        filled: true,
        fillColor: AppTheme.panelSoft.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.cyan),
        ),
      ),
    );
  }
}

class _SignalListCard extends StatelessWidget {
  const _SignalListCard({required this.signal});

  final Map<String, dynamic> signal;

  @override
  Widget build(BuildContext context) {
    final title = (signal['signal_name'] ?? signal['title'] ?? 'Signal').toString();
    final address = (signal['full_address'] ?? '').toString();
    final municipality = (signal['municipality'] ?? 'Unknown').toString();
    final family = (signal['signal_family'] ?? 'uncategorized').toString();
    final status = (signal['status'] ?? 'unknown').toString();
    final severity = (signal['severity'] as num?)?.toDouble();
    final strength = (signal['strength'] as num?)?.toDouble();
    final confidence = (signal['confidence'] as num?)?.toDouble();
    final evidenceCount = (signal['evidence_count'] as num?)?.toInt() ?? 0;
    final detector = (signal['detector_key'] ?? '—').toString();
    final signalColor = _opportunityTypeColor(signal);

    final chips = <Widget>[
      _OpportunityChip(label: family.replaceAll('_', ' ').toUpperCase(), color: signalColor),
      _OpportunityChip(
        label: status.toUpperCase(),
        color: status.toLowerCase() == 'active' ? AppTheme.green : AppTheme.textMuted,
      ),
      if (severity != null)
        _OpportunityChip(
          label: 'SEV ${severity.toStringAsFixed(0)}',
          color: severity >= 80 ? AppTheme.cyan : AppTheme.blue,
        ),
    ];

    Widget identity({required bool compact}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: signalColor.withOpacity(0.11),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(_opportunityMapIcon(signal), color: signalColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                address.trim().isEmpty ? municipality : address,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.35),
              ),
              const SizedBox(height: 4),
              Text(
                detector,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 8),
              ),
            ],
          ),
        ),
        if (compact) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        ],
      ],
    );

    return InkWell(
      onTap: () => _showSignalDetail(context, signal),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity(compact: true),
                  const SizedBox(height: 11),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 14,
                    runSpacing: 7,
                    children: [
                      Text(strength == null ? 'Strength —' : 'Strength ${strength.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w800)),
                      Text(confidence == null ? 'Confidence —' : '${(confidence * 100).toStringAsFixed(0)}% confidence', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                      Text('$evidenceCount evidence item${evidenceCount == 1 ? '' : 's'}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 4, child: identity(compact: false)),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Wrap(spacing: 6, runSpacing: 6, children: chips)),
                SizedBox(
                  width: 125,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(strength == null ? 'Strength —' : 'Strength ${strength.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(confidence == null ? 'Confidence —' : '${(confidence * 100).toStringAsFixed(0)}% confidence', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                      const SizedBox(height: 4),
                      Text('$evidenceCount evidence item${evidenceCount == 1 ? '' : 's'}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _showSignalDetail(
  BuildContext context,
  Map<String, dynamic> signal,
) {
  final title =
      (signal['signal_name'] ?? signal['title'] ?? 'Signal').toString();
  final confidence = (signal['confidence'] as num?)?.toDouble();
  final evidence = signal['evidence_summary'];
  final evidenceText = evidence is Map
      ? const JsonEncoder.withIndent('  ').convert(evidence)
      : (evidence?.toString() ?? 'No evidence summary.');

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: AppTheme.cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${signal['full_address'] ?? signal['municipality'] ?? 'Property intelligence'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'SEVERITY',
                      value: '${signal['severity'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'STRENGTH',
                      value: '${signal['strength'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'CONFIDENCE',
                      value: confidence == null
                          ? '—'
                          : '${(confidence * 100).toStringAsFixed(0)}%',
                    ),
                    _MiniStat(
                      label: 'EVIDENCE',
                      value: '${signal['evidence_count'] ?? 0}',
                    ),
                    _MiniStat(
                      label: 'STATUS',
                      value: '${signal['status'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'PROPERTY',
                      value: '${signal['property_type'] ?? '—'}',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Family: ${signal['signal_family'] ?? '—'}\n'
                  'Signal key: ${signal['signal_key'] ?? '—'}\n'
                  'Detector: ${signal['detector_key'] ?? '—'}\n'
                  'Direction: ${signal['direction'] ?? '—'}\n'
                  'Detected: ${signal['detected_at'] ?? '—'}\n'
                  'Effective: ${signal['effective_at'] ?? '—'}\n'
                  'Expires: ${signal['expires_at'] ?? '—'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Evidence summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.panelSoft.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: SelectableText(
                    evidenceText,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Signal ID: ${signal['signal_id'] ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PropertiesPage extends StatefulWidget {
  const _PropertiesPage();

  @override
  State<_PropertiesPage> createState() => _PropertiesPageState();
}

class _PropertiesPageState extends State<_PropertiesPage> {
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  late Future<Map<String, dynamic>> _request;
  int _offset = 0;
  String? _search;
  String? _municipality;
  String? _propertyType;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _municipalityController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_properties',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_search': _search,
            'p_municipality': _municipality,
            'p_property_type': _propertyType,
            'p_limit': _pageSize,
            'p_offset': _offset,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Properties API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Properties response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() {
    final next = _load();
    setState(() => _request = next);
  }

  void _applyFilters() {
    _offset = 0;
    _search = _clean(_searchController.text);
    _municipality = _clean(_municipalityController.text);
    _propertyType = _clean(_typeController.text);
    _reload();
  }

  String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _clearFilters() {
    _searchController.clear();
    _municipalityController.clear();
    _typeController.clear();
    _offset = 0;
    _search = null;
    _municipality = null;
    _propertyType = null;
    _reload();
  }

  void _previous() {
    if (_offset <= 0) return;
    _offset = (_offset - _pageSize).clamp(0, 1 << 30);
    _reload();
  }

  void _next() {
    _offset += _pageSize;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['properties'];
        final properties = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        final hasMore = data?['has_more'] == true;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Properties',
              subtitle:
                  'Connecticut property universe • search, inspect, and open intelligence',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'PROPERTY INVENTORY',
                      value: '1,282,833',
                      detail: 'Imported Connecticut CAMA / parcel rows',
                      icon: Icons.home_work_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PAGE',
                      value: '${(_offset ~/ _pageSize) + 1}',
                      detail:
                          '${properties.isEmpty ? 0 : _offset + 1}–${_offset + properties.length}',
                      icon: Icons.view_list_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'SEARCH MODE',
                      value: _search == null &&
                              _municipality == null &&
                              _propertyType == null
                          ? 'Browse'
                          : 'Filtered',
                      detail: '25 properties per request',
                      icon: Icons.manage_search_rounded,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              _propertyField(
                                controller: _searchController,
                                label: 'Address or parcel',
                                icon: Icons.search_rounded,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                              const SizedBox(height: 10),
                              _propertyField(
                                controller: _municipalityController,
                                label: 'Municipality',
                                icon: Icons.location_city_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                              const SizedBox(height: 10),
                              _propertyField(
                                controller: _typeController,
                                label: 'Property type',
                                icon: Icons.category_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _propertyField(
                                controller: _searchController,
                                label: 'Address or parcel',
                                icon: Icons.search_rounded,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _propertyField(
                                controller: _municipalityController,
                                label: 'Municipality',
                                icon: Icons.location_city_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _propertyField(
                                controller: _typeController,
                                label: 'Property type',
                                icon: Icons.category_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: loading ? null : _applyFilters,
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Search'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: loading ? null : _clearFilters,
                          icon: const Icon(Icons.clear_rounded, size: 17),
                          label: const Text('Clear'),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Search narrows properties before intelligence joins',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.38),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (properties.isEmpty)
              const Card(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No properties match this search.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Connecticut Properties',
                        subtitle:
                            'Inventory • property facts • attached intelligence',
                        action: 'Open property',
                      ),
                      const SizedBox(height: 14),
                      ...properties.map(
                        (property) => _PropertyListCard(property: property),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _offset > 0 && !loading ? _previous : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                            ),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: hasMore && !loading ? _next : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                            label: const Text('Next'),
                          ),
                          const Spacer(),
                          Text(
                            '${properties.length} returned',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _propertyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
        ),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
        isDense: true,
        filled: true,
        fillColor: AppTheme.panelSoft.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.cyan),
        ),
      ),
    );
  }
}

class _PropertyListCard extends StatelessWidget {
  const _PropertyListCard({required this.property});

  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final address = (property['full_address'] ?? '').toString();
    final municipality = (property['municipality'] ?? 'Unknown').toString();
    final county = (property['county'] ?? '').toString();
    final parcel = (property['parcel_number'] ?? 'No parcel').toString();
    final type = (property['property_type'] ?? 'UNKNOWN').toString();
    final score = property['final_score'] as num?;
    final opportunityScore = property['opportunity_score'] as num?;
    final priority = property['opportunity_priority']?.toString();
    final signal = property['top_signal_type']?.toString();
    final assessed = property['assessed_total_value'] as num?;
    final yearBuilt = property['year_built'];

    final displayAddress = address.trim().isEmpty || address == '${property['postal_code']}, CT'
        ? '$municipality, CT • $parcel'
        : address;

    final chips = <Widget>[
      _OpportunityChip(label: type, color: AppTheme.blue),
      if (score != null) _OpportunityChip(label: 'SCORE ${score.toStringAsFixed(1)}', color: AppTheme.cyan),
      if (priority != null) _OpportunityChip(label: priority.toUpperCase(), color: _opportunityPriorityColor(priority)),
      if (signal != null) _OpportunityChip(label: signal.replaceAll('_', ' ').toUpperCase(), color: AppTheme.green),
    ];

    final facts = [
      if (yearBuilt != null) 'Built $yearBuilt',
      if (assessed != null) '\$${_formatInteger(assessed)} assessed',
    ];

    Widget identity({required bool compact}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.cyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.home_work_outlined, color: AppTheme.cyan, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayAddress, maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text([municipality, if (county.isNotEmpty) '$county County', parcel].join(' • '), maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.35)),
            ],
          ),
        ),
        if (compact) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        ],
      ],
    );

    return InkWell(
      onTap: () => _showPropertyInventoryDetail(context, property),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final opportunityText = opportunityScore == null ? 'No active opportunity' : 'Opportunity ${opportunityScore.toStringAsFixed(1)}';
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity(compact: true),
                  const SizedBox(height: 11),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 14,
                    runSpacing: 7,
                    children: [
                      Text(opportunityText, style: TextStyle(color: opportunityScore == null ? AppTheme.textMuted : AppTheme.cyan, fontSize: 9, fontWeight: FontWeight.w700)),
                      Text(facts.isEmpty ? 'Property record' : facts.join(' • '), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 4, child: identity(compact: false)),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Wrap(spacing: 6, runSpacing: 6, children: chips)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 135,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(opportunityText, style: TextStyle(color: opportunityScore == null ? AppTheme.textMuted : AppTheme.cyan, fontSize: 9, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(facts.isEmpty ? 'Property record' : facts.join(' • '), textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _showPropertyInventoryDetail(
  BuildContext context,
  Map<String, dynamic> property,
) {
  final propertyId = property['property_id']?.toString();
  if (propertyId == null || propertyId.isEmpty) return;

  showDialog<void>(
    context: context,
    builder: (context) => _PropertyIntelligenceDialog(propertyId: propertyId),
  );
}

class _PropertyIntelligenceDialog extends StatefulWidget {
  const _PropertyIntelligenceDialog({required this.propertyId});

  final String propertyId;

  @override
  State<_PropertyIntelligenceDialog> createState() =>
      _PropertyIntelligenceDialogState();
}

class _PropertyIntelligenceDialogState
    extends State<_PropertyIntelligenceDialog> {
  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final results=await Future.wait<Object>([
      http.post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_property_detail_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({'p_property_id': widget.propertyId}),
        ).timeout(const Duration(seconds: 30)),
      _callRpc('bridgepoint_property_timeline_v78',{'p_property_id':widget.propertyId,'p_limit':120})
        .catchError((_)=><String,dynamic>{}),
    ]);
    final response=results[0] as http.Response;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Property Intelligence API ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected property intelligence response.');
    }
    final detail=Map<String,dynamic>.from(decoded);
    final timeline=results[1] as Map<String,dynamic>;
    if(timeline['timeline'] is List){
      detail['timeline']=timeline['timeline'];
      detail['timeline_explanation']=timeline['explanation'];
      final summary=detail['summary'] is Map?Map<String,dynamic>.from(detail['summary'] as Map):<String,dynamic>{};
      summary['timeline_item_count']=timeline['item_count'];detail['summary']=summary;
    }
    return detail;
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.panel,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 850),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const SizedBox(
                height: 520,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.cyan,
                    strokeWidth: 2.5,
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DashboardError(
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data ?? <String, dynamic>{};
            final property = data['property'] is Map
                ? Map<String, dynamic>.from(data['property'] as Map)
                : <String, dynamic>{};
            final summary = data['summary'] is Map
                ? Map<String, dynamic>.from(data['summary'] as Map)
                : <String, dynamic>{};
            final scores = _detailList(data['scores']);
            final opportunities = _detailList(data['opportunities']);
            final signals = _detailList(data['signals']);
            final timeline = _detailList(data['timeline']);
            final physical = data['physical_intelligence'] is Map
                ? Map<String, dynamic>.from(
                    data['physical_intelligence'] as Map,
                  )
                : <String, dynamic>{};
            final solar = data['solar_intelligence'] is Map
                ? Map<String, dynamic>.from(data['solar_intelligence'] as Map)
                : <String, dynamic>{};
            final propertyDna = data['property_dna'] is Map
                ? Map<String, dynamic>.from(data['property_dna'] as Map)
                : <String, dynamic>{};
            final building2d = _detailList(physical['building_2d']);
            final building3d = _detailList(physical['building_3d']);
            final solarInstallations = _detailList(solar['installations']);
            final solarPotential = _detailList(solar['potential']);
            final patterns = _detailList(data['patterns']);
            final relationships = _detailList(data['relationships']);
            final modernScores = _detailList(data['modern_scores']);
            final modernPatterns = _detailList(data['modern_patterns']);
            final modernOpportunities =
                _detailList(data['modern_opportunities']);

            final address =
                '${property['full_address'] ?? '${property['municipality'] ?? 'Connecticut'} property'}';
            final assessed = property['assessed_total_value'] as num?;
            final market = property['market_total_value'] as num?;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hub_outlined,
                        color: AppTheme.cyan,
                        size: 25,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PROPERTY INTELLIGENCE RECORD • ${property['municipality'] ?? 'CT'} • ${property['parcel_number'] ?? 'No parcel'}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh intelligence',
                        onPressed: _reload,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withOpacity(.06)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniStat(
                              label: 'MODEL SCORES',
                              value: '${summary['score_count'] ?? scores.length}',
                            ),
                            _MiniStat(
                              label: 'OPPORTUNITIES',
                              value:
                                  '${summary['active_opportunity_count'] ?? opportunities.length}',
                            ),
                            _MiniStat(
                              label: 'SIGNALS',
                              value: '${summary['signal_count'] ?? signals.length}',
                            ),
                            _MiniStat(
                              label: 'TIMELINE',
                              value:
                                  '${summary['timeline_item_count'] ?? timeline.length}',
                            ),
                            _MiniStat(
                              label: 'PHYSICAL',
                              value:
                                  '${propertyDna['physical_record_count'] ?? building2d.length + building3d.length}',
                            ),
                            _MiniStat(
                              label: 'PATTERNS',
                              value:
                                  '${propertyDna['pattern_count'] ?? patterns.length}',
                            ),
                            _MiniStat(
                              label: 'RELATIONSHIPS',
                              value:
                                  '${propertyDna['relationship_count'] ?? relationships.length}',
                            ),
                            _MiniStat(
                              label: 'V37 SCORE',
                              value: modernScores.isEmpty
                                  ? '—'
                                  : _formatDecimal(
                                      modernScores.first['intelligence_score'],
                                    ),
                            ),
                            _MiniStat(
                              label: 'V38 OPPORTUNITIES',
                              value: '${modernOpportunities.length}',
                            ),
                            _MiniStat(
                              label: 'ASSESSED',
                              value: assessed == null
                                  ? '—'
                                  : '\$${_formatInteger(assessed)}',
                            ),
                            _MiniStat(
                              label: 'MARKET',
                              value: market == null
                                  ? '—'
                                  : '\$${_formatInteger(market)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _DetailSection(
                          title: 'Property',
                          subtitle: 'Canonical Connecticut property record',
                          child: Wrap(
                            spacing: 22,
                            runSpacing: 10,
                            children: [
                              _DetailFact('Type', property['property_type']),
                              _DetailFact('Land use', property['land_use_description']),
                              _DetailFact('Year built', property['year_built']),
                              _DetailFact('Buildings', property['building_count']),
                              _DetailFact('Acreage', property['acreage']),
                              _DetailFact('Tax year', property['tax_year']),
                              _DetailFact('County', property['county']),
                              _DetailFact('Postal', property['postal_code']),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Modern BridgePoint Intelligence',
                          subtitle:
                              'V37 scoring, V36 compound patterns and V38 opportunity decisions',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'This property has not reached the modern intelligence engines yet.',
                            records: <Map<String, dynamic>>[
                              ...modernScores.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'V37 Property Score',
                                  ...row,
                                },
                              ),
                              ...modernPatterns.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'V36 Pattern',
                                  ...row,
                                },
                              ),
                              ...modernOpportunities.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'V38 Opportunity',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Physical & Building Intelligence',
                          subtitle:
                              'Connecticut 2023 2D and 3D building baselines linked to this property',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'No matched building baseline currently attached.',
                            records: <Map<String, dynamic>>[
                              ...building2d.map(
                                (row) => <String, dynamic>{
                                  'record_type': '2D building baseline',
                                  ...row,
                                },
                              ),
                              ...building3d.map(
                                (row) => <String, dynamic>{
                                  'record_type': '3D building baseline',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Solar Intelligence',
                          subtitle:
                              'Known installations and property-level solar potential',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'No solar installation or potential record currently attached.',
                            records: <Map<String, dynamic>>[
                              ...solarInstallations.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Solar installation',
                                  ...row,
                                },
                              ),
                              ...solarPotential.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Solar potential',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Patterns & Relationships',
                          subtitle:
                              'Cross-source patterns, ownership and connected-entity intelligence',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'No active patterns or relationships currently attached.',
                            records: <Map<String, dynamic>>[
                              ...patterns.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Pattern',
                                  ...row,
                                },
                              ),
                              ...relationships.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Relationship',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Model Scores',
                          subtitle:
                              'Current BridgePoint scoring results for this property',
                          child: scores.isEmpty
                              ? const _EmptyDetail('No current model scores.')
                              : Column(
                                  children: scores
                                      .map((s) => _ScoreDetailRow(score: s))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Active Opportunities',
                          subtitle:
                              'Qualified actions currently surfaced by BridgePoint',
                          child: opportunities.isEmpty
                              ? const _EmptyDetail(
                                  'No active opportunities currently attached.',
                                )
                              : Column(
                                  children: opportunities
                                      .map(
                                        (o) => _OpportunityDetailRow(
                                          opportunity: o,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Signals & Evidence',
                          subtitle:
                              'Property evidence and area/context intelligence are labeled separately',
                          child: signals.isEmpty
                              ? const _EmptyDetail('No signals attached.')
                              : Column(
                                  children: signals
                                      .map((s) => _SignalDetailRow(signal: s))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Property Timeline',
                          subtitle:
                              '${data['timeline_explanation']??'One chronological history of evidence, patterns, opportunities, your notes, and claim activity.'}',
                          child: timeline.isEmpty
                              ? const _EmptyDetail('No timeline items.')
                              : Column(
                                  children: timeline
                                      .map((t) => _TimelineDetailRow(item: t))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Property ID: ${data['property_id'] ?? widget.propertyId}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.25),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _detailList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

class _JsonIntelligenceList extends StatelessWidget {
  const _JsonIntelligenceList({
    required this.records,
    required this.emptyMessage,
  });

  final List<Map<String, dynamic>> records;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return _EmptyDetail(emptyMessage);
    return Column(
      children: records.take(25).map((record) {
        final visible = record.entries.where((entry) {
          final value = entry.value;
          return value != null &&
              '$value'.trim().isNotEmpty &&
              value is! Map &&
              value is! List;
        }).take(10).toList();
        final title = '${record['record_type'] ?? 'Intelligence record'}';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.025),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 18,
                runSpacing: 7,
                children: visible
                    .where((entry) => entry.key != 'record_type')
                    .map(
                      (entry) => _DetailFact(
                        _intelligenceLabel(entry.key),
                        entry.value,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _intelligenceLabel(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact(this.label, this.value);

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${value ?? '—'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDetailRow extends StatelessWidget {
  const _ScoreDetailRow({required this.score});
  final Map<String, dynamic> score;

  @override
  Widget build(BuildContext context) {
    final finalScore = score['final_score'] as num?;
    final confidence = score['confidence_score'] as num?;
    return _DetailRowShell(
      icon: Icons.speed_rounded,
      title: '${score['model_name'] ?? score['model_key'] ?? 'Model score'}',
      subtitle: '${score['explanation'] ?? 'Current intelligence score'}',
      chips: [
        if (finalScore != null)
          _OpportunityChip(
            label: 'SCORE ${finalScore.toStringAsFixed(1)}',
            color: AppTheme.cyan,
          ),
        if (score['score_status'] != null)
          _OpportunityChip(
            label: '${score['score_status']}'.toUpperCase(),
            color: AppTheme.blue,
          ),
        if (confidence != null)
          _OpportunityChip(
            label: '${confidence.toStringAsFixed(0)}% CONF',
            color: AppTheme.green,
          ),
        _OpportunityChip(
          label: '${score['event_count'] ?? 0} EVENTS',
          color: AppTheme.textMuted,
        ),
      ],
    );
  }
}

class _OpportunityDetailRow extends StatelessWidget {
  const _OpportunityDetailRow({required this.opportunity});
  final Map<String, dynamic> opportunity;

  @override
  Widget build(BuildContext context) {
    final score = opportunity['score'] as num?;
    final priority = '${opportunity['priority'] ?? 'medium'}';
    return _DetailRowShell(
      icon: Icons.bolt_rounded,
      title: '${opportunity['title'] ?? 'Opportunity'}',
      subtitle:_opportunityWhyThisProperty(opportunity),
      chips: [
        if (score != null)
          _OpportunityChip(
            label: 'SCORE ${score.toStringAsFixed(1)}',
            color: AppTheme.cyan,
          ),
        _OpportunityChip(
          label: priority.toUpperCase(),
          color: _opportunityPriorityColor(priority),
        ),
        if (opportunity['model_name'] != null)
          _OpportunityChip(
            label: '${opportunity['model_name']}',
            color: AppTheme.blue,
          ),
      ],
    );
  }
}

class _SignalDetailRow extends StatelessWidget {
  const _SignalDetailRow({required this.signal});
  final Map<String, dynamic> signal;

  @override
  Widget build(BuildContext context) {
    final evidence = signal['evidence_summary'] is Map
        ? Map<String, dynamic>.from(signal['evidence_summary'] as Map)
        : <String, dynamic>{};
    final precision = '${evidence['matching_precision'] ?? ''}';
    final contextual = precision.startsWith('AREA_') ||
        '${evidence['storage_mode'] ?? ''}'.contains('area_context');
    final severity = signal['severity'] as num?;
    final confidence = signal['confidence'] as num?;

    return _DetailRowShell(
      icon: contextual ? Icons.public_rounded : Icons.place_outlined,
      title: '${signal['signal_name'] ?? signal['title'] ?? 'Signal'}',
      subtitle: contextual
          ? 'Area/context intelligence • ${evidence['provider'] ?? signal['signal_family'] ?? ''}'
          : 'Property evidence • ${evidence['provider'] ?? signal['signal_family'] ?? ''}',
      chips: [
        _OpportunityChip(
          label: contextual ? 'AREA CONTEXT' : 'PROPERTY EVIDENCE',
          color: contextual ? AppTheme.blue : AppTheme.green,
        ),
        if (severity != null)
          _OpportunityChip(
            label: 'SEV ${severity.toStringAsFixed(0)}',
            color: AppTheme.cyan,
          ),
        if (confidence != null)
          _OpportunityChip(
            label: '${(confidence * 100).toStringAsFixed(0)}% CONF',
            color: AppTheme.textMuted,
          ),
        _OpportunityChip(
          label: '${signal['evidence_count'] ?? 0} EVIDENCE',
          color: AppTheme.textMuted,
        ),
      ],
    );
  }
}

class _TimelineDetailRow extends StatelessWidget {
  const _TimelineDetailRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = '${item['timeline_type'] ?? 'SIGNAL'}';
    final when = '${item['timeline_at'] ?? ''}';
    final support='${item['support_level']??''}';
    final confidence=item['confidence'] as num?;
    final severity=item['severity'] as num?;
    final modelUses=(item['model_uses'] as List? ?? const []).map((e)=>'$e').toList();
    final color=switch(type){'CLAIM'=>AppTheme.green,'NOTE'=>AppTheme.amber,'PATTERN'=>const Color(0xFF9B7BFF),'OPPORTUNITY'=>AppTheme.cyan,_=>AppTheme.blue};
    final icon=switch(type){'CLAIM'=>Icons.policy_rounded,'NOTE'=>Icons.sticky_note_2_outlined,'PATTERN'=>Icons.schema_rounded,'OPPORTUNITY'=>Icons.bolt_rounded,_=>Icons.radio_button_checked_rounded};
    return InkWell(
      onTap:()=>_showInfoDialog(
        context,
        '${item['title']??type}',
        '${item['description']??'This event is part of the property history.'}'
        '\n\nWhat it means: ${item['why_it_matters']??'This dated observation adds context to the property story.'}'
        '\n\nType: $type'
        '\nEvidence level: ${support.isEmpty?'PROPERTY HISTORY':support.replaceAll('_',' ')}'
        '\nDate: ${when.isEmpty?'Not available':when}'
        '\nSource: ${item['source_label']??'BridgePoint intelligence'}'
        '${item['match_method']!=null?'\nHow it was matched: ${item['match_method']}':''}'
        '${confidence!=null?'\nConfidence: ${(confidence*100).toStringAsFixed(0)}%':''}'
        '${severity!=null?'\nSeverity/strength: ${severity.toStringAsFixed(0)}':''}'
        '${modelUses.isNotEmpty?'\nUsed directly by: ${modelUses.map((e)=>e.replaceAll('_',' ')).join(', ')}':''}'
        '\n\nImportant limitation: ${item['limitations']??'Verify material facts with the cited source or a qualified inspection before acting.'}',
      ),
      borderRadius:BorderRadius.circular(8),
      child:Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(.045)),
          ),
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,color:color,size: 15),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['title'] ?? type}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  when.length >= 10 ? when.substring(0, 10) : when,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 8,
                  ),
                ),
                if('${item['description']??''}'.isNotEmpty)...[
                  const SizedBox(height:4),
                  Text('${item['description']}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
                ],
                if('${item['source_label']??''}'.isNotEmpty)...[
                  const SizedBox(height:3),Text('Source: ${item['source_label']}',style:TextStyle(color:color.withOpacity(.9),fontSize:8,fontWeight:FontWeight.w700)),
                ],
                if(support.isNotEmpty)...[
                  const SizedBox(height:5),Wrap(spacing:5,runSpacing:4,children:[
                    _OpportunityChip(label:support.replaceAll('_',' '),color:support=='DIRECT_MODEL_EVIDENCE'||support=='VERIFIED_OPPORTUNITY'?AppTheme.green:support=='AREA_CONTEXT'?AppTheme.blue:color),
                    if(confidence!=null)_OpportunityChip(label:'${(confidence*100).toStringAsFixed(0)}% CONF',color:AppTheme.textMuted),
                    if(severity!=null)_OpportunityChip(label:'SEV ${severity.toStringAsFixed(0)}',color:AppTheme.amber),
                  ]),
                ],
              ],
            ),
          ),
          _OpportunityChip(
            label: type,
            color: color,
          ),
        ],
        ),
      ),
    );
  }
}

class _DetailRowShell extends StatelessWidget {
  const _DetailRowShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:()=>_showInfoDialog(context,title,'$subtitle\n\nThe badges show how BridgePoint classified this evidence. Use it as supporting context—not as a guarantee—and confirm important decisions with the cited source or an inspection.'),
      borderRadius:BorderRadius.circular(8),
      child:Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(.045)),
          ),
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 8,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 10,
      ),
    );
  }
}

class _OpportunitiesPage extends StatefulWidget {
  const _OpportunitiesPage({
    required this.modelKey,
    required this.packageName,
  });

  final String modelKey;
  final String packageName;

  @override
  State<_OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<_OpportunitiesPage> {
  static const int _pageSize = 25;

  late Future<Map<String, dynamic>> _request;
  int _offset = 0;
  String? _priority;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void didUpdateWidget(covariant _OpportunitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelKey != widget.modelKey) {
      _offset = 0;
      _priority = null;
      _request = _load();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_opportunities_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_model_key': widget.modelKey,
            'p_limit': _pageSize,
            'p_offset': _offset,
            'p_priority': _priority,
            'p_stage': null,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Opportunities API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException(
        'Unexpected BridgePoint Opportunities response.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _request = next;
    });
  }

  void _setPriority(String? value) {
    _offset = 0;
    _priority = value == 'all' ? null : value;
    _refresh();
  }

  void _previousPage() {
    if (_offset <= 0) return;
    _offset = (_offset - _pageSize).clamp(0, 1 << 30);
    _refresh();
  }

  void _nextPage() {
    _offset += _pageSize;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['opportunities'];
        final opportunities = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        final total = (data?['total_results'] as num?)?.toInt() ?? 0;
        final hasMore = data?['has_more'] == true;
        final loading =
            snapshot.connectionState == ConnectionState.waiting;
        final first = total == 0 ? 0 : _offset + 1;
        final last = total == 0
            ? 0
            : (_offset + opportunities.length).clamp(0, total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Opportunities',
              subtitle:
                  '${widget.packageName} • live ranked Connecticut property intelligence',
              onRefresh: _refresh,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'MATCHING OPPORTUNITIES',
                      value: loading && data == null
                          ? '—'
                          : _formatInteger(total),
                      detail: widget.packageName,
                      icon: Icons.bolt_rounded,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'CURRENT PAGE',
                      value: total == 0
                          ? '0'
                          : '${(_offset ~/ _pageSize) + 1}',
                      detail: '$first–$last of ${_formatInteger(total)}',
                      icon: Icons.view_list_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'FILTER',
                      value: _priority == null
                          ? 'All'
                          : _priority!.toUpperCase(),
                      detail: 'Priority filter',
                      icon: Icons.filter_alt_outlined,
                      accent: AppTheme.amber,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.cyan,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Priority',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _priority ?? 'all',
                      dropdownColor: AppTheme.panel,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('Critical'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: loading ? null : _setPriority,
                    ),
                    const Spacer(),
                    Text(
                      '25 results per page',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (opportunities.isEmpty)
              const Card(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No opportunities match the current filters.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Ranked Property Opportunities',
                        subtitle:
                            'Live scoring • signals • evidence • recommended action',
                        action: 'Open property',
                      ),
                      const SizedBox(height: 14),
                      ...opportunities.map(
                        (opportunity) => _OpportunityListCard(
                          opportunity: opportunity,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _offset > 0 && !loading ? _previousPage : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                            ),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed:
                                hasMore && !loading ? _nextPage : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                            label: const Text('Next'),
                          ),
                          const Spacer(),
                          Text(
                            '$first–$last of ${_formatInteger(total)}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OpportunityListCard extends StatelessWidget {
  const _OpportunityListCard({required this.opportunity});

  final Map<String, dynamic> opportunity;

  @override
  Widget build(BuildContext context) {
    final score = opportunity['score'] as num?;
    final confidence = opportunity['confidence_score'] as num? ??
        opportunity['opportunity_confidence_percent'] as num?;
    final priority =
        (opportunity['priority'] ?? 'medium').toString().toLowerCase();
    final priorityColor = _opportunityPriorityColor(priority);
    final rank = opportunity['rank_value'];
    final address =
        (opportunity['full_address'] ?? 'Address unavailable').toString();
    final signal =
        (opportunity['top_signal_type'] ?? 'No top signal').toString();
    final events = (opportunity['event_count'] as num?)?.toInt() ?? 0;
    final distinctSignals =
        (opportunity['distinct_signal_count'] as num?)?.toInt() ?? 0;
    final stage = (opportunity['stage'] ?? 'monitor').toString();
    final action =
        (opportunity['recommended_action'] ?? 'Continue monitoring').toString();

    final chips = <Widget>[
      _OpportunityChip(label: priority.toUpperCase(), color: priorityColor),
      _OpportunityChip(
        label: stage.replaceAll('_', ' ').toUpperCase(),
        color: AppTheme.blue,
      ),
      _OpportunityChip(label: '$events EVENTS', color: AppTheme.cyan),
      _OpportunityChip(
        label: '$distinctSignals SIGNALS',
        color: AppTheme.green,
      ),
    ];

    Widget rankBlock({required bool compact}) => Container(
      width: compact ? 52 : 58,
      padding: compact ? const EdgeInsets.symmetric(vertical: 7) : EdgeInsets.zero,
      decoration: compact
          ? BoxDecoration(
              color: AppTheme.cyan.withOpacity(.07),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rank == null ? '—' : '#$rank',
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score == null ? '—' : score.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    Widget identity({required bool compact}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${opportunity['model_name'] ?? opportunity['model_key'] ?? 'BridgePoint'} • $signal',
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            height: 1.35,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () => _showOpportunityDetail(context, opportunity),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      rankBlock(compact: true),
                      const SizedBox(width: 11),
                      Expanded(child: identity(compact: true)),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                  const SizedBox(height: 11),
                  Text(
                    confidence == null
                        ? 'Confidence —'
                        : 'Confidence ${confidence.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                rankBlock(compact: false),
                Container(
                  width: 1,
                  height: 52,
                  color: Colors.white.withOpacity(0.07),
                ),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: identity(compact: false)),
                Expanded(
                  flex: 3,
                  child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 145,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        confidence == null
                            ? 'Confidence —'
                            : 'Confidence ${confidence.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        action,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpportunityChip extends StatelessWidget {
  const _OpportunityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

Color _priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppTheme.red;
    case 'high':
      return AppTheme.amber;
    case 'medium':
      return AppTheme.cyan;
    default:
      return AppTheme.textMuted;
  }
}

Future<void> _saveOpportunity(BuildContext context,Map<String,dynamic> opportunity) async {
  try{
    await _callRpc('bridgepoint_save_opportunity_v70',{
      'p_opportunity_id':opportunity['opportunity_id'],'p_property_id':opportunity['property_id'],
      'p_title':opportunity['title']??opportunity['model_name']??'BridgePoint opportunity',
      'p_address':opportunity['full_address']??'','p_score':opportunity['score'],
      'p_reason':_opportunityWhyThisProperty(opportunity),'p_recommended_action':opportunity['recommended_action']??'',
      'p_vertical_key':opportunity['vertical_key']??opportunity['model_key']??'','p_next_action_at':null});
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Opportunity saved to My Work.')));
  }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save',e.toString());}
}

Future<void> _showAddNoteDialog(BuildContext context,Map<String,dynamic> opportunity) async {
  final note=TextEditingController(); String preset='CALL';
  await showDialog(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
    title:const Text('Add a customer note'),
    content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Choose what happens next, then add anything your team should remember.',style:TextStyle(color:AppTheme.textMuted,height:1.45)),
      const SizedBox(height:14),DropdownButtonFormField<String>(value:preset,dropdownColor:AppTheme.panel,
        decoration:const InputDecoration(labelText:'Preset action',border:OutlineInputBorder()),
        items:const {'CALL':'Call customer','VISIT':'Visit property','QUOTE':'Prepare quote','FOLLOW_UP':'Follow up','NOT_INTERESTED':'Not interested','WON':'Won','LOST':'Lost','GENERAL':'General note'}
          .entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setState(()=>preset=v??preset)),
      const SizedBox(height:12),TextField(controller:note,maxLines:4,decoration:const InputDecoration(labelText:'Note',hintText:'Example: Owner asked for a call Tuesday afternoon.',border:OutlineInputBorder())),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:() async{
      if(note.text.trim().isEmpty)return;
      try{await _callRpc('bridgepoint_save_customer_note_v70',{
        'p_property_id':opportunity['property_id'],'p_opportunity_id':opportunity['opportunity_id'],
        'p_preset_key':preset,'p_note_text':note.text.trim(),'p_follow_up_at':null});
        if(dialogContext.mounted)Navigator.pop(dialogContext);
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Note saved to My Work.')));
      }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save note',e.toString());}
    },child:const Text('Save note'))],
  )));
  note.dispose();
}

void _showOpportunityDetail(
  BuildContext context,
  Map<String, dynamic> opportunity,
) {
  final score = opportunity['score'] as num?;
  final assessed = opportunity['assessed_total_value'] as num?;
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: AppTheme.panel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.home_work_outlined,
                        color: AppTheme.cyan,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (opportunity['full_address'] ??
                                  'Property Intelligence')
                              .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(
                        label: 'SCORE',
                        value: score?.toStringAsFixed(2) ?? '—',
                      ),
                      _MiniStat(
                        label: 'RANK',
                        value: opportunity['rank_value'] == null
                            ? '—'
                            : '#${opportunity['rank_value']}',
                      ),
                      _MiniStat(
                        label: 'EVENTS',
                        value: '${opportunity['event_count'] ?? 0}',
                      ),
                      _MiniStat(
                        label: 'SIGNALS',
                        value:
                            '${opportunity['distinct_signal_count'] ?? 0}',
                      ),
                      _MiniStat(
                        label: 'YEAR BUILT',
                        value: '${opportunity['year_built'] ?? '—'}',
                      ),
                      _MiniStat(
                        label: 'ASSESSED',
                        value: assessed == null
                            ? '—'
                            : '\$${_formatInteger(assessed)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _ReasoningPanel(opportunity:opportunity),
                  const SizedBox(height:20),
                  Row(children:[
                    Expanded(child:FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity'))),
                    const SizedBox(width:10),
                    Expanded(child:OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note'))),
                  ]),
                  const SizedBox(height: 18),
                  Text(
                    'Property ID: ${opportunity['property_id'] ?? '—'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.32),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MyWorkPage extends StatefulWidget {
  const _MyWorkPage();
  @override State<_MyWorkPage> createState()=>_MyWorkPageState();
}
class _MyWorkPageState extends State<_MyWorkPage>{
  late Future<Map<String,dynamic>> request;
  static const claimStages=['CLAIM_FILED','ADJUSTER_ASSIGNED','INSPECTION_SCHEDULED','INSPECTED','ESTIMATE_IN_PROGRESS','ESTIMATE_SUBMITTED','NEGOTIATION','APPROVED','WORK_SCHEDULED','IN_PROGRESS','COMPLETED','PAID','CLOSED_LOST'];
  @override void initState(){super.initState();request=_callRpc('bridgepoint_my_work_v78',const {'p_limit':200});}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_my_work_v78',const {'p_limit':200}));
  Future<void> stage(Map<String,dynamic> item,String value) async{
    try{await _callRpc('bridgepoint_update_lead_stage_v70',{
      'p_saved_opportunity_id':item['saved_opportunity_id'],'p_lead_stage':value,'p_next_action_at':item['next_action_at']});refresh();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not update lead',e.toString());}
  }
  Future<void> openClaim(Map<String,dynamic> item)async{
    final carrier=TextEditingController(),damage=TextEditingController();DateTime lossDate=DateTime.now();
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      backgroundColor:AppTheme.panel,title:const Text('Open claim workflow'),
      content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('This creates your private claim workspace and property timeline. BridgePoint never invents carrier or claim information.',style:TextStyle(color:AppTheme.textMuted,height:1.45)),const SizedBox(height:14),
        TextField(controller:damage,decoration:const InputDecoration(labelText:'Damage type (wind, hail, fire, water...)',border:OutlineInputBorder())),const SizedBox(height:10),
        TextField(controller:carrier,decoration:const InputDecoration(labelText:'Insurance carrier (optional)',border:OutlineInputBorder())),const SizedBox(height:10),
        OutlinedButton.icon(onPressed:()async{final picked=await showDatePicker(context:context,initialDate:lossDate,firstDate:DateTime(2000),lastDate:DateTime.now());if(picked!=null)setLocal(()=>lossDate=picked);},icon:const Icon(Icons.calendar_month_rounded),label:Text('Date of loss: ${lossDate.toIso8601String().substring(0,10)}')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Open claim'))],
    )));
    if(confirmed!=true)return;
    try{await _callRpc('bridgepoint_open_claim_v78',{'p_saved_opportunity_id':item['saved_opportunity_id'],'p_date_of_loss':lossDate.toIso8601String().substring(0,10),'p_damage_type':damage.text.trim(),'p_carrier_name':carrier.text.trim()});refresh();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not open claim',e.toString());}
  }
  Future<void> updateClaim(Map<String,dynamic> item,String value)async{
    try{await _callRpc('bridgepoint_update_claim_v78',{'p_claim_id':item['claim_id'],'p_claim_stage':value});refresh();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not update claim',e.toString());}
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
    final savedRaw=snapshot.data?['saved_opportunities'];final noteRaw=snapshot.data?['open_notes'];final claimRaw=snapshot.data?['claims'];final taskRaw=snapshot.data?['claim_tasks'];
    final saved=savedRaw is List?savedRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final notes=noteRaw is List?noteRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final claims=claimRaw is List?claimRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final tasks=taskRaw is List?taskRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final due=saved.where((e)=>e['next_action_at']!=null).length+notes.where((e)=>e['follow_up_at']!=null).length+tasks.length;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _PageHeading(title:'My Work',subtitle:'Saved opportunities • lead stages • notes • follow-up calendar',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
      const SizedBox(height:10),const _ExplainerBanner(icon:Icons.policy_rounded,title:'From first signal through paid claim',message:'Save a promising opportunity, qualify it, open a private claim workflow, record each milestone, attach notes and schedule the next action. Public evidence updates automatically; carrier details appear only when you enter them or authorize an integration.'),
      const SizedBox(height:18),LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
        _MetricCard(width:w,label:'SAVED LEADS',value:_formatInteger(saved.length),detail:'Opportunities kept by you',icon:Icons.bookmarks_rounded,accent:AppTheme.cyan),
        _MetricCard(width:w,label:'OPEN NOTES',value:_formatInteger(notes.length),detail:'Customer and property notes',icon:Icons.sticky_note_2_rounded,accent:AppTheme.green),
        _MetricCard(width:w,label:'ACTIVE CLAIMS',value:_formatInteger(claims.where((c)=>!['PAID','CLOSED_LOST'].contains(c['claim_stage'])).length),detail:'Customer-controlled claim workflows',icon:Icons.policy_rounded,accent:const Color(0xFF9B7BFF)),
        _MetricCard(width:w,label:'CALENDAR ITEMS',value:_formatInteger(due),detail:'Scheduled next actions',icon:Icons.calendar_month_rounded,accent:AppTheme.amber),
      ]);}),
      const SizedBox(height:18),
      if(snapshot.hasError)_DashboardError(message:snapshot.error.toString(),onRetry:refresh)
      else ...[
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const _PanelHeader(title:'Claims Lifecycle',subtitle:'Customer-controlled milestones from filing through completed work and payment',action:'Private'),const SizedBox(height:12),
        if(claims.isEmpty)const SizedBox(height:120,child:Center(child:Text('Save an opportunity, then choose “Open claim workflow” when a real claim exists.',style:TextStyle(color:AppTheme.textMuted))))
        else ...claims.map((item)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF9B7BFF).withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFF9B7BFF).withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.policy_rounded,color:Color(0xFF9B7BFF),size:19)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${item['address']??item['opportunity_title']??'Property claim'}',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${item['damage_type']??'Damage type not entered'} • ${item['carrier_name']??'Carrier not entered'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))])),if(item['claim_number']!=null)_OpportunityChip(label:'CLAIM ${item['claim_number']}',color:AppTheme.cyan)]),
          const SizedBox(height:10),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:'${item['claim_stage']}',dropdownColor:AppTheme.panel,decoration:const InputDecoration(labelText:'Claim stage',isDense:true,border:OutlineInputBorder()),items:claimStages.map((v)=>DropdownMenuItem(value:v,child:Text(v.replaceAll('_',' '),style:const TextStyle(fontSize:10)))).toList(),onChanged:(v){if(v!=null)updateClaim(item,v);})),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(item['approved_amount']==null?'Approval pending':'\$${_formatInteger(item['approved_amount'])} approved',style:const TextStyle(color:AppTheme.green,fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(item['next_action_at']==null?'No next action':'Next ${item['next_action_at'].toString().substring(0,10)}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))])]),
        ]))),
        if(tasks.isNotEmpty)...[const Divider(height:24),Text('${tasks.length} open claim task${tasks.length==1?'':'s'} on your calendar',style:const TextStyle(color:AppTheme.amber,fontSize:10,fontWeight:FontWeight.w800))],
      ]))),
      const SizedBox(height:16),
      LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;final width=wide?(c.maxWidth-16)/2:c.maxWidth;return Wrap(spacing:16,runSpacing:16,children:[
        SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Saved Opportunities',subtitle:'Your working lead list—independent of live ranking changes',action:'Lead stage'),const SizedBox(height:12),
          if(saved.isEmpty)const SizedBox(height:180,child:Center(child:Text('Open an opportunity and choose “Save opportunity.”',style:TextStyle(color:AppTheme.textMuted))))
          else ...saved.map((item)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(item['address']?.toString().isNotEmpty==true?item['address'].toString():item['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),Text('${item['score']??'—'}',style:const TextStyle(color:AppTheme.cyan,fontWeight:FontWeight.w900))]),
            const SizedBox(height:5),Text(item['reason']?.toString()??'',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),
            const SizedBox(height:9),DropdownButtonFormField<String>(value:item['lead_stage']?.toString()??'NEW',dropdownColor:AppTheme.panel,
              decoration:const InputDecoration(labelText:'Lead stage',isDense:true,border:OutlineInputBorder()),
              items:const ['NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM','WON','LOST'].map((v)=>DropdownMenuItem(value:v,child:Text(v.replaceAll('_',' ')))).toList(),
              onChanged:(v){if(v!=null)stage(item,v);}),
            if(!claims.any((claim)=>claim['saved_opportunity_id']==item['saved_opportunity_id']))...[
              const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>openClaim(item),icon:const Icon(Icons.policy_outlined),label:const Text('Open claim workflow'))),
            ],
          ]))),
        ])))),
        SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Notes & Calendar',subtitle:'Preset actions and scheduled follow-ups',action:'Next action'),const SizedBox(height:12),
          if(notes.isEmpty)const SizedBox(height:180,child:Center(child:Text('Customer notes and follow-ups will appear here.',style:TextStyle(color:AppTheme.textMuted))))
          else ...notes.map((item)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12)),child:Row(children:[
            Container(width:38,height:38,decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.event_note_rounded,color:AppTheme.amber,size:19)),
            const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item['preset_key']?.toString().replaceAll('_',' ')??'NOTE',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:AppTheme.cyan)),const SizedBox(height:4),Text(item['note_text']?.toString()??'',style:const TextStyle(fontSize:11,height:1.4))])),
            Text(item['follow_up_at']==null?'UNSCHEDULED':item['follow_up_at'].toString().substring(0,10),style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),
          ]))),
        ])))),
      ]);}),],
    ]);
  });
}

class _OwnerCenterPage extends StatefulWidget{
  const _OwnerCenterPage();
  @override State<_OwnerCenterPage> createState()=>_OwnerCenterPageState();
}

class _OwnerCenterPageState extends State<_OwnerCenterPage>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('owner_dashboard_v84',const {});}
  void refresh()=>setState(()=>request=_callRpc('owner_dashboard_v84',const {}));
  Map<String,dynamic> map(dynamic value)=>value is Map?Map<String,dynamic>.from(value):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic value)=>value is List
      ?value.whereType<Map>().map((item)=>Map<String,dynamic>.from(item)).toList()
      :<Map<String,dynamic>>[];
  String money(dynamic value){final amount=value is num?value.toDouble():double.tryParse('$value')??0;return '\$${amount.toStringAsFixed(0)}';}

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final system=map(data['system']),customers=map(data['customers']),revenue=map(data['revenue']),usage=map(data['usage']);
      final offer=map(data['founding_offer']),intel=map(data['intelligence']);
      final verticals=rows(data['top_opportunity_verticals']),failures=rows(data['recent_failures']);
      final healthy=(system['failed_runs_15m'] as num? ?? 0)==0;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PageHeading(title:'Owner Center',subtitle:'Your private daily view of revenue • customers • automation • intelligence',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
        const SizedBox(height:10),_ExplainerBanner(
          icon:healthy?Icons.verified_rounded:Icons.warning_amber_rounded,
          title:healthy?'BridgePoint is operating normally':'BridgePoint needs your attention',
          message:healthy?'Start here each day. This page combines customer growth, revenue readiness, promotion use, automation health, and intelligence production.':'Review the recent failures below. Customer-facing intelligence remains separated from this owner-only page.',
        ),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
          _MetricCard(width:w,label:'USING NOW',value:_formatInteger(usage['active_now']??0),detail:'Active during the last 5 minutes',icon:Icons.online_prediction_rounded,accent:AppTheme.cyan),
          _MetricCard(width:w,label:'TODAY / 7 DAYS',value:'${_formatInteger(usage['daily_active']??0)} / ${_formatInteger(usage['weekly_active']??0)}',detail:'Unique people who opened BridgePoint',icon:Icons.insights_rounded,accent:AppTheme.blue),
          _MetricCard(width:w,label:'CUSTOMERS',value:_formatInteger(customers['total_accounts']??0),detail:'${customers['new_24h']??0} today • ${customers['new_7d']??0} this week',icon:Icons.groups_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'ACTIVE MRR',value:money(revenue['active_mrr']),detail:'${customers['active_paid']??0} active paid accounts',icon:Icons.payments_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'TRIAL PIPELINE',value:money(revenue['trial_pipeline_mrr']),detail:'${customers['active_trials']??0} active customer trials',icon:Icons.hourglass_top_rounded,accent:AppTheme.amber),
          _MetricCard(width:w,label:'VERIFIED OPPORTUNITIES',value:_formatInteger(intel['verified_unique_opportunities']??0),detail:'Unique properties with named direct evidence',icon:Icons.verified_rounded,accent:AppTheme.red),
          _MetricCard(width:w,label:'30-DAY USERS',value:_formatInteger(usage['monthly_active']??0),detail:'${usage['page_views_7d']??0} page views this week',icon:Icons.calendar_month_rounded,accent:const Color(0xFF9B7BFF)),
        ]);}),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;final w=wide?(c.maxWidth-16)/2:c.maxWidth;return Wrap(spacing:16,runSpacing:16,children:[
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Customer & Revenue Watch',subtitle:'The items most likely to need a decision today',action:'Private'),const SizedBox(height:14),
            _OwnerStatusRow('Trials ending within 72 hours','${customers['trials_ending_72h']??0}',AppTheme.amber),
            _OwnerStatusRow('Past-due subscriptions','${customers['past_due']??0}',(customers['past_due'] as num? ?? 0)>0?AppTheme.red:AppTheme.green),
            _OwnerStatusRow('Checkout connected',revenue['checkout_connected']==true?'YES':'NOT YET',revenue['checkout_connected']==true?AppTheme.green:AppTheme.amber),
            _OwnerStatusRow('Founding offer remaining','${offer['remaining']??10} of 10',AppTheme.cyan),
            _OwnerStatusRow('Founding discounts applied','${offer['applied']??0}',AppTheme.green),
          ])))),
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Automation & Intelligence',subtitle:'Whether the data-to-opportunity system is moving',action:'Live'),const SizedBox(height:14),
            _OwnerStatusRow('Active scheduled jobs','${system['active_jobs']??0}',AppTheme.cyan),
            _OwnerStatusRow('Failed runs in 15 minutes','${system['failed_runs_15m']??0}',healthy?AppTheme.green:AppTheme.red),
            _OwnerStatusRow('Verified unique opportunities',_formatInteger(intel['verified_unique_opportunities']??0),AppTheme.amber),
            _OwnerStatusRow('Elite verified opportunities',_formatInteger(intel['elite_opportunities']??0),AppTheme.green),
            _OwnerStatusRow('Minimum direct signals','${intel['minimum_direct_signals']??'—'}',AppTheme.cyan),
            _OwnerStatusRow('Property scores',_formatInteger(intel['property_scores_v37']??0),AppTheme.blue),
            _OwnerStatusRow('Detected patterns',_formatInteger(intel['patterns_v36']??0),AppTheme.green),
          ])))),
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Opportunity Mix',subtitle:'Where BridgePoint currently sees the most actionable volume',action:'Top models'),const SizedBox(height:12),
            if(verticals.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Opportunity mix will appear as models produce results.',style:TextStyle(color:AppTheme.textMuted)))
            else ...verticals.map((item)=>_OwnerStatusRow(item['vertical_key']?.toString().replaceAll('_',' ').toUpperCase()??'MODEL','${_formatInteger(item['opportunity_count']??0)} • avg ${item['average_score']??'—'}',AppTheme.cyan)),
          ])))),
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Recent Automation Failures',subtitle:'Only owner-visible operational messages',action:'Last 10'),const SizedBox(height:12),
            if(failures.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Row(children:[Icon(Icons.check_circle_rounded,color:AppTheme.green),SizedBox(width:10),Expanded(child:Text('No recent failures recorded.',style:TextStyle(color:AppTheme.textMuted)))]))
            else ...failures.map((item)=>Container(
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(11),
              decoration:BoxDecoration(
                color:AppTheme.red.withOpacity(.06),
                borderRadius:BorderRadius.circular(10),
                border:Border.all(color:AppTheme.red.withOpacity(.14)),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('JOB ${item['jobid']??'—'} • ${item['status']??'FAILED'}',style:const TextStyle(color:AppTheme.red,fontSize:10,fontWeight:FontWeight.w900)),
                const SizedBox(height:4),
                Text(item['message']?.toString()??'No error detail',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),
              ]),
            )),
          ])))),
        ]);}),
        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(
          alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:18,runSpacing:12,children:[
            SizedBox(width:c.maxWidth>=760?c.maxWidth-260:c.maxWidth,child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Stripe payout readiness',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
              SizedBox(height:5),
              Text('Connect and verify the bank account that receives BridgePoint revenue. Bank details stay inside Stripe and are never entered into this app.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
            ])),
            FilledButton.icon(onPressed:()=>_openOwnerPayoutSettings(context),icon:const Icon(Icons.account_balance_outlined),label:const Text('Open secure payout setup')),
          ],
        )))),
        const SizedBox(height:18),const _EmergencyAdminPanel(),
        if(snapshot.hasError)...[const SizedBox(height:16),_DashboardError(message:snapshot.error.toString(),onRetry:refresh)],
      ]);
    },
  );
}

class _EmergencyAdminPanel extends StatefulWidget{
  const _EmergencyAdminPanel();
  @override State<_EmergencyAdminPanel> createState()=>_EmergencyAdminPanelState();
}
class _EmergencyAdminPanelState extends State<_EmergencyAdminPanel>{
  late Future<Map<String,dynamic>> request;final email=TextEditingController();final confirmation=TextEditingController();bool busy=false;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_emergency_admin_state_v82',const {});}
  @override void dispose(){email.dispose();confirmation.dispose();super.dispose();}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_emergency_admin_state_v82',const {}));
  Future<void> invite()async{
    final targetEmail=email.text.trim().toLowerCase();
    if(!targetEmail.contains('@')){
      _showInfoDialog(context,'Email required','Enter the trusted person’s full email address. No invitation has been sent.');
      return;
    }
    if(confirmation.text.trim()!='GRANT BACKUP ADMIN'){
      _showInfoDialog(context,'Confirmation required','Type GRANT BACKUP ADMIN exactly. No invitation has been sent.');
      return;
    }
    setState(()=>busy=true);
    try{
      final result=await Supabase.instance.client.functions.invoke('bridgepoint-emergency-admin-v82',body:{'email':targetEmail,'confirmation':confirmation.text.trim()});
      final payload=_edgeFunctionPayload(result.data);
      if(result.status<200||result.status>=300||payload['complete']!=true||payload['email_sent']!=true){
        throw Exception('${payload['email_message']??payload['error']??'The invitation email was not accepted for delivery.'}');
      }
      email.clear();confirmation.clear();
      if(mounted){
        await _showInfoDialog(context,'Backup invitation sent','The secure email provider accepted the invitation for $targetEmail. Ask her to check Inbox, Promotions, and Spam. This screen will continue to show Invitation pending until she accepts it.');
        refresh();
      }
    }catch(e){if(mounted)_showInfoDialog(context,'Invitation was not sent','${e.toString()}\n\nNothing is being marked as delivered. Fix the email-service message shown above, then try again.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> revoke(Map<String,dynamic> admin)async{
    final controller=TextEditingController();
    final confirmed=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('Revoke backup administrator?'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('This immediately removes platform and company co-owner access. Type REVOKE BACKUP ADMIN to confirm.',style:TextStyle(color:AppTheme.textMuted,height:1.5)),const SizedBox(height:12),TextField(controller:controller,decoration:const InputDecoration(labelText:'Confirmation',border:OutlineInputBorder()))]),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,controller.text=='REVOKE BACKUP ADMIN'),child:const Text('Revoke'))]));
    controller.dispose();if(confirmed!=true)return;
    try{await _callRpc('bridgepoint_revoke_emergency_admin_v82',{'p_auth_user_id':admin['auth_user_id'],'p_confirmation':'REVOKE BACKUP ADMIN'});if(mounted)refresh();}catch(e){if(mounted)_showInfoDialog(context,'Could not revoke access',e.toString());}
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
    final data=snapshot.data??const <String,dynamic>{};final admins=(data['active_backup_admins'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();final pending=data['pending_invitation'];
    return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _PanelHeader(title:'Emergency Co-owner',subtitle:'One separate verified backup account • free All Intelligence • no shared password',action:'Owner only'),const SizedBox(height:12),
      const _ExplainerBanner(icon:Icons.admin_panel_settings_outlined,title:'Backup access is prepared and waiting for an email',message:'When you choose a trusted person, enter their email below. After they verify their own account, they become your company co-owner and a backup platform administrator. The primary owner cannot be removed by the co-owner.'),
      if(snapshot.hasError)...[const SizedBox(height:10),_InlineError(message:snapshot.error.toString())],
      if(admins.isNotEmpty)...[const SizedBox(height:12),...admins.map((admin)=>ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Icon(Icons.security_outlined)),title:Text('${admin['display_name']??admin['email']}'),subtitle:Text('${admin['email']??''} • ${admin['platform_role']??'platform_admin'}'),trailing:OutlinedButton(onPressed:()=>revoke(admin),child:const Text('Revoke'))))]
      else if(pending is Map)...[const SizedBox(height:12),_SettingsStatusRow(label:'Invitation pending',value:'${pending['invited_email']}',color:AppTheme.amber)]
      else ...[const SizedBox(height:14),LayoutBuilder(builder:(context,c)=>Wrap(spacing:10,runSpacing:10,children:[
        SizedBox(width:c.maxWidth>=760?(c.maxWidth-20)*.45:c.maxWidth,child:TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Trusted person’s email',border:OutlineInputBorder()))),
        SizedBox(width:c.maxWidth>=760?(c.maxWidth-20)*.32:c.maxWidth,child:TextField(controller:confirmation,decoration:const InputDecoration(labelText:'Type GRANT BACKUP ADMIN',border:OutlineInputBorder()))),
        FilledButton.icon(onPressed:busy?null:invite,icon:const Icon(Icons.person_add_alt_1_rounded),label:Text(busy?'Preparing…':'Send secure invite')),
      ]))],
      const SizedBox(height:10),const Text('For strongest recovery, require multi-factor authentication on both accounts and never give anyone your password or recovery codes.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
    ])));
  });
}

class _OwnerStatusRow extends StatelessWidget{
  const _OwnerStatusRow(this.label,this.value,this.color);
  final String label,value;final Color color;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:11))),Text(value,style:TextStyle(color:color,fontWeight:FontWeight.w900,fontSize:11))]));
}

class _ExplainerBanner extends StatelessWidget{
  const _ExplainerBanner({required this.icon,required this.title,required this.message});final IconData icon;final String title,message;
  @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(
    gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.10),AppTheme.blue.withOpacity(.05)]),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),
    child:Row(children:[Icon(icon,color:AppTheme.cyan),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45))]))]));
}

class _PermitContextPage extends StatefulWidget {
  const _PermitContextPage();
  @override
  State<_PermitContextPage> createState() => _PermitContextPageState();
}

class _PermitContextPageState extends State<_PermitContextPage> {
  late Future<Map<String, dynamic>> _request;
  final _town = TextEditingController();

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _town.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load([String? municipality]) async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_permit_context_v68'),
      headers: _apiHeaders(),
      body: jsonEncode({'p_municipality': municipality?.trim().isEmpty == true ? null : municipality?.trim()}),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Permit Context API ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Unexpected permit context response.');
    return Map<String, dynamic>.from(decoded);
  }

  void _refresh() => setState(() => _request = _load(_town.text));
  void _clear() {
    _town.clear();
    setState(() => _request = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _request,
    builder: (context, snapshot) {
      final raw = snapshot.data?['rows'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final latestYear = rows.fold<int>(0, (value, row) =>
          ((row['report_year'] as num?)?.toInt() ?? 0) > value
              ? ((row['report_year'] as num?)?.toInt() ?? 0) : value);
      final latest = rows.where((row) => (row['report_year'] as num?)?.toInt() == latestYear).toList();
      final units = latest.fold<int>(0, (sum, row) => sum + ((row['total_units'] as num?)?.toInt() ?? 0));
      final demolitions = latest.fold<int>(0, (sum, row) => sum + ((row['demolitions'] as num?)?.toInt() ?? 0));
      final loading = snapshot.connectionState == ConnectionState.waiting;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PageHeading(
          title: 'Permit Context',
          subtitle: 'Official Connecticut DECD construction activity • municipality-level context',
          onRefresh: _refresh,
          loading: loading,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 3 : 1;
          const gap = 14.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            _MetricCard(width: width,label:'LATEST REPORT',value:latestYear == 0 ? '—' : '$latestYear',detail:'DECD annual construction report',icon:Icons.calendar_month_rounded,accent:AppTheme.cyan),
            _MetricCard(width: width,label:'PERMITTED UNITS',value:_formatInteger(units),detail:'Current filtered latest-year total',icon:Icons.apartment_rounded,accent:AppTheme.green),
            _MetricCard(width: width,label:'DEMOLITIONS',value:_formatInteger(demolitions),detail:'Current filtered latest-year total',icon:Icons.domain_disabled_rounded,accent:AppTheme.amber),
          ]);
        }),
        const SizedBox(height: 18),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          Expanded(child:TextField(controller:_town,onSubmitted:(_)=>_refresh(),decoration:const InputDecoration(prefixIcon:Icon(Icons.location_city_rounded),labelText:'Filter by municipality',hintText:'Example: Hartford',border:OutlineInputBorder()))),
          const SizedBox(width:10),FilledButton.icon(onPressed:loading?null:_refresh,icon:const Icon(Icons.search_rounded),label:const Text('Apply')),
          const SizedBox(width:8),OutlinedButton(onPressed:loading?null:_clear,child:const Text('Clear')),
        ]))),
        const SizedBox(height: 18),
        if (snapshot.hasError) _DashboardError(message:snapshot.error.toString(),onRetry:_refresh)
        else if (loading && rows.isEmpty) const Card(child:SizedBox(height:240,child:Center(child:CircularProgressIndicator(color:AppTheme.cyan))))
        else Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Municipal Construction Activity',subtitle:'Permitted housing units and demolitions • contextual evidence, not individual permit records',action:'Live source'),
          const SizedBox(height:12),
          ...rows.take(100).map((row)=>Container(
            margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),
            decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.06))),
            child:Row(children:[
              Container(width:42,height:42,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.construction_rounded,color:AppTheme.cyan,size:20)),
              const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${row['municipality'] ?? 'Unknown'} • ${row['report_year'] ?? '—'}',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800)),
                const SizedBox(height:4),Text('${row['county'] ?? 'Statewide'} County • ${_formatInteger(row['one_unit'])} single-family • ${_formatInteger(row['five_plus_units'])} 5+ unit',style:const TextStyle(color:AppTheme.textMuted,fontSize:10)),
              ])),
              _PermitValue(label:'UNITS',value:_formatInteger(row['total_units']),color:AppTheme.green),
              const SizedBox(width:18),_PermitValue(label:'DEMOS',value:_formatInteger(row['demolitions']),color:AppTheme.amber),
            ]),
          )),
          if(rows.isEmpty) const SizedBox(height:180,child:Center(child:Text('No municipality matched that filter.',style:TextStyle(color:AppTheme.textMuted)))),
        ]))),
      ]);
    },
  );
}

class _PermitValue extends StatelessWidget {
  const _PermitValue({required this.label,required this.value,required this.color});
  final String label,value; final Color color;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
    Text(value,style:TextStyle(color:color,fontSize:15,fontWeight:FontWeight.w900)),
    Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w800,letterSpacing:.6)),
  ]);
}

class _SourcesPage extends StatelessWidget {
  const _SourcesPage({
    required this.sourcesRequest,
    required this.onRefresh,
  });

  final Future<Map<String, dynamic>> sourcesRequest;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: sourcesRequest,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['sources'];
        final sources = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        final connected = data?['connected_source_count'];
        final registered = data?['registered_source_count'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Intelligence Sources',
              subtitle:
                  'Live registry, source health, ingestion volume, and refresh state',
              onRefresh: onRefresh,
              loading: snapshot.connectionState == ConnectionState.waiting,
            ),
            const SizedBox(height: 22),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: onRefresh,
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : 1;
                  const gap = 14.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      _MetricCard(
                        width: width,
                        label: 'CONNECTED',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '—'
                            : _formatInteger(connected),
                        detail: 'Enabled Connecticut sources',
                        icon: Icons.hub_rounded,
                        accent: AppTheme.green,
                      ),
                      _MetricCard(
                        width: width,
                        label: 'REGISTERED',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '—'
                            : _formatInteger(registered),
                        detail: 'Sources in the live registry',
                        icon: Icons.inventory_2_outlined,
                        accent: AppTheme.cyan,
                      ),
                      _MetricCard(
                        width: width,
                        label: 'RECORDS TRACKED',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '—'
                            : _formatCompact(
                                sources.fold<num>(
                                  0,
                                  (sum, source) =>
                                      sum +
                                      ((source['total_records_ingested']
                                              as num?) ??
                                          0),
                                ),
                              ),
                        detail: 'Registry-reported ingested records',
                        icon: Icons.data_usage_rounded,
                        accent: AppTheme.blue,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Source Registry',
                        subtitle:
                            'Automatically rendered from Supabase — no hard-coded source cards',
                        action: 'Live',
                      ),
                      const SizedBox(height: 18),
                      if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.cyan,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1050
                                ? 2
                                : 1;
                            const gap = 14.0;
                            final width =
                                (constraints.maxWidth -
                                        gap * (columns - 1)) /
                                    columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: sources
                                  .map(
                                    (source) => _DetailedSourceCard(
                                      width: width,
                                      source: source,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LiveSourceCard extends StatelessWidget {
  const _LiveSourceCard({required this.width, required this.source});

  final double width;
  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final category = (source['source_category'] ?? 'INTELLIGENCE').toString();
    final color = _sourceColor(category);
    final icon = _sourceIcon(source);
    final healthy = (source['health_status'] ?? '').toString() == 'HEALTHY';

    return InkWell(
      onTap: () => _showSourceDetail(context, source),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (source['source_name'] ?? 'Unnamed source').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _sourceSubtitle(source),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PulseDot(color: healthy ? AppTheme.green : AppTheme.amber),
        ],
        ),
      ),
    );
  }
}

class _DetailedSourceCard extends StatelessWidget {
  const _DetailedSourceCard({
    required this.width,
    required this.source,
  });

  final double width;
  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final category = (source['source_category'] ?? 'INTELLIGENCE').toString();
    final color = _sourceColor(category);
    final health = (source['health_status'] ?? 'NOT_RUN').toString();
    final provider = (source['provider'] ?? 'Provider unavailable').toString();
    final records = _formatInteger(source['total_records_ingested']);
    final refresh =
        (source['refresh_frequency'] ?? 'Not scheduled').toString();
    final confidence = source['default_confidence'] is num
        ? '${((source['default_confidence'] as num) * 100).toStringAsFixed(0)}%'
        : '—';

    return InkWell(
      onTap: () => _showSourceDetail(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.52),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_sourceIcon(source), color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (source['source_name'] ?? 'Unnamed source').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _HealthBadge(status: health),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _sourceSubtitle(source),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(label: 'RECORDS', value: records),
              _MiniStat(label: 'REFRESH', value: refresh),
              _MiniStat(label: 'CONFIDENCE', value: confidence),
              _MiniStat(label: 'ACCESS', value: '${source['access_method'] ?? '—'}'),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

void _showSourceDetail(
  BuildContext context,
  Map<String, dynamic> source,
) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: AppTheme.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${source['source_name'] ?? 'Intelligence Source'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _sourceSubtitle(source),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              if('${source['source_code']}'=='CT_DCP_HIC_REGISTRY')...[
                SizedBox(width:double.infinity,child:FilledButton.icon(
                  onPressed:()=>_showContractorRegistryDialog(context),
                  icon:const Icon(Icons.verified_user_outlined),
                  label:const Text('Check a Connecticut contractor'),
                )),
                const SizedBox(height:12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: _JsonIntelligenceList(
                    records: [source],
                    emptyMessage: 'No source details available.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showContractorRegistryDialog(BuildContext context)=>showDialog<void>(
  context:context,builder:(context)=>const _ContractorRegistryDialog(),
);

class _ContractorRegistryDialog extends StatefulWidget{
  const _ContractorRegistryDialog();
  @override State<_ContractorRegistryDialog> createState()=>_ContractorRegistryDialogState();
}

class _ContractorRegistryDialogState extends State<_ContractorRegistryDialog>{
  final query=TextEditingController();
  final city=TextEditingController();
  Future<Map<String,dynamic>>? request;
  @override void dispose(){query.dispose();city.dispose();super.dispose();}
  void search(){
    final q=query.text.trim();final c=city.text.trim();
    if(q.isEmpty&&c.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a contractor name, registration number, or city.')));
      return;
    }
    setState(()=>request=_callRpc('bridgepoint_search_ct_contractors_v85',{
      'p_query':q.isEmpty?null:q,'p_city':c.isEmpty?null:c,'p_limit':50,
    }));
  }
  @override Widget build(BuildContext context)=>Dialog(
    backgroundColor:AppTheme.panel,
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:860,maxHeight:780),child:Padding(
      padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.verified_user_outlined,color:AppTheme.cyan),const SizedBox(width:9),const Expanded(child:Text('Connecticut Contractor Check',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
        const SizedBox(height:5),const Text('Search the official Connecticut DCP Home Improvement Contractor registry before hiring, dispatching, or referring work.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
        const SizedBox(height:14),Wrap(spacing:10,runSpacing:10,children:[
          SizedBox(width:380,child:TextField(controller:query,onSubmitted:(_)=>search(),decoration:const InputDecoration(labelText:'Name or registration number',prefixIcon:Icon(Icons.search_rounded),border:OutlineInputBorder()))),
          SizedBox(width:260,child:TextField(controller:city,onSubmitted:(_)=>search(),decoration:const InputDecoration(labelText:'Exact city (optional)',prefixIcon:Icon(Icons.location_city_outlined),border:OutlineInputBorder()))),
          SizedBox(height:56,child:FilledButton.icon(onPressed:search,icon:const Icon(Icons.fact_check_outlined),label:const Text('Check'))),
        ]),
        const SizedBox(height:12),const _ExplainerBanner(icon:Icons.info_outline_rounded,title:'What this proves',message:'This confirms the registration record and its reported status. It does not prove technical skill, insurance, workmanship, complaint history, or suitability. Verify the official record and current insurance before work.'),
        const SizedBox(height:12),Expanded(child:request==null
          ?const Center(child:Text('Enter a name, registration number, or city to begin.',style:TextStyle(color:AppTheme.textMuted)))
          :FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
            if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
            if(snapshot.hasError)return _DashboardError(message:snapshot.error.toString(),onRetry:search);
            final items=(snapshot.data?['results'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
            if(items.isEmpty)return const Center(child:Text('No matching registration record was found. Try the official registration number or a shorter name.',style:TextStyle(color:AppTheme.textMuted)));
            return ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,index){
              final item=items[index];final active=item['active']==true;return ListTile(
                leading:CircleAvatar(backgroundColor:(active?AppTheme.green:AppTheme.amber).withOpacity(.12),child:Icon(active?Icons.verified_rounded:Icons.warning_amber_rounded,color:active?AppTheme.green:AppTheme.amber)),
                title:Text('${item['display_name']??'Unnamed registrant'}',style:const TextStyle(fontWeight:FontWeight.w800)),
                subtitle:Text('${item['full_credential_code']??'No code'} • ${item['credential']??'Home Improvement Contractor'}\n${item['city']??'City not listed'}, ${item['state_code']??'CT'} • Expires ${item['expiration_date']??'not listed'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
                trailing:_OpportunityChip(label:active?'ACTIVE':'${item['status']??'CHECK'}',color:active?AppTheme.green:AppTheme.amber),
              );
            });
          })),
      ]),
    )),
  );
}

Future<void> _showInfoDialog(
  BuildContext context,
  String title,
  String message,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final healthy = status == 'HEALTHY';
    final color = healthy ? AppTheme.green : AppTheme.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:()=>_showInfoDialog(context,label,'Current value: $value\n\nThis value describes the selected record. It is shown with its surrounding evidence so you can understand why BridgePoint surfaced it.'),
      borderRadius:BorderRadius.circular(9),
      child:Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Tooltip(message:'Explain this page',child:IconButton(
          onPressed:()=>_showInfoDialog(context,title,'$subtitle\n\nTap any summary card, list row, map marker, legend item, status, or timeline event for a plain-language explanation and the next available action.'),
          icon:const Icon(Icons.help_outline_rounded,color:AppTheme.cyan),
        )),
        const SizedBox(width:4),
        _IconButton(
          icon: Icons.refresh_rounded,
          onTap: loading ? () {} : onRefresh,
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.red.withOpacity(0.18)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
    );
  }
}

class _TeamSettingsPanel extends StatefulWidget {
  const _TeamSettingsPanel();
  @override State<_TeamSettingsPanel> createState()=>_TeamSettingsPanelState();
}

class _TeamSettingsPanelState extends State<_TeamSettingsPanel>{
  late Future<Map<String,dynamic>> request;
  final companyName=TextEditingController();
  final inviteEmail=TextEditingController();
  String inviteRole='MEMBER';
  bool busy=false;
  bool fieldNotes=true;

  @override void initState(){super.initState();request=_load();}
  @override void dispose(){companyName.dispose();inviteEmail.dispose();super.dispose();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_team_workspace_v80',const {});
  void refresh()=>setState(()=>request=_load());

  Future<void> _createCompany()async{
    final name=companyName.text.trim();
    if(name.length<2){_showInfoDialog(context,'Company name required','Enter the name teammates should see in their shared workspace.');return;}
    setState(()=>busy=true);
    try{await _callRpc('bridgepoint_create_company_workspace_v80',{'p_organization_name':name});if(mounted){Navigator.pop(context);refresh();}}
    catch(e){if(mounted)_showInfoDialog(context,'Could not create company workspace',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  void _showCreateCompany(){showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
    backgroundColor:AppTheme.panel,title:const Text('Create Company workspace'),
    content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Includes five seats, All Intelligence, shared opportunities and notes, Live Field Assist, and owner/co-owner backup controls.',style:TextStyle(color:AppTheme.textMuted,height:1.5)),
      const SizedBox(height:14),TextField(controller:companyName,decoration:const InputDecoration(labelText:'Company name',border:OutlineInputBorder())),
      const SizedBox(height:10),const Text('Your seven-day trial starts when this workspace is created.',style:TextStyle(color:AppTheme.green,fontSize:10)),
    ])),
    actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:busy?null:_createCompany,child:Text(busy?'Creating…':'Create workspace'))],
  ));}

  Future<void> _invite()async{
    final email=inviteEmail.text.trim();
    if(!email.contains('@')){_showInfoDialog(context,'Email required','Enter the teammate’s email address.');return;}
    setState(()=>busy=true);
    try{
      final result=await Supabase.instance.client.functions.invoke('bridgepoint-team-invite-v80',body:{'email':email,'member_role':inviteRole});
      final payload=_edgeFunctionPayload(result.data);
      if(result.status<200||result.status>=300||payload['complete']!=true)throw Exception('${payload['email_message']??payload['error']??'The invitation could not be completed.'}');
      final memberAdded=payload['delivery_status']=='NOT_REQUIRED';
      final emailSent=payload['email_sent']==true;
      if(!memberAdded&&!emailSent)throw Exception('${payload['email_message']??'The invitation email was not accepted for delivery.'}');
      inviteEmail.clear();
      if(mounted){
        await _showInfoDialog(context,memberAdded?'Access granted':'Team invitation sent',memberAdded?'$email already had a verified BridgePoint account, so access was granted immediately.':'The secure email provider accepted the invitation for $email. Ask the teammate to check Inbox, Promotions, and Spam.');
        refresh();
      }
    }catch(e){if(mounted)_showInfoDialog(context,'Invitation was not sent','${e.toString()}\n\nBridgePoint did not mark this as delivered.');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _updateMember(Map<String,dynamic> member,String role,bool active)async{
    setState(()=>busy=true);
    try{await _callRpc('bridgepoint_update_team_member_v80',{'p_user_id':member['user_id'],'p_member_role':role,'p_active':active});if(mounted)refresh();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not update teammate',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _setFieldNotes(bool value)async{
    setState(()=>fieldNotes=value);
    try{await _callRpc('bridgepoint_set_field_note_enabled_v81',{'p_enabled':value});}
    catch(e){if(mounted){setState(()=>fieldNotes=!value);_showInfoDialog(context,'Could not update Field Notes',e.toString());}}
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final hasWorkspace=data['has_company_workspace']==true;
      final role='${data['current_role']??'MEMBER'}';
      final canManage=data['can_manage']==true;
      final canAdmin=data['can_administer']==true;
      final members=(data['members'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      final invitations=(data['pending_invitations'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      if(snapshot.hasError)return _SettingsSection(icon:Icons.groups_2_outlined,title:'Company & team',subtitle:'Shared workspaces and seat management.',children:[_InlineError(message:snapshot.error.toString()),const SizedBox(height:8),OutlinedButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Try again'))]);
      if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)return const _SettingsSection(icon:Icons.groups_2_outlined,title:'Company & team',subtitle:'Loading your workspace…',children:[LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)]);
      if(!hasWorkspace)return _SettingsSection(icon:Icons.groups_2_outlined,title:'Company & team',subtitle:'Five seats, shared field work, and backup leadership on the Company plan.',children:[
        const Text('Create a company workspace to invite teammates, appoint a co-owner, share opportunities and notes, and use consent-based Live Field Assist.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5)),
        const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_showCreateCompany,icon:const Icon(Icons.add_business_rounded),label:const Text('Start Company trial'))),
        const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>_openBillingPortal(context),icon:const Icon(Icons.workspace_premium_outlined),label:const Text('View Company plan'))),
      ]);
      final used=(data['active_members'] as num?)?.toInt()??members.length;
      final limit=(data['seat_limit'] as num?)?.toInt()??5;
      return _SettingsSection(icon:Icons.groups_2_outlined,title:'${data['organization_name']??'Company'} team',subtitle:'Your role: ${role.replaceAll('_',' ')} • shared Company workspace',children:[
        Row(children:[Expanded(child:LinearProgressIndicator(value:limit==0?0:(used/limit).clamp(0,1),color:used>=limit?AppTheme.amber:AppTheme.green,backgroundColor:AppTheme.panelSoft,minHeight:8)),const SizedBox(width:10),Text('$used of $limit seats',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,fontWeight:FontWeight.w800))]),
        const SizedBox(height:12),...members.map((member){
          final name='${member['display_name']??member['email']??'Teammate'}'.trim();
          final initial=name.isEmpty?'?':name.substring(0,1).toUpperCase();
          final memberRole='${member['member_role']??'MEMBER'}';
          final isPrimary=memberRole=='OWNER';
          return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white.withOpacity(.06))),child:Row(children:[
            CircleAvatar(radius:17,backgroundColor:AppTheme.cyan.withOpacity(.12),child:Text(initial,style:const TextStyle(color:AppTheme.cyan,fontWeight:FontWeight.w900))),
            const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),Text('${member['email']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))])),
            if(!canManage||isPrimary)_OpportunityChip(label:memberRole.replaceAll('_',' '),color:isPrimary?AppTheme.amber:AppTheme.cyan)
            else PopupMenuButton<String>(tooltip:'Change team role',onSelected:(value){if(value=='REMOVE'){_updateMember(member,memberRole,false);}else{_updateMember(member,value,true);}},itemBuilder:(context)=>[
              if(role=='OWNER')const PopupMenuItem(value:'CO_OWNER',child:Text('Make co-owner')),
              const PopupMenuItem(value:'MANAGER',child:Text('Manager')),const PopupMenuItem(value:'MEMBER',child:Text('Member')),const PopupMenuItem(value:'VIEWER',child:Text('Viewer')),
              const PopupMenuDivider(),const PopupMenuItem(value:'REMOVE',child:Text('Remove access')),
            ],child:_OpportunityChip(label:memberRole.replaceAll('_',' '),color:memberRole=='CO_OWNER'?AppTheme.amber:AppTheme.cyan)),
          ]));
        }),
        if(canManage)...[
          const Divider(height:24),TextField(controller:inviteEmail,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Invite teammate by email',border:OutlineInputBorder(),prefixIcon:Icon(Icons.alternate_email_rounded))),
          const SizedBox(height:8),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:inviteRole,decoration:const InputDecoration(labelText:'Role',border:OutlineInputBorder()),dropdownColor:AppTheme.panelSoft,items:[
            if(role=='OWNER')const DropdownMenuItem(value:'CO_OWNER',child:Text('Co-owner (backup admin)')),
            const DropdownMenuItem(value:'MANAGER',child:Text('Manager')),const DropdownMenuItem(value:'MEMBER',child:Text('Sales / field member')),const DropdownMenuItem(value:'VIEWER',child:Text('Viewer')),
          ],onChanged:busy?null:(v)=>setState(()=>inviteRole=v??'MEMBER'))),const SizedBox(width:8),FilledButton.icon(onPressed:busy||used+invitations.length>=limit?null:_invite,icon:const Icon(Icons.person_add_alt_1_rounded),label:Text(busy?'Sending…':'Invite'))]),
          if(invitations.isNotEmpty)...[const SizedBox(height:10),Text('${invitations.length} invitation${invitations.length==1?'':'s'} pending',style:const TextStyle(color:AppTheme.amber,fontSize:10,fontWeight:FontWeight.w800))],
        ],
        if(canAdmin)...[
          const Divider(height:24),SwitchListTile(contentPadding:EdgeInsets.zero,value:fieldNotes,title:const Text('Field Note of the Day',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),subtitle:const Text('Show original safety, ethics, service, and encouragement notes on the Daily Brief.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)),onChanged:_setFieldNotes),
        ],
        const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>_openBillingPortal(context),icon:const Icon(Icons.swap_horiz_rounded),label:const Text('Change Company plan / billing'))),
      ]);
    },
  );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.ownerMode,
    required this.settingsRequest,
    required this.healthRequest,
    required this.refreshSeconds,
    required this.onRefreshSecondsChanged,
    required this.onRefresh,
  });

  final bool ownerMode;

  final Future<Map<String, dynamic>> settingsRequest;
  final Future<Map<String, dynamic>> healthRequest;
  final int refreshSeconds;
  final ValueChanged<int> onRefreshSecondsChanged;
  final VoidCallback onRefresh;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late int _refreshSeconds;
  bool _showConfidence = true;
  bool _showPatterns = true;
  bool _showRawSignals = true;
  bool _mapAutoRotate = true;
  String _mapStyle = 'standard';
  String _feedbackCategory = 'SUGGESTION';
  final _feedback = TextEditingController();
  bool _sendingFeedback = false;
  late _DisplayPreferences _accessibility;
  bool _savingAccessibility=false;

  @override
  void initState() {
    super.initState();
    _refreshSeconds = widget.refreshSeconds;
    _accessibility=_displayPreferences.value;
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeconds != widget.refreshSeconds) {
      _refreshSeconds = widget.refreshSeconds;
    }
  }

  @override void dispose(){_feedback.dispose();super.dispose();}
  Future<void> _sendFeedback() async{
    if(_feedback.text.trim().length<3)return;
    setState(()=>_sendingFeedback=true);
    try{await _callRpc('bridgepoint_submit_feedback_v70',{'p_category':_feedbackCategory,'p_page_key':'settings','p_message':_feedback.text.trim()});
      _feedback.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Thank you—your suggestion was received.')));
    }catch(e){if(mounted)_showInfoDialog(context,'Could not send suggestion',e.toString());}
    finally{if(mounted)setState(()=>_sendingFeedback=false);}
  }

  Future<void> _saveAccessibility(_DisplayPreferences next)async{
    setState((){_accessibility=next;_savingAccessibility=true;});
    _displayPreferences.value=next;
    try{
      final saved=await _callRpc('bridgepoint_update_display_preferences_v80',{
        'p_large_text':next.largeText,'p_high_contrast':next.highContrast,
        'p_reduced_motion':next.reducedMotion,'p_simplified_views':next.simplifiedViews,
      });
      _applyDisplayPreferences(saved);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not save display settings',e.toString());}
    finally{if(mounted)setState(()=>_savingAccessibility=false);}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          title: 'Settings',
          subtitle: 'Live workspace controls • security • automation • account readiness',
          onRefresh: widget.onRefresh,
          loading: false,
        ),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>>(
          future: widget.healthRequest,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const <String, dynamic>{};
            final cron = data['cron'] is Map
                ? Map<String, dynamic>.from(data['cron'] as Map)
                : const <String, dynamic>{};
            final engines = data['engine_estimates'] is Map
                ? Map<String, dynamic>.from(data['engine_estimates'] as Map)
                : const <String, dynamic>{};
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 4 : 2;
                const gap = 14.0;
                final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'SYSTEM',
                      value: '${data['status'] ?? (snapshot.hasError ? 'ATTENTION' : 'LOADING')}',
                      detail: '${cron['recent_failures_15m'] ?? 0} failures in 15 minutes',
                      icon: Icons.health_and_safety_rounded,
                      accent: data['status'] == 'HEALTHY' ? AppTheme.green : AppTheme.amber,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE WORKERS',
                      value: '${cron['active_jobs'] ?? '—'}',
                      detail: '${cron['recent_successes_15m'] ?? '—'} successful runs in 15m',
                      icon: Icons.precision_manufacturing_rounded,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'OPPORTUNITIES',
                      value: _compactNumber(engines['opportunities_v38']),
                      detail: 'Modern V38 live estimate',
                      icon: Icons.bolt_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PROPERTY SCORES',
                      value: _compactNumber(engines['property_scores_v37']),
                      detail: 'Modern V37 live estimate',
                      icon: Icons.analytics_rounded,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final width = wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _SettingsSection(
                    icon: Icons.sync_rounded,
                    title: 'Live refresh',
                    subtitle: 'Control how often the workspace pulls new intelligence.',
                    children: [
                      DropdownButtonFormField<int>(
                        value: _refreshSeconds,
                        dropdownColor: AppTheme.panelSoft,
                        decoration: const InputDecoration(
                          labelText: 'Automatic refresh interval',
                          border: OutlineInputBorder(),
                        ),
                        items: const [30, 60, 120, 300, 600]
                            .map((seconds) => DropdownMenuItem(
                                  value: seconds,
                                  child: Text(seconds < 60
                                      ? '$seconds seconds'
                                      : '${seconds ~/ 60} minute${seconds == 60 ? '' : 's'}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _refreshSeconds = value);
                          widget.onRefreshSecondsChanged(value);
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Applied immediately to this live workspace.',
                        style: TextStyle(color: AppTheme.green, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width:width,
                  child:_SettingsSection(
                    icon:Icons.accessibility_new_rounded,
                    title:'Display & accessibility',
                    subtitle:'Make BridgePoint easier to see, calmer to use, or less detailed. These choices follow your account on every device.',
                    children:[
                      _SettingsSwitch('Larger text',_accessibility.largeText,(v)=>_saveAccessibility(_accessibility.copyWith(largeText:v))),
                      _SettingsSwitch('Stronger contrast',_accessibility.highContrast,(v)=>_saveAccessibility(_accessibility.copyWith(highContrast:v))),
                      _SettingsSwitch('Reduce motion and scanning effects',_accessibility.reducedMotion,(v)=>_saveAccessibility(_accessibility.copyWith(reducedMotion:v))),
                      _SettingsSwitch('Simplified views (hide optional map layers)',_accessibility.simplifiedViews,(v)=>_saveAccessibility(_accessibility.copyWith(simplifiedViews:v))),
                      if(_savingAccessibility)const Padding(padding:EdgeInsets.only(top:6),child:LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)),
                      const SizedBox(height:8),
                      const Text('Map layers can also be shown or hidden at any time from the Intelligence Map. Buttons remain large and keyboard accessible.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SettingsSection(
                    icon: Icons.map_rounded,
                    title: 'Intelligence map',
                    subtitle: 'Opportunity markers now use category-specific icons.',
                    children: [
                      DropdownButtonFormField<String>(
                        value: _mapStyle,
                        dropdownColor: AppTheme.panelSoft,
                        decoration: const InputDecoration(
                          labelText: 'Map style',
                          border: OutlineInputBorder(),
                        ),
                        items: const ['standard', 'street', 'satellite']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value[0].toUpperCase() + value.substring(1)),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _mapStyle = value ?? 'standard'),
                      ),
                      SwitchListTile(
                        value: _mapAutoRotate,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Automatically rotate live results'),
                        onChanged: (value) => setState(() => _mapAutoRotate = value),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SettingsSection(
                    icon: Icons.visibility_rounded,
                    title: 'Evidence display',
                    subtitle: 'Choose which intelligence details appear in property views.',
                    children: [
                      _SettingsSwitch('Confidence scores', _showConfidence,
                          (v) => setState(() => _showConfidence = v)),
                      _SettingsSwitch('Detected patterns', _showPatterns,
                          (v) => setState(() => _showPatterns = v)),
                      _SettingsSwitch('Raw supporting signals', _showRawSignals,
                          (v) => setState(() => _showRawSignals = v)),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: widget.settingsRequest,
                    builder: (context, snapshot) {
                      final authenticated = snapshot.data?['authentication_configured'] == true;
                      return _SettingsSection(
                        icon: Icons.workspace_premium_rounded,
                        title: 'Account & trial',
                        subtitle: 'New accounts start in a scoped BridgePoint trial workspace.',
                        children: [
                          const _SettingsStatusRow(
                            label: 'Free trial',
                            value: '7 days',
                            color: AppTheme.green,
                          ),
                          const _SettingsStatusRow(
                            label: 'Payment method',
                            value: 'Not required for trial',
                            color: AppTheme.cyan,
                          ),
                          _SettingsStatusRow(
                            label: 'Authentication',
                            value: authenticated ? 'Configured' : 'Ready for first account',
                            color: authenticated ? AppTheme.green : AppTheme.amber,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your account, trial and billing settings synchronize securely across devices.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.45),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(width:double.infinity,child:OutlinedButton.icon(
                            onPressed:()=>_openBillingPortal(context),
                            icon:const Icon(Icons.swap_horiz_rounded),label:const Text('Change plan / manage billing'),
                          )),
                          SizedBox(width:double.infinity,child:TextButton.icon(
                            onPressed:()=>Supabase.instance.client.auth.signOut(),
                            icon:const Icon(Icons.logout_rounded),label:const Text('Sign out'),
                          )),
                        ],
                      );
                    },
                  ),
                ),
                if(widget.ownerMode)SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.preview_rounded,title:'Customer experience preview',
                  subtitle:'Your owner account stays free and unlocked. Replay customer-facing moments without changing your access.',
                  children:[
                    SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _WalkthroughDialog()),
                      icon:const Icon(Icons.route_rounded),label:const Text('Replay guided walkthrough'))),
                    const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(
                      onPressed:()=>showDialog<void>(context:context,builder:(context)=>AlertDialog(
                        backgroundColor:AppTheme.panel,title:const Text('Customer welcome preview'),
                        content:const Text('New customers choose a profile name, answer five dropdown questions, receive a package recommendation, then land on a personalized Daily Brief. Your owner account bypasses those gates while this preview remains available.'),
                        actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Got it'))])),
                      icon:const Icon(Icons.waving_hand_outlined),label:const Text('Preview signup & welcome'))),
                    const SizedBox(height:8),const Text('To see the live personalized welcome, choose Daily Brief in the left menu. To see alerts, tap the bell.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
                  ],
                )),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.ios_share_rounded,title:'Share BridgePoint',
                  subtitle:'Send the permanent app link by email, text, device share menu, or social network.',
                  children:[
                    const SelectableText(_bridgePointLiveUrl,style:TextStyle(color:AppTheme.cyan,fontSize:11,fontWeight:FontWeight.w800)),
                    const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:()=>_showShareBridgePointDialog(context),icon:const Icon(Icons.send_rounded),label:const Text('Choose how to share'))),
                    const SizedBox(height:8),const Text('You always review and choose the recipient before an email or text is sent.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
                  ],
                )),
                SizedBox(width:width,child:const _TeamSettingsPanel()),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.help_center_outlined,title:'Help & FAQ',
                  subtitle:'Search plain-language answers without leaving your workspace.',
                  children:[
                    SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:()=>_showFaqDialog(context),icon:const Icon(Icons.question_answer_outlined),label:const Text('Open Help & FAQ'))),
                    const SizedBox(height:8),const Text('If the answer is not there, use Suggestions & feedback below and choose Question.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
                  ],
                )),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.policy_outlined,title:'Legal & Trust Center',
                  subtitle:'Versioned terms, privacy choices, data limits, field conduct, and acceptance history.',
                  children:[
                    SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _LegalCenterDialog()),icon:const Icon(Icons.verified_user_outlined),label:const Text('Open Legal & Trust Center'))),
                    const SizedBox(height:8),const Text('File a privacy access, correction, deletion, portability, or appeal request from the Legal & Trust Center. Identity verification is required.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
                  ],
                )),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.forum_rounded,title:'Suggestions & feedback',
                  subtitle:'Tell us what would make BridgePoint more useful. Every submission is saved for review.',
                  children:[
                    DropdownButtonFormField<String>(value:_feedbackCategory,dropdownColor:AppTheme.panelSoft,
                      decoration:const InputDecoration(labelText:'Type',border:OutlineInputBorder()),
                      items:const {'SUGGESTION':'Suggestion','BUG':'Something is not working','DATA_REQUEST':'Request a data source','QUESTION':'Question','COMPLIMENT':'What you like'}
                        .entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
                      onChanged:_sendingFeedback?null:(v)=>setState(()=>_feedbackCategory=v??_feedbackCategory)),
                    const SizedBox(height:10),TextField(controller:_feedback,maxLines:4,
                      decoration:const InputDecoration(labelText:'What should we know?',hintText:'Describe the idea, problem, or data you want added.',border:OutlineInputBorder())),
                    const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:_sendingFeedback?null:_sendFeedback,icon:const Icon(Icons.send_rounded),label:Text(_sendingFeedback?'Sending…':'Send to BridgePoint'))),
                  ],
                )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: AppTheme.cyan, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        onChanged: onChanged,
      );
}

class _SettingsStatusRow extends StatelessWidget {
  const _SettingsStatusRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

String _compactNumber(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return '—';
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(2)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return number.toStringAsFixed(0);
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        height: 420,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.cyan, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This BridgePoint workspace is next in the live-data build.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _sourceIcon(Map<String, dynamic> source) {
  final explicit = (source['flutter_icon'] ?? '').toString().toLowerCase();
  final category = (source['source_category'] ?? '').toString().toUpperCase();
  final value='${source['source_code']??''} ${source['source_name']??''} ${source['provider']??''} $category $explicit'.toLowerCase();

  if(value.contains('verified_user')||value.contains('contractor trust')||value.contains('hic registry'))return Icons.verified_user_outlined;
  if(value.contains('fema')||value.contains('flood'))return Icons.flood_outlined;
  if(value.contains('nfirs')||value.contains('fire'))return Icons.local_fire_department_outlined;
  if(value.contains('noaa')||value.contains('storm')||value.contains('weather'))return Icons.thunderstorm_outlined;
  if(value.contains('ust')||value.contains('tank'))return Icons.oil_barrel_outlined;
  if(value.contains('spill')||value.contains('release'))return Icons.water_drop_outlined;
  if(value.contains('react')||value.contains('remediation')||value.contains('brownfield'))return Icons.science_outlined;
  if(value.contains('solar'))return Icons.solar_power_outlined;
  if(value.contains('usgs')||value.contains('hydrolog')||value.contains('elevation'))return Icons.terrain_outlined;
  if(value.contains('business')||value.contains('registry'))return Icons.business_center_outlined;
  if(value.contains('transition')||value.contains('sale')||value.contains('ownership'))return Icons.swap_horiz_rounded;
  if(value.contains('footprint')||value.contains('building')||value.contains('lidar')||value.contains('3d'))return Icons.architecture_outlined;
  if(value.contains('permit')||value.contains('construction'))return Icons.construction_outlined;
  if(value.contains('grid')||value.contains('outage')||value.contains('electric'))return Icons.electric_bolt_outlined;
  if(value.contains('census')||value.contains('demograph'))return Icons.groups_outlined;
  if(value.contains('311')||value.contains('service request'))return Icons.campaign_outlined;
  if(value.contains('cama')||value.contains('parcel')||value.contains('property'))return Icons.home_work_outlined;
  return Icons.dataset_outlined;
}

Color _sourceColor(String category) {
  final value = category.toUpperCase();
  if (value.contains('FIRE')) return AppTheme.red;
  if (value.contains('GRID')) return AppTheme.amber;
  if (value.contains('FLOOD') || value.contains('DISASTER')) {
    return AppTheme.cyan;
  }
  if (value.contains('TRANSITION')) return AppTheme.green;
  if (value.contains('WEATHER') || value.contains('STORM')) {
    return AppTheme.blue;
  }
  return AppTheme.cyan;
}

String _sourceSubtitle(Map<String, dynamic> source) {
  final description = source['description']?.toString();
  if (description != null && description.trim().isNotEmpty) {
    return description;
  }

  switch ((source['source_category'] ?? '').toString().toUpperCase()) {
    case 'WEATHER':
      return 'Weather exposure, storm events, and proximity intelligence';
    case 'FIRE':
      return 'Fire incidents and property-relevant fire intelligence';
    case 'DISASTER_FLOOD':
      return 'Disaster, flood, and FEMA property intelligence';
    case 'GRID_INFRASTRUCTURE':
      return 'Grid outage, reliability, and infrastructure intelligence';
    case 'PROPERTY_TRANSITION':
      return 'Recorded property sales and ownership-transition intelligence';
    default:
      return (source['source_category'] ?? 'Connected intelligence source')
          .toString()
          .replaceAll('_', ' ');
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        );
        final actionButton = TextButton(
          onPressed: () => _showInfoDialog(
            context,
            title,
            '$subtitle\n\nOpen the rows or cards below for property-level detail, supporting evidence, timing, confidence, sources, and suggested next steps.',
          ),
          child: Text(action),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: actionButton),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 10),
            actionButton,
          ],
        );
      },
    );
  }
}

class _ModelProgress extends StatelessWidget {
  const _ModelProgress({
    required this.label,
    required this.status,
    required this.color,
    this.value,
  });

  final String label;
  final String status;
  final Color color;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              status,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.06),
            value: value,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Icon(icon, color: AppTheme.textMuted, size: 20),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.45), blurRadius: 8),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 24.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

String _formatInteger(dynamic value) {
  final number = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  final digits = number.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }

  return number < 0 ? '-$buffer' : buffer.toString();
}

String _formatCompact(dynamic value) {
  final number = value is num ? value.toDouble() : 0.0;
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(2)}M';
  }
  if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toStringAsFixed(0);
}

String _formatDecimal(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number?.toStringAsFixed(2) ?? '—';
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Color _opportunityPriorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppTheme.red;
    case 'high':
      return AppTheme.amber;
    case 'medium':
      return AppTheme.cyan;
    default:
      return AppTheme.green;
  }
}
