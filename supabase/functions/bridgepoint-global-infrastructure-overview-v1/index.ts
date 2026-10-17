import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "private, max-age=30",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info"
};

const EVENT_DOMAINS = ["GLOBAL_HAZARDS", "SEISMIC", "VOLCANO"];
const EVENT_COLUMNS = "source_key,entity_key,domain,entity_type,display_name,observed_at,expires_at,metadata,updated_at";
const SIGNAL_COLUMNS = "source_key,signal_key,domain,signal_type,display_name,severity,observed_at,expires_at,payload,updated_at";

async function readRows(table: string, params: Record<string, string>) {
  if (!SUPABASE_URL || !SERVICE_KEY) throw new Error("SERVER_CONFIGURATION_MISSING");
  const url = new URL(SUPABASE_URL + "/rest/v1/" + table);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  const response = await fetch(url, {
    headers: {
      apikey: SERVICE_KEY,
      authorization: "Bearer " + SERVICE_KEY,
      accept: "application/json"
    }
  });
  if (!response.ok) throw new Error("DATA_QUERY_FAILED:" + table + ":" + response.status);
  const data = await response.json();
  return Array.isArray(data) ? data : [];
}

function cleanText(value: unknown, max = 240): string | null {
  if (typeof value !== "string") return null;
  const result = value.replace(/[\u0000-\u001F\u007F]/g, " ").trim();
  return result ? result.slice(0, max) : null;
}

function safeMetadata(value: unknown): Record<string, string | number | boolean> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const raw = value as Record<string, unknown>;
  const allowed = ["mag", "depth_km", "place", "status", "alert_level", "severity",
    "category", "country", "updated", "source_url", "url", "event_id"];
  const result: Record<string, string | number | boolean> = {};
  for (const key of allowed) {
    const item = raw[key];
    if (typeof item === "number" && Number.isFinite(item)) result[key] = item;
    else if (typeof item === "boolean") result[key] = item;
    else {
      const text = cleanText(item, 240);
      if (text) result[key] = text;
    }
  }
  for (const key of ["source_url", "url"]) {
    if (typeof result[key] === "string") {
      try {
        if (new URL(String(result[key])).protocol !== "https:") delete result[key];
      } catch {
        delete result[key];
      }
    }
  }
  return result;
}

function toPublicEvent(row: Record<string, unknown>) {
  return {
    source_key: cleanText(row.source_key, 100),
    event_key: cleanText(row.entity_key, 160),
    domain: cleanText(row.domain, 60),
    event_type: cleanText(row.entity_type, 80),
    title: cleanText(row.display_name, 180) || "Public-source event",
    observed_at: cleanText(row.observed_at, 80),
    expires_at: cleanText(row.expires_at, 80),
    metadata: safeMetadata(row.metadata)
  };
}

function toPublicSignal(row: Record<string, unknown>) {
  return {
    source_key: cleanText(row.source_key, 100),
    signal_key: cleanText(row.signal_key, 160),
    domain: cleanText(row.domain, 60),
    signal_type: cleanText(row.signal_type, 80),
    title: cleanText(row.display_name, 180) || "Space-weather signal",
    severity: typeof row.severity === "number" ? row.severity : null,
    observed_at: cleanText(row.observed_at, 80),
    expires_at: cleanText(row.expires_at, 80),
    metadata: safeMetadata(row.payload)
  };
}

function publicProgress(row: Record<string, unknown> | undefined) {
  if (!row) return null;
  const allowed = ["us_public_parcels", "global_non_us_canonical", "worldwide_canonical_total",
    "materialized_global_boundaries", "global_building_footprints", "global_3d_building_models",
    "global_addresses", "materialized_country_count", "goal", "goal_remaining", "goal_pct",
    "source_cache_updated_at", "updated_at", "roof_shell_buildings", "exact_roof_plane_records",
    "lidar_roof_rows"];
  const result: Record<string, unknown> = {};
  for (const key of allowed) if (key in row) result[key] = row[key];
  return result;
}

function publicCountry(row: Record<string, unknown>) {
  return {
    country_code: cleanText(row.country_code, 12),
    active_canonical: Number(row.active_canonical || 0),
    with_boundary: Number(row.with_boundary || 0),
    materialized_boundary_rows: Number(row.materialized_boundary_rows || 0),
    building_footprints: Number(row.building_footprints || 0),
    building_3d_models: Number(row.building_3d_models || 0),
    addresses: Number(row.addresses || 0),
    roof_records: Number(row.roof_records || 0),
    source_count: Number(row.source_count || 0),
    complete_sources: Number(row.complete_sources || 0),
    source_cache_updated_at: cleanText(row.source_cache_updated_at, 80),
    updated_at: cleanText(row.updated_at, 80)
  };
}

function publicInfrastructureSource(row: Record<string, unknown>) {
  return {
    source_key: cleanText(row.source_key, 120),
    scope: cleanText(row.scope, 32),
    country_code: cleanText(row.country_code, 12),
    jurisdiction_code: cleanText(row.jurisdiction_code, 40),
    source_name: cleanText(row.source_name, 200),
    authority_name: cleanText(row.authority_name, 160),
    rights_class: cleanText(row.rights_class, 60),
    ingest_mode: cleanText(row.ingest_mode, 60),
    status: cleanText(row.status, 60),
    discovered_count: Number(row.discovered_count || 0),
    materialized_count: Number(row.materialized_count || 0),
    geometry_truth: cleanText(row.geometry_truth, 100),
    last_verified_at: cleanText(row.last_verified_at, 80),
    updated_at: cleanText(row.updated_at, 80)
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: HEADERS });
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ ok: false, error: "METHOD_NOT_ALLOWED" }), {
      status: 405, headers: HEADERS
    });
  }

  try {
    const now = new Date().toISOString();
    const [progressRows, countryRows, eventRows, signalRows, infrastructureSourceRows] = await Promise.all([
      readRows("bridgepoint_global_progress_v5700", { select: "*", singleton: "eq.true", limit: "1" }),
      readRows("bridgepoint_global_country_progress_v5710", {
        select: "country_code,active_canonical,with_boundary,materialized_boundary_rows,building_footprints,building_3d_models,addresses,roof_records,source_count,complete_sources,source_cache_updated_at,updated_at",
        order: "active_canonical.desc", limit: "40"
      }),
      readRows("intelligence_live_entity_v5500", {
        select: EVENT_COLUMNS,
        domain: "in.(" + EVENT_DOMAINS.join(",") + ")",
        expires_at: "gt." + now,
        order: "observed_at.desc", limit: "60"
      }),
      readRows("intelligence_global_signal_v5503", {
        select: SIGNAL_COLUMNS, domain: "eq.SPACE_WEATHER",
        expires_at: "gt." + now, order: "observed_at.desc", limit: "20"
      }),
      readRows("intelligence_bridge_source_v5540", {
        select: "source_key,scope,country_code,jurisdiction_code,source_name,authority_name,rights_class,ingest_mode,status,discovered_count,materialized_count,geometry_truth,last_verified_at,updated_at",
        order: "updated_at.desc", limit: "25"
      })
    ]);

    const events = eventRows.map((row: Record<string, unknown>) => toPublicEvent(row));
    const signals = signalRows.map((row: Record<string, unknown>) => toPublicSignal(row));
    const countries = countryRows.map((row: Record<string, unknown>) => publicCountry(row));
    const infrastructureSources = infrastructureSourceRows.map((row: Record<string, unknown>) => publicInfrastructureSource(row));
    const progress = publicProgress(progressRows[0] as Record<string, unknown> | undefined);
    const observedTimes = [...events, ...signals]
      .map((item: Record<string, unknown>) => Date.parse(String(item.observed_at || "")))
      .filter((time: number) => Number.isFinite(time));
    const latestObservedAt = observedTimes.length
      ? new Date(Math.max(...observedTimes)).toISOString()
      : null;

    return new Response(JSON.stringify({
      ok: true, version: 1, generated_at: now, latest_observed_at: latestObservedAt,
      global_progress: progress, countries,
      infrastructure_sources: infrastructureSources,
      recent_public_events: events, space_weather_signals: signals,
      summary: {
        country_rows_loaded: countries.length,
        infrastructure_source_rows_loaded: infrastructureSources.length,
        recent_public_events_loaded: events.length,
        space_weather_signals_loaded: signals.length,
        event_domains: EVENT_DOMAINS
      },
      limitations: [
        "Public-source observations are not automatically ground truth.",
        "Records may be delayed, incomplete, duplicated, or expired upstream.",
        "This overview omits live entity coordinates, tracks, heading, speed and altitude."
      ]
    }), { status: 200, headers: HEADERS });
  } catch (error) {
    console.error("global infrastructure overview failed", error);
    return new Response(JSON.stringify({ ok: false, error: "GLOBAL_INTELLIGENCE_UNAVAILABLE" }), {
      status: 502, headers: HEADERS
    });
  }
});