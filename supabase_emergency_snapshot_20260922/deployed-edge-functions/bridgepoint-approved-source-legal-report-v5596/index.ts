import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { PDFDocument, StandardFonts, rgb } from "npm:pdf-lib@1.17.1";
const ALLOWED=new Set(["https://bridgepointintelligence.online","https://www.bridgepointintelligence.online","https://olekingkole28-dot.github.io"]);
const safeOrigin=(o:string)=>ALLOWED.has(o)?o:"https://bridgepointintelligence.online";
const ascii=(v:unknown)=>String(v??"").normalize("NFKD").replace(/[^\x20-\x7E]/g," ").replace(/\s+/g," ").trim();
const wrap=(s:string,max=92)=>{const w=ascii(s).split(" "),out:string[]=[];let line="";for(const x of w){if(!x)continue;const n=line?line+" "+x:x;if(n.length>max){if(line)out.push(line);line=x}else line=n}if(line)out.push(line);return out.length?out:[""];};
Deno.serve(async(req:Request)=>{
 const origin=req.headers.get("origin")||"",cors={"access-control-allow-origin":safeOrigin(origin),"vary":"Origin","access-control-allow-methods":"GET,OPTIONS","access-control-allow-headers":"content-type","x-content-type-options":"nosniff","referrer-policy":"strict-origin-when-cross-origin"};
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="GET")return new Response("GET required",{status:405,headers:cors});
 if(origin&&!ALLOWED.has(origin))return new Response("Origin not allowed",{status:403,headers:{...cors,"cache-control":"no-store"}});
 try{
  const probe=new URL(req.url).searchParams.get("probe")==="1";
  const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:ops}=await db.schema("automation").from("autonomous_ops_state_v5590").select("mode,last_tick_at").eq("singleton",true).maybeSingle();
  let refresh:any={attempted:false,completed:false,mode:ops?.mode??"UNKNOWN"};
  if(ops?.mode==="GREEN"){refresh.attempted=true;const rr=await db.schema("automation").rpc("refresh_legal_evidence_manifest_v1840");refresh.completed=!rr.error;refresh.error=rr.error?.message??null}
  const {data:rows,error}=await db.schema("automation").from("legal_evidence_manifest_v1840")
   .select("source_system,source_key,source_name,provider,source_url,evidence_url,state_code,source_category,access_method,refresh_frequency,rights_status,activation_status,allowed_use_scope,legal_basis,license_note,last_checked_at,last_successful_pull_at,total_records_ingested,source_record_count,snapshot_at")
   .eq("activation_status","APPROVED").eq("rights_status","PASS").order("state_code",{ascending:true}).order("source_name",{ascending:true}).limit(5000);
  if(error)throw error;
  const {count:reviewCount}=await db.schema("automation").from("legal_evidence_manifest_v1840").select("source_key",{count:"exact",head:true}).neq("rights_status","PASS");
  const list=rows??[],latest=list.reduce((m:any,r:any)=>!r.snapshot_at?m:(!m||new Date(r.snapshot_at)>new Date(m)?r.snapshot_at:m),null);
  const pdf=await PDFDocument.create();pdf.setTitle("BridgePoint Intelligence - Approved Source and Legal Evidence Register");pdf.setAuthor("BridgePoint Intelligence");pdf.setSubject("Source provenance, legal basis, allowed use scope, evidence links, and verification status");
  const regular=await pdf.embedFont(StandardFonts.Helvetica),bold=await pdf.embedFont(StandardFonts.HelveticaBold);
  const W=612,H=792,M=42;let page:any,y=0,pageNo=0;
  const addPage=()=>{page=pdf.addPage([W,H]);pageNo++;y=H-M;page.drawText("BRIDGEPOINT INTELLIGENCE",{x:M,y,font:bold,size:9,color:rgb(.15,.55,.68)});page.drawText("Approved Source & Legal Evidence Register",{x:M,y:y-17,font:bold,size:16,color:rgb(.05,.12,.16)});page.drawText("Page "+pageNo,{x:W-M-45,y,font:regular,size:8,color:rgb(.35,.43,.47)});y-=42};
  const line=(t:string,size=8,indent=0,isBold=false,color=rgb(.12,.18,.21))=>{if(y<M+30)addPage();page.drawText(ascii(t),{x:M+indent,y,font:isBold?bold:regular,size,color});y-=size+3};
  const block=(label:string,value:unknown)=>{const v=ascii(value);if(!v)return;for(const [i,l] of wrap(label+": "+v,93).entries())line(l,7.2,i?12:0,i===0)};
  addPage();line("Generated: "+new Date().toISOString(),8,0,true);line("Approved + rights-pass sources: "+list.length,8,0,true);line("Sources outside PASS status: "+Number(reviewCount||0)+" (excluded from approved-source listing)",8);line("Manifest snapshot: "+ascii(latest||"unavailable"),8);line("Pressure mode: "+ascii(ops?.mode||"UNKNOWN"),8);line(refresh.completed?"Manifest refreshed during this request.":refresh.attempted?"Manifest refresh attempted but did not complete.":"Manifest refresh deferred by pressure governor; using latest persisted legal manifest.",8);y-=8;
  for(const [idx,r] of list.entries()){if(y<M+125)addPage();line((idx+1)+". "+ascii(r.source_name||r.source_key),9,0,true,rgb(.04,.23,.30));block("Provider",r.provider);block("Jurisdiction",r.state_code||"US / multi-jurisdiction");block("Category",r.source_category);block("Access method",r.access_method);block("Allowed use",r.allowed_use_scope);block("Legal basis",r.legal_basis);block("License / legal note",r.license_note);block("Source URL",r.source_url);block("Evidence URL",r.evidence_url);block("Last checked",r.last_checked_at);block("Last successful pull",r.last_successful_pull_at);const n=r.total_records_ingested??r.source_record_count;if(n!=null)block("Records represented",String(n));block("Manifest snapshot",r.snapshot_at);y-=7}
  if(y<M+100)addPage();line("Interpretation notes",10,0,true);for(const t of ["Only activation_status=APPROVED and rights_status=PASS records are listed as approved sources.","Review-required, unknown, disabled, or quarantined sources are not represented as legally approved.","This register documents BridgePoint's recorded provenance and rights decisions; it is not independent legal advice.","The register is generated from BridgePoint's live legal-evidence manifest and is pressure-governor aware."])for(const l of wrap(t,94))line(l,7.4);
  const bytes=await pdf.save();
  if(probe)return new Response(JSON.stringify({ok:true,version:5596,pdf_bytes:bytes.length,pages:pdf.getPageCount(),approved_sources:list.length,non_pass_sources:Number(reviewCount||0),manifest_snapshot:latest,pressure_mode:ops?.mode??"UNKNOWN",refresh}),{status:200,headers:{...cors,"content-type":"application/json","cache-control":"no-store"}});
  return new Response(bytes,{status:200,headers:{...cors,"content-type":"application/pdf","content-disposition":"inline; filename=\"bridgepoint-approved-source-legal-register.pdf\"","cache-control":"public,max-age=300,s-maxage=900,stale-while-revalidate=3600","x-bridgepoint-legal-report":"v5596","x-bridgepoint-approved-source-count":String(list.length),"x-bridgepoint-manifest-snapshot":String(latest||"")}});
 }catch(e){return new Response(JSON.stringify({complete:false,error:"LEGAL_REPORT_UNAVAILABLE",detail:String((e as any)?.message??e)}),{status:500,headers:{...cors,"content-type":"application/json","cache-control":"no-store"}})}
});