import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const relevantEvents = [
  "Severe Thunderstorm Warning",
  "Severe Thunderstorm Watch",
  "Tornado Warning",
  "Tornado Watch",
  "Special Weather Statement",
];

function maxNumber(matches: RegExpMatchArray[]): number | null {
  const vals = matches.map((m) => Number(m[1])).filter((n) => Number.isFinite(n));
  return vals.length ? Math.max(...vals) : null;
}

function parseWind(text: string): number | null {
  const matches = [...text.matchAll(/(?:WIND(?:S| GUSTS?)?[^.\n]{0,80}?)?(\d{2,3})\s*MPH/gi)];
  return maxNumber(matches);
}

function parseHail(text: string): number | null {
  const direct = [...text.matchAll(/(?:HAIL[^.\n]{0,80}?)?(\d+(?:\.\d+)?)\s*(?:INCH(?:ES)?|IN\b)/gi)];
  const d = maxNumber(direct);
  if (d != null && d <= 6) return d;
  const lower = text.toLowerCase();
  const sizes: Array<[string, number]> = [
    ["pea size", .25], ["dime size", .7], ["penny size", .75], ["nickel size", .88],
    ["quarter size", 1], ["half dollar size", 1.25], ["ping pong ball", 1.5],
    ["golf ball", 1.75], ["hen egg", 2], ["tennis ball", 2.5], ["baseball", 2.75], ["softball", 4]
  ];
  let best: number | null = null;
  for (const [term, size] of sizes) if (lower.includes(term)) best = Math.max(best ?? 0, size);
  return best;
}

function confidenceFromAlert(p: any): number {
  const certainty = String(p?.certainty ?? "").toLowerCase();
  const severity = String(p?.severity ?? "").toLowerCase();
  let c = certainty === "observed" ? .95 : certainty === "likely" ? .85 : .70;
  if (severity === "extreme" || severity === "severe") c = Math.min(.98, c + .03);
  return c;
}

function perilFor(event: string, hail: number | null, wind: number | null): string {
  const e = event.toLowerCase();
  if (e.includes("tornado")) return "TORNADO";
  if (e.includes("severe thunderstorm")) return "SEVERE_THUNDERSTORM";
  if ((hail ?? 0) > 0) return "HAIL";
  if ((wind ?? 0) > 0) return "WIND";
  return "OTHER";
}

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const client = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });

  const supplied = req.headers.get("x-bridgepoint-prestorm-token") ?? "";
  const { data: secretRow, error: secretErr } = await client.schema("automation").from("prestorm_worker_secret_v516").select("token").eq("singleton", true).maybeSingle();
  if (secretErr || !secretRow?.token || supplied !== secretRow.token) {
    return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "content-type": "application/json" } });
  }

  const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
  const limit = Math.max(1, Math.min(Number(body?.limit ?? 25), 100));
  const { data: candidates, error: candErr } = await client.rpc("[REDACTED_LONG_LITERAL]", { p_token: supplied, p_limit: limit });
  if (candErr) return new Response(JSON.stringify({ ok: false, error: candErr.message }), { status: 500, headers: { "content-type": "application/json" } });

  const list = Array.isArray(candidates) ? candidates : [];
  let alertsSeen = 0, threatsUpserted = 0, errors = 0;
  const summaries: any[] = [];

  for (const c of list) {
    try {
      const lat = Number(c.latitude), lon = Number(c.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
      const url = `https://api.weather.gov/alerts/active?point=${lat.toFixed(4)},${lon.toFixed(4)}`;
      const res = await fetch(url, { headers: { "Accept": "application/geo+json", "User-Agent": "BridgePoint Intelligence (https://bridgepointintelligence.online)" } });
      if (!res.ok) throw new Error(`NWS ${res.status}`);
      const payload = await res.json();
      const features = Array.isArray(payload?.features) ? payload.features : [];
      let local = 0;
      for (const f of features) {
        const p = f?.properties ?? {};
        const event = String(p.event ?? "");
        if (!relevantEvents.some((x) => event.includes(x))) continue;
        alertsSeen++;
        const text = [p.headline, p.description, p.instruction, p.parameters ? JSON.stringify(p.parameters) : ""].filter(Boolean).join("\n");
        const wind = parseWind(text);
        const hail = parseHail(text);
        if (event === "Special Weather Statement" && wind == null && hail == null) continue;
        const validFrom = p.onset || p.effective || new Date().toISOString();
        const validTo = p.ends || p.expires || new Date(Date.now() + 6 * 3600_000).toISOString();
        const sourceEventId = String(p.id || f.id || `${event}-${validFrom}`);
        const payloadHash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify({ id: sourceEventId, event, validFrom, validTo, wind, hail, severity: p.severity, urgency: p.urgency, certainty: p.certainty })));
        const hashHex = [...new Uint8Array(payloadHash)].map((b) => b.toString(16).padStart(2, "0")).join("");
        const { error } = await client.rpc("bridgepoint_ingest_prestorm_threat_v518", {
          p_token: supplied,
          p_property_id: c.property_id,
          p_source_event_id: sourceEventId.slice(0, 500),
          p_event_name: event,
          p_peril_key: perilFor(event, hail, wind),
          p_valid_from: validFrom,
          p_valid_to: validTo,
          p_wind_mph: wind,
          p_hail_inches: hail,
          p_probability: null,
          p_confidence: confidenceFromAlert(p),
          p_source_url: p['@id'] || f.id || url,
          p_payload_hash: hashHex,
          p_severity: p.severity ?? null,
          p_urgency: p.urgency ?? null,
          p_certainty: p.certainty ?? null,
          p_metadata: { headline: p.headline ?? null, areaDesc: p.areaDesc ?? null, senderName: p.senderName ?? null }
        });
        if (error) { errors++; } else { threatsUpserted++; local++; }
      }
      summaries.push({ property_id: c.property_id, alerts_processed: local });
    } catch (e) {
      errors++;
      summaries.push({ property_id: c.property_id, error: String(e?.message ?? e) });
    }
  }

  return new Response(JSON.stringify({ ok: true, candidates: list.length, alerts_seen: alertsSeen, threats_upserted: threatsUpserted, errors, summaries }), { headers: { "content-type": "application/json", "cache-control": "no-store" } });
});
