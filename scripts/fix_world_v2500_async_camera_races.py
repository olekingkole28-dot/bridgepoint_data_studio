from pathlib import Path

p=Path('web/bridgepoint-3d-world/world-v2500.js')
s=p.read_text(encoding='utf-8')
old="""async function startAtUser(){
  cancelCameraJourney();viewer.camera.setView({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0}});if(!navigator.geolocation)return;
  await new Promise(resolve=>navigator.geolocation.getCurrentPosition(async p=>{const lon=p.coords.longitude,lat=p.coords.latitude,c=countryAt(lon,lat);if(!c||unlocked(c))await cinematicFlyTo(lon,lat,13000);resolve()},()=>resolve(),{enableHighAccuracy:true,timeout:6500,maximumAge:120000}))
}
async function searchPlace(q){q=q.trim();if(!q)return;setStatus('Searching BridgePoint…');try{const data=await rpcTimed('bridgepoint_universal_search_context_v244',{p_query:q,p_limit:8},8000);const rows=Array.isArray(data)?data:(data?.results||data?.items||[]);const first=rows.find(r=>finite(r.latitude)!==null&&finite(r.longitude??r.lng)!==null);if(first){const lat=finite(first.latitude),lon=finite(first.longitude??first.lng);await cinematicFlyTo(lon,lat,1800);setStatus(`BridgePoint search centered on ${first.full_address||first.title||q}.`,'ok')}else setStatus(`BridgePoint search returned context for “${q}” but no map coordinate.`, 'warn')}catch(e){setStatus(`Search unavailable: ${e?.message||e}`,'bad')}}"""
new="""async function startAtUser(){
  cancelCameraJourney();const requestToken=state.cameraJourney;viewer.camera.setView({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0}});if(!navigator.geolocation)return;
  await new Promise(resolve=>navigator.geolocation.getCurrentPosition(async p=>{if(requestToken!==state.cameraJourney)return resolve();const lon=p.coords.longitude,lat=p.coords.latitude,c=countryAt(lon,lat);if(!c||unlocked(c))await cinematicFlyTo(lon,lat,13000);resolve()},()=>resolve(),{enableHighAccuracy:true,timeout:6500,maximumAge:120000}))
}
async function searchPlace(q){q=q.trim();if(!q)return;cancelCameraJourney();const requestToken=state.cameraJourney;setStatus('Searching BridgePoint…');try{const data=await rpcTimed('bridgepoint_universal_search_context_v244',{p_query:q,p_limit:8},8000);if(requestToken!==state.cameraJourney){setStatus('Search result ready · camera move canceled because you navigated manually.','ok');return}const rows=Array.isArray(data)?data:(data?.results||data?.items||[]);const first=rows.find(r=>finite(r.latitude)!==null&&finite(r.longitude??r.lng)!==null);if(first){const lat=finite(first.latitude),lon=finite(first.longitude??first.lng);await cinematicFlyTo(lon,lat,1800);setStatus(`BridgePoint search centered on ${first.full_address||first.title||q}.`,'ok')}else setStatus(`BridgePoint search returned context for “${q}” but no map coordinate.`, 'warn')}catch(e){if(requestToken===state.cameraJourney)setStatus(`Search unavailable: ${e?.message||e}`,'bad')}}"""
if new in s:
    print('Async camera race guards already applied.')
elif old in s:
    p.write_text(s.replace(old,new,1),encoding='utf-8')
    print('Async camera race guards applied.')
else:
    raise SystemExit('Expected current V2500 camera block not found; refusing blind edit.')
