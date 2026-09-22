import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response(JSON.stringify({ ok: false, error: "POST required" }), { status: 405, headers: { "content-type": "application/json" } });
  const integrationId = req.headers.get("x-bridgepoint-integration-id") ?? "";
  const token = req.headers.get("x-bridgepoint-iot-token") ?? "";
  if (!/^[0-9a-f-]{36}$/i.test(integrationId) || token.length < 32) return new Response(JSON.stringify({ ok: false, error: "invalid credentials" }), { status: 401, headers: { "content-type": "application/json" } });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const client = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });
  const payload = await req.json().catch(() => null);
  if (!payload) return new Response(JSON.stringify({ ok: false, error: "invalid json" }), { status: 400, headers: { "content-type": "application/json" } });

  const externalDeviceId = String(payload.external_device_id ?? "").trim();
  const measurements = Array.isArray(payload.measurements) ? payload.measurements : [payload];
  if (!externalDeviceId || measurements.length === 0 || measurements.length > 100) return new Response(JSON.stringify({ ok: false, error: "external_device_id and 1-100 measurements required" }), { status: 400, headers: { "content-type": "application/json" } });

  let accepted = 0;
  const results: any[] = [];
  for (const m of measurements) {
    const key = String(m.measurement_key ?? "").trim().toUpperCase();
    if (!key || key.length > 120) { results.push({ accepted: false, error: "invalid measurement_key" }); continue; }
    const canonical = JSON.stringify({ integrationId, externalDeviceId, key, value_numeric: m.value_numeric ?? null, value_text: m.value_text ?? null, unit: m.unit ?? null, observed_at: m.observed_at ?? null, metadata: m.metadata ?? {} });
    const hashBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical));
    const payloadHash = [...new Uint8Array(hashBuf)].map((b) => b.toString(16).padStart(2, "0")).join("");
    const { data, error } = await client.rpc("bridgepoint_iot_ingest_v519", {
      p_integration_id: integrationId,
      p_token: token,
      p_external_device_id: externalDeviceId,
      p_measurement_key: key,
      p_value_numeric: typeof m.value_numeric === "number" ? m.value_numeric : null,
      p_value_text: m.value_text == null ? null : String(m.value_text),
      p_unit: m.unit == null ? null : String(m.unit),
      p_observed_at: m.observed_at ?? new Date().toISOString(),
      p_payload_hash: payloadHash,
      p_metadata: m.metadata ?? {}
    });
    if (error) results.push({ accepted: false, measurement_key: key, error: error.message });
    else { accepted++; results.push({ accepted: true, measurement_key: key, result: data }); }
  }

  return new Response(JSON.stringify({ ok: accepted > 0, accepted, rejected: results.length - accepted, results }), { status: accepted > 0 ? 200 : 400, headers: { "content-type": "application/json", "cache-control": "no-store" } });
});