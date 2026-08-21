from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v417-owner-running-release-truth'
if marker in text:
    print('Owner running release truth V417 already applied')
    raise SystemExit(0)
if 'bridgepoint-v416-owner-attention' not in text:
    raise SystemExit('V417 requires V416 Owner Attention')

anchor="    moving.add('${oauth['publish_ready']??0} of ${oauth['configured']??oauth['providers']??6} social targets are publish-ready.');"
if text.count(anchor)!=1:
    raise SystemExit(f'V417 release placement anchor count {text.count(anchor)}')
replacement=anchor+r'''
    const runningRelease=String.fromEnvironment('BRIDGEPOINT_RELEASE',defaultValue:'');
    if(runningRelease.isEmpty){
      automatic.add('This build does not contain an embedded production release SHA, so treat it as local/preview until a verified production build is loaded.');
    }else{
      final shortRelease=runningRelease.length>12?runningRelease.substring(0,12):runningRelease;
      moving.add('Running app release $shortRelease is embedded in this exact web/PWA build.');
    }
'''
text=text.replace(anchor,replacement,1)

footer_anchor="      const Text('bridgepoint-v416-owner-attention',style:TextStyle(fontSize:0,color:Colors.transparent)),"
if text.count(footer_anchor)!=1:
    raise SystemExit(f'V417 footer anchor count {text.count(footer_anchor)}')
footer=footer_anchor+r'''
      const Text('bridgepoint-v417-owner-running-release-truth',style:TextStyle(fontSize:0,color:Colors.transparent)),'''
text=text.replace(footer_anchor,footer,1)

path.write_text(text,encoding='utf-8')
print('Applied Owner running release truth V417')
