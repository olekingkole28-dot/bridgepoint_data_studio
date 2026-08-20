from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v353-ui-shell-polish'
if marker in text:
    print('BridgePoint v353 UI shell polish already applied.')
    raise SystemExit(0)

required=[
    'class _DashboardScreenState extends State<DashboardScreen>',
    'class _TopBar extends StatelessWidget',
    'class _LiveSyncStrip extends StatelessWidget',
    'class _CompactNavigation extends StatelessWidget',
]
missing=[x for x in required if x not in text]
if missing:
    raise SystemExit(f'v353 required shell anchors missing: {missing}')

old_primary="""  List<int> get _primaryNavigationIndicesV248 {
    final model=packageModelKeys[selectedPackage]??'all';
    final labels=<String>{
      if(_effectiveOwnerMode)'Owner Center',
      'Daily Brief','Opportunities','Intelligence Map','Properties','My Work','Community','Settings',
      if(model=='bridgepoint_home')'My Home',
      if(model!='bridgepoint_home'&&model!='all')'Field Mode',
    };
    final ordered=<String>[
      if(_effectiveOwnerMode)'Owner Center','Daily Brief',
      if(model=='bridgepoint_home')'My Home',
      'Opportunities','Intelligence Map','Properties',
      if(model!='bridgepoint_home'&&model!='all')'Field Mode',
      'My Work','Community','Settings',
    ];
    final indices=<int>[];
    for(final label in ordered){
      if(!labels.contains(label))continue;
      final i=visibleNavigationItems.indexWhere((item)=>item.label==label);
      if(i>=0&&!indices.contains(i))indices.add(i);
    }
    return indices;
  }
"""
new_primary="""  List<int> get _primaryNavigationIndicesV248 {
    final model=packageModelKeys[selectedPackage]??'all';
    final ordered=<String>[
      if(_effectiveOwnerMode)...['Owner Center','Daily Brief','Opportunities','Intelligence Map','Properties']
      else if(model=='bridgepoint_home')...['Daily Brief','My Home','Opportunities','Intelligence Map','My Work']
      else if(model!='all')...['Daily Brief','Opportunities','Intelligence Map','Field Mode','My Work']
      else ...['Daily Brief','Opportunities','Intelligence Map','Properties','My Work'],
    ];
    final indices=<int>[];
    for(final label in ordered){
      final i=visibleNavigationItems.indexWhere((item)=>item.label==label);
      if(i>=0&&!indices.contains(i))indices.add(i);
      if(indices.length>=5)break;
    }
    return indices;
  }
"""
if old_primary not in text:
    raise SystemExit('v353 primary navigation anchor mismatch')
text=text.replace(old_primary,new_primary,1)

top_anchor='class _TopBar extends StatelessWidget {'
helper="""String _bridgePointUserInitialsV353(){
  final user=Supabase.instance.client.auth.currentUser;
  final meta=user?.userMetadata??const <String,dynamic>{};
  final raw='${meta['nickname']??meta['display_name']??user?.email??'BP'}'.trim();
  final cleaned=raw.split('@').first.replaceAll(RegExp(r'[^A-Za-z0-9]+'),' ').trim();
  final words=cleaned.split(RegExp(r'\\s+')).where((e)=>e.isNotEmpty).toList();
  if(words.isEmpty)return 'BP';
  if(words.length==1){final value=words.first.toUpperCase();return value.substring(0,value.length.clamp(1,2));}
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

class _BridgePointUserAvatarV353 extends StatelessWidget{
  const _BridgePointUserAvatarV353({required this.radius});
  final double radius;
  @override Widget build(BuildContext context){
    final email=Supabase.instance.client.auth.currentUser?.email??'BridgePoint account';
    return Tooltip(message:email,child:CircleAvatar(
      radius:radius,backgroundColor:AppTheme.blue,
      child:Text(_bridgePointUserInitialsV353(),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:radius*.62)),
    ));
  }
}

"""
if top_anchor not in text: raise SystemExit('v353 TopBar anchor missing')
text=text.replace(top_anchor,helper+top_anchor,1)

avatar18="""                const CircleAvatar(
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
"""
avatar19="""          const CircleAvatar(
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
"""
if text.count(avatar18)!=1 or text.count(avatar19)!=1:
    raise SystemExit(f'v353 avatar anchors mismatch mobile={text.count(avatar18)} desktop={text.count(avatar19)}')
text=text.replace(avatar18,"                const _BridgePointUserAvatarV353(radius:18),\n",1)
text=text.replace(avatar19,"          const _BridgePointUserAvatarV353(radius:19),\n",1)

old_mobile_actions="""                const SizedBox(width: 8),
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
                const _BridgePointUserAvatarV353(radius:18),
"""
new_mobile_actions="""                const SizedBox(width:8),
                PopupMenuButton<String>(
                  tooltip:'Quick actions',
                  onSelected:(v){
                    if(v=='share')_showShareBridgePointDialog(context);
                    if(v=='walk')onTraining();
                    if(v=='help')_showFaqDialog(context);
                    if(v=='alerts')onNotifications();
                  },
                  itemBuilder:(context)=>const [
                    PopupMenuItem(value:'alerts',child:ListTile(leading:Icon(Icons.notifications_none_rounded),title:Text('Alerts'))),
                    PopupMenuItem(value:'share',child:ListTile(leading:Icon(Icons.ios_share_rounded),title:Text('Share BridgePoint'))),
                    PopupMenuItem(value:'walk',child:ListTile(leading:Icon(Icons.school_outlined),title:Text('Walkthrough'))),
                    PopupMenuItem(value:'help',child:ListTile(leading:Icon(Icons.help_outline_rounded),title:Text('Help'))),
                  ],
                  child:Container(width:40,height:40,decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white12)),child:const Icon(Icons.more_horiz_rounded,size:20)),
                ),
                const SizedBox(width:8),
                const _BridgePointUserAvatarV353(radius:18),
"""
if old_mobile_actions not in text: raise SystemExit('v353 mobile action row anchor mismatch')
text=text.replace(old_mobile_actions,new_mobile_actions,1)

old_mobile_second="""                Expanded(child: _packageSelector()),
                const SizedBox(width: 8),
                _IconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _showShareBridgePointDialog(context),
                ),
"""
new_mobile_second="""                Expanded(child:_packageSelector()),
                const SizedBox(width:8),
                Tooltip(message:'Ask BridgePoint AI',child:_IconButton(
                  icon:Icons.auto_awesome_rounded,
                  onTap:()=>_showBridgePointAiPromptV248(context,onSearch),
                )),
"""
if old_mobile_second not in text: raise SystemExit('v353 mobile package row anchor mismatch')
text=text.replace(old_mobile_second,new_mobile_second,1)

old_strip="""        const _PulseDot(color:AppTheme.green),const SizedBox(width:8),
        const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8)),
"""
new_strip="""        const _PulseDot(color:AppTheme.cyan),const SizedBox(width:8),
        const Text('LIVE SYNC',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8)),
"""
if old_strip not in text: raise SystemExit('v353 live strip anchor mismatch')
text=text.replace(old_strip,new_strip,1)

old_status="""                      Text(
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
"""
new_status="""                      Text(
                        'AUTO-REFRESH ON',
                        style: TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height:3),
                      Text(
                        'BridgePoint keeps this workspace synced',
                        style:TextStyle(color:AppTheme.textMuted,fontSize:10),
                      ),
"""
if old_status not in text: raise SystemExit('v353 sidebar status anchor mismatch')
text=text.replace(old_status,new_status,1)

text=text.replace('color: AppTheme.green.withOpacity(0.08),\n              borderRadius: BorderRadius.circular(14),\n              border: Border.all(color: AppTheme.green.withOpacity(0.18)),','color: AppTheme.cyan.withOpacity(0.06),\n              borderRadius: BorderRadius.circular(14),\n              border: Border.all(color: AppTheme.cyan.withOpacity(0.16)),',1)
text=text.replace('_PulseDot(color: AppTheme.green),','_PulseDot(color: AppTheme.cyan),',1)

text += "\nconst String _bridgePointUiShellPolishV353='bridgepoint-v353-ui-shell-polish | five-primary-nav | dynamic-account-avatar | truthful-live-sync';\n"

checks=[marker,'LIVE SYNC','AUTO-REFRESH ON','_BridgePointUserAvatarV353',"if(indices.length>=5)break;",'Ask BridgePoint AI']
missing=[x for x in checks if x not in text]
if missing: raise SystemExit(f'v353 output checks missing: {missing}')
if "'KJ'" in text[text.find('class _TopBar extends StatelessWidget'):text.find('class _LiveSyncStrip extends StatelessWidget')]:
    raise SystemExit('v353 hard-coded founder avatar remains in TopBar')

path.write_text(text,encoding='utf-8')
print('BRIDGEPOINT UI SHELL POLISH V353 PASSED')
print(' - compact navigation limited to five package-aware primary destinations')
print(' - mobile top bar consolidated and BridgePoint AI promoted')
print(' - signed-in avatar derives from nickname/display name/email')
print(' - sync/status copy no longer overclaims strict intelligence or system health')
