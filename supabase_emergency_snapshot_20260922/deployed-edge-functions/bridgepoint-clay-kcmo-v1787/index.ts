import { createClient } from "jsr:@supabase/supabase-js@2";
const NONCE="clay-v1787-6c31a9e4-2f5b";
const BASE="https://data.kcmo.org/resource/6g4y-sh3m.json";
const CANDIDATE="e9cfe02c-a72f-4181-bb1e-38a18c4835e8";
const RUN="2dced317-763c-40dc-9e22-a0f6bc81b876";
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response("method",{status:405});
 const body=await req.json().catch(()=>({})); if(body.nonce!==NONCE) return new Response("unauthorized",{status:401});
 const offset=Math.max(0,Number(body.offset??0)), limit=Math.min(2000,Math.max(1,Number(body.limit??2000)));
 const u=new URL(BASE);u.searchParams.set("$select","objectid,apn");u.searchParams.set("$where","apn like 'CL%' AND apn <> 'CL'");u.searchParams.set("$order","objectid");u.searchParams.set("$limit",String(limit));u.searchParams.set("$offset",String(offset));
 const r=await fetch(u); if(!r.ok) throw new Error(`Socrata ${r.status}: ${await r.text()}`); const data=await r.json(); if(!Array.isArray(data)) throw new Error("non-array response");
 const rows=data.map((x:any)=>{const apn=String(x.apn??"").trim();return apn.length>2?{run_id:RUN,candidate_id:CANDIDATE,state_code:"MO",source_record_id:apn,payload:{objectid:x.objectid,apn,parcel_id:apn,county:"Clay County",county_name:"Clay County",municipality:"Kansas City",source_provider:"City of Kansas City, Missouri / Open Data KC",source_resource_id:"6g4y-sh3m",privacy_projection_v1787:true},materialization_status:"PENDING"}:null}).filter(Boolean);
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}}); let attempted=0;
 for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const {error}=await sb.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(error) throw error;attempted+=chunk.length;}
 return Response.json({complete:true,version:1787,offset,requested:limit,remote_records:data.length,attempted_stage:attempted,eof:data.length<limit});
}catch(e){return Response.json({complete:false,version:1787,error:String(e?.message||e)},{status:500});}});