import { createClient } from "npm:@supabase/supabase-js@2";

type Cursor = { refreshed_on: string; credential: string };
const DATASET = "5r9m-qgni";
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json" },
});
const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, n));
const esc = (s: string) => s.replaceAll("'", "''");

function adminKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) throw new Error("Supabase server key unavailable");
  const key = Object.values(JSON.parse(raw)).find((value) =>
    typeof value === "string" && value.length > 0
  );
  if (!key) throw new Error("Supabase server key unavailable");
  return key as string;
}

const url = Deno.env.get("SUPABASE_URL");
if (!url) throw new Error("SUPABASE_URL unavailable");
const db = createClient(url, adminKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await db.rpc(name, args);
  if (error) throw new Error(`${name}: ${error.message}`);
  return data as T;
}

async function fetchRows(cursor: Cursor, limit: number): Promise<Record<string, unknown>[]> {
  const endpoint = new URL(`https://data.ct.gov/resource/${DATASET}.json`);
  endpoint.searchParams.set("$order", "recordrefreshedon ASC,fullcredentialcode ASC");
  endpoint.searchParams.set("$limit", String(limit));
  endpoint.searchParams.set("$where", cursor.credential
    ? `(recordrefreshedon > '${esc(cursor.refreshed_on)}' OR (recordrefreshedon = '${esc(cursor.refreshed_on)}' AND fullcredentialcode > '${esc(cursor.credential)}'))`
    : `recordrefreshedon > '${esc(cursor.refreshed_on)}'`);

  let message = "";
  for (let attempt = 1; attempt <= 5; attempt++) {
    const response = await fetch(endpoint, { headers: {
      accept: "application/json",
      "user-agent": "BridgePoint-Intelligence/CT-HIC-Registry-V85",
      ...(Deno.env.get("SOCRATA_APP_TOKEN")
        ? { "x-app-token": Deno.env.get("SOCRATA_APP_TOKEN")! }
        : {}),
    }});
    if (response.ok) {
      const body = await response.json();
      if (!Array.isArray(body)) throw new Error("Socrata response was not an array");
      return body;
    }
    message = `HTTP ${response.status}: ${(await response.text()).slice(0, 500)}`;
    if (![429, 500, 502, 503, 504].includes(response.status)) break;
    await new Promise((resolve) => setTimeout(resolve, attempt * 1500));
  }
  throw new Error(`Socrata request failed: ${message}`);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ complete: false, status: "method_not_allowed" }, 405);
  }
  let claimed = false;
  try {
    const body = await request.json();
    const state = await rpc<Record<string, unknown>>("bridgepoint_ct_hic_refresh_state_v85");
    claimed = state.due === true;
    if (!state.task_token || String(body?.task_token ?? "") !== state.task_token) {
      return json({ complete: false, status: "unauthorized" }, 401);
    }
    if (!state.enabled) return json({ complete: true, status: "source_disabled" });
    if (!state.due) {
      return json({ complete: true, status: "not_due", next_scheduled_check_at: state.next_scheduled_check_at });
    }

    let cursor: Cursor = { refreshed_on: "1970-01-01T00:00:00.000", credential: "" };
    if (typeof state.last_watermark === "string" && state.last_watermark) {
      try { cursor = JSON.parse(state.last_watermark); } catch { cursor.refreshed_on = state.last_watermark; }
    }
    const pageSize = clamp(Number(body?.page_size ?? 500), 50, 1000);
    const maxPages = clamp(Number(body?.max_pages ?? 10), 1, 20);
    let found = 0, inserted = 0, updated = 0, hasMore = false;

    for (let page = 0; page < maxPages; page++) {
      const rows = await fetchRows(cursor, pageSize);
      if (!rows.length) { hasMore = false; break; }
      found += rows.length;
      const result = await rpc<Record<string, unknown>>("bridgepoint_stage_ct_hic_registry_v85", { p_records: rows });
      inserted += Number(result?.inserted ?? 0);
      updated += Number(result?.updated ?? 0);
      const last = rows.at(-1)!;
      cursor = {
        refreshed_on: String(last.recordrefreshedon ?? cursor.refreshed_on),
        credential: String(last.fullcredentialcode ?? cursor.credential),
      };
      hasMore = rows.length === pageSize;
      if (!hasMore) break;
    }

    const commit = await rpc("bridgepoint_ct_hic_refresh_commit_v85", {
      p_watermark: JSON.stringify(cursor),
      p_found: found,
      p_inserted: inserted,
      p_updated: updated,
      p_has_more: hasMore,
      p_error: null,
    });
    return json({
      complete: !hasMore,
      status: hasMore ? "continuing" : "completed",
      source_code: "CT_DCP_HIC_REGISTRY",
      dataset_id: DATASET,
      found,
      inserted,
      updated,
      has_more: hasMore,
      watermark: cursor,
      commit,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (claimed) {
      try {
        await rpc("bridgepoint_ct_hic_refresh_commit_v85", {
          p_watermark: null,
          p_found: 0,
          p_inserted: 0,
          p_updated: 0,
          p_has_more: true,
          p_error: message,
        });
      } catch { /* preserve the original error */ }
    }
    console.error(message);
    return json({ complete: false, status: "failed", error: message }, 500);
  }
});
