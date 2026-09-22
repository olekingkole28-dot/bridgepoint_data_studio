import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = createClient(U, S, { auth: { persistSession: false, autoRefreshToken: false } });
const H = { "content-type": "application/json", "cache-control": "no-store" };
const V = 1088;
type J = Record<string, any>;

const T = (x: any, n = 4000) => String(x ?? "").trim().slice(0, n);
const out = (b: any, s = 200) => new Response(JSON.stringify(b), { status: s, headers: H });

async function auth(req: Request) {
  const token = req.headers.get("x-bridgepoint-worker-token") || "";
  if (token.length < 24) return false;
  const { data, error } = await db.schema("automation").from("geographic_expansion_worker_secret_v90").select("task_token").eq("singleton", true).maybeSingle();
  return !error && token === data?.task_token;
}

function csvEscape(v: any) {
  const s = String(v ?? "").replace(/\r?\n/g, " ").trim();
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [], field = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; }
        else quoted = false;
      } else field += ch;
    } else {
      if (ch === '"') quoted = true;
      else if (ch === ',') { row.push(field); field = ""; }
      else if (ch === '\n') { row.push(field.replace(/\r$/, "")); if (row.some(x => x.length)) rows.push(row); row = []; field = ""; }
      else field += ch;
    }
  }
  if (field.length || row.length) { row.push(field.replace(/\r$/, "")); if (row.some(x => x.length)) rows.push(row); }
  return rows;
}

async function completeChunk(results: J[]) {
  const { data, error } = await db.schema("automation").rpc("complete_census_geocoder_v1070", { p_results: results });
  if (error) throw new Error(`COMPLETE_RPC: ${error.message}`);
  return data as J;
}

async function complete(results: J[]) {
  const CHUNK = 250;
  const total = { complete: true, version: V, success: 0, failed: 0, ambiguous: 0, write_chunks: 0 };
  for (let i = 0; i < results.length; i += CHUNK) {
    const part = results.slice(i, i + CHUNK);
    const r = await completeChunk(part);
    total.success += Number(r?.success ?? 0);
    total.failed += Number(r?.failed ?? 0);
    total.ambiguous += Number(r?.ambiguous ?? 0);
    total.write_chunks++;
  }
  return total;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return out({ ok: false, version: V, error: "POST_REQUIRED" }, 405);
  if (!(await auth(req))) return out({ ok: false, version: V, error: "UNAUTHORIZED" }, 401);
  const body = await req.json().catch(() => ({}));
  const limit = Math.max(1, Math.min(Number(body.limit || 500), 1000));

  try {
    const { data: claimed, error: claimError } = await db.schema("automation").rpc("claim_census_geocoder_v1070", { p_limit: limit });
    if (claimError) throw new Error(`CLAIM_RPC: ${claimError.message}`);
    const tasks: J[] = Array.isArray(claimed?.tasks) ? claimed.tasks : [];
    if (!tasks.length) return out({ ok: true, version: V, claimed: 0, complete: true });

    const lines = tasks.map(t => [t.job_id, t.street, t.city, t.state, t.zip].map(csvEscape).join(","));
    const csv = lines.join("\n") + "\n";
    const form = new FormData();
    form.append("addressFile", new Blob([csv], { type: "text/csv" }), "bridgepoint_addresses.csv");
    form.append("benchmark", "Public_AR_Current");

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort("CENSUS_TIMEOUT"), 85000);
    let resp: Response;
    try {
      resp = await fetch("https://geocoding.geo.census.gov/geocoder/locations/addressbatch", { method: "POST", body: form, signal: controller.signal });
    } finally {
      clearTimeout(timeout);
    }

    const text = await resp.text();
    if (!resp.ok) {
      const failed = tasks.map(t => ({ job_id: t.job_id, match_indicator: "", match_type: "", error: `CENSUS_HTTP_${resp.status}:${T(text, 500)}` }));
      const completion = await complete(failed);
      return out({ ok: false, version: V, claimed: tasks.length, census_status: resp.status, completion }, 502);
    }

    const rows = parseCsv(text);
    const byId = new Map<string, string[]>();
    for (const row of rows) if (row[0]) byId.set(row[0].trim(), row);

    const results: J[] = tasks.map(t => {
      const row = byId.get(String(t.job_id));
      if (!row) return { job_id: t.job_id, match_indicator: "", match_type: "", error: "CENSUS_RESULT_MISSING" };
      const coords = String(row[5] || "").split(",");
      return {
        job_id: t.job_id,
        input_address: row[1] || t.address_text || "",
        match_indicator: row[2] || "",
        match_type: row[3] || "",
        matched_address: row[4] || "",
        longitude: coords[0]?.trim() || "",
        latitude: coords[1]?.trim() || "",
        tigerline_id: row[6] || "",
        tigerline_side: row[7] || ""
      };
    });

    const completion = await complete(results);
    return out({ ok: true, version: V, claimed: tasks.length, census_rows: rows.length, completion });
  } catch (e) {
    return out({ ok: false, version: V, error: T((e as any)?.message || e, 1500) }, 500);
  }
});
