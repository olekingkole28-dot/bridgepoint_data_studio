from pathlib import Path
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v280-owner-weather-motion-compile'
if marker in body:
    print('v280 compile repair already applied.')
    raise SystemExit(0)

repairs={
"imageOpacity:daily?.24:map?.22:.16":"imageOpacity:daily ? .24 : map ? .22 : .16",
"final speed=kind=='SNOW'?.30+(i%5)*.028:.72+(i%6)*.055;":"final speed=kind=='SNOW' ? .30+(i%5)*.028 : .72+(i%6)*.055;",
"weatherIntensity=(pop/100).clamp(.20,1.0);":"weatherIntensity=(pop/100).clamp(.20,1.0).toDouble();",
"intensity.clamp(.35,1.0)":"intensity.clamp(.35,1.0).toDouble()",
"withOpacity((widget.dim+.10).clamp(0.0,1.0))":"withOpacity((widget.dim+.10).clamp(0.0,1.0).toDouble())",
"final path=Path()..moveTo":"final path=ui.Path()..moveTo",
"subtitle:Text('${m['detail']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35));})]":"subtitle:Text('${m['detail']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)));})]",
}
for old,new in repairs.items():
    count=body.count(old)
    if count==0:
        raise SystemExit(f'v280 repair anchor missing: {old[:80]}')
    if old=="intensity.clamp(.35,1.0)":
        body=body.replace(old,new)
        print(f'v280 repaired {count} weather opacity clamp(s).')
    else:
        if count!=1:
            raise SystemExit(f'v280 repair anchor ambiguous ({count}): {old[:80]}')
        body=body.replace(old,new,1)

unused="    final routeBright=Paint()..style=PaintingStyle.stroke..strokeWidth=1.8..strokeCap=StrokeCap.round..color=accent.withOpacity(.25);\n"
if unused in body:
    body=body.replace(unused,'',1)

body += "\nconst String _bridgePointV280OwnerWeatherMotionCompile='bridgepoint-v280-owner-weather-motion-compile | ui.Path | safe ternaries | double clamps | investor readiness closure';\n"
path.write_text(body,encoding='utf-8')
print('Repaired v277-v279 generated Flutter compile points v280.')
runpy.run_path('tool/apply_founder_story_reviews_v282.py', run_name='__main__')
runpy.run_path('tool/fix_founder_reviews_customer_preview_v284.py', run_name='__main__')
