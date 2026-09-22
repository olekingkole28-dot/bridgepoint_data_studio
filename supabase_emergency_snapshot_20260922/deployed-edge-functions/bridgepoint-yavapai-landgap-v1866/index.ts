import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1866,PAGE=1000,PAGES=10;
const CENSUS='https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer';
const AZ='https://azgeo.az.gov/arcgis/rest/services/TerraSystems/AZParcelFeatures/FeatureServer/0/query';
async function postForm(url:string,p:URLSearchParams){const r=await fetch(url,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded','user-agent':'BridgePointIntelligence/1.0'},body:p.toString(),signal:AbortSignal.timeout(30000)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,200)}`);let j:any;try{j=JSON.parse(t)}catch{throw new Error(`BAD_JSON:${t.slice(0,160)}`)};if(j?.error)throw new Error(`ARCGIS:${JSON.stringify(j.error).slice(0,400)}`);return j}
async function countyGeom(){for(const layer of [1,2,0]){try{const p=new URLSearchParams({where:"STATE='04' AND COUNTY='025'",outFields:'GEOID,NAME',returnGeometry:'true',outSR:'4326',f:'json'});const j=await postForm(`${CENSUS}/${layer}/query`,p);const f=j?.features?.[0];if(f?.geometry?.rings?.length)return {geometry:f.geometry,layer};}catch{}}throw new Error('YAVAPAI_CENSUS_GEOMETRY_NOT_FOUND')}
Deno.serve(async(req:Request)=>{let shardId=0;try{
 if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST_REQUIRED'}),{status:405,headers:H});
 const body=await req.json().catch(()=>({}));const tok=String(body.task_token||req.headers.get('x-bridgepoint-worker-token')||'');const auth=await db.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:tok});if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:'UNAUTHORIZED'}),{status:401,headers:H});
 const cl=await db.rpc('[REDACTED_LONG_LITERAL]');if(cl.error)throw cl.error;const sh=cl.data?.shard;if(!sh)return new Response(JSON.stringify({complete:true,version:V,claimed:0,records:0}),{headers:H});
 shardId=Number(sh.shard_id);let offset=Number(sh.current_offset),end=Number(sh.end_offset),seen=Number(sh.remote_seen||0),total=0,done=false;const cid=String(sh.candidate_id),run=String(sh.run_id);const cg=await countyGeom();const geom=JSON.stringify({rings:cg.geometry.rings,spatialReference:{wkid:4326}});const stats:any[]=[];
 for(let p=0;p<PAGES&&!done;p++){
   const lim=Math.min(PAGE,Math.max(0,end-offset));if(lim<=0){done=true;break}
   const qp=new URLSearchParams({where:'1=1',geometry:geom,geometryType:'esriGeometryPolygon',inSR:'4326',spatialRel:'esriSpatialRelIntersects',outFields:'OBJECTID,AZ_APN',returnGeometry:'false',orderByFields:'OBJECTID ASC',resultOffset:String(offset),resultRecordCount:String(lim),f:'json'});
   const j=await postForm(AZ,qp);const feats=Array.isArray(j?.features)?j.features:[];const rows=feats.map((f:any)=>{const a=f?.attributes||{},apn=String(a.AZ_APN??'').trim();return apn?{run_id:run,candidate_id:cid,state_code:'AZ',source_record_id:apn,source_updated_at:new Date().toISOString(),record_hash:`YAVAPAI|${apn}`,payload:{parcel_id:apn,county_fips:'04025',county_name:'Yavapai County',state_code:'AZ',fragmentation_lane:'LAND_GAP',source_mode:'YAVAPAI_AZGEO_APN_ONLY_V1866',geometry_retained:false,address_retained:false,owner_retained:false,values_retained:false,raw_resale:false},materialization_status:'PENDING'}:null}).filter(Boolean);
   if(rows.length){const {error}=await db.schema('staging').from('geographic_source_records_v90').upsert(rows,{onConflict:'candidate_id,source_record_id',ignoreDuplicates:true});if(error)throw error;}
   offset+=feats.length;seen+=feats.length;total+=feats.length;done=feats.length<lim||offset>=end;
   const up=await db.rpc('[REDACTED_LONG_LITERAL]',{p_shard_id:shardId,p_current_offset:offset,p_remote_seen:seen,p_done:done});if(up.error)throw up.error;
   stats.push({page:p+1,records:feats.length,offset,seen});if(!feats.length)done=true;
 }
 return new Response(JSON.stringify({complete:true,version:V,claimed:1,shard_id:shardId,records:total,offset,remote_seen:seen,done,census_layer:cg.layer,pages:stats}),{headers:H});
 }catch(e){const msg=String((e as any)?.message||e);if(shardId){try{await db.rpc('[REDACTED_LONG_LITERAL]',{p_shard_id:shardId,p_error:msg})}catch{}}return new Response(JSON.stringify({complete:false,version:V,shard_id:shardId,error:msg}),{status:500,headers:H})}
});