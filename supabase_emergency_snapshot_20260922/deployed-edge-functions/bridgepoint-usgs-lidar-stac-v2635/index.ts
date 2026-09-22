import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json"};
const abs=(href:string,base:string)=>{try{return new URL(href,base).toString()}catch{return href}};
const arr=(v:any)=>Array.isArray(v)?v:[];
function eptProject(j:any,url:string,title?:string,bbox?:any){
 const b=Array.isArray(bbox)?bbox:(Array.isArray(j?.boundsConforming)&&j.boundsConforming.length>=6?[j.boundsConforming[0],j.boundsConforming[1],j.boundsConforming[3],j.boundsConforming[4]]:null);
 const srs=j?.srs||{}; const auth=srs?.authority||srs?.horizontal||null;
 return {project_key:String(title||url.split('/').filter(Boolean).slice(-2,-1)[0]||url),ept_url:url,title:title||j?.title||null,bbox:b,point_count:j?.points??null,horizontal_crs:auth?String(auth):null,vertical_crs:srs?.vertical?String(srs.vertical):null,schema_fields:j?.schema??null,metadata:{dataType:j?.dataType,span:j?.span,version:j?.version},updated_at:null};
}
function parseDoc(j:any,url:string){
 const children:any[]=[]; const projects:any[]=[]; const type=String(j?.type||'');
 if(j?.bounds && j?.schema && (j?.points!==undefined || url.endsWith('/ept.json'))){ projects.push(eptProject(j,url)); return {children,projects}; }
 for(const l of arr(j?.links)){
  const rel=String(l?.rel||''); const href=l?.href?abs(String(l.href),url):''; if(!href)continue;
  if(['child','item','items','collection','data'].includes(rel) && href.endsWith('.json')) children.push({url:href,rel,title:l?.title||null});
  if(href.endsWith('/ept.json')) children.push({url:href,rel:rel||'ept',title:l?.title||null});
 }
 const features=type==='FeatureCollection'?arr(j?.features):type==='Feature'?[j]:[];
 for(const f of features){
  const fb=Array.isArray(f?.bbox)?f.bbox:null; const ttl=f?.properties?.title||f?.properties?.name||f?.id||null;
  for(const [k,a] of Object.entries(f?.assets||{})){
   const href=(a as any)?.href?abs(String((a as any).href),url):''; if(!href)continue;
   if(href.endsWith('/ept.json')||href.endsWith('ept.json')) projects.push({project_key:String(f?.id||ttl||href),ept_url:href,title:ttl,bbox:fb,point_count:null,horizontal_crs:f?.properties?.['proj:epsg']?`EPSG:${f.properties['proj:epsg']}`:null,vertical_crs:null,schema_fields:null,metadata:{asset_key:k,stac_properties:f?.properties||{}},updated_at:f?.properties?.updated||f?.properties?.datetime||null});
  }
 }
 const uniq=new Map<string,any>(); for(const c of children)uniq.set(c.url,c);
 const puniq=new Map<string,any>(); for(const p of projects)puniq.set(p.ept_url,p);
 return {children:[...uniq.values()],projects:[...puniq.values()]};
}
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST required'}),{status:405,headers:H});
 try{
  const b=await req.json().catch(()=>({})); const tok=String(b?.task_token||'');
  const {data:ok,error:ae}=await db.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:tok});
  if(ae||ok!==true)return new Response(JSON.stringify({complete:false,error:'invalid worker token'}),{status:401,headers:H});
  const {data:claim,error:ce}=await db.schema('automation').rpc('claim_usgs_lidar_stac_v2635',{p_limit:Math.min(Math.max(Number(b?.limit||5),1),10)}); if(ce)throw ce;
  const lease=claim?.lease_token; const tasks=claim?.tasks||[]; const detail=[];
  for(const t of tasks){
   try{
    const r=await fetch(String(t.url),{headers:{accept:'application/json','user-agent':'BridgePointIntelligence/2635 lidar-index'},signal:AbortSignal.timeout(20000)}); const text=await r.text(); if(!r.ok)throw new Error(`HTTP_${r.status}:${text.slice(0,180)}`);
    const j=JSON.parse(text); const payload=parseDoc(j,String(t.url));
    const {data:stored,error:pe}=await db.schema('automation').rpc('persist_usgs_lidar_stac_v2635',{p_task_token:tok,p_url:String(t.url),p_lease_token:lease,p_payload:payload,p_error:null}); if(pe)throw pe;
    detail.push({url:t.url,children:payload.children.length,projects:payload.projects.length,stored});
   }catch(e){
    await db.schema('automation').rpc('persist_usgs_lidar_stac_v2635',{p_task_token:tok,p_url:String(t.url),p_lease_token:lease,p_payload:{},p_error:String((e as any)?.message||e).slice(0,700)});
    detail.push({url:t.url,error:String((e as any)?.message||e).slice(0,180)});
   }
  }
  return new Response(JSON.stringify({complete:true,version:2635,claimed:tasks.length,detail}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,version:2635,error:String((e as any)?.message||e)}),{status:500,headers:H});}
});