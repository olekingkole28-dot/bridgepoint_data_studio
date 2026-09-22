import { asyncBufferFromUrl, parquetMetadataAsync } from 'npm:hyparquet@1.30.0';

const U=Deno.env.get('SUPABASE_URL')!,S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ALLOWED=new Set(['OVERTURE_BUILDINGS_20260819','OVERTURE_BUILDING_PARTS_20260819']);
async function rpc(n:string,b:any){
  const r=await fetch(`${U}/rest/v1/rpc/${n}`,{method:'POST',headers:{apikey:S,authorization:`Bearer ${S}`,'content-type':'application/json'},body:JSON.stringify(b),signal:AbortSignal.timeout(45000)});
  const t=await r.text(); if(!r.ok) throw new Error(`${n}:${t.slice(0,1200)}`); return t?JSON.parse(t):null;
}
function num(v:any):number|null{if(v==null)return null;if(typeof v==='number')return Number.isFinite(v)?v:null;if(typeof v==='bigint')return Number(v);const n=Number(v);return Number.isFinite(n)?n:null}
function stat(g:any,path:string){const c=(g.columns||[]).find((x:any)=>(x.meta_data?.path_in_schema||x.path_in_schema||[]).join('.')===path);const s=c?.meta_data?.statistics;return{min:num(s?.min_value??s?.min),max:num(s?.max_value??s?.max),null_count:num(s?.null_count)}}

Deno.serve(async req=>{
  let claim:any=null,t='';
  try{
    const b=await req.json().catch(()=>({})); t=String(b.task_token||'');
    if(await rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:t})!==true)return new Response('unauthorized',{status:401});
    claim=await rpc('bridgepoint_building_rowgroup_index_claim_v2711',{p_task_token:t});
    if(!claim?.claimed)return Response.json(claim||{complete:true,claimed:false});
    const source=String(claim.source_key),item=String(claim.item_id),url=String(claim.parquet_url),expected=Number(claim.expected_rows);
    if(!ALLOWED.has(source))throw new Error('SOURCE_NOT_ALLOWED'); if(!/^https:\/\//.test(url))throw new Error('PARQUET_URL_REQUIRED');
    const f=await asyncBufferFromUrl({url,requestInit:{headers:{'user-agent':'BridgePointIntelligence/2711-building-rowgroup-index'}}});
    const m:any=await parquetMetadataAsync(f); let start=0;
    const groups=(m.row_groups||[]).map((g:any,i:number)=>{const rows=Number(g.num_rows||0),xmin=stat(g,'bbox.xmin'),ymin=stat(g,'bbox.ymin'),xmax=stat(g,'bbox.xmax'),ymax=stat(g,'bbox.ymax');const out={row_group_id:i,row_start:start,row_count:rows,bbox_west:xmin.min,bbox_south:ymin.min,bbox_east:xmax.max,bbox_north:ymax.max};start+=rows;return out});
    if(groups.length===0)throw new Error('NO_ROW_GROUPS');
    if(start!==expected)throw new Error(`ROW_GROUP_TOTAL_MISMATCH:${start}/${expected}`);
    if(groups.some((g:any)=>[g.bbox_west,g.bbox_south,g.bbox_east,g.bbox_north].some((v:any)=>v==null)))throw new Error('INCOMPLETE_BBOX_STATS');
    const persisted=await rpc('bridgepoint_building_rowgroups_replace_v2710',{p_source_key:source,p_item_id:item,p_groups:groups});
    const progress=await rpc('bridgepoint_building_rowgroup_index_progress_v2711',{p_task_token:t,p_source_key:source,p_item_id:item,p_lease_token:claim.lease_token,p_error:null});
    if(progress?.stored!==true)throw new Error(`INDEX_PROGRESS_REJECTED:${JSON.stringify(progress).slice(0,500)}`);
    return Response.json({complete:true,version:2711,source_key:source,item_id:item,rows:start,row_groups:groups.length,persisted,progress});
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,1500);
    if(claim?.claimed&&t){try{await rpc('bridgepoint_building_rowgroup_index_progress_v2711',{p_task_token:t,p_source_key:String(claim.source_key),p_item_id:String(claim.item_id),p_lease_token:claim.lease_token,p_error:msg})}catch{}}
    return Response.json({complete:false,version:2711,error:msg},{status:500});
  }
});