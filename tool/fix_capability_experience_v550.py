from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')

old="Widget _metric(String label,dynamic value,String detail)=>Expanded(child:Container("
new="Widget _metric(String label,dynamic value,String detail)=>Container("
if old in s:
    s=s.replace(old,new,1)
    tail="Text(detail,style:const TextStyle(fontSize:10,color:AppTheme.textMuted))])));"
    tail_new="Text(detail,style:const TextStyle(fontSize:10,color:AppTheme.textMuted))]));"
    if tail not in s:
        raise SystemExit('V550 metric closing anchor missing')
    s=s.replace(tail,tail_new,1)

replacements={
"OutlinedButton(onPressed:null,child:Text('Autonomy Center → web'))":"OutlinedButton(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/distribution/autonomy/'),mode:LaunchMode.platformDefault),child:const Text('Autonomy Center → web'))",
"OutlinedButton(onPressed:null,child:Text('Property Trust Engine → web'))":"OutlinedButton(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/distribution/trust/'),mode:LaunchMode.platformDefault),child:const Text('Property Trust Engine → web'))",
"OutlinedButton(onPressed:null,child:Text('Distribution → web'))":"OutlinedButton(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/distribution/'),mode:LaunchMode.platformDefault),child:const Text('Distribution → web'))",
"OutlinedButton(onPressed:null,child:Text('Innovation → web'))":"OutlinedButton(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/innovation/'),mode:LaunchMode.platformDefault),child:const Text('Innovation → web'))",
}
for a,b in replacements.items():
    if a in s:s=s.replace(a,b,1)

p.write_text(s,encoding='utf-8')
print('V550 native capability center build fixes applied')
