from pathlib import Path

js_path = Path('web/bridgepoint-3d-world/world-v2500.js')
css_path = Path('web/bridgepoint-3d-world/world-v2500.css')
js = js_path.read_text(encoding='utf-8')
css = css_path.read_text(encoding='utf-8')


def swap(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'already fixed {label}')
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one old anchor, found {count}')
    print(f'fixed {label}')
    return text.replace(old, new, 1)


js = swap(js, '  maximumLevel: 16,', '  maximumLevel: 23,', 'USGS imagery LOD')
js = swap(js,
    "  viewportKey:'', viewportBusy:false, viewportSeq:0, selectedEntity:null,",
    "  viewportKey:'', viewportBusy:false, viewportPending:false, viewportSeq:0, selectedEntity:null,",
    'viewport pending state')
js = swap(js,
    "  radar:true, radarLayer:null, radarTime:null, weatherBusy:false, weatherSeq:0, weatherLast:0,",
    "  radar:true, radarLayer:null, radarTime:null, weatherBusy:false, weatherPending:false, weatherSeq:0, weatherLast:0,",
    'weather pending state')
js = swap(js,
    "function clearPropertyGeometry(){for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','propertyPoints','labels'])sources[k].entities.removeAll();state.viewportKey='';viewer.scene.requestRender()}",
    "function clearPropertyGeometry({resetKey=true}={}){for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','propertyPoints','labels'])sources[k].entities.removeAll();if(resetKey)state.viewportKey='';viewer.scene.requestRender()}",
    'viewport cache primitive')
js = swap(js,
    "function renderViewport(data={}){\n  clearPropertyGeometry();let labels=0;",
    "function renderViewport(data={}){\n  clearPropertyGeometry({resetKey:false});let labels=0;",
    'render keeps viewport key')
js = swap(js,
    "  guardCountry();if(state.viewportBusy)return;const c=state.focus?.country;",
    "  guardCountry();if(state.viewportBusy){state.viewportPending=true;state.viewportSeq++;return}const c=state.focus?.country;",
    'queue latest viewport')
js = swap(js,
    "  catch(e){console.error(e);setStatus(`BridgePoint property stream unavailable: ${e?.message||e}`,'bad')}finally{state.viewportBusy=false}\n}",
    "  catch(e){console.error(e);setStatus(`BridgePoint property stream unavailable: ${e?.message||e}`,'bad')}finally{state.viewportBusy=false;if(state.viewportPending){state.viewportPending=false;queueMicrotask(()=>streamViewport(true))}}\n}",
    'replay latest viewport')
js = swap(js,
    "async function loadWeather(force=false){const now=Date.now();if(state.weatherBusy||(!force&&now-state.weatherLast<1800))return;state.weatherBusy=true;state.weatherLast=now;const seq=++state.weatherSeq;const v=viewRectangle();",
    "async function loadWeather(force=false){const now=Date.now();if(state.weatherBusy){state.weatherPending=true;state.weatherSeq++;return}if(!force&&now-state.weatherLast<1800)return;state.weatherBusy=true;state.weatherLast=now;const seq=++state.weatherSeq;const v=viewRectangle();",
    'queue latest weather')
js = swap(js,
    "  catch(e){console.warn(e);setStatus(`Weather context refresh failed without resetting the map: ${e?.message||e}`,'warn')}finally{state.weatherBusy=false}}",
    "  catch(e){console.warn(e);setStatus(`Weather context refresh failed without resetting the map: ${e?.message||e}`,'warn')}finally{state.weatherBusy=false;if(state.weatherPending){state.weatherPending=false;queueMicrotask(()=>loadWeather(true))}}}",
    'replay latest weather')
js = swap(js,
    "function currentPrecip(rows,layers){const text=[...rows,...layers].slice(0,250).map(r=>JSON.stringify(r)).join(' ').toLowerCase();if(text.includes('hail'))return'hail';if(text.includes('snow')||text.includes('winter precipitation'))return'snow';if(text.includes('rain')||text.includes('precipitation'))return'rain';return''}\nfunction applyAtmosphere(rows,layers){const all=[...rows,...layers];let visibility=null,cloud=null,storm=0;for(const r of all){visibility??=finite(r.visibility_miles??r.visibilityMiles);cloud??=finite(r.cloud_coverage??r.cloudCoverage);const kind=hazardKind(r);if(['tornado','hurricane','wind','hail'].includes(kind))storm=Math.max(storm,observed(r)?.8:.35)}const vis=visibility??10;viewer.scene.fog.density=(vis<1?.0028:vis<3?.0011:vis<6?.00045:.00017)*(1+storm*.5);viewer.scene.fog.minimumBrightness=clamp(.25-(cloud??0)/180-storm*.12,.03,.3);weatherFx.className='';if(state.fx){const precip=currentPrecip(rows,layers);if(precip)weatherFx.classList.add(`wx-${precip}`)}viewer.scene.requestRender()}",
    "function currentPrecip(rows,layers){const text=[...rows,...layers].slice(0,250).map(r=>JSON.stringify(r)).join(' ').toLowerCase();if(text.includes('hail'))return'hail';if(text.includes('snow')||text.includes('winter precipitation'))return'snow';if(text.includes('rain')||text.includes('precipitation'))return'rain';return''}\nfunction rowAffectsFocus(row={}){const f=state.focus||focusPoint();if(!f)return false;const g=rowGeometry(row);if(g&&pointInGeometry(f.lon,f.lat,g))return true;const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat===null||lon===null)return false;const dy=(lat-f.lat)*111.32,dx=(lon-f.lon)*111.32*Math.cos(f.lat*Math.PI/180);return Math.hypot(dx,dy)<=25}\nfunction applyAtmosphere(rows,layers){const localRows=rows.filter(rowAffectsFocus),localLayers=layers.filter(rowAffectsFocus),all=[...localRows,...localLayers];let visibility=null,cloud=null,storm=0;for(const r of all){visibility??=finite(r.visibility_miles??r.visibilityMiles);cloud??=finite(r.cloud_coverage??r.cloudCoverage);const kind=hazardKind(r);if(['tornado','hurricane','wind','hail'].includes(kind))storm=Math.max(storm,observed(r)?.8:.35)}const vis=visibility??10;viewer.scene.fog.density=(vis<1?.0028:vis<3?.0011:vis<6?.00045:.00017)*(1+storm*.5);viewer.scene.fog.minimumBrightness=clamp(.25-(cloud??0)/180-storm*.12,.03,.3);weatherFx.className='';if(state.fx){const precip=currentPrecip(localRows,localLayers);if(precip)weatherFx.classList.add(`wx-${precip}`)}viewer.scene.requestRender()}",
    'camera-local weather FX')
js = swap(js,
    "function eventCenter(row){const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat!==null&&lon!==null)return[lon,lat];const ring=outerRings(rowGeometry(row))[0];return ring?centerOfRing(ring):null}",
    "function eventCenter(row,{allowGeometry=true}={}){const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat!==null&&lon!==null)return[lon,lat];if(!allowGeometry)return null;const ring=outerRings(rowGeometry(row))[0];return ring?centerOfRing(ring):null}",
    'event center truth')
js = swap(js, "const c=eventCenter(row);if(!c)continue;", "const c=eventCenter(row,{allowGeometry:false});if(!c)continue;", 'fire explicit point only')
js = swap(js,
    "material:Cesium.Color.fromCssColorString(color).withAlpha(.64),outline:true,outlineColor:Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.5)",
    "material:Cesium.Color.fromCssColorString(color).withAlpha(.96),outline:true,outlineColor:Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.62)",
    'solid building massing')
js = swap(js,
    "state.selectedEntity.polygon.material=Cesium.Color.fromCssColorString(old).withAlpha(.64);state.selectedEntity.polygon.outlineColor=Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.5)",
    "state.selectedEntity.polygon.material=Cesium.Color.fromCssColorString(old).withAlpha(.96);state.selectedEntity.polygon.outlineColor=Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.62)",
    'solid building restore')
js = swap(js,
    "entity.polygon.material=Cesium.Color.fromCssColorString(c).withAlpha(.82);entity.polygon.outlineColor=Cesium.Color.WHITE.withAlpha(.95)",
    "entity.polygon.material=Cesium.Color.fromCssColorString(c).withAlpha(1);entity.polygon.outlineColor=Cesium.Color.WHITE.withAlpha(.98)",
    'solid selected building')

css = swap(css, 'body{touch-action:none}', 'body{touch-action:manipulation}', 'body touch behavior')
css = swap(css, '#propertyCard{position:fixed;', '#propertyCard{touch-action:pan-y;overscroll-behavior:contain;position:fixed;', 'property card touch scroll')
css = swap(css, '#layerPanel{position:fixed;', '#layerPanel{touch-action:pan-y;overscroll-behavior:contain;position:fixed;', 'layer panel touch scroll')

js_path.write_text(js, encoding='utf-8')
css_path.write_text(css, encoding='utf-8')
print('World V2500 hardening pass complete.')
