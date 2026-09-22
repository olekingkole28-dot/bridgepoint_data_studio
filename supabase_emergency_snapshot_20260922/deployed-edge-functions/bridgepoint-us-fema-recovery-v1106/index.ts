import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
function clamp(value: number, min: number, max: number) { return Math.max(min, Math.min(max, value)); }
async function fetchJsonWithRetry(url: URL): Promise<any> {
  let last = "";
  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      const res = await fetch(url.toString(), { headers: { accept: "application/json", "user-agent": "BridgePointIntelligence/1.0 national-fema-recovery-ingest" } });
      if (res.ok) return await res.json();
      last = `HTTP ${res.status}: ${(await res.text()).slice(0, 500)}`;
      if (![429,500,502,503,504].includes(res.status)) throw new Error(last);
    } catch (e) { last = e instanceof Error ? e.message : String(e); }
    if (attempt < 5) await new Promise((r) => setTimeout(r, Math.min(8000, attempt * 1200)));
  }
  throw new Error(last || "source request failed");
}
function rowsFromPayload(payload: any): Record<string, unknown>[] {
  const candidates = [payload?.RegistrationIntakeIndividualsHouseholdPrograms,payload?.registrationIntakeIndividualsHouseholdPrograms,payload?.RegistrationIntakeIndividualsHouseholdProgram,payload?.registrationIntakeIndividualsHouseholdProgram];
  for (const c of candidates) if (Array.isArray(c)) return c;
  return Array.isArray(payload) ? payload : [];
}
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ complete:false,error:"method_not_allowed" },405);
  try {
    const body = await req.json().catch(() => ({}));
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) throw new Error("Supabase server credentials unavailable");
    const db = createClient(supabaseUrl,serviceKey,{ auth:{ persistSession:false,autoRefreshToken:false } });
    const { data:secret,error:secretError } = await db.schema("automation").from("fema_recovery_secret_v1105").select("task_token").eq("singleton",true).maybeSingle();
    const supplied = String(body?.task_token ?? "");
    if (secretError || !secret?.task_token || supplied !== secret.task_token) return json({ complete:false,error:"unauthorized" },401);

    const pageSize = clamp(Number(body?.page_size ?? 1000),1,1000);
    const maxPages = clamp(Number(body?.max_pages ?? 20),1,20);
    let offset = Math.max(Number(body?.start_offset ?? 0),0);
    let totalSeen=0,totalInserted=0,statesSeen=0;
    let hasMore=false;

    for (let page=0; page<maxPages; page++) {
      const url = new URL("https://www.fema.gov/api/open/v2/RegistrationIntakeIndividualsHouseholdPrograms");
      url.searchParams.set("$top",String(pageSize));
      url.searchParams.set("$skip",String(offset));
      const rows = rowsFromPayload(await fetchJsonWithRetry(url));
      hasMore = rows.length === pageSize;
      const nextOffset = offset + rows.length;
      const { data:result,error:ingestError } = await db.rpc("ingest_us_fema_recovery_national_v1106",{ p_rows:rows,p_next_offset:hasMore?nextOffset:0,p_has_more:hasMore });
      if (ingestError) throw ingestError;
      totalSeen += Number(result?.seen ?? rows.length);
      totalInserted += Number(result?.inserted ?? 0);
      statesSeen = Math.max(statesSeen,Number(result?.states_seen ?? 0));
      offset = nextOffset;
      if (!hasMore || rows.length===0) break;
    }

    const { data:coverage,error:coverageError } = await db.rpc("sync_fema_recovery_state_coverage_v1108");
    if (coverageError) throw coverageError;
    statesSeen = Math.max(statesSeen,Number(coverage?.states ?? 0));

    return json({ complete:true,source_code:"FEMA_IHP_RECOVERY_US_V1106",total_seen:totalSeen,total_inserted:totalInserted,states_seen:statesSeen,next_offset:hasMore?offset:0,has_more:hasMore,state_coverage_synced:true,truth_boundary:"AGGREGATED_NON_PII_CONTEXT_ONLY" });
  } catch (e) {
    return json({ complete:false,error:e instanceof Error ? e.message : String(e) },500);
  }
});