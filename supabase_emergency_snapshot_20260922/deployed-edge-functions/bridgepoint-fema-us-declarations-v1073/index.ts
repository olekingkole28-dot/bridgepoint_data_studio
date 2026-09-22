import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Obj = Record<string, unknown>;
const FIELDS = [
  "id","state","hash","femaDeclarationString","disasterNumber","declarationType","declarationDate","fyDeclared",
  "incidentType","designatedIncidentTypes","declarationTitle","incidentBeginDate","incidentEndDate","disasterCloseoutDate",
  "lastIAFilingDate","ihProgramDeclared","iaProgramDeclared","paProgramDeclared","hmProgramDeclared","tribalRequest",
  "fipsStateCode","fipsCountyCode","placeCode","designatedArea","declarationRequestNumber","incidentId","region","lastRefresh"
];

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "Content-Type": "application/json", "Cache-Control": "no-store" } });
}
function bounded(v: unknown, fallback: number, min: number, max: number) {
  const n = Number(v); return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.trunc(n))) : fallback;
}
function camelToSnake(v: string) { return v.replace(/(.)([A-Z][a-z]+)/g,"$1_$2").replace(/([a-z0-9])([A-Z])/g,"$1_$2").toLowerCase(); }
async function readBody(req: Request): Promise<Obj> { const t=await req.text(); if(!t.trim()) return {}; const x=JSON.parse(t); if(!x||typeof x!=="object"||Array.isArray(x)) throw new Error("JSON object required"); return x as Obj; }
function urlFor(state: string, skip: number, top: number) {
  const q = new URLSearchParams();
  q.set("$filter", `state eq '${state}' and declarationDate ge '2000-01-01T00:00:00.000Z'`);
  q.set("$select", FIELDS.join(",")); q.set("$orderby","id asc"); q.set("$top",String(top)); q.set("$skip",String(skip));
  if(skip===0) q.set("$count","true");
  return `https://www.fema.gov/api/open/v2/DisasterDeclarationsSummaries?${q}`;
}
async function fetchJson(url: string) {
  let last: unknown;
  for(let i=0;i<3;i++) {
    try {
      const r=await fetch(url,{headers:{Accept:"application/json","User-Agent":"BridgePoint-FEMA-US-V1074/1.0"},signal:AbortSignal.timeout(35000)});
      const text=await r.text(); if(!r.ok) throw new Error(`OpenFEMA HTTP ${r.status}: ${text.slice(0,800)}`);
      const j=JSON.parse(text); if(!j||typeof j!=="object"||Array.isArray(j)) throw new Error("Unexpected OpenFEMA response"); return j as Obj;
    } catch(e) { last=e; if(i<2) await new Promise(res=>setTimeout(res,750*(i+1))); }
  }
  throw last instanceof Error ? last : new Error(String(last));
}
function normalize(row: Obj): Obj {
  const out: Obj = { source_dataset_key:"fema_disaster_declarations_2000_present", source_record_id:String(row.id ?? row.hash ?? crypto.randomUUID()), record_type:"FEMA_DISASTER_DECLARATION_AREA" };
  for(const f of FIELDS) { if(f==="id") continue; const v=row[f]; if(v!==null&&v!==undefined&&v!=="") out[camelToSnake(f)]=v; }
  return out;
}

Deno.serve(async (req: Request) => {
  if(req.method==="OPTIONS") return new Response("ok",{headers:CORS_HEADERS});
  if(req.method!=="POST") return response({complete:false,error:"POST required"},405);
  const started=Date.now(); let workerId:string|null=null; let state:string|null=null;
  try {
    const body=await readBody(req); const token=String(body.task_token ?? "");
    const url=Deno.env.get("SUPABASE_URL"), key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if(!url||!key) throw new Error("Supabase runtime credentials unavailable");
    const sb=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data:authorized,error:authErr}=await sb.rpc("authorize_fema_scheduler_v1073",{p_token:token});
    if(authErr||authorized!==true) return response({complete:false,status:"unauthorized"},401);
    workerId=crypto.randomUUID();
    const {data:claim,error:claimErr}=await sb.rpc("claim_fema_us_declaration_state_v1073",{p_worker_id:workerId});
    if(claimErr) throw new Error(`claim failed: ${claimErr.message}`);
    if(!claim||claim.complete===true) return response({complete:true,status:"nothing_due",duration_ms:Date.now()-started});
    state=String(claim.state_code); let offset=Number(claim.offset ?? 0);
    const batchSize=bounded(body.batch_size,250,25,250), maxPages=bounded(body.max_pages,4,1,6); const pages:Obj[]=[];
    for(let page=1;page<=maxPages;page++) {
      const json=await fetchJson(urlFor(state,offset,batchSize));
      const rows=json.DisasterDeclarationsSummaries; if(!Array.isArray(rows)) throw new Error("OpenFEMA omitted DisasterDeclarationsSummaries");
      const normalized=(rows as Obj[]).map(normalize);
      let ingest:Obj={records_new:0,records_updated:0,records_duplicate:0};
      if(normalized.length) {
        const {data,error}=await sb.rpc("bridgepoint_ingest_fema_lean_batch",{p_dataset_key:"fema_disaster_declarations_2000_present",p_records:normalized,p_run_type:"US_STATE_REFRESH_V1074"});
        if(error) throw new Error(`ingest failed: ${error.message}`); ingest=(data ?? {}) as Obj;
      }
      const received=rows.length, next=offset+received, done=received<batchSize;
      const {data:update,error:updateErr}=await sb.rpc("complete_fema_us_declaration_page_v1073",{
        p_worker_id:workerId,p_state_code:state,p_next_offset:next,p_page_received:received,
        p_records_new:Number(ingest.records_new??0),p_records_updated:Number(ingest.records_updated??0),p_records_duplicate:Number(ingest.records_duplicate??0),p_complete:done,p_error:null
      });
      if(updateErr) throw new Error(`checkpoint failed: ${updateErr.message}`);
      pages.push({page,offset,received,new:ingest.records_new??0,updated:ingest.records_updated??0,duplicate:ingest.records_duplicate??0,complete:done});
      offset=next;
      if(done) {
        await sb.rpc("reconcile_fema_us_declaration_truth_v1073");
        return response({complete:true,status:"state_cycle_completed",state_code:state,pages,duration_ms:Date.now()-started,checkpoint:update,worker_version:1074});
      }
    }
    const {data:release,error:releaseErr}=await sb.rpc("release_fema_us_declaration_state_v1074",{p_worker_id:workerId,p_state_code:state});
    if(releaseErr) throw new Error(`release failed: ${releaseErr.message}`);
    return response({complete:false,status:"state_checkpointed",state_code:state,next_offset:offset,pages,release,duration_ms:Date.now()-started,worker_version:1074});
  } catch(e) {
    const message=e instanceof Error?e.message:String(e);
    try {
      if(workerId&&state) {
        const url=Deno.env.get("SUPABASE_URL"), key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if(url&&key) { const sb=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}}); await sb.rpc("complete_fema_us_declaration_page_v1073",{p_worker_id:workerId,p_state_code:state,p_next_offset:0,p_page_received:0,p_records_new:0,p_records_updated:0,p_records_duplicate:0,p_complete:false,p_error:message.slice(0,4000)}); }
      }
    } catch {}
    return response({complete:false,status:"failed",state_code:state,error:message,duration_ms:Date.now()-started,worker_version:1074},500);
  }
});