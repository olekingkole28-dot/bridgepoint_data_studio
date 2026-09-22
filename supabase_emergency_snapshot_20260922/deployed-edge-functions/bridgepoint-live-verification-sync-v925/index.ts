import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
const VERSION = 926;
const RAW_RECEIPT = "https://raw.githubusercontent.com/olekingkole28-dot/bridgepoint-live/main/live-verification-status-v926.json";
const RUNS_API = "https://api.github.com/repos/olekingkole28-dot/bridgepoint-live/actions/workflows/verify-live-v926.yml/runs?per_page=10";
const H = { "content-type": "application/json", "cache-control": "no-store" };

async function authenticated(token: string) {
  const a = await sb.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: token });
  return !a.error && a.data === true;
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ complete: false, version: VERSION, error: "POST required" }), { status: 405, headers: H });
    }
    const body = await req.json().catch(() => ({}));
    const token = String(body.task_token || req.headers.get("x-bridgepoint-token") || "");
    if (!(await authenticated(token))) {
      return new Response(JSON.stringify({ complete: false, version: VERSION, error: "invalid task token" }), { status: 401, headers: H });
    }

    const receiptRes = await fetch(`${RAW_RECEIPT}?ts=${Date.now()}`, {
      headers: { "accept": "application/json", "user-agent": "BridgePointIntelligence/1.0", "cache-control": "no-cache" },
      signal: AbortSignal.timeout(15000),
    });
    if (receiptRes.status === 404) {
      return new Response(JSON.stringify({ complete: true, version: VERSION, synced: false, reason: "RECEIPT_NOT_READY" }), { status: 200, headers: H });
    }
    if (!receiptRes.ok) throw new Error(`receipt HTTP ${receiptRes.status}`);
    const evidence = await receiptRes.json();

    if (evidence?.status !== "VERIFIED" || Number(evidence?.verifier_version || 0) < 926 || Number(evidence?.property_twin_release || 0) < 922) {
      throw new Error("receipt policy mismatch");
    }
    const triggerSha = String(evidence?.trigger_sha || "");
    if (!/^[0-9a-f]{40}$/i.test(triggerSha)) throw new Error("receipt trigger SHA missing/invalid");

    const runsRes = await fetch(RUNS_API, {
      headers: { "accept": "application/vnd.github+json", "x-github-api-version": "2022-11-28", "user-agent": "BridgePointIntelligence/1.0" },
      signal: AbortSignal.timeout(15000),
    });
    if (!runsRes.ok) throw new Error(`GitHub Actions API HTTP ${runsRes.status}`);
    const runs = await runsRes.json();
    const matched = Array.isArray(runs?.workflow_runs)
      ? runs.workflow_runs.find((r: any) => r?.head_sha === triggerSha && r?.status === "completed" && r?.conclusion === "success")
      : null;
    if (!matched) {
      return new Response(JSON.stringify({ complete: true, version: VERSION, synced: false, reason: "NO_MATCHING_SUCCESSFUL_WORKFLOW_RUN", trigger_sha: triggerSha }), { status: 200, headers: H });
    }

    const rec = await sb.rpc("bridgepoint_record_external_verification_v925", {
      p_task_token: token,
      p_evidence: evidence,
      p_source_url: RAW_RECEIPT,
    });
    if (rec.error) throw rec.error;

    return new Response(JSON.stringify({
      complete: true,
      version: VERSION,
      synced: true,
      workflow_run_id: matched.id,
      workflow_event: matched.event,
      workflow_head_sha: matched.head_sha,
      recorded: rec.data,
    }), { status: 200, headers: H });
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, version: VERSION, error: String((e as any)?.message || e) }), { status: 500, headers: H });
  }
});
