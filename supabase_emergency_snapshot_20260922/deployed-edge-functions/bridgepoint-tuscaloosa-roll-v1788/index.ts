import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { Buffer } from "node:buffer";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NONCE="tusc-v1788-8d4f2c71";
const RUN="4c01fc6f-fc75-4fca-9c22-89eec618cd23",CAND="deb9a154-f318-45e4-9e06-d3d3749332fa";
const PDFS=[
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-01-21.pdf",
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-22-30.pdf",
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-31.pdf",
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-32-45.pdf"];
const H={"content-type":"application/json","cache-control":"no-store"};
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));if(String(b.nonce||req.headers.get("x-bridgepoint-nonce")||"")!==NONCE)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const doc=Math.max(0,Math.min(3,Number(b.doc??0)));const r=await fetch(PDFS[doc],{headers:{"user-agent":"BridgePointIntelligence/1.0 (public-assessment-roll-parser)"},signal:AbortSignal.timeout(60000)});if(!r.ok)throw new Error(`PDF_HTTP_${r.status}`);
 const buf=Buffer.from(await r.arrayBuffer());const mod:any=await import("npm:pdf-parse@1.1.1");const parse=mod.default||mod;const parsed=await parse(buf);const text=String(parsed.text||"");
 const broad=text.match(/\b\d{2}(?:-\d{1,4}){3,8}(?:\.\d{1,4})?\b/g)||[];const uniq=[...new Set(broad.map((x:string)=>x.trim()))];
 if(b.count_only)return new Response(JSON.stringify({complete:true,version:1788,doc,pages:parsed.numpages||null,text_bytes:text.length,broad_matches:broad.length,unique_candidates:uniq.length,sample:uniq.slice(0,80)}),{headers:H});
 const ids=uniq.filter((id:string)=>/^\d{2}-\d{2}-\d{2}-\d-\d{3}-\d{3}(?:\.\d{3})?$/.test(id));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});const rows=ids.map((id:string)=>({run_id:RUN,candidate_id:CAND,state_code:"AL",source_record_id:id,payload:{parcel_id:id,county_fips:"01125",county_name:"Tuscaloosa County",state_code:"AL",source_mode:"[REDACTED_LONG_LITERAL]",source_document_index:doc,owner_retained:false,address_retained:false,assessment_retained:false,tax_retained:false,legal_description_retained:false,geometry_retained:false,raw_resale:false},materialization_status:"PENDING"}));
 let staged=0;for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const q=await s.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(q.error)throw q.error;staged+=chunk.length;}
 return new Response(JSON.stringify({complete:true,version:1788,doc,pages:parsed.numpages||null,parsed_ids:ids.length,staged}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1788,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});