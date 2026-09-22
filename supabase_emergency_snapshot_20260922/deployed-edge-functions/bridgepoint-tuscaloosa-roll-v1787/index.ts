import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { Buffer } from "node:buffer";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="tuscaloosa-v1787-91c6e334";
const RUN="4c01fc6f-fc75-4fca-9c22-89eec618cd23",CAND="deb9a154-f318-45e4-9e06-d3d3749332fa";
const URLS:any={
 "01-21":"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-01-21.pdf",
 "22-30":"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-22-30.pdf",
 "31":"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-31.pdf",
 "32-45":"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-32-45.pdf"
};
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));if(String(b.nonce||'')!==NONCE)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const part=String(b.part||'01-21');const url=URLS[part];if(!url)return new Response(JSON.stringify({complete:false,error:"INVALID_PART"}),{status:400,headers:H});
 const r=await fetch(url,{headers:{'user-agent':'BridgePointIntelligence/1.0 (official-assessment-roll-parcel-id-parser)'},signal:AbortSignal.timeout(60000)});if(!r.ok)throw new Error(`PDF_HTTP_${r.status}`);
 const buf=Buffer.from(await r.arrayBuffer());const mod:any=await import("npm:pdf-parse@1.1.1");const parse=mod.default||mod;const parsed=await parse(buf);const text=String(parsed.text||'');
 const rx=/\b63-\d{2}-\d{2}-\d{2}-\d-\d{3}-\d{3}\.\d{3}\b/g;const ids=new Set<string>(text.match(rx)||[]);
 if(b.count_only)return new Response(JSON.stringify({complete:true,version:1787,part,pages:parsed.numpages||null,pdf_bytes:buf.length,text_bytes:text.length,unique_parcel_ids:ids.size,sample:[...ids].slice(0,10)}),{headers:H});
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});const now=new Date().toISOString();const rows=[...ids].map(id=>({run_id:RUN,candidate_id:CAND,state_code:'AL',source_record_id:id,source_updated_at:now,payload:{parcel_id:id,county_fips:'01125',county_name:'Tuscaloosa County',state_code:'AL',source_mode:`TUSCALOOSA_2026_NUMERICAL_REAL_PROPERTY_${part}_PARCEL_ID_ONLY_V1787`,owner_retained:false,address_retained:false,valuation_retained:false,legal_description_retained:false,geometry_retained:false,raw_pdf_resale:false},materialization_status:'PENDING'}));
 let staged=0;for(let i=0;i<rows.length;i+=1000){const chunk=rows.slice(i,i+1000);const q=await s.schema('staging').from('geographic_source_records_v90').upsert(chunk,{onConflict:'candidate_id,source_record_id',ignoreDuplicates:true});if(q.error)throw q.error;staged+=chunk.length;}
 return new Response(JSON.stringify({complete:true,version:1787,part,pages:parsed.numpages||null,unique_parcel_ids:ids.size,staged}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1787,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});
