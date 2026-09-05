import { createClient } from "npm:@supabase/supabase-js@2";
import * as XLSX from "npm:xlsx@0.18.5";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H = { "content-type": "application/json", "cache-control": "no-store" };
const V = 1849;

function clean(v: unknown): string {
  return String(v ?? "").replace(/\u0000/g, "").trim();
}

function isHttp(url: string): boolean {
  return /^https?:\/\//i.test(url);
}

function keyName(v: unknown): string {
  return clean(v).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}

function normalizedKeys(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) {
    const nk = keyName(k);
    if (nk) out[nk] = v;
  }
  return out;
}

function firstNonEmpty(row: Record<string, unknown>, keys: string[]): string {
  for (const k of keys) {
    const v = clean(row[k]);
    if (v) return v;
  }
  return "";
}

function projectRow(raw: Record<string, unknown>, meta: any, index: number): Record<string, unknown> | null {
  const row = normalizedKeys(raw);
  const configured = Array.isArray(meta?.parcel_id_fields) ? meta.parcel_id_fields.map(keyName).filter(Boolean) : [];
  const parcelKeys = configured.length ? configured : [
    "parcel_id", "parcelid", "parcel_number", "parcel_no", "parcel", "pin", "parcel_pin",
    "property_number", "property_no", "account", "account_no", "account_number", "tax_parcel_id",
    "realkey", "real_key", "map_parcel", "map_and_parcel", "mapparcel"
  ];
  const parcelId = firstNonEmpty(row, parcelKeys);
  if (!parcelId) return null;

  const out: Record<string, unknown> = {
    parcel_id: parcelId,
    property_number: parcelId,
    county_fips: clean(meta?.county_fips),
    county_name: clean(meta?.county_name),
    state_code: clean(meta?.state_code),
    source_mode: "BULK_TABULAR_PARCEL_ID_ONLY_V1849",
    _bridgepoint_source_record_id: parcelId,
    _bridgepoint_input_row: index,
    owner_retained: false,
    mailing_address_retained: false,
    valuation_retained: false,
    tax_retained: false,
    legal_description_retained: false,
    raw_row_retained: false,
    geometry_retained: false
  };

  const keep = Array.isArray(meta?.allowed_projection_fields) ? meta.allowed_projection_fields.map(keyName).filter(Boolean) : [];
  for (const k of keep) {
    if (row[k] != null && clean(row[k])) out[k] = row[k];
  }
  return out;
}

function firstSheetRows(wb: XLSX.WorkBook): Record<string, unknown>[] {
  const name = wb.SheetNames[0];
  if (!name) return [];
  return XLSX.utils.sheet_to_json(wb.Sheets[name], { defval: "", raw: false }) as Record<string, unknown>[];
}

function parseDelimited(text: string, delimiter: string): Record<string, unknown>[] {
  return firstSheetRows(XLSX.read(text, { type: "string", raw: false, FS: delimiter }));
}

function parseWorkbook(bytes: Uint8Array): Record<string, unknown>[] {
  return firstSheetRows(XLSX.read(bytes, { type: "array", raw: false }));
}

async function fetchRows(url: string, format: string): Promise<Record<string, unknown>[]> {
  if (!isHttp(url)) throw new Error("Bulk feeder requires a public HTTPS/HTTP download URL; FTP-only sources must expose an HTTPS gateway or mirror.");
  const r = await fetch(url, {
    redirect: "follow",
    headers: { "user-agent": "BridgePointIntelligence/1.0 (public-record bulk importer)" },
    signal: AbortSignal.timeout(90000)
  });
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${url}`);
  const f = format.toUpperCase();
  if (f.includes("XLS") || f.includes("SPREADSHEET")) return parseWorkbook(new Uint8Array(await r.arrayBuffer()));
  const text = await r.text();
  if (f.includes("TSV") || f.includes("TAB")) return parseDelimited(text, "\t");
  if (f.includes("PIPE")) return parseDelimited(text, "|");
  return parseDelimited(text, ",");
}

function supportedAccess(v: unknown): boolean {
  const a = clean(v).toUpperCase();
  return a.includes("CSV") || a.includes("TSV") || a.includes("SPREADSHEET") || a.includes("XLS") || a.includes("TABULAR") || a.includes("PIPE");
}

async function runTask(sb: any, t: any) {
  try {
    if (!supportedAccess(t.access_method)) throw new Error(`Unsupported bulk access method: ${t.access_method}`);
    const meta = t.candidate_metadata || {};
    const format = clean(meta.bulk_format || t.access_method || "CSV");
    const all = await fetchRows(String(t.source_url || ""), format);
    const offset = Math.max(0, Number(t.cursor?.offset || 0));
    const pageSize = Math.min(Math.max(Number(meta.bulk_page_size || 6000), 500), 10000);
    const slice = all.slice(offset, offset + pageSize);
    const projected = slice.map((r, i) => projectRow(r, meta, offset + i)).filter(Boolean) as Record<string, unknown>[];
    const deduped = [...new Map(projected.map((r) => [String(r._bridgepoint_source_record_id), r])).values()];
    const next = offset + slice.length;
    const done = next >= all.length;

    const st = await sb.rpc("bridgepoint_expansion_worker_stage_records_v90", {
      p_source_task_id: t.source_task_id,
      p_records: deduped,
      p_next_cursor: { offset: next, estimated_total_rows: all.length, pagination_mode: "BULK_TABULAR_V1849" },
      p_done: done,
      p_result: {
        bulk_tabular_feeder_version: V,
        input_rows: slice.length,
        staged_parcel_ids: deduped.length,
        rejected_rows_without_parcel_id: slice.length - projected.length,
        estimated_total_rows: all.length,
        pagination_mode: "BULK_TABULAR_V1849",
        privacy_projection: "PARCEL_ID_ONLY_UNLESS_EXPLICITLY_ALLOWED"
      }
    });
    if (st.error) throw st.error;
    return { task: t.source_task_id, state: t.state_code, records: deduped.length, input_rows: slice.length, next, total: all.length, done };
  } catch (e) {
    await sb.rpc("bridgepoint_expansion_worker_fail_task_v90", {
      p_source_task_id: t.source_task_id,
      p_error: String((e as any)?.message || e),
      p_detail: { bulk_tabular_feeder_version: V, source_url: t.source_url, access_method: t.access_method }
    });
    return { task: t.source_task_id, state: t.state_code, done: false, records: 0, error: String((e as any)?.message || e) };
  }
}

Deno.serve(async (req: Request) => {
  try {
    const b = await req.json().catch(() => ({}));
    const runId = clean(b.run_id);
    if (!runId) return new Response(JSON.stringify({ complete: false, version: V, error: "run_id is required; v1849 never claims from the global foundation queue" }), { status: 400, headers: H });

    const sb = createClient(U, S, { auth: { persistSession: false, autoRefreshToken: false } });
    const ok = await sb.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: String(b.task_token || "") });
    if (ok.error || ok.data !== true) return new Response(JSON.stringify({ complete: false, error: "Invalid task token" }), { status: 401, headers: H });

    const cl = await sb.rpc("bridgepoint_expansion_worker_claim_tasks_v90", {
      p_run_id: runId,
      p_limit: Math.min(Math.max(Number(b.limit || 1), 1), 4)
    });
    if (cl.error) throw cl.error;
    const tasks = cl.data?.tasks || [];
    if (tasks.some((t: any) => !supportedAccess(t.access_method))) {
      throw new Error("Explicit run contains a non-tabular task; refusing to consume it with v1849");
    }
    const results = await Promise.all(tasks.map((t: any) => runTask(sb, t)));
    return new Response(JSON.stringify({ complete: true, version: V, run_id: runId, claimed: tasks.length, records: results.reduce((n: number, x: any) => n + Number(x.records || 0), 0), results }), { headers: H });
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, version: V, error: String((e as any)?.stack || (e as any)?.message || e) }), { status: 400, headers: H });
  }
});
