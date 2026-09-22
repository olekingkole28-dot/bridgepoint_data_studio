import { createClient } from "npm:@supabase/supabase-js@2";
import { asyncBufferFromUrl, parquetReadObjects } from "npm:hyparquet";
import { compressors } from "npm:hyparquet-compressors";

const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const REL="2026-08-19.0";
function safe(v:any):any{if(typeof v==='bigint')return v.toString();if(Array.isArray(v))return v.map(safe);if(v&&typeof v==='object'){const o:any={};for(const [k,x] of Object.entries(v))o[k]=safe(x);return o}return v}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const a=await sb.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const id=String(b.item_id||"00032"); if(!/^\d{5}$/.test(id))throw new Error("INVALID_ITEM_ID");
 const start=Math.max(0,Math.floor(Number(b.row_start||0))), limit=Math.max(1,Math.min(25,Math.floor(Number(b.limit||10))));
 const stac=`https://stac.overturemaps.org/${REL}/buildings/building/${id}/${id}.json`;
 const ir=await fetch(stac,{headers:{accept:"application/json"},signal:AbortSignal.timeout(12000)}); if(!ir.ok)throw new Error(`STAC_HTTP_${ir.status}`); const item=await ir.json();
 const url=String(item?.assets?.aws?.href||item?.assets?.azure?.href||""); if(!url)throw new Error("PARQUET_ASSET_MISSING");
 const file=await asyncBufferFromUrl({url,requestInit:{headers:{"user-agent":"BridgePointIntelligence/1.0"}}});
 const rows=await parquetReadObjects({file,compressors,columns:["id","bbox","geometry","height","min_height","num_floors","facade_material","roof_material","roof_shape","roof_direction","roof_orientation","roof_height","sources"],rowStart:start,rowEnd:start+limit});
 return new Response(JSON.stringify({complete:true,version:2005,release:REL,item_id:id,item_bbox:item.bbox,num_rows:item?.properties?.num_rows||null,row_start:start,returned:rows.length,parquet_url:url,rows:safe(rows)}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:2005,error:String((e as any)?.message||e)}),{status:500,headers:H})}});
