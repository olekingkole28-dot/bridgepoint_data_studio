from __future__ import annotations

from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v359-owner-access-health-ui'

if marker in text:
    print('Owner access health UI v359 already applied')
    raise SystemExit(0)

if 'bridgepoint-v357-owner-national-sources-ui' not in text:
    raise SystemExit('v359 requires the V357 owner Sources surface first')

state_anchor = "class _SourcesPageState extends State<_SourcesPage>{\n  String selectedState='ALL';"
state_replacement = """class _SourcesPageState extends State<_SourcesPage>{
  String selectedState='ALL';
  Future<Map<String,dynamic>>? _ownerAccessRequestV359;

  Future<Map<String,dynamic>> _ownerAccessV359()=>
      _ownerAccessRequestV359??=_callRpc('bridgepoint_owner_access_status_v358',const {});

  void _refreshOwnerAccessV359(){
    setState(()=>_ownerAccessRequestV359=_callRpc('bridgepoint_owner_access_status_v358',const {}));
  }"""
if state_anchor not in text:
    raise SystemExit('v359 Sources state structural anchor missing')
text = text.replace(state_anchor, state_replacement, 1)

owner_banner = """          const SizedBox(height:16),
          Container(
            width:double.infinity,padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.055),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Icon(Icons.admin_panel_settings_outlined,color:AppTheme.cyan,size:20),const SizedBox(width:10),
              Expanded(child:Text('OWNER VIEW • National accepted candidates are classified before they can influence intelligence. FOUNDATION_ONLY builds canonical property coverage; CONTEXT_ONLY adds supporting context; INTELLIGENCE_ELIGIBLE may feed direct intelligence only when matching and evidence rules also pass. Customer accounts never receive this infrastructure payload.',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45))),
            ]),
          ),
          const SizedBox(height:18),"""

owner_health = r"""          const SizedBox(height:16),
          Container(
            width:double.infinity,padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.055),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Icon(Icons.admin_panel_settings_outlined,color:AppTheme.cyan,size:20),const SizedBox(width:10),
              Expanded(child:Text('OWNER VIEW • National accepted candidates are classified before they can influence intelligence. FOUNDATION_ONLY builds canonical property coverage; CONTEXT_ONLY adds supporting context; INTELLIGENCE_ELIGIBLE may feed direct intelligence only when matching and evidence rules also pass. Customer accounts never receive this infrastructure payload.',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45))),
            ]),
          ),
          const SizedBox(height:14),
          // bridgepoint-v359-owner-access-health-ui
          FutureBuilder<Map<String,dynamic>>(
            future:_ownerAccessV359(),
            builder:(context,accessSnapshot){
              final access=accessSnapshot.data;
              final accessLoading=accessSnapshot.connectionState==ConnectionState.waiting;
              final healthy=access?['owner_access']==true
                  && access?['bypass_subscriptions']==true
                  && access?['access_all_models']==true
                  && access?['access_all_features']==true
                  && access?['access_all_geographies']==true
                  && access?['organization_active']==true;
              final role='${access?['organization_role']??'OWNER'}'.replaceAll('_',' ');
              final level='${access?['platform_access_level']??'platform owner'}'.replaceAll('_',' ');
              final profileHealthy=access?['product_profile_present']==true&&access?['workspace_profile_present']==true;
              final onboardingHealthy=access?['product_onboarding_complete']==true&&access?['workspace_onboarding_complete']==true;
              return Card(child:Padding(
                padding:const EdgeInsets.all(18),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    Container(width:40,height:40,decoration:BoxDecoration(color:(healthy?AppTheme.green:AppTheme.amber).withOpacity(.11),borderRadius:BorderRadius.circular(11)),child:Icon(healthy?Icons.verified_user_rounded:Icons.security_update_warning_rounded,color:healthy?AppTheme.green:AppTheme.amber,size:21)),
                    const SizedBox(width:11),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      const Text('Owner Access Health',style:TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900)),
                      const SizedBox(height:3),
                      Text(accessLoading?'Verifying protected owner contracts…':healthy?'Protected owner override is healthy':'Owner access needs attention',style:TextStyle(color:healthy?AppTheme.green:AppTheme.amber,fontSize:9.5,fontWeight:FontWeight.w800)),
                    ])),
                    IconButton(tooltip:'Recheck owner access',onPressed:accessLoading?null:_refreshOwnerAccessV359,icon:const Icon(Icons.refresh_rounded,size:18)),
                  ]),
                  if(accessSnapshot.hasError)...[
                    const SizedBox(height:10),
                    Text('Owner diagnostic could not be verified: ${accessSnapshot.error}',style:const TextStyle(color:AppTheme.amber,fontSize:9.5,height:1.4)),
                  ] else if(!accessLoading)...[
                    const SizedBox(height:12),
                    Wrap(spacing:7,runSpacing:7,children:[
                      _OpportunityChip(label:role,color:AppTheme.cyan),
                      _OpportunityChip(label:level.toUpperCase(),color:healthy?AppTheme.green:AppTheme.amber),
                      _OpportunityChip(label:'ALL STATES',color:access?['access_all_geographies']==true?AppTheme.green:AppTheme.amber),
                      _OpportunityChip(label:'ALL MODELS',color:access?['access_all_models']==true?AppTheme.green:AppTheme.amber),
                      _OpportunityChip(label:'ALL FEATURES',color:access?['access_all_features']==true?AppTheme.green:AppTheme.amber),
                      _OpportunityChip(label:'SUBSCRIPTION BYPASS',color:access?['bypass_subscriptions']==true?AppTheme.green:AppTheme.amber),
                    ]),
                    const SizedBox(height:11),
                    Text(
                      '${access?['email']??'Owner account'} • product profile ${profileHealthy?'healthy':'review'} • onboarding ${onboardingHealthy?'complete':'review'} • workspace role ${access?['workspace_role_name']??'—'}',
                      style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45),
                    ),
                    const SizedBox(height:6),
                    const Text('This diagnostic verifies the protected owner override only. It does not expose secrets or grant customer accounts additional access.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.8,height:1.4)),
                  ],
                ]),
              ));
            },
          ),
          const SizedBox(height:18),"""

if owner_banner not in text:
    raise SystemExit('v359 owner banner structural anchor missing')
text = text.replace(owner_banner, owner_health, 1)

for needle in (
    'bridgepoint-v359-owner-access-health-ui',
    "bridgepoint_owner_access_status_v358",
    'Owner Access Health',
    'ALL STATES',
    'SUBSCRIPTION BYPASS',
    'does not expose secrets or grant customer accounts additional access',
):
    if needle not in text:
        raise SystemExit(f'v359 required marker missing: {needle}')

path.write_text(text,encoding='utf-8')
print('Owner access health UI v359 applied')
