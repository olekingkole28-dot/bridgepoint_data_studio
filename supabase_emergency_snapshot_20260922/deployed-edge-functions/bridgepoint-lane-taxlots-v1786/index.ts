import { createClient } from "jsr:@supabase/supabase-js@2";
const NONCE="lane-v1786-4b7d9f2a-1c6e";
const SOURCE="https://gis.eugene-or.gov/arcgis/rest/services/PWM/COE_Basemap_Tiled_Pro/MapServer/2/query";
const CANDIDATE="9ad03799-9259-4a8c-b45f-82ec96b69f6d";
const RUN="d06f1c7d-9b88-43f4-b46e-8a0535b25093";
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response("method",{status:405});
 const body=await req.json().catch(()=>({})); if(body.nonce!==NONCE) return new Response("unauthorized",{status:401});
 const offset=Math.max(0,Number(body.offset??0)), limit=Math.min(2000,Math.max(1,Number(body.limit??2000)));
 const idRes=await fetch(SOURCE,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({where:"1=1",returnIdsOnly:"true",f:"json"})});
 const idJson=await idRes.json(); if(!Array.isArray(idJson.objectIds)) throw new Error("No objectIds: "+JSON.stringify(idJson).slice(0,500));
 const ids=[...idJson.objectIds].sort((a,b)=>a-b), slice=ids.slice(offset,offset+limit);
 if(!slice.length) return Response.json({complete:true,version:1786,total_ids:ids.length,offset,remote_records:0,staged:0,eof:true});
 const qRes=await fetch(SOURCE,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({objectIds:slice.join(","),outFields:"OBJECTID,maptaxlot",returnGeometry:"false",f:"json"})});
 const qJson=await qRes.json(); if(!Array.isArray(qJson.features)) throw new Error("No features: "+JSON.stringify(qJson).slice(0,500));
 const rows=qJson.features.map((f:any)=>{const a=f.attributes||{},parcel=String(a.maptaxlot??"").trim();return parcel?{run_id:RUN,candidate_id:CANDIDATE,state_code:"OR",source_record_id:`lane:${a.OBJECTID}`,payload:{OBJECTID:a.OBJECTID,maptaxlot:parcel,parcel_id:parcel,county_name:"Lane County",county_fips:"41039"},materialization_status:"PENDING"}:null}).filter(Boolean);
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}}); let attempted=0;
 for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const {error}=await sb.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(error) throw error;attempted+=chunk.length;}
 return Response.json({complete:true,version:1786,total_ids:ids.length,offset,requested:limit,remote_records:qJson.features.length,attempted_stage:attempted,eof:offset+limit>=ids.length,first_id:slice[0],last_id:slice[slice.length-1]});
}catch(e){return Response.json({complete:false,version:1786,error:String(e?.message||e)},{status:500});}});