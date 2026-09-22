import { createClient } from "jsr:@supabase/supabase-js@2";
const NONCE="forsyth-v1795-b4c81e2d";
const SOURCE="https://geo.forsythco.com/gis/rest/services/Public/Tax_Parcel/FeatureServer/0/query";
const CANDIDATE="6b4fe57b-22bd-47da-9c97-7b44da7753e4";
const RUN="87951312-272c-4661-881d-e35af993377d";
Deno.serve(async(req:Request)=>{try{
  if(req.method!=="POST") return new Response("method",{status:405});
  const body=await req.json().catch(()=>({})); if(String(body.nonce||"")!==NONCE) return new Response("unauthorized",{status:401});
  const offset=Math.max(0,Number(body.offset??0)), limit=Math.min(2000,Math.max(1,Number(body.limit??2000)));
  const idRes=await fetch(SOURCE,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({where:"1=1",returnIdsOnly:"true",f:"json"})});
  const idJson=await idRes.json(); if(!Array.isArray(idJson.objectIds)) throw new Error("No objectIds: "+JSON.stringify(idJson).slice(0,500));
  const ids=[...idJson.objectIds].sort((a,b)=>a-b), slice=ids.slice(offset,offset+limit);
  if(!slice.length) return Response.json({complete:true,version:1795,total_ids:ids.length,offset,remote_records:0,staged:0,eof:true});
  const qRes=await fetch(SOURCE,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({objectIds:slice.join(","),outFields:"OBJECTID,PARCELID",returnGeometry:"false",f:"json"})});
  const qJson=await qRes.json(); if(!Array.isArray(qJson.features)) throw new Error("No features: "+JSON.stringify(qJson).slice(0,500));
  const rows=qJson.features.map((f:any)=>{const a=f.attributes||{},parcel=String(a.PARCELID??"").trim();return parcel?{run_id:RUN,candidate_id:CANDIDATE,state_code:"GA",source_record_id:String(a.OBJECTID),payload:{OBJECTID:a.OBJECTID,PARCELID:parcel,parcel_id:parcel,county_fips:"13117",county_name:"Forsyth County",source_mode:"FORSYTH_OFFICIAL_NIGHTLY_PARCELID_ONLY_V1795",geometry_retained:false,owner_retained:false,address_retained:false,assessment_retained:false,raw_resale:false},materialization_status:"PENDING"}:null}).filter(Boolean);
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}}); let attempted=0;
  for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const {error}=await sb.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(error) throw error;attempted+=chunk.length;}
  return Response.json({complete:true,version:1795,total_ids:ids.length,offset,requested:limit,remote_records:qJson.features.length,attempted_stage:attempted,eof:offset+limit>=ids.length,first_id:slice[0],last_id:slice[slice.length-1]});
}catch(e){return Response.json({complete:false,version:1795,error:String((e as any)?.message||e)},{status:500});}});