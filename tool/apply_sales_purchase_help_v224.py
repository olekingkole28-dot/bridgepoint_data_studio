from pathlib import Path
import sys

path=Path(sys.argv[1] if len(sys.argv)>1 else 'lib/main.dart')
s=path.read_text(encoding='utf-8')
marker='bridgepoint-v224-sales-purchase-help'
if marker in s:
    print('v224 already applied')
    raise SystemExit(0)

def once(old,new,label):
    global s
    c=s.count(old)
    if c!=1:
        raise SystemExit(f'{label}: expected 1 match, found {c}')
    s=s.replace(old,new,1)

once("case 'Packages': return const _PackagesPage();","case 'Packages': return _PackagesPage(ownerMode:_effectiveOwnerMode);",'packages route')

once("""class _PackagesPage extends StatefulWidget {
  const _PackagesPage();

  @override
  State<_PackagesPage> createState() => _PackagesPageState();
}
""","""class _PackagesPage extends StatefulWidget {
  const _PackagesPage({required this.ownerMode});
  final bool ownerMode;

  @override
  State<_PackagesPage> createState() => _PackagesPageState();
}
""",'packages widget')

once("""    const SizedBox(height:10),const _BillingReadinessBannerV220(),
    const SizedBox(height:10),const _ExplainerBanner(icon:Icons.auto_awesome_rounded,title:'A few plans are featured on purpose',message:'BridgePoint highlights the clearest starting points first. Use the dropdown or Show more to compare specialty, enterprise and technology products without scrolling through a wall of plans.'),
""","""    const SizedBox(height:10),const _BillingReadinessBannerV220(),
    if(widget.ownerMode)...[
      const SizedBox(height:10),
      Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.07),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.amber.withOpacity(.20))),child:Row(children:[
        const Icon(Icons.point_of_sale_rounded,color:AppTheme.amber),const SizedBox(width:10),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('SALES DEMO VIEW',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.8)),SizedBox(height:3),Text('Preview the full customer purchase path - package, Stripe checkout, activation, confirmation, and billing settings - without charging anything.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45))])),
        FilledButton.tonalIcon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _SalesDemoDialogV224()),icon:const Icon(Icons.play_circle_outline_rounded),label:const Text('Demo checkout')),
      ])),
    ],
    const SizedBox(height:10),const _ExplainerBanner(icon:Icons.auto_awesome_rounded,title:'A few plans are featured on purpose',message:'BridgePoint highlights the clearest starting points first. Use the dropdown or Show more to compare specialty, enterprise and technology products without scrolling through a wall of plans.'),
""",'packages demo banner')

s=s.replace("_LivePackageCard(package:p)","_LivePackageCard(package:p,ownerMode:widget.ownerMode)")
if s.count("_LivePackageCard(package:p,ownerMode:widget.ownerMode)")<3:
    raise SystemExit('package card wiring incomplete')

once("""class _LivePackageCard extends StatelessWidget {
  const _LivePackageCard({required this.package});

  final Map<String, dynamic> package;
""","""class _LivePackageCard extends StatelessWidget {
  const _LivePackageCard({required this.package,required this.ownerMode});

  final Map<String, dynamic> package;
  final bool ownerMode;
""",'package card constructor')
once("onTap: () => _showPackageDetail(context, package),","onTap: () => _showPackageDetail(context, package,ownerMode:ownerMode),",'package detail owner wiring')

once("""    final deliveryStatus='${configuration['delivery_status']??(technology?'MANAGED_PILOT':'READY')}'.toUpperCase();
    final checkoutReady=technology?false:configuration['checkout_ready']==true;
    final deliveryNote='${configuration['delivery_note']??configuration['delivery_summary']??''}'.trim();
""","""    final purchaseMode='${configuration['purchase_mode']??'IMMEDIATE'}'.toUpperCase();
    final deliveryStatus='${configuration['delivery_status']??(purchaseMode=='FOUNDING_EARLY_ACCESS'?'EARLY ACCESS':purchaseMode=='MANAGED_ACTIVATION'?'MANAGED ACTIVATION':'READY')}'.toUpperCase();
    final checkoutReady=configuration['checkout_ready']==true&&configuration['available_for_self_checkout']==true;
    final deliveryNote='${configuration['customer_delivery_disclosure']??configuration['delivery_note']??configuration['delivery_summary']??''}'.trim();
""",'card delivery configuration')

once("""                      !technology&&!checkoutReady
                          ? 'BUILDING VERIFIED DELIVERY • NOT BILLING YET'
                          : monthly == null && yearly == null
                              ? 'Pricing not configured'
                              : monthly != null
                                  ? '${technology?'Starting at ':''}\$${monthly.toStringAsFixed(0)} / month'
                                  : '\$${yearly!.toStringAsFixed(0)} / year',
""","""                      !checkoutReady
                          ? 'CHECKOUT NOT AVAILABLE YET'
                          : monthly == null && yearly == null
                              ? 'Pricing not configured'
                              : monthly != null
                                  ? '\$${monthly.toStringAsFixed(0)} / month'
                                  : '\$${yearly!.toStringAsFixed(0)} / year',
""",'card pricing')

once("""  Map<String, dynamic> package,
) {
""","""  Map<String, dynamic> package,{
  bool ownerMode=false,
}) {
""",'package detail signature')

once("""  final deliveryStatus='${configuration['delivery_status']??(technology?'MANAGED_PILOT':'READY')}'.toUpperCase();
  final checkoutReady=technology?false:configuration['checkout_ready']==true;
  final deliveryNote='${configuration['delivery_note']??configuration['delivery_summary']??''}'.trim();
""","""  final purchaseMode='${configuration['purchase_mode']??'IMMEDIATE'}'.toUpperCase();
  final deliveryStatus='${configuration['delivery_status']??(purchaseMode=='FOUNDING_EARLY_ACCESS'?'EARLY ACCESS':purchaseMode=='MANAGED_ACTIVATION'?'MANAGED ACTIVATION':'READY')}'.toUpperCase();
  final checkoutReady=configuration['checkout_ready']==true&&configuration['available_for_self_checkout']==true;
  final deliveryNote='${configuration['customer_delivery_disclosure']??configuration['delivery_note']??configuration['delivery_summary']??''}'.trim();
""",'detail delivery configuration')

once("""                    technology
                      ? 'Technology pricing is shown as a starting point. BridgePoint scopes data volume, deployment mode, geography, API usage and support before billing. Core scoring weights and proprietary learning logic stay protected.'
                      : checkoutReady
                        ? 'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.'
                        : (deliveryNote.isEmpty?'BridgePoint is still building the verified delivery for this package. Self-checkout is paused and no customer will be billed until the package-specific output is live.':deliveryNote),
""","""                    deliveryNote.isNotEmpty
                      ? deliveryNote
                      : checkoutReady
                        ? (technology?'Enterprise purchase is available through secure Stripe checkout. Managed or staged delivery terms are shown before payment.':'Start with the configured trial where eligible. Secure Stripe checkout activates the server-side package entitlement after successful payment.')
                        : 'Checkout is not available for this package yet.',
""",'detail disclosure card')

old_buttons="""                const SizedBox(height: 12),
                if(technology)SizedBox(width:double.infinity,child:FilledButton.icon(
                  onPressed:()async{
                    try{
                      final result=await _callRpc('bridgepoint_request_technology_package_v93',{'p_package_key':package['package_key'],'p_note':null});
                      if(context.mounted){Navigator.of(context).pop();_showInfoDialog(context,'Technology request saved','${result['message']??'BridgePoint saved your request.'}');}
                    }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save request',e.toString());}
                  },
                  icon:const Icon(Icons.business_center_outlined),
                  label:Text('Request technology scope • starting at \$${(package['monthly_price'] as num?)?.toStringAsFixed(0)??'—'}/mo'),
                )) else Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:!checkoutReady||package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:Icon(checkoutReady?Icons.bolt_rounded:Icons.construction_rounded),
                    label:Text(!checkoutReady?'Building verified feed':package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:!checkoutReady||package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(!checkoutReady?'Not billing yet':package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
"""
new_buttons="""                const SizedBox(height: 12),
                if(ownerMode)...[
                  SizedBox(width:double.infinity,child:FilledButton.tonalIcon(
                    onPressed:()=>showDialog<void>(context:context,builder:(context)=>_SalesDemoDialogV224(initialPackageKey:'${package['package_key']??''}')),
                    icon:const Icon(Icons.point_of_sale_rounded),label:const Text('Demo customer checkout - no charge')),
                  const SizedBox(height:8),
                ],
                Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:!checkoutReady||package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:Icon(checkoutReady?Icons.lock_open_rounded:Icons.construction_rounded),
                    label:Text(!checkoutReady?'Checkout unavailable':package['monthly_price']==null?'Monthly unavailable':'Monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:!checkoutReady||package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(!checkoutReady?'Checkout unavailable':package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
                if(technology&&purchaseMode=='MANAGED_ACTIVATION')...[
                  const SizedBox(height:8),
                  SizedBox(width:double.infinity,child:TextButton.icon(
                    onPressed:()async{
                      try{
                        final result=await _callRpc('bridgepoint_request_technology_package_v93',{'p_package_key':package['package_key'],'p_note':'Customer requested managed activation follow-up from package detail.'});
                        if(context.mounted)_showInfoDialog(context,'Managed activation request saved','${result['message']??'BridgePoint saved your activation request.'}');
                      }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save request',e.toString());}
                    },
                    icon:const Icon(Icons.support_agent_rounded),label:const Text('Request onboarding / deployment help'))),
                ],
"""
once(old_buttons,new_buttons,'purchase buttons')

once("WidgetsBinding.instance.addPostFrameCallback((_)=>_maybeOfferWalkthrough());","WidgetsBinding.instance.addPostFrameCallback((_){_maybeOfferWalkthrough();unawaited(_maybeShowCheckoutResultV224());});",'checkout callback')
checkout_method=r'''
  Future<void> _maybeShowCheckoutResultV224()async{
    final params=Uri.base.queryParameters;
    final state='${params['checkout']??''}';
    if(state=='cancelled'){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Checkout cancelled - no purchase was made.')));
      return;
    }
    if(state!='success')return;
    final session='${params['session_id']??''}'.trim();
    if(session.isEmpty)return;
    Map<String,dynamic> result=<String,dynamic>{};
    for(var attempt=0;attempt<4;attempt++){
      try{result=await _callRpc('bridgepoint_purchase_confirmation_v223',{'p_checkout_session_id':session});}catch(_){result=<String,dynamic>{};}
      if(result['complete']==true)break;
      await Future<void>.delayed(const Duration(seconds:2));
    }
    if(!mounted)return;
    if(result['complete']!=true){
      _showInfoDialog(context,'Payment received','Stripe returned successfully. BridgePoint is still syncing the entitlement. Open Settings → Purchases & billing in a moment to confirm access.');
      return;
    }
    await showDialog<void>(context:context,builder:(context)=>AlertDialog(
      backgroundColor:AppTheme.panel,
      title:const Row(children:[Icon(Icons.verified_rounded,color:AppTheme.green),SizedBox(width:9),Expanded(child:Text('Purchase complete'))]),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${result['thank_you']??'Thank you for choosing BridgePoint Intelligence.'}',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800,height:1.45)),
        const SizedBox(height:12),_SettingsStatusRow(label:'Package',value:'${result['package_name']??result['package_key']??'BridgePoint'}',color:AppTheme.cyan),
        _SettingsStatusRow(label:'Access',value:'${result['fulfillment_status']??'ENTITLED'}'.replaceAll('_',' '),color:AppTheme.green),
        _SettingsStatusRow(label:'Delivery',value:'${result['purchase_mode']??'IMMEDIATE'}'.replaceAll('_',' '),color:AppTheme.blue),
        const SizedBox(height:10),const Text('Your package is now tied to this BridgePoint account. You can review access, billing, cancellation, and package instructions from Settings → Purchases & billing.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5)),
      ]))),
      actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Continue to BridgePoint'))],
    ));
  }

'''
anchor="""  int? _navigationIndexForLabel(String label){
"""
idx=s.find(anchor)
if idx<0: raise SystemExit('dashboard method anchor missing')
s=s[:idx]+checkout_method+s[idx:]

classes=r'''
class _PurchaseCenterV224 extends StatefulWidget{
  const _PurchaseCenterV224({required this.ownerMode});final bool ownerMode;
  @override State<_PurchaseCenterV224> createState()=>_PurchaseCenterV224State();
}
class _PurchaseCenterV224State extends State<_PurchaseCenterV224>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_my_purchases_v223',const {});}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_my_purchases_v223',const {}));
  @override Widget build(BuildContext context)=>_SettingsSection(
    icon:Icons.receipt_long_rounded,title:'Purchases & billing',subtitle:'See what is active, understand delivery, manage billing, or open step-by-step purchase help.',children:[
      FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
        final purchases=_bpRows(snapshot.data?['purchases']);
        if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);
        if(snapshot.hasError)return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${snapshot.error}',style:const TextStyle(color:AppTheme.amber,fontSize:9)),TextButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Try again'))]);
        if(purchases.isEmpty)return const Padding(padding:EdgeInsets.only(bottom:8),child:Text('No paid package purchase is recorded yet. Trial, owner, or promotional access can still be active.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45)));
        return Column(children:purchases.take(8).map((p)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(10)),child:Row(children:[
          Icon(p['has_access']==true?Icons.verified_rounded:Icons.warning_amber_rounded,color:p['has_access']==true?AppTheme.green:AppTheme.amber,size:18),const SizedBox(width:8),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p['package_name']??p['package_key']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10.5)),const SizedBox(height:2),Text('${p['status']??''} • ${'${p['purchase_mode']??'IMMEDIATE'}'.replaceAll('_',' ')}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),
          _OpportunityChip(label:p['has_access']==true?'ACCESS ON':'CHECK ACCESS',color:p['has_access']==true?AppTheme.green:AppTheme.amber),
        ]))).toList());
      }),
      const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _CustomerPurchaseGuideV224()),icon:const Icon(Icons.menu_book_rounded),label:const Text('Open setup & purchase guide'))),
      if(widget.ownerMode)...[const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _SalesDemoDialogV224()),icon:const Icon(Icons.point_of_sale_rounded),label:const Text('Open sales checkout demo - no charge')))],
      const SizedBox(height:8),SizedBox(width:double.infinity,child:TextButton.icon(onPressed:()=>_openBillingPortal(context),icon:const Icon(Icons.credit_card_rounded),label:const Text('Open secure billing portal'))),
      const Text('Billing changes are handled by Stripe. BridgePoint never asks you to type card or bank details into the app itself.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
      const Text('bridgepoint-v224-sales-purchase-help',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ]);
}

class _CustomerPurchaseGuideV224 extends StatelessWidget{
  const _CustomerPurchaseGuideV224();
  Widget section(String title,String body)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:4),Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5))]));
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:820,maxHeight:760),child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Icon(Icons.menu_book_rounded,color:AppTheme.cyan),const SizedBox(width:9),const Expanded(child:Text('BridgePoint setup & purchase guide',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
    const Text('Customer help for account settings, packages, checkout, billing, team setup, accessibility, sharing, and support.',style:TextStyle(color:AppTheme.textMuted,fontSize:10)),const SizedBox(height:12),
    Expanded(child:FutureBuilder<Map<String,dynamic>>(future:_callRpc('bridgepoint_flutter_packages',const {}),builder:(context,snapshot){final packages=_bpRows(snapshot.data?['packages']);final immediate=packages.where((p)=>'${_bpMap(p['configuration'])['purchase_mode']??'IMMEDIATE'}'=='IMMEDIATE').map((p)=>'${p['package_name']}').toList();final early=packages.where((p)=>'${_bpMap(p['configuration'])['purchase_mode']}'=='FOUNDING_EARLY_ACCESS').map((p)=>'${p['package_name']}').toList();final managed=packages.where((p)=>'${_bpMap(p['configuration'])['purchase_mode']}'=='MANAGED_ACTIVATION').map((p)=>'${p['package_name']}').toList();return SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      section('1. Account & sign-in','Create an account with your email and password, confirm email if prompted, then choose your nickname. Settings shows the signed-in account email and secure session state.'),
      section('2. Trial & choosing a package','Eligible standard plans show the configured trial before paid billing. Open Packages, choose a plan, compare monthly vs annual pricing, and read the delivery disclosure before checkout.'),
      section('3. Secure checkout','BridgePoint opens Stripe Checkout. Confirm the package, interval, trial/discount if shown, and delivery disclosure. Enter payment information only on Stripe - never in a BridgePoint text box or support message.'),
      section('4. After payment','Stripe sends BridgePoint a signed payment event. BridgePoint activates the server-side entitlement and returns you to a purchase confirmation. Open Settings → Purchases & billing to confirm access.'),
      section('5. Manage or cancel','Settings → Purchases & billing → Open secure billing portal. Stripe handles payment methods, invoices, subscription changes, and cancellation. Access follows the paid/trial period.'),
      section('6. Company & team','Company customers use Settings → Company & team for the shared workspace, roles, invitations, and seats. Owners/managers should create or join the Company workspace before Company checkout.'),
      section('7. Display, maps & evidence','Settings lets you change refresh timing, text size, contrast, motion, map style, and whether confidence, patterns, or raw supporting signals are shown.'),
      section('8. Sharing, help, legal & feedback','Use Share BridgePoint for the permanent app link. Help & FAQ answers common questions. Legal & Trust Center contains terms/privacy/data limitations. Suggestions & feedback sends support questions or data requests.'),
      section('Immediate Access packages',immediate.isEmpty?'Loading package list…':immediate.join(' • ')),
      section('Founding Early Access packages',early.isEmpty?'None currently listed.':early.join(' • ')+'\nYour entitlement starts after successful checkout, while clearly identified capabilities may roll out in stages.'),
      section('Managed Activation packages',managed.isEmpty?'None currently listed.':managed.join(' • ')+'\nPurchase reserves/activates the entitlement, then BridgePoint completes package-specific onboarding or deployment.'),
    ]));})),
  ]))));
}

class _SalesDemoDialogV224 extends StatefulWidget{
  const _SalesDemoDialogV224({this.initialPackageKey});final String? initialPackageKey;
  @override State<_SalesDemoDialogV224> createState()=>_SalesDemoDialogV224State();
}
class _SalesDemoDialogV224State extends State<_SalesDemoDialogV224>{
  String? selected;String interval='month';
  @override void initState(){super.initState();selected=widget.initialPackageKey;}
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900,maxHeight:760),child:Padding(padding:const EdgeInsets.all(22),child:FutureBuilder<Map<String,dynamic>>(future:_callRpc('bridgepoint_flutter_packages',const {}),builder:(context,snapshot){
    final packages=_bpRows(snapshot.data?['packages']).where((p)=>_bpMap(p['configuration'])['checkout_ready']==true).toList();
    final fallback=packages.isEmpty?<String,dynamic>{}:packages.first;final key=selected??'${fallback['package_key']??''}';final matches=packages.where((p)=>'${p['package_key']}'==key).toList();final p=matches.isEmpty?fallback:matches.first;final config=_bpMap(p['configuration']);final price=interval=='year'?p['yearly_price']:p['monthly_price'];final mode='${config['purchase_mode']??'IMMEDIATE'}';final disclosure='${config['customer_delivery_disclosure']??''}';
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.point_of_sale_rounded,color:AppTheme.amber),const SizedBox(width:9),const Expanded(child:Text('Customer checkout demo',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),const _OpportunityChip(label:'DEMO • NO CHARGE',color:AppTheme.green),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
      const SizedBox(height:5),const Text('Use this during a sales demo to show exactly what a customer sees before, during, and after purchase. This preview never opens a payment session.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),const SizedBox(height:12),
      if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)const LinearProgressIndicator(color:AppTheme.cyan) else Expanded(child:SingleChildScrollView(child:Column(children:[
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('STEP 1 • CHOOSE PACKAGE',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),const SizedBox(height:8),
          DropdownButtonFormField<String>(value:key.isEmpty?null:key,dropdownColor:AppTheme.panelSoft,decoration:const InputDecoration(labelText:'Package to demo',border:OutlineInputBorder()),items:packages.map((x)=>DropdownMenuItem(value:'${x['package_key']}',child:Text('${x['package_name']}'))).toList(),onChanged:(v)=>setState(()=>selected=v)),const SizedBox(height:8),
          SegmentedButton<String>(segments:const [ButtonSegment(value:'month',label:Text('Monthly')),ButtonSegment(value:'year',label:Text('Annual'))],selected:{interval},onSelectionChanged:(v)=>setState(()=>interval=v.first)),const SizedBox(height:8),
          Text('${p['package_name']??'Package'} • ${price==null?'Price unavailable':'\$${(price as num).toStringAsFixed(0)} / ${interval=='year'?'year':'month'}'}',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(mode.replaceAll('_',' '),style:const TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900)),if(disclosure.isNotEmpty)...[const SizedBox(height:5),Text(disclosure,style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45))],
        ])),const SizedBox(height:10),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF101827),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[Icon(Icons.lock_rounded,color:AppTheme.green,size:18),SizedBox(width:7),Text('STEP 2 • STRIPE SECURE CHECKOUT',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),Spacer(),Text('stripe.com',style:TextStyle(color:AppTheme.textMuted,fontSize:9))]),const SizedBox(height:10),
          _SettingsStatusRow(label:'Customer email',value:'customer@example.com',color:AppTheme.cyan),_SettingsStatusRow(label:'Plan',value:'${p['package_name']??'BridgePoint'} • ${interval=='year'?'Annual':'Monthly'}',color:AppTheme.blue),
          Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white.withOpacity(.04),borderRadius:BorderRadius.circular(8)),child:const Text('Card number   MM/YY   CVC\nBilling name & address',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.8))),const SizedBox(height:8),
          if(disclosure.isNotEmpty)Text('Before Subscribe: $disclosure',style:const TextStyle(color:AppTheme.amber,fontSize:9,height:1.45)),const SizedBox(height:8),
          SizedBox(width:double.infinity,child:FilledButton(onPressed:null,child:Text('DEMO ONLY • Subscribe ${price==null?'':'• \$${(price as num).toStringAsFixed(0)}'}'))),
        ])),const SizedBox(height:10),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.06),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.18))),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('STEP 3 • PAYMENT CONFIRMED + ACCESS ACTIVATED',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),SizedBox(height:7),Text('Stripe sends a signed webhook → BridgePoint records the subscription → server-side package entitlement turns on → purchase confirmation appears → welcome email is queued for the configured delivery provider.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5))])),const SizedBox(height:10),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.06),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.blue.withOpacity(.18))),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('STEP 4 • CUSTOMER SETTINGS',style:TextStyle(color:AppTheme.blue,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),SizedBox(height:7),Text('Settings → Purchases & billing shows the active package, access state, delivery mode, setup & purchase guide, and secure billing portal for invoices, payment methods, plan changes, or cancellation.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5))])),
      ]))),
    ]);
  }))));
}

'''
field_anchor="class _FieldModePage extends StatefulWidget {"
idx=s.find(field_anchor)
if idx<0: raise SystemExit('field mode anchor missing')
s=s[:idx]+classes+s[idx:]

once("""                SizedBox(width:width,child:const _TeamSettingsPanel()),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.help_center_outlined,title:'Help & FAQ',
""","""                SizedBox(width:width,child:const _TeamSettingsPanel()),
                SizedBox(width:width,child:_PurchaseCenterV224(ownerMode:widget.ownerMode)),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.help_center_outlined,title:'Help & FAQ',
""",'purchase center settings')

once("""                    SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:()=>_showFaqDialog(context),icon:const Icon(Icons.question_answer_outlined),label:const Text('Open Help & FAQ'))),
                    const SizedBox(height:8),const Text('If the answer is not there, use Suggestions & feedback below and choose Question.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
""","""                    SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:()=>_showFaqDialog(context),icon:const Icon(Icons.question_answer_outlined),label:const Text('Open Help & FAQ'))),
                    const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(
                      onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _CustomerPurchaseGuideV224()),icon:const Icon(Icons.menu_book_rounded),label:const Text('Setup, package & purchase instructions'))),
                    const SizedBox(height:8),const Text('If the answer is not there, use Suggestions & feedback below and choose Question.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
""",'help purchase guide')

path.write_text(s,encoding='utf-8')
print('Applied BridgePoint sales, checkout demo, purchase center and customer help v224.')
