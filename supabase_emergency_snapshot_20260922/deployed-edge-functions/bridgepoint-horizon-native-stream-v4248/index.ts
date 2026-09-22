import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.95.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Cache-Control": "no-store"
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" }
  });
}

function readSecret(): string {
  try {
    const raw = Deno.env.get("SUPABASE_SECRET_KEYS") || "{}";
    const map = JSON.parse(raw);
    if (typeof map?.default === "string" && map.default) return map.default;
  } catch (_) {}
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
}

function authorized(req: Request, secret: string): boolean {
  if (!secret) return false;
  const apiKey = req.headers.get("apikey") || "";
  const auth = req.headers.get("authorization") || "";
  return apiKey === secret || auth === `Bearer ${secret}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const secret = readSecret();
  if (!url || !secret) return json({ ok: false, error: "native stream control plane is not configured" }, 503);

  const admin = createClient(url, secret, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  if (req.method === "GET") {
    const { data, error } = await admin
      .from("horizon_native_stream_runtime")
      .select("*")
      .eq("id", "primary")
      .maybeSingle();

    if (error) return json({ ok: false, error: error.message }, 500);

    const heartbeatMs = data?.heartbeat_at ? Date.parse(data.heartbeat_at) : 0;
    const ageSeconds = heartbeatMs ? Math.max(0, (Date.now() - heartbeatMs) / 1000) : null;
    const fresh = ageSeconds !== null && ageSeconds <= 45;
    const online = Boolean(data?.enabled && data?.status === "online" && fresh && data?.player_url);

    return json({
      ok: true,
      online,
      build: data?.build_sha || null,
      engine_version: data?.engine_version || "5.8",
      player_url: online ? data?.player_url : null,
      region: data?.signalling_region || null,
      fps: data?.fps ?? null,
      connected_players: data?.connected_players ?? 0,
      status: online ? "online" : (data?.status || "offline"),
      heartbeat_age_seconds: ageSeconds,
      message: data?.message || null
    });
  }

  if (req.method !== "POST") return json({ ok: false, error: "method not allowed" }, 405);
  if (!authorized(req, secret)) return json({ ok: false, error: "unauthorized" }, 401);

  let body: any = {};
  try { body = await req.json(); } catch (_) { return json({ ok: false, error: "invalid json" }, 400); }

  const status = String(body.status || "online");
  const allowed = new Set(["offline","starting","online","degraded","stopping","error"]);
  if (!allowed.has(status)) return json({ ok: false, error: "invalid status" }, 400);

  const playerUrl = body.player_url == null ? null : String(body.player_url);
  if (playerUrl && !/^https:\/\//i.test(playerUrl)) {
    return json({ ok: false, error: "player_url must be https" }, 400);
  }

  const now = new Date().toISOString();
  const payload = {
    id: "primary",
    enabled: Boolean(body.enabled ?? (status === "online" || status === "starting" || status === "degraded")),
    status,
    player_url: playerUrl,
    signalling_region: body.region == null ? null : String(body.region).slice(0, 80),
    build_sha: body.build_sha == null ? null : String(body.build_sha).slice(0, 80),
    engine_version: "5.8",
    heartbeat_at: now,
    started_at: body.started_at || (status === "starting" || status === "online" ? now : null),
    fps: Number.isFinite(Number(body.fps)) ? Number(body.fps) : null,
    connected_players: Math.max(0, Math.min(10000, Number(body.connected_players || 0) | 0)),
    message: body.message == null ? null : String(body.message).slice(0, 500),
    updated_at: now
  };

  const { data, error } = await admin
    .from("horizon_native_stream_runtime")
    .upsert(payload, { onConflict: "id" })
    .select("*")
    .single();

  if (error) return json({ ok: false, error: error.message }, 500);
  return json({ ok: true, runtime: data });
});
