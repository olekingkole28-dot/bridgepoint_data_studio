const VERSION=2502;

const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
const finite=(v)=>Number.isFinite(Number(v))?Number(v):null;
const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const now=()=>Cesium.JulianDate.now();

function stableHash(value){
  const s=String(value??'bridgepoint');
  let h=2166136261;
  for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}
  return h>>>0;
}
function valueOf(p){try{return p?.getValue?p.getValue(now()):p}catch(_){return p}}
function hexColor(hex){return Cesium.Color.fromCssColorString(hex)}
function cssHex(c){
  const ch=(v)=>Math.round(clamp(v,0,1)*255).toString(16).padStart(2,'0');
  return '#'+ch(c.red)+ch(c.green)+ch(c.blue);
}
function vary(baseHex,seed,amount=.085){
  const base=hexColor(baseHex),h=stableHash(seed);
  const d=(shift)=>((((h>>>shift)&31)-15)/15)*amount;
  return new Cesium.Color(clamp(base.red+d(0),.08,.96),clamp(base.green+d(5),.08,.96),clamp(base.blue+d(10),.08,.96),1);
}
function textOf(row){
  return [row?.facade_material,row?.building_material,row?.material,row?.building,row?.building_type,row?.class,row?.classification_label,row?.category,row?.subclass].filter(Boolean).join(' ').toLowerCase();
}
function facadeBase(row={}){
  const t=textOf(row);
  if(/glass|curtain/.test(t))return'#647f8d';
  if(/brick/.test(t))return'#8c6255';
  if(/stone|limestone/.test(t))return'#918a7c';
  if(/metal|steel/.test(t))return'#7f898c';
  if(/concrete/.test(t))return'#8b8d89';
  if(/wood/.test(t))return'#88745f';
  if(/stucco|plaster/.test(t))return'#a39a8c';
  if(/church|religious/.test(t))return'#9b907b';
  if(/industrial|warehouse/.test(t))return'#747b79';
  if(/hospital|school|civic|government/.test(t))return'#9b9588';
  if(/office|commercial/.test(t))return'#7e8b91';
  if(/apartment|residential|house/.test(t))return'#8e8178';
  const palette=['#7d8588','#8d8178','#8c7568','#8d887d','#707d83','#988c7c','#806f65','#88918f','#938679','#7c7773','#8b8a83','#7a858b'];
  return palette[stableHash(row?.building_id??row?.property_id??row?.source_key)%palette.length];
}
function roofBase(row={}){
  const t=String(row?.roof_material??row?.roof_type??row?.roof_shape??'').toLowerCase();
  if(t.includes('metal'))return'#9da8aa';
  if(t.includes('tile'))return'#9e6e5a';
  if(t.includes('slate'))return'#596872';
  if(t.includes('shingle'))return'#66615d';
  if(t.includes('concrete'))return'#909591';
  if(t.includes('glass'))return'#78939b';
  const palette=['#72787a','#8b8177','#666d70','#8c7567','#7b7e79','#69757a','#8d8a82','#786c64','#878f8c','#73706e'];
  return palette[stableHash(row?.building_id??row?.property_id??row?.id??row?.source_key)%palette.length];
}
function source(name){
  const a=world?.viewer?.dataSources?.getByName?.(name);
  return a?.[0]||null;
}
function buildingKey(e,row,index){
  return row?.building_id??row?.property_id??row?.source_id??row?.source_key??e?.id??index;
}
function tuneGlobe(){
  const viewer=world?.viewer;if(!viewer)return;
  const s=world.state||{},low=s.tier==='LOW',medium=s.tier==='MEDIUM';
  const target=low?.86:medium?.94:1;
  if(Number(viewer.resolutionScale||0)<target)viewer.resolutionScale=target;
  const globe=viewer.scene?.globe;
  if(globe){
    globe.maximumScreenSpaceError=low?1.55:medium?1.25:1.0;
    globe.depthTestAgainstTerrain=true;
    if('preloadAncestors'in globe)globe.preloadAncestors=true;
    if('preloadSiblings'in globe)globe.preloadSiblings=true;
    if('tileCacheSize'in globe)globe.tileCacheSize=low?220:medium?360:520;
    if('loadingDescendantLimit'in globe)globe.loadingDescendantLimit=40;
  }
  try{viewer.scene.postProcessStages.fxaa.enabled=true}catch(_){}
}
function roofCapExists(roofs,id){
  return roofs?.entities?.getById?.(id)||null;
}
function styleBuildings(){
  const buildings=source('bp-buildings'),roofs=source('bp-roofs');if(!buildings||!roofs)return{buildings:0,caps:0};
  const s=world.state||{},low=s.tier==='LOW',height=finite(s.cameraHeightMeters)||1e9;
  const capLimit=low?1350:height<2500?3000:2100;
  let styled=0,caps=0;
  const values=buildings.entities.values||[];
  for(let i=0;i<values.length;i++){
    const e=values[i],p=e?.polygon,row=e?.bridgepoint||{};if(!p)continue;
    const key=buildingKey(e,row,i),seed=stableHash(key);
    const facade=vary(facadeBase(row),seed,.095);
    p.material=facade;
    p.outline=true;
    p.outlineColor=vary('#dbe2de',seed>>>3,.045).withAlpha(low?.34:.48);
    try{p.shadows=low?Cesium.ShadowMode.DISABLED:Cesium.ShadowMode.ENABLED}catch(_){}
    e.bridgepoint={...row,__displayColor:cssHex(facade),__visualStyleVersion:VERSION,__visualSeed:seed};
    styled++;
    if(caps>=capLimit||height>26000)continue;
    const top=finite(valueOf(p.extrudedHeight)),base=finite(valueOf(p.height))||0,hierarchy=valueOf(p.hierarchy);
    if(top===null||top<=base+.8||!hierarchy?.positions?.length)continue;
    const capId='bp-v2502-roofcap-'+String(e.id);
    if(roofCapExists(roofs,capId))continue;
    const roof=vary(roofBase(row),seed^0x9e3779b9,.075);
    const cap=roofs.entities.add({id:capId,polygon:{
      hierarchy,
      height:top+.08,
      material:roof.withAlpha(.985),
      outline:true,
      outlineColor:vary('#e1e1d9',seed>>>5,.035).withAlpha(low?.42:.62),
      distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,26000)
    }});
    cap.bridgepoint={...row,visual_roof_cap:true,exact_roof_geometry:false,__visualStyleVersion:VERSION};
    caps++;
  }
  for(const e of roofs.entities.values||[]){
    if(String(e.id||'').startsWith('bp-v2502-roofcap-'))continue;
    const row=e.bridgepoint||{},seed=stableHash(row?.building_id??row?.property_id??row?.id??e.id);
    if(e.polygon){
      e.polygon.material=vary(roofBase(row),seed,.065).withAlpha(.94);
      e.polygon.outlineColor=vary('#eceae1',seed>>>4,.03).withAlpha(.66);
    }
  }
  return{buildings:styled,caps};
}
const spriteCache=new Map();
function foliageSprite(seed,bush=false){
  const variant=stableHash(seed)%12,key=(bush?'b':'t')+variant;if(spriteCache.has(key))return spriteCache.get(key);
  const c=document.createElement('canvas');c.width=48;c.height=64;const x=c.getContext('2d');
  x.clearRect(0,0,48,64);
  if(!bush){x.fillStyle='#5a4330';x.fillRect(21,37,6,23)}
  const greens=['#3e7749','#4b8653','#356d42','#5b8c59','#477b4a','#2f6840','#5a8050','#3f8351'];
  x.fillStyle=greens[variant%greens.length];
  if(bush){
    x.beginPath();x.ellipse(24,47,16,10,0,0,Math.PI*2);x.fill();
    x.fillStyle=greens[(variant+3)%greens.length];x.beginPath();x.ellipse(16,43,9,8,0,0,Math.PI*2);x.fill();x.beginPath();x.ellipse(31,42,10,9,0,0,Math.PI*2);x.fill();
  }else{
    const shift=(variant%3)-1;
    for(const [cx,cy,rx,ry] of [[24,20,14,15],[14+shift,28,11,12],[34-shift,29,11,13],[24,33,15,13]]){x.beginPath();x.ellipse(cx,cy,rx,ry,0,0,Math.PI*2);x.fill()}
    x.fillStyle='rgba(210,235,195,.18)';x.beginPath();x.ellipse(18,18,6,5,0,0,Math.PI*2);x.fill();
  }
  spriteCache.set(key,c);return c;
}
function styleVegetation(){
  const ds=source('bp-vegetation');if(!ds)return 0;
  const s=world.state||{},limit=s.tier==='LOW'?650:s.tier==='MEDIUM'?1100:1800;
  let n=0;
  for(const [i,e] of (ds.entities.values||[]).entries()){
    if(n>=limit)break;
    const row=e.bridgepoint||{},t=JSON.stringify(row).toLowerCase(),bush=/bush|shrub|hedge/.test(t),seed=stableHash(row?.id??row?.source_id??e.id??i);
    e.billboard=new Cesium.BillboardGraphics({
      image:foliageSprite(seed,bush),width:bush?18:26,height:bush?15:38,
      verticalOrigin:Cesium.VerticalOrigin.BOTTOM,
      distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,bush?2500:6500),
      scaleByDistance:new Cesium.NearFarScalar(40,1.15,bush?2500:6500,.45)
    });
    if(e.point)e.point.show=false;n++;
  }
  return n;
}
function styleRoads(){
  const ds=source('bp-roads');if(!ds)return{roads:0,bridges:0,walkways:0};
  let roads=0,bridges=0,walkways=0;
  for(const e of ds.entities.values||[]){
    const row=e.bridgepoint||{},t=JSON.stringify(row).toLowerCase(),p=e.polyline;if(!p)continue;roads++;
    if(/sidewalk|pedestrian|footway|walkway|path|steps/.test(t)){
      p.width=2.5;p.material=hexColor('#bbb9ad').withAlpha(.92);walkways++;
    }else if(/bridge|viaduct|overpass/.test(t)){
      p.width=4.2;
      p.material=new Cesium.PolylineGlowMaterialProperty({color:hexColor('#c7c7bc').withAlpha(.94),glowPower:.12,taperPower:.7});
      bridges++;
    }else if(/motorway|interstate|trunk|primary|highway/.test(t)){
      p.width=3.1;p.material=hexColor('#d6d1c4').withAlpha(.9);
    }else{
      p.width=2.25;p.material=hexColor('#c8c4b8').withAlpha(.86);
    }
  }
  return{roads,bridges,walkways};
}
function styleSurfaces(){
  const parking=source('bp-parking');for(const e of parking?.entities?.values||[]){if(e.polygon){e.polygon.material=hexColor('#656660').withAlpha(.54);e.polygon.outlineColor=hexColor('#aaa99f').withAlpha(.34)}}
  const water=source('bp-water');for(const e of water?.entities?.values||[]){if(e.polygon){e.polygon.material=hexColor('#277f9f').withAlpha(.38);e.polygon.outlineColor=hexColor('#70bfd3').withAlpha(.38)}}
}
function postProcess(){
  tuneGlobe();
  const b=styleBuildings(),v=styleVegetation(),r=styleRoads();styleSurfaces();
  world.viewer.scene.requestRender();
  state.last={at:new Date().toISOString(),...b,vegetation:v,...r,cameraHeight:world.state?.cameraHeightMeters??null};
  return state.last;
}
const state={ready:false,last:null,retries:0,mobile:false};
let world=null,moveToken=0,settleTimer=0,tileTimer=0;
function scheduleSettledRetry(){
  const token=++moveToken;clearTimeout(settleTimer);
  postProcess();
  const s=world.state||{};if(!s.mobile||finite(s.cameraHeightMeters)>45000)return;
  settleTimer=setTimeout(async()=>{
    if(token!==moveToken)return;
    try{await world.streamViewport(true);state.retries++}catch(e){console.warn('V2502 settled detail retry',e)}
    if(token===moveToken)postProcess();
  },s.tier==='LOW'?950:700);
}
function bind(){
  if(state.ready)return;
  world=window.BridgePointWorldV2500;if(!world?.viewer){setTimeout(bind,90);return}
  state.ready=true;state.mobile=Boolean(world.state?.mobile);tuneGlobe();
  world.viewer.camera.moveEnd.addEventListener(scheduleSettledRetry);
  try{world.viewer.scene.globe.tileLoadProgressEvent.addEventListener((left)=>{if(left!==0)return;clearTimeout(tileTimer);tileTimer=setTimeout(postProcess,140)})}catch(_){}
  document.addEventListener('visibilitychange',()=>{if(!document.hidden){postProcess();scheduleSettledRetry()}},{passive:true});
  window.addEventListener('pageshow',()=>setTimeout(()=>{postProcess();scheduleSettledRetry()},120),{passive:true});
  for(const ms of [120,500,1300,2600])setTimeout(postProcess,ms);
  console.info('BridgePoint Visual Fidelity V2502 ready',world.state?.tier||'UNKNOWN');
}
window.BridgePointVisualFidelityV2502={version:VERSION,refresh:()=>{if(world)return postProcess();bind();return null},get state(){return{...state,deviceTier:world?.state?.tier||null,resolutionScale:world?.viewer?.resolutionScale||null}}};
bind();
