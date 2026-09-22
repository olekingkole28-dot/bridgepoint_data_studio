const U=Deno.env.get('SUPABASE_URL')!,S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RELEASE='2026-08-19.0';
const COLLECTIONS=[
  {type:'segment',source_key:'OVERTURE_TRANSPORT_20260819_V2626',feature_type:'transport_segment',priority:1280},
  {type:'connector',source_key:'OVERTURE_TRANSPORT_CONNECTOR_20260819_V2681',feature_type:'transport_connector',priority:1280}
];
async function rpc(n:string,b:any){const r=await fetch(`${U}/rest/v1/rpc/${n}`,{method:'POST',headers:{apikey:S,authorization:`Bearer ${S}`,'content-type':'application/json'},body:JSON.stringify(b),signal:AbortSignal.timeout(45000)});const t=await r.text();if(!r.ok)throw new Error(`${n}:${t.slice(0,800)}`);return t?JSON.parse(t):null}
async function seedCollection(c:any,t:string){
  const base=`https://stac.overturemaps.org/${RELEASE}/transportation/${c.type}/collection.json`;
  const rr=await fetch(base,{signal:AbortSignal.timeout(30000)});if(!rr.ok)throw new Error(`${c.type}_COLLECTION_HTTP_${rr.status}`);const col=await rr.json();
  const links=(col.links||[]).filter((x:any)=>x.rel==='item'&&x.href);const rows=[] as any[];
  for(const l of links){const url=new URL(l.href,base).href;const ir=await fetch(url,{signal:AbortSignal.timeout(30000)});if(!ir.ok)throw new Error(`${c.type}_ITEM_HTTP_${ir.status}:${url}`);const j=await ir.json();const a=j.assets||{};const href=[a.azure?.href,a.aws?.href,...Object.values(a).map((z:any)=>z?.href)].find((z:any)=>typeof z==='string'&&z.startsWith('http'));if(!href)continue;rows.push({source_key:c.source_key,feature_type:c.feature_type,item_id:String(j.id),release:RELEASE,stac_url:url,parquet_url:href,bbox:j.bbox,num_rows:j.properties?.num_rows??null,priority:c.priority,metadata:{license:col.license||'ODbL-1.0',transportation_type:c.type,seed_version:2681}})}
  const out=await rpc('bridgepoint_overture_world_seed_v2636',{p_task_token:t,p_rows:rows});return{type:c.type,items:rows.length,declared_rows:rows.reduce((a,x)=>a+Number(x.num_rows||0),0),out};
}
Deno.serve(async req=>{try{const b=await req.json().catch(()=>({}));const t=String(b.task_token||'');if(await rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:t})!==true)return new Response('unauthorized',{status:401});const results=[];for(const c of COLLECTIONS)results.push(await seedCollection(c,t));return Response.json({complete:true,version:2681,release:RELEASE,results})}catch(e){return Response.json({complete:false,version:2681,error:String((e as any)?.message||e)},{status:500})}});