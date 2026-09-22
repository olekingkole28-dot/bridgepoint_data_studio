import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { getDocumentProxy } from "npm:unpdf@1.8.1";
declare const EdgeRuntime:{waitUntil(p:Promise<unknown>):void};
const NONCE="oceola-v1851-7e42d19c";
const RUN="163f9ea8-84ac-44c5-9351-af4d1940ed4a";
const CAND="4951e99a-db6b-483d-9a0e-a09f4952081a";
const PDF="https://static1.squarespace.com/static/65a924f5055c4b23f4490bb5/t/69cc2c65e5f73d2b7e276bbf/1774988396881/2026%2BAssessment%2BRoll.pdf";
const RE=/\b4707-\d{2}-\d{3}-\d{3}\b/g;
const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}});
const SELF=()=>`${Deno.env.get("SUPABASE_URL")}/functions/v1/bridgepoint-oceola-roll-v1851`;
async function processRange(start:number,stop:number,count:number,shard:string){
 const r=await fetch(PDF,{redirect:"follow",signal:AbortSignal.timeout(60000)});if(!r.ok)throw new Error(`PDF_HTTP_${r.status}`);
 const data=new Uint8Array(await r.arrayBuffer());const doc:any=await getDocumentProxy(data,{maxImageSize:16777216,disableFontFace:true,useSystemFonts:true});
 const end=Math.min(doc.numPages,stop,start+count-1);const ids=new Set<string>();
 for(let p=start;p<=end;p++){const page=await doc.getPage(p);const tc=await page.getTextContent();const text=(tc.items as any[]).map((x:any)=>String(x.str||"")).join(" ");for(const m of text.match(RE)||[])ids.add(m);page.cleanup?.();}
 await doc.destroy?.();
 const rows=[...ids].map(id=>({run_id:RUN,candidate_id:CAND,state_code:"MI",source_record_id:id,source_updated_at:"2026-03-31T19:23:00Z",payload:{parcel_id:id,property_number:id,county_fips:"26093",county_name:"Livingston County",municipality_name:"Oceola Township",state_code:"MI",source_mode:"OCEOLA_2026_FINAL_ASSESSMENT_ROLL_PARCEL_ID_ONLY_V1851",owner_retained:false,address_retained:false,assessment_retained:false,tax_retained:false,legal_description_retained:false,geometry_retained:false,raw_pdf_retained:false,personal_property:false},materialization_status:"PENDING"}));
 for(let i=0;i<rows.length;i+=400){const q=await sb.schema("staging").from("geographic_source_records_v90").upsert(rows.slice(i,i+400),{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(q.error)throw q.error;}
 const m=await sb.rpc("bridgepoint_materialize_candidate_parcel_ids_v1792",{p_candidate_id:CAND,p_limit:8000});if(m.error)throw m.error;
 const q=await sb.schema("automation").from("geographic_source_candidates_v86").select("metadata").eq("candidate_id",CAND).single();if(!q.error){await sb.schema("automation").from("geographic_source_candidates_v86").update({metadata:{...(q.data?.metadata||{}),[`oceola_shard_${shard}_last_page_v1851`]:end,[`oceola_shard_${shard}_stop_v1851`]:stop,[`oceola_shard_${shard}_status_v1851`]:end>=stop?"EOF":"RUNNING",[`oceola_shard_${shard}_updated_at_v1851`]:new Date().toISOString()}}).eq("candidate_id",CAND);}
 if(end<stop){const z=await fetch(SELF(),{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({nonce:NONCE,auto:true,shard,page_start:end+1,page_stop:stop,page_count:count})});if(!z.ok)throw new Error(`SELF_HTTP_${z.status}`);}
 return {page_start:start,page_end:end,page_stop:stop,unique_ids:ids.size,materialize:m.data};
}
Deno.serve(async(req:Request)=>{try{if(req.method!=="POST")return new Response("method",{status:405});const b=await req.json().catch(()=>({}));if(String(b.nonce||"")!==NONCE)return new Response("unauthorized",{status:401});const start=Math.max(1,Number(b.page_start||1)),stop=Math.max(start,Math.min(1664,Number(b.page_stop||1664))),count=Math.max(1,Math.min(50,Number(b.page_count||40))),shard=String(b.shard||"x").replace(/[^a-zA-Z0-9_-]/g,"").slice(0,16);if(b.auto){EdgeRuntime.waitUntil(processRange(start,stop,count,shard));return new Response(JSON.stringify({complete:true,queued:true,version:1851,shard,page_start:start,page_stop:stop}),{headers:{"content-type":"application/json"}});}const out=await processRange(start,stop,count,shard);return new Response(JSON.stringify({complete:true,version:1851,...out}),{headers:{"content-type":"application/json"}});}catch(e){return new Response(JSON.stringify({complete:false,version:1851,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:{"content-type":"application/json"}})}});