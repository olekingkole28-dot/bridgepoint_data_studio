from pathlib import Path

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v220-live-billing-readiness'
if marker in body:
    print('Billing live readiness v220 already applied.')
    raise SystemExit(0)

old_payout = """Future<void> _openOwnerPayoutSettings(BuildContext context) async {
  final uri=Uri.parse('https://dashboard.stripe.com/test/settings/payouts');
  if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&context.mounted){
    _showInfoDialog(context,'Could not open Stripe','Open Stripe Dashboard → Settings → Bank accounts and scheduling. Enter bank information only inside Stripe.');
  }
}
"""
new_payout = """Future<void> _openOwnerPayoutSettings(BuildContext context) async {
  final uri=Uri.parse('https://dashboard.stripe.com/settings/payouts');
  if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&context.mounted){
    _showInfoDialog(context,'Could not open Stripe','Open Stripe Dashboard → Settings → Bank accounts and scheduling. Enter bank information only inside Stripe.');
  }
}

Future<Map<String,dynamic>> _bridgePointBillingReadinessV220() async {
  final response=await http.get(
    Uri.parse('$_supabaseUrl/functions/v1/bridgepoint-billing-readiness-v67'),
    headers:{'apikey':_supabasePublishableKey},
  ).timeout(const Duration(seconds:20));
  final decoded=jsonDecode(response.body);
  if(response.statusCode<200||response.statusCode>=300||decoded is! Map)throw Exception(decoded is Map?decoded['error']:'Billing readiness check failed');
  return Map<String,dynamic>.from(decoded);
}

class _BillingReadinessBannerV220 extends StatefulWidget{
  const _BillingReadinessBannerV220({this.owner=false});
  final bool owner;
  @override State<_BillingReadinessBannerV220> createState()=>_BillingReadinessBannerV220State();
}
class _BillingReadinessBannerV220State extends State<_BillingReadinessBannerV220>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_bridgePointBillingReadinessV220();}
  void refresh()=>setState(()=>request=_bridgePointBillingReadinessV220());
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,
    builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final live=data['readiness']=='LIVE_READY'&&data['payments_enabled']==true;
      final environment='${data['environment']??'checking'}'.toUpperCase();
      final readiness='${data['readiness']??(snapshot.hasError?'CHECK FAILED':'CHECKING')}'.replaceAll('_',' ');
      final accent=live?AppTheme.green:AppTheme.amber;
      final message=live
        ?'Live Stripe payments are ready. Checkout, subscriptions, webhooks, payouts and customer billing management are enabled.'
        :'Live customer charges are not enabled yet. BridgePoint blocks production checkout while Stripe is in sandbox/test mode, so no real customer can be sent into a test purchase. Once the live Stripe key, live webhook secret and live price catalog are connected, checkout unlocks without changing the customer flow.';
      return Container(
        width:double.infinity,padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:accent.withOpacity(.07),borderRadius:BorderRadius.circular(14),border:Border.all(color:accent.withOpacity(.22))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(live?Icons.verified_rounded:Icons.shield_outlined,color:accent,size:20),const SizedBox(width:9),Expanded(child:Text(live?'LIVE PAYMENTS READY':'PAYMENTS NOT LIVE YET',style:TextStyle(color:accent,fontWeight:FontWeight.w900,fontSize:12))),_OpportunityChip(label:environment,color:accent)]),
          const SizedBox(height:7),Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
          const SizedBox(height:8),Wrap(spacing:10,runSpacing:6,children:[
            Text('Status: $readiness',style:TextStyle(color:accent,fontSize:9,fontWeight:FontWeight.w800)),
            Text('Charges: ${data['live_charges_enabled']==true?'enabled':'not live'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
            Text('Payouts: ${data['payouts_enabled']==true?'enabled':'not live'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
            Text('Webhook: ${data['webhook_secret_configured']==true?'configured':'missing'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
          ]),
          if(snapshot.hasError)...[const SizedBox(height:7),Text('${snapshot.error}',style:const TextStyle(color:AppTheme.red,fontSize:9))],
          if(widget.owner)...[
            const SizedBox(height:11),Wrap(spacing:8,runSpacing:8,children:[
              FilledButton.icon(onPressed:()=>_openOwnerPayoutSettings(context),icon:const Icon(Icons.account_balance_outlined),label:const Text('Open Stripe payout settings')),
              OutlinedButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Recheck billing')),
            ]),
          ],
          const Text('bridgepoint-v220-live-billing-readiness',style:TextStyle(fontSize:0,color:Colors.transparent)),
        ]),
      );
    },
  );
}
"""
if old_payout not in body:
    raise SystemExit('v220 payout anchor not found')
body=body.replace(old_payout,new_payout,1)

old_packages = """    _PageHeading(title:'Packages',subtitle:'Start with the best fit • expand the catalog only when you want more choices',onRefresh:_reload,loading:loading),
    const SizedBox(height:10),const _ExplainerBanner(icon:Icons.auto_awesome_rounded,title:'A few plans are featured on purpose',message:'BridgePoint highlights the clearest starting points first. Use the dropdown or Show more to compare specialty, enterprise and technology products without scrolling through a wall of plans.'),
"""
new_packages = """    _PageHeading(title:'Packages',subtitle:'Start with the best fit • expand the catalog only when you want more choices',onRefresh:_reload,loading:loading),
    const SizedBox(height:10),const _BillingReadinessBannerV220(),
    const SizedBox(height:10),const _ExplainerBanner(icon:Icons.auto_awesome_rounded,title:'A few plans are featured on purpose',message:'BridgePoint highlights the clearest starting points first. Use the dropdown or Show more to compare specialty, enterprise and technology products without scrolling through a wall of plans.'),
"""
if old_packages not in body:
    raise SystemExit('v220 packages anchor not found')
body=body.replace(old_packages,new_packages,1)

old_row = "_OwnerStatusRow('Checkout connected',revenue['checkout_connected']==true?'YES':'NOT YET',revenue['checkout_connected']==true?AppTheme.green:AppTheme.amber),"
new_row = "_OwnerStatusRow('Billing records present',revenue['checkout_connected']==true?'YES':'NOT YET',revenue['checkout_connected']==true?AppTheme.green:AppTheme.amber),"
if old_row not in body:
    raise SystemExit('v220 revenue row anchor not found')
body=body.replace(old_row,new_row,1)

old_owner = """        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(
          alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:18,runSpacing:12,children:[
            SizedBox(width:c.maxWidth>=760?c.maxWidth-260:c.maxWidth,child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Stripe payout readiness',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
              SizedBox(height:5),
              Text('Connect and verify the bank account that receives BridgePoint revenue. Bank details stay inside Stripe and are never entered into this app.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
            ])),
            FilledButton.icon(onPressed:()=>_openOwnerPayoutSettings(context),icon:const Icon(Icons.account_balance_outlined),label:const Text('Open secure payout setup')),
          ],
        )))),
"""
new_owner = """        const _BillingReadinessBannerV220(owner:true),
"""
if old_owner not in body:
    raise SystemExit('v220 owner billing anchor not found')
body=body.replace(old_owner,new_owner,1)

path.write_text(body,encoding='utf-8')
print('Applied BridgePoint live billing readiness v220 UI.')
