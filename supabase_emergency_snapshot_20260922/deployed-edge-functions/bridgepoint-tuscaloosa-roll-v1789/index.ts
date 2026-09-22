import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { getDocumentProxy } from "npm:unpdf@1.8.1";
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="tusc-v1789-82d4a6c1", RUN="b8624844-7585-4cd7-8653-e3e3d4e7372c", CAND="deb9a154-f318-45e4-9e06-d3d3749332fa";
const PDFS=[
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-01-21.pdf",
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-22-30.pdf",
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-31.pdf",
"https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-32-45.pdf"];
const RE=/\b\d{2}-\d{2}-\d{2}-\d-\d{3}-\d{3}(?:\.\d{3})?\b/g;
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response("method",{status:405});
 const b=await req.json().catch(()=>({})); if(String(b.nonce||req.headers.get("x-bridgepoint-nonce")||"")!==NONCE) return new Response("unauthorized",{status:401});
 const idx=Math.max(0,Math.min(3,Number(b.file_index??0))); const pageStart=Math.max(1,Number(b.page_start??1)); const pageCount=Math.max(1,Math.min(120,Number(b.page_count??100)));
 const r=await fetch(PDFS[idx],{headers:{"user-agent":"BridgePointIntelligence/1.0 (public-assessment-roll-parser)"},signal:AbortSignal.timeout(60000)}); if(!r.ok) throw new Error(`PDF_${idx}_HTTP_${r.status}`);
 const data=new Uint8Array(await r.arrayBuffer()); const doc:any=await getDocumentProxy(data,{maxImageSize:16777216,disableFontFace:true,useSystemFonts:true});
 const pageEnd=Math.min(doc.numPages,pageStart+pageCount-1); const ids=new Set<string>(); let matches=0;
 for(let p=pageStart;p<=pageEnd;p++){const page=await doc.getPage(p); const tc=await page.getTextContent(); const text=(tc.items as any[]).map((x:any)=>String(x.str||"")).join(" "); const mm=text.match(RE)||[]; matches+=mm.length; for(const raw of mm) ids.add(raw.trim()); page.cleanup?.();}
 await doc.destroy?.();
 if(b.inspect_only) return new Response(JSON.stringify({complete:true,version:1792,file_index:idx,total_pages:doc.numPages,page_start:pageStart,page_end:pageEnd,matches,unique_ids:ids.size,sample:[...ids].slice(0,20)}),{headers:H});
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}}); const now=new Date().toISOString();
 const rows=[...ids].map(id=>({run_id:RUN,candidate_id:CAND,state_code:"AL",source_record_id:id,source_updated_at:now,payload:{parcel_id:id,property_number:id,county_fips:"01125",county_name:"Tuscaloosa County",state_code:"AL",source_mode:"[REDACTED_LONG_LITERAL]",source_file_index:idx,owner_retained:false,address_retained:false,assessment_retained:false,tax_retained:false,legal_description_retained:false,geometry_retained:false,raw_pdf_retained:false,raw_resale:false},materialization_status:"PENDING"}));
 let attempted=0; for(let i=0;i<rows.length;i+=400){const chunk=rows.slice(i,i+400); const q=await sb.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true}); if(q.error) throw q.error; attempted+=chunk.length;}
 return new Response(JSON.stringify({complete:true,version:1792,file_index:idx,total_pages:doc.numPages,page_start:pageStart,page_end:pageEnd,matches,unique_ids:ids.size,attempted_stage:attempted,eof:pageEnd>=doc.numPages}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1792,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});