import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const JSON_HEADERS={
  "content-type":"application/json",
  "cache-control":"public, max-age=20",
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"authorization, apikey, content-type, x-bridgepoint-cron"
};
const SUPABASE_URL=Deno.env.get("SUPABASE_URL")!;
const SERVICE=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SERVICE_HEADERS={
  "content-type":"application/json",
  "apikey":SERVICE,
  "authorization":"Bearer "+SERVICE
};

async function rpc(name:string,body:any={}){
  const r=await fetch(SUPABASE_URL+"/rest/v1/rpc/"+name,{
    method:"POST",headers:SERVICE_HEADERS,body:JSON.stringify(body)
  });
  const txt=await r.text();
  if(!r.ok)throw new Error(name+" "+r.status+" "+txt.slice(0,240));
  try{return JSON.parse(txt)}catch{return txt}
}
async function quota(sessionKey:string,tool="GLOBAL"){
  return await rpc("bridgepoint_intelligence_demo_quota_v5300",{
    p_session_key:sessionKey,p_tool_key:tool,p_increment:1
  });
}
async function fetchJson(url:string,timeout=9000){
  const ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),timeout);
  try{
    const r=await fetch(url,{
      headers:{"user-agent":"BridgePoint-Intelligence/5503 official-public-source-adapter"},
      signal:ctl.signal
    });
    if(!r.ok)throw new Error("source "+r.status+" "+url);
    return await r.json();
  }finally{clearTimeout(tm)}
}
function iso(v:any,fallback=new Date().toISOString()){
  if(v===null||v===undefined||v==="")return fallback;
  const d=typeof v==="number"?new Date(v):new Date(String(v));
  return Number.isFinite(d.getTime())?d.toISOString():fallback;
}
function pointCoords(v:any){
  if(!Array.isArray(v)||v.length<2)return null;
  const lon=Number(v[0]),lat=Number(v[1]);
  return Number.isFinite(lon)&&Number.isFinite(lat)&&lat>=-90&&lat<=90&&lon>=-180&&lon<=180
    ?{lon,lat}:null;
}
function slimEarthquake(f:any){
  const p=f?.properties||{},c=f?.geometry?.coordinates||[];
  return {type:"Feature",geometry:{type:"Point",coordinates:[Number(c[0]),Number(c[1]),Number(c[2]||0)]},properties:{
    id:String(f?.id||""),mag:Number(p.mag||0),place:String(p.place||""),time:p.time?new Date(p.time).toISOString():null,
    updated:p.updated?new Date(p.updated).toISOString():null,url:String(p.url||""),status:String(p.status||""),tsunami:Number(p.tsunami||0),
    source:"USGS Earthquake Hazards Program",truth:"OBSERVED_EVENT_CATALOG"
  }}
}
function earthquakeEntities(d:any){
  const expires=new Date(Date.now()+48*3600_000).toISOString();
  return (d?.features||[]).slice(0,1600).flatMap((f:any)=>{
    const c=pointCoords(f?.geometry?.coordinates),p=f?.properties||{};
    if(!c||!f?.id)return [];
    return [{
      entity_key:String(f.id),entity_type:"EARTHQUAKE",display_name:String(p.place||"Earthquake"),
      lat:c.lat,lon:c.lon,observed_at:iso(p.time),expires_at:expires,
      metadata:{
        mag:Number(p.mag||0),depth_km:Number(f?.geometry?.coordinates?.[2]||0),
        place:String(p.place||""),url:String(p.url||""),status:String(p.status||""),
        tsunami:Number(p.tsunami||0),source_url:"https://earthquake.usgs.gov/earthquakes/feed/"
      }
    }];
  });
}
function slimVolcano(f:any){
  const p=f?.properties||{},c=f?.geometry?.coordinates||[];
  return {type:"Feature",geometry:{type:"Point",coordinates:[Number(c[0]),Number(c[1]),Number(c[2]||0)]},properties:{
    id:String(p.vnum||p.id||p.volcanoCd||""),name:String(p.vname||p.name||p.volcano_name||"Volcano"),
    status:String(p.color_code||p.colorCode||p.status||""),alert_level:String(p.alert_level||p.alertLevel||""),
    updated:String(p.updated||p.date||""),source:"USGS Volcano Hazards Program",truth:"OFFICIAL_STATUS"
  }}
}
function volcanoEntities(d:any){
  const raw=Array.isArray(d?.features)?d.features:Array.isArray(d)?d:[];
  const observed=new Date().toISOString(),expires=new Date(Date.now()+12*3600_000).toISOString();
  return raw.slice(0,1200).flatMap((f:any,i:number)=>{
    const c=pointCoords(f?.geometry?.coordinates),p=f?.properties||{};
    if(!c)return [];
    const id=String(p.vnum||p.id||p.volcanoCd||p.vname||p.name||("volcano-"+i));
    return [{
      entity_key:id,entity_type:"VOLCANO_STATUS",display_name:String(p.vname||p.name||p.volcano_name||"Volcano"),
      lat:c.lat,lon:c.lon,observed_at:observed,expires_at:expires,
      metadata:{
        status:String(p.color_code||p.colorCode||p.status||""),
        alert_level:String(p.alert_level||p.alertLevel||""),
        updated:String(p.updated||p.date||""),scope:"US_STATUS",
        source_url:"https://volcanoes.usgs.gov/vsc/api/volcanoApi/"
      }
    }];
  });
}
function eonetEntities(d:any){
  const events=Array.isArray(d?.events)?d.events:[];
  const expires=new Date(Date.now()+60*60_000).toISOString();
  return events.slice(0,700).flatMap((e:any)=>{
    const geos=Array.isArray(e?.geometry)?e.geometry:[];
    const g=[...geos].reverse().find((x:any)=>String(x?.type||"").toLowerCase()==="point"&&pointCoords(x?.coordinates));
    const c=g?pointCoords(g.coordinates):null;
    if(!c||!e?.id)return [];
    const categories=(e?.categories||[]).map((x:any)=>({id:x?.id,title:x?.title})).slice(0,8);
    return [{
      entity_key:String(e.id),entity_type:String(categories?.[0]?.id||"NATURAL_EVENT").toUpperCase(),
      display_name:String(e.title||"Natural event"),lat:c.lat,lon:c.lon,
      observed_at:iso(g?.date),expires_at:expires,
      metadata:{
        description:String(e.description||""),categories,sources:(e?.sources||[]).slice(0,8),
        link:String(e.link||""),closed:e.closed||null,
        magnitudeValue:e.magnitudeValue??null,magnitudeUnit:e.magnitudeUnit??null,
        source_url:"https://eonet.gsfc.nasa.gov/api/v3/events"
      }
    }];
  });
}

function swpcSeverity(text:string,kp?:number){
  if(Number.isFinite(kp)){
    if((kp as number)>=9)return 5;
    if((kp as number)>=8)return 4;
    if((kp as number)>=7)return 3;
    if((kp as number)>=6)return 2;
    if((kp as number)>=5)return 1;
  }
  const t=String(text||"").toUpperCase();
  const m=t.match(/\b[GRS]([1-5])\b/);
  return m?Math.max(0,Math.min(5,Number(m[1]))):0;
}
function swpcSignals(alerts:any,kp:any){
  const out:any[]=[];
  const expires=new Date(Date.now()+45*60_000).toISOString();
  const a=Array.isArray(alerts)?alerts:[];
  a.slice(0,120).forEach((x:any,i:number)=>{
    const msg=String(x?.message||x?.summary||x?.description||"");
    const observed=iso(x?.issue_datetime||x?.issueTime||x?.time_tag||x?.time);
    const key=String(x?.product_id||x?.productId||x?.id||("alert-"+observed+"-"+i));
    out.push({
      signal_key:"alert:"+key,
      signal_type:"SWPC_ALERT",
      display_name:String(x?.product_id||x?.productId||"NOAA SWPC Alert"),
      severity:swpcSeverity(msg),
      observed_at:observed,
      expires_at:expires,
      payload:{
        product_id:x?.product_id??x?.productId??null,
        issue_datetime:x?.issue_datetime??x?.issueTime??null,
        message:msg.slice(0,6000),
        source_url:"https://services.swpc.noaa.gov/products/alerts.json"
      }
    });
  });

  if(Array.isArray(kp)&&kp.length>1){
    const rows=Array.isArray(kp[0])?kp.slice(1):kp;
    const last=[...rows].reverse().find((r:any)=>Array.isArray(r)&&r.length>=2);
    if(last){
      const time=String(last[0]||new Date().toISOString());
      const kval=Number(last[1]);
      out.push({
        signal_key:"kp:"+time,
        signal_type:"PLANETARY_K_INDEX",
        display_name:"NOAA Planetary K-index",
        severity:swpcSeverity("",kval),
        observed_at:iso(time),
        expires_at:expires,
        payload:{
          kp:Number.isFinite(kval)?kval:null,
          row:last.slice(0,8),
          source_url:"https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"
        }
      });
    }
  }
  return out;
}

function plateBoundaryFeatures(d:any,featureClass:string){
  const raw=Array.isArray(d?.features)?d.features:[];
  return raw.slice(0,2000).flatMap((f:any,i:number)=>{
    const g=f?.geometry;
    if(!g||typeof g!=="object"||!String(g?.type||"").includes("Line"))return [];
    const p=f?.properties||{};
    const oid=String(p.OBJECTID??p.objectid??p.FID??i);
    const name=String(p.NAME??p.name??p.LABEL??featureClass);
    return [{
      feature_key:featureClass.toLowerCase()+":"+oid,
      feature_class:featureClass,
      display_name:name,
      geometry:g,
      properties:{
        name:String(p.NAME??p.name??""),
        boundary_type:String(p.LABEL??p.label??""),
        object_id:oid,
        source_service:"USGS Tectonic Plate Boundaries",
        source_url:"https://earthquake.usgs.gov/arcgis/rest/services/eq/map_plateboundaries/MapServer",
        truth:"SCIENTIFIC_REFERENCE_NOT_REALTIME"
      }
    }];
  });
}

function esriGeometryToGeoJson(g:any){
  if(!g||typeof g!=="object")return null;
  if(Number.isFinite(Number(g.x))&&Number.isFinite(Number(g.y))){
    return {type:"Point",coordinates:[Number(g.x),Number(g.y)]};
  }
  if(Array.isArray(g.rings)){
    return {type:"Polygon",coordinates:g.rings};
  }
  if(Array.isArray(g.paths)){
    if(g.paths.length===1)return {type:"LineString",coordinates:g.paths[0]};
    return {type:"MultiLineString",coordinates:g.paths};
  }
  if(g.type&&Array.isArray(g.coordinates))return g;
  return null;
}
function yellowstoneReferenceFeatures(d:any,featureClass:string){
  if(d?.error)throw new Error("WSGS ArcGIS "+String(d.error?.code||"error")+": "+String(d.error?.message||"query failed"));
  const raw=Array.isArray(d?.features)?d.features:[];
  return raw.slice(0,2000).flatMap((f:any,i:number)=>{
    const g=esriGeometryToGeoJson(f?.geometry);
    if(!g)return [];
    const p=f?.properties||f?.attributes||{};
    const oid=String(p.OBJECTID??p.objectid??p.FID??i);
    const name=String(p.NAME??p.name??featureClass);
    return [{
      feature_key:featureClass.toLowerCase()+":"+oid,
      feature_class:featureClass,
      display_name:name,
      geometry:g,
      properties:{
        name,
        chemistry:String(p.Chem_Type??p.chem_type??""),
        thermal_activity:String(p.Th_Active??p.th_active??""),
        name_source:String(p.Source??p.source??""),
        data_source:String(p.Data_source??p.data_source??""),
        object_id:oid,
        mirror_provider:"Wyoming State Geological Survey",
        source_service:"YVO Thermal Features",
        original_thermal_area_source:"USGS DOI 10.5066/P1457JVI",
        geyser_source:"USGS GNIS",
        mirror_qc_note:"WSGS did not formally review or quality-control the copied thermal-area data",
        truth:"SCIENTIFIC_REFERENCE_NOT_REALTIME",
        prediction:false
      }
    }];
  });
}

async function ingestReferenceGeometry(sourceKey:string,features:any[]){
  if(!features.length)return {ok:true,upserted:0};
  return await rpc("bridgepoint_intelligence_ingest_reference_geometry_v5505",{
    p_source_key:sourceKey,p_features:features
  });
}

async function ingest(sourceKey:string,entities:any[]){
  if(!entities.length)return {ok:true,upserted:0};
  return await rpc("bridgepoint_intelligence_ingest_live_entities_v5501",{
    p_source_key:sourceKey,p_entities:entities
  });
}

async function ingestSignals(sourceKey:string,signals:any[]){
  if(!signals.length)return {ok:true,upserted:0};
  return await rpc("bridgepoint_intelligence_ingest_global_signals_v5503",{
    p_source_key:sourceKey,p_signals:signals
  });
}

async function due(sourceKey:string){
  return await rpc("bridgepoint_intelligence_live_source_due_v5502",{p_source_key:sourceKey});
}
async function mark(sourceKey:string,ok:boolean,count=0,error:string|null=null){
  try{return await rpc("bridgepoint_intelligence_live_source_mark_v5502",{
    p_source_key:sourceKey,p_ok:ok,p_count:count,p_error:error
  })}catch{return null}
}
async function refreshOne(sourceKey:string,loader:()=>Promise<any[]>){
  const d=await due(sourceKey);
  if(!d?.due)return {source_key:sourceKey,due:false,ok:true,count:0};
  try{
    const entities=await loader();
    const result=await ingest(sourceKey,entities);
    await mark(sourceKey,true,Number(result?.upserted||entities.length),null);
    return {source_key:sourceKey,due:true,ok:true,count:Number(result?.upserted||entities.length)};
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,900);
    await mark(sourceKey,false,0,msg);
    return {source_key:sourceKey,due:true,ok:false,count:0,error:msg};
  }
}

async function refreshSignalSource(sourceKey:string,loader:()=>Promise<any[]>){
  const d=await due(sourceKey);
  if(!d?.due)return {source_key:sourceKey,due:false,ok:true,count:0};
  try{
    const signals=await loader();
    const result=await ingestSignals(sourceKey,signals);
    await mark(sourceKey,true,Number(result?.upserted||signals.length),null);
    return {source_key:sourceKey,due:true,ok:true,count:Number(result?.upserted||signals.length)};
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,900);
    await mark(sourceKey,false,0,msg);
    return {source_key:sourceKey,due:true,ok:false,count:0,error:msg};
  }
}

async function refreshReferenceSource(sourceKey:string,loader:()=>Promise<any[]>){
  const d=await due(sourceKey);
  if(!d?.due)return {source_key:sourceKey,due:false,ok:true,count:0};
  try{
    const features=await loader();
    const result=await ingestReferenceGeometry(sourceKey,features);
    await mark(sourceKey,true,Number(result?.upserted||features.length),null);
    return {source_key:sourceKey,due:true,ok:true,count:Number(result?.upserted||features.length)};
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,900);
    await mark(sourceKey,false,0,msg);
    return {source_key:sourceKey,due:true,ok:false,count:0,error:msg};
  }
}

async function refreshCache(){
  const results=[];
  results.push(await refreshOne("USGS_EARTHQUAKES_GLOBAL",async()=>{
    const d=await fetchJson("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson");
    return earthquakeEntities(d);
  }));
  results.push(await refreshOne("NASA_EONET_GLOBAL",async()=>{
    const d=await fetchJson("https://eonet.gsfc.nasa.gov/api/v3/events?status=open&limit=500");
    return eonetEntities(d);
  }));
  results.push(await refreshOne("USGS_VOLCANO_GLOBAL",async()=>{
    const d=await fetchJson("https://volcanoes.usgs.gov/vsc/api/volcanoApi/geojson");
    return volcanoEntities(d);
  }));

  results.push(await refreshSignalSource("NOAA_SWPC",async()=>{
    const [alerts,kp]=await Promise.all([
      fetchJson("https://services.swpc.noaa.gov/products/alerts.json"),
      fetchJson("https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json")
    ]);
    return swpcSignals(alerts,kp);
  }));
  results.push(await refreshReferenceSource("USGS_PLATE_BOUNDARIES_GLOBAL",async()=>{
    const base="https://earthquake.usgs.gov/arcgis/rest/services/eq/map_plateboundaries/MapServer/";
    const qs="/query?where=1%3D1&outFields=OBJECTID%2CNAME%2CLABEL&returnGeometry=true&f=geojson&outSR=4326";
    const [microplates,plates]=await Promise.all([
      fetchJson(base+"0"+qs,12000),
      fetchJson(base+"1"+qs,12000)
    ]);
    return [
      ...plateBoundaryFeatures(microplates,"MICROPLATE_BOUNDARY"),
      ...plateBoundaryFeatures(plates,"PLATE_BOUNDARY")
    ];
  }));

  results.push(await refreshReferenceSource("WY_WSGS_YELLOWSTONE_THERMAL",async()=>{
    const base="https://portal.wsgs.wyo.gov/ags/rest/services/YVO/YVO_Thermal/MapServer/";
    const [geyserIds,areaIds]=await Promise.all([
      fetchJson(base+"1/query?where=1%3D1&returnIdsOnly=true&f=json",12000),
      fetchJson(base+"2/query?where=1%3D1&returnIdsOnly=true&f=json",12000)
    ]);
    const gIds=(geyserIds?.objectIds||[]).slice(0,2000);
    const aIds=(areaIds?.objectIds||[]).slice(0,2000);
    if(!gIds.length&&!aIds.length)throw new Error("WSGS_YELLOWSTONE_NO_OBJECT_IDS");
    const [geysers,thermalAreas]=await Promise.all([
      gIds.length?fetchJson(base+"1/query?objectIds="+encodeURIComponent(gIds.join(","))+"&outFields=OBJECTID%2CNAME%2CData_source&returnGeometry=true&f=json&outSR=4326",12000):Promise.resolve({features:[]}),
      aIds.length?fetchJson(base+"2/query?objectIds="+encodeURIComponent(aIds.join(","))+"&outFields=OBJECTID%2CNAME%2CChem_Type%2CTh_Active%2CSource%2CData_source&returnGeometry=true&f=json&outSR=4326",12000):Promise.resolve({features:[]})
    ]);
    const features=[
      ...yellowstoneReferenceFeatures(geysers,"GEYSER"),
      ...yellowstoneReferenceFeatures(thermalAreas,"THERMAL_AREA")
    ];
    if(!features.length)throw new Error("WSGS_YELLOWSTONE_EMPTY_FEATURE_SET");
    return features;
  }));
  return {ok:results.every((x:any)=>x.ok),version:5506,generated_at:new Date().toISOString(),results};
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{headers:JSON_HEADERS});
  try{
    const body=await req.json().catch(()=>({})),action=String(body.action||"earthquakes");

    if(action==="refresh_cache"){
      const token=req.headers.get("x-bridgepoint-cron")||String(body.cron_token||"");
      const authorized=await rpc("bridgepoint_intelligence_live_refresh_authorize_v5502",{p_token:token});
      if(authorized!==true)return new Response(JSON.stringify({ok:false,error:"REFRESH_UNAUTHORIZED"}),{status:401,headers:JSON_HEADERS});
      const out=await refreshCache();
      return new Response(JSON.stringify(out),{status:out.ok?200:207,headers:{...JSON_HEADERS,"cache-control":"no-store"}});
    }

    const sessionKey=String(body.session_key||"");
    if(sessionKey.length<16||sessionKey.length>200)return new Response(JSON.stringify({ok:false,error:"DEMO_SESSION_KEY_REQUIRED"}),{status:400,headers:JSON_HEADERS});
    const q=await quota(sessionKey,action==="capabilities"||action==="eonet"?"GLOBAL":"GEOLOGY");
    if(q?.allowed===false)return new Response(JSON.stringify({...q,ok:false,error:"DEMO_LIMIT_REACHED"}),{status:429,headers:JSON_HEADERS});

    if(action==="earthquakes"){
      const feed=String(body.window||"day")==="hour"?"all_hour":"all_day";
      const d=await fetchJson("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/"+feed+".geojson");
      const minMag=Math.max(0,Number(body.min_magnitude||0));
      const features=(d?.features||[]).filter((f:any)=>Number(f?.properties?.mag||0)>=minMag).slice(0,1200).map(slimEarthquake);
      try{await ingest("USGS_EARTHQUAKES_GLOBAL",earthquakeEntities(d))}catch{}
      return new Response(JSON.stringify({ok:true,version:5503,source:"USGS",generated_at:new Date().toISOString(),quota:q,type:"FeatureCollection",features}),{headers:JSON_HEADERS});
    }
    if(action==="volcanoes"){
      const d=await fetchJson("https://volcanoes.usgs.gov/vsc/api/volcanoApi/geojson");
      const raw=Array.isArray(d?.features)?d.features:Array.isArray(d)?d:[];
      const features=raw.slice(0,1000).map(slimVolcano).filter((f:any)=>Number.isFinite(f.geometry.coordinates[0])&&Number.isFinite(f.geometry.coordinates[1]));
      try{await ingest("USGS_VOLCANO_GLOBAL",volcanoEntities(d))}catch{}
      return new Response(JSON.stringify({ok:true,version:5503,source:"USGS Volcano Hazards Program",generated_at:new Date().toISOString(),quota:q,type:"FeatureCollection",features}),{headers:JSON_HEADERS});
    }
    if(action==="eonet"){
      const d=await fetchJson("https://eonet.gsfc.nasa.gov/api/v3/events?status=open&limit=500");
      const entities=eonetEntities(d);
      try{await ingest("NASA_EONET_GLOBAL",entities)}catch{}
      return new Response(JSON.stringify({ok:true,version:5503,source:"NASA EONET",generated_at:new Date().toISOString(),quota:q,events:d?.events||[]}),{headers:JSON_HEADERS});
    }

    if(action==="space_weather"){
      const d=await rpc("bridgepoint_intelligence_global_signals_v5503",{p_domain:"SPACE_WEATHER",p_limit:200});
      return new Response(JSON.stringify({...d,quota:q,version:5503}),{headers:JSON_HEADERS});
    }

    if(action==="tectonics"){
      const d=await rpc("bridgepoint_intelligence_reference_geometry_v5505",{
        p_domain:"TECTONICS",p_feature_class:null,p_limit:2500
      });
      return new Response(JSON.stringify({...d,quota:q,version:5505}),{headers:JSON_HEADERS});
    }

    if(action==="geothermal"){
      const d=await rpc("bridgepoint_intelligence_reference_geometry_v5505",{
        p_domain:"GEOTHERMAL",p_feature_class:null,p_limit:2500
      });
      return new Response(JSON.stringify({
        ...d,quota:q,version:5506,
        truth:"SCIENTIFIC_REFERENCE_NOT_REALTIME",
        prediction:false
      }),{headers:JSON_HEADERS});
    }

    if(action==="capabilities"){
      const r=await fetch(SUPABASE_URL+"/rest/v1/rpc/bridgepoint_intelligence_capabilities_v5300",{method:"POST",headers:SERVICE_HEADERS,body:"{}"});
      const d=await r.json();
      const manifest=await rpc("bridgepoint_intelligence_tool_manifest_v5501",{});
      return new Response(JSON.stringify({...d,live_tools:manifest,quota:q,version:5503}),{headers:JSON_HEADERS});
    }
    return new Response(JSON.stringify({ok:false,error:"ACTION_NOT_SUPPORTED"}),{status:400,headers:JSON_HEADERS});
  }catch(e){
    return new Response(JSON.stringify({ok:false,error:String((e as any)?.message||e),version:5503}),{status:502,headers:JSON_HEADERS});
  }
});