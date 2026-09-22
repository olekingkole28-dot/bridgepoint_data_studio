import { createClient } from "jsr:@supabase/supabase-js@2";
const NONCE="berrien-v1788-9d42c1a7";
const SOURCE="https://gis.berriencountymi.gov/server/rest/services/Parcels_Future/FeatureServer/1/query";
const CANDIDATE="8668aa3d-419d-4169-b2b4-7d2166423bb4";
const RUN="7e10b7ea-e30c-40fa-8a93-7f77cf5e69a3";
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response("method",{status:405});
 const body=await req.json().catch(()=>({})); if(body.nonce!==NONCE) return new Response("unauthorized",{status:401});
 const offset=Math.max(0,Number(body.offset??0)), limit=Math.min(2000,Math.max(1,Number(body.limit??2000)));
 const idRes=await fetch(SOURCE,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({where:"1=1",returnIdsOnly:"true",f:"json"})});
 const idJson=await idRes.json(); if(!Array.isArray(idJson.objectIds)) throw new Error("No objectIds: "+JSON.stringify(idJson).slice(0,500));
 const ids=[...idJson.objectIds].sort((a,b)=>a-b), slice=ids.slice(offset,offset+limit);
 if(!slice.length) return Response.json({complete:true,version:1788,total_ids:ids.length,offset,remote_records:0,staged:0,eof:true});
 const qRes=await fetch(SOURCE,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({objectIds:slice.join(","),outFields:"OBJECTID,PIN",returnGeometry:"false",f:"json"})});
 const qJson=await qRes.json(); if(!Array.isArray(qJson.features)) throw new Error("No features: "+JSON.stringify(qJson).slice(0,500));
 const rows=qJson.features.map((f:any)=>{const a=f.attributes||{},pin=String(a.PIN??"").trim(),oid=String(a.OBJECTID??"").trim();return pin&&oid?{run_id:RUN,candidate_id:CANDIDATE,state_code:"MI",source_record_id:oid,payload:{parcel_id:pin,county:"Berrien County",county_name:"Berrien County",county_fips:"26021",projection:"PIN_ONLY",source_mode:"BERRIEN_PUBLIC_PIN_V1788"},materialization_status:"PENDING"}:null}).filter(Boolean);
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});let attempted=0;
 for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const {error}=await sb.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(error) throw error;attempted+=chunk.length;}
 return Response.json({complete:true,version:1788,total_ids:ids.length,offset,requested:limit,remote_records:qJson.features.length,attempted_stage:attempted,eof:offset+limit>=ids.length,first_id:slice[0],last_id:slice[slice.length-1]});
}catch(e){return Response.json({complete:false,version:1788,error:String(e?.message||e)},{status:500});}});