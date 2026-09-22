import { asyncBufferFromUrl, parquetMetadataAsync } from 'npm:hyparquet@1.30.0';
const U=Deno.env.get('SUPABASE_URL')!,S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ALLOWED=new Set(['OVERTURE_TRANSPORT_20260819_V2626','OVERTURE_TRANSPORT_CONNECTOR_20260819_V2681']);
async function rpc(n:string,b:any){const r=await fetch(`${U}/rest/v1/rpc/${n}`,{method:'POST',headers:{apikey:S,authorization:`Bearer ${S}`,'content-type':'application/json'},body:JSON.stringify(b),signal:AbortSignal.timeout(45000)});const t=await r.text();if(!r.ok)throw new Error(`${n}:${t.slice(0,1000)}`);return t?JSON.parse(t):null}
function num(v:any):number|null{if(v==null)return null;if(typeof v==='number')return Number.isFinite(v)?v:null;if(typeof v==='bigint')return Number(v);const n=Number(v);return Number.isFinite(n)?n:null}
function stat(g:any,path:string){const c=(g.columns||[]).find((x:any)=>(x.meta_data?.path_in_schema||x.path_in_schema||[]).join('.')===path);const s=c?.meta_data?.statistics;return {min:num(s?.min_value??s?.min),max:num(s?.max_value??s?.max),null_count:num(s?.null_count)};}
Deno.serve(async req=>{try{
 const b=await req.json().catch(()=>({})),t=String(b.task_token||''),source=String(b.source_key||''),item=String(b.item_id||''),url=String(b.parquet_url||'');
 if(await rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:t})!==true)return new Response('unauthorized',{status:401});
 if(!ALLOWED.has(source))throw new Error('SOURCE_NOT_ALLOWED');if(!item)throw new Error('item_id required');if(!/^https:\/\//.test(url))throw new Error('parquet_url required');
 const f=await asyncBufferFromUrl({url,requestInit:{headers:{'user-agent':'BridgePointIntelligence/2691-transport-rowgroup-index'}}});const m:any=await parquetMetadataAsync(f);let start=0;
 const groups=(m.row_groups||[]).map((g:any,i:number)=>{const rows=Number(g.num_rows||0),xmin=stat(g,'bbox.xmin'),ymin=stat(g,'bbox.ymin'),xmax=stat(g,'bbox.xmax'),ymax=stat(g,'bbox.ymax');const out={row_group_index:i,row_start:start,row_end:start+rows,row_count:rows,bbox_west:xmin.min,bbox_south:ymin.min,bbox_east:xmax.max,bbox_north:ymax.max,stats_complete:[xmin.min,ymin.min,xmax.max,ymax.max].every(x=>x!=null),metadata:{bbox_null_counts:{xmin:xmin.null_count,ymin:ymin.null_count,xmax:xmax.null_count,ymax:ymax.null_count},metadata_worker_version:2691}};start+=rows;return out});
 if(start!==Number(m.num_rows||0))throw new Error(`ROW_GROUP_TOTAL_MISMATCH:${start}/${Number(m.num_rows||0)}`);
 const persisted=await rpc('bridgepoint_transport_row_groups_persist_v2689',{p_task_token:t,p_source_key:source,p_item_id:item,p_groups:groups});
 return Response.json({complete:true,version:2691,source_key:source,item_id:item,num_rows:Number(m.num_rows||0),row_group_count:groups.length,persisted});
}catch(e){return Response.json({complete:false,version:2691,error:String((e as any)?.message||e)},{status:500})}});