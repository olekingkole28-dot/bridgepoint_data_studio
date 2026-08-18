from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v313-brand-live-refresh'
if marker in body:
    print('v313 brand live refresh already applied.')
    raise SystemExit(0)

start=body.find('class _FounderStoryReviewsV282State')
end=body.find('class ',start+10)
if start<0 or end<0:
    raise SystemExit('v313 founder/review state bounds unavailable')
section=body[start:end]
old="Timer.periodic(const Duration(seconds:20),(_){if(mounted&&!submitting)setState(()=>request=_callRpc('bridgepoint_brand_profile_v212',const {}));});"
new="Timer.periodic(const Duration(seconds:8),(_){if(mounted&&!submitting)setState(()=>request=_callRpc('bridgepoint_brand_profile_v212',const {}));});"
if section.count(old)!=1:
    raise SystemExit(f'v313 founder/review refresh anchor {section.count(old)}')
section=section.replace(old,new,1)
body=body[:start]+section+body[end:]
body += "\nconst String _bridgePointBrandLiveRefreshV313='bridgepoint-v313-brand-live-refresh | owner profile and approved review changes refresh every 8 seconds while About is open | explicit save/submit refresh immediately';\n"
path.write_text(body,encoding='utf-8')
print('Applied v313 near-live founder profile and review refresh.')
