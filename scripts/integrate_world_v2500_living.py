from pathlib import Path

js_path=Path('web/bridgepoint-3d-world/world-v2500.js')
html_path=Path('web/bridgepoint-3d-world/index.html')
js=js_path.read_text(encoding='utf-8')
html=html_path.read_text(encoding='utf-8')

def swap(text,old,new,label):
    if new in text:
        print('already fixed',label);return text
    c=text.count(old)
    if c!=1: raise SystemExit(f'{label}: expected 1 anchor, found {c}')
    print('fixed',label);return text.replace(old,new,1)

js=swap(js,
"import { createStructureLab } from './world-v2500-inspector.js';",
"import { createStructureLab } from './world-v2500-inspector.js';\nimport { enableBridgePointTerrain } from './world-v2500-terrain.js';\nimport { initLivingWorld } from './world-v2500-living.js';",
'world module imports')
js=swap(js,
"  lab:null, session:null\n};",
"  lab:null, session:null, terrain:null, living:null\n};",
'living state')
js=swap(js,
"  await Promise.allSettled([refreshRadar(),streamViewport(true),loadWeather(true)]);\n  if(!session)setStatus(`World V${VERSION} ready with public context. Sign in on BridgePoint to stream protected property intelligence.`,'warn');\n  else setStatus(`World V${VERSION} ready · public-only context · BridgePoint property truth · ${tier} device profile.`,'ok');",
"  await Promise.allSettled([refreshRadar(),streamViewport(true),loadWeather(true)]);\n  if(session){\n    try{state.terrain=await enableBridgePointTerrain({viewer,supabase,tier});document.getElementById('terrainStatus').textContent=state.terrain?.enabled?'USGS 3DEP terrain active':'Terrain fallback active';document.getElementById('terrainStatus').classList.toggle('active',Boolean(state.terrain?.enabled))}catch(e){console.warn('3DEP terrain unavailable',e);document.getElementById('terrainStatus').textContent='Terrain fallback active'}\n    try{state.living=await initLivingWorld({viewer,supabase,tier,getViewRectangle:viewRectangle,getCameraHeight:cameraHeight,getFocus:()=>state.focus||focusPoint(),getSelectedCenter:()=>{const b=state.currentCard?.building;if(!b)return null;const p=buildingResolvePoint(b);return p?[p[0],p[1],finite(b.ground_elevation_m??b.elevation_m)||0]:null},getPrimaryCounts:()=>({roads:sources.roads.entities.values.length,rails:sources.rails.entities.values.length,water:sources.water.entities.values.length})})}catch(e){console.warn('living public context unavailable',e)}\n  }\n  if(!session)setStatus(`World V${VERSION} ready with public context. Sign in on BridgePoint to stream protected property intelligence.`,'warn');\n  else setStatus(`World V${VERSION} ready · BridgePoint truth + governed public living context · ${tier} device profile.`,'ok');",
'boot terrain and living world')
js=swap(js,
"selectedProperty:state.currentCard?.model?.property_id||null,publicOnly:true}}",
"selectedProperty:state.currentCard?.model?.property_id||null,terrain:state.terrain?.enabled||false,living:state.living?.state||null,publicOnly:true}}",
'world diagnostics')

html=swap(html,
"      <button data-layer=\"vegetation\">Vegetation</button><button data-layer=\"labels\">Labels</button>\n    </div>",
"      <button data-layer=\"vegetation\">Vegetation</button><button data-layer=\"labels\">Labels</button>\n      <button id=\"cloudsButton\">Satellite clouds</button><button id=\"livingButton\">Living public context</button>\n      <button id=\"flyButton\">Cinematic fly</button><button id=\"terrainStatus\" disabled>Terrain starting…</button>\n    </div>",
'living controls')
html=swap(html,
"    <div class=\"truthNote\">Radar starts on. Property circles and close-up physical effects start off.",
"    <div class=\"truthNote\">Satellite clouds and living public context start on when the signed-in package allows their governed BridgePoint endpoints. Cinematic fly is user-triggered. Radar starts on. Property circles and close-up physical effects start off.",
'living truth note')

js_path.write_text(js,encoding='utf-8')
html_path.write_text(html,encoding='utf-8')
print('World V2500 terrain + living context integrated.')
