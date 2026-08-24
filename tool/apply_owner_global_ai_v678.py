from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
marker='// bridgepoint-v678-native-owner-global-ai'

imports="""import 'screens/bridgepoint_owner_ai_cockpit.dart';
import 'screens/bridgepoint_owner_global_control.dart';
"""
if "bridgepoint_owner_ai_cockpit.dart" not in s:
    anchor="import 'package:url_launcher/url_launcher.dart';\n"
    if anchor not in s:
        raise SystemExit('Could not locate Flutter import anchor')
    s=s.replace(anchor,anchor+'\n'+imports,1)

# Do not depend on a historical navigation-list shape. Later BridgePoint release
# layers legitimately evolve navigation. Put durable owner launchers directly in
# the current Owner Center and open the full native pages from there.
owner_anchor='class _OwnerCenterPage extends StatefulWidget{'
if owner_anchor not in s:
    raise SystemExit('V678 current Owner Center anchor missing')

launcher=r'''// bridgepoint-v678-native-owner-global-ai
class _OwnerGlobalAiLauncherV678 extends StatelessWidget{
  const _OwnerGlobalAiLauncherV678();
  @override Widget build(BuildContext context)=>Card(child:Padding(
    padding:const EdgeInsets.all(15),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[
        Icon(Icons.public_rounded,color:AppTheme.cyan),SizedBox(width:9),
        Expanded(child:Text('Global, Export & AI Controls',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900))),
      ]),
      const SizedBox(height:5),
      const Text('Owner-only controls for worldwide expansion, state exports, local-first continuity, language readiness and BridgePoint AI. Customer access is unchanged.',style:TextStyle(fontSize:11,height:1.4)),
      const SizedBox(height:11),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(
          onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:SafeArea(child:BridgePointOwnerAiCockpit())))),
          icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Owner AI Cockpit')),
        FilledButton.icon(
          onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:SafeArea(child:BridgePointOwnerGlobalControl())))),
          icon:const Icon(Icons.language_rounded),label:const Text('Global / Export Control')),
      ]),
    ]),
  ));
}

'''
if marker not in s:
    s=s.replace(owner_anchor,launcher+owner_anchor,1)

if 'const _OwnerGlobalAiLauncherV678()' not in s:
    owner_start=s.find(owner_anchor)
    build_pos=s.find('Widget build(BuildContext context)',owner_start)
    if build_pos<0:
        raise SystemExit('V678 Owner Center build anchor missing')
    children_candidates=['children:[','children: [']
    children_pos=-1; token=''
    for candidate in children_candidates:
        pos=s.find(candidate,build_pos)
        if pos>=0:
            children_pos=pos; token=candidate; break
    if children_pos<0:
        raise SystemExit('V678 Owner Center children anchor missing')
    insert_at=children_pos+len(token)
    s=s[:insert_at]+"\n        const _OwnerGlobalAiLauncherV678(),"+s[insert_at:]

required=[
    "bridgepoint_owner_ai_cockpit.dart",
    "bridgepoint_owner_global_control.dart",
    marker,
    "class _OwnerGlobalAiLauncherV678",
    "const _OwnerGlobalAiLauncherV678()",
    "BridgePointOwnerAiCockpit()",
    "BridgePointOwnerGlobalControl()",
]
missing=[x for x in required if x not in s]
if missing:
    raise SystemExit('Missing V678 markers: '+repr(missing))

p.write_text(s,encoding='utf-8')
print('Applied resilient native owner AI + global/export controls V678 inside current Owner Center')
