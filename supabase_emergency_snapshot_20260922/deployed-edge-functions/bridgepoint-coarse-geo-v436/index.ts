import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const allowedOrigins = new Set([
  "https://bridgepointintelligence.online",
  "https://www.bridgepointintelligence.online",
]);
const publishableKey = "sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25";

function cors(origin: string | null) {
  const allow = origin && allowedOrigins.has(origin) ? origin : "https://bridgepointintelligence.online";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers": "apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Vary": "Origin",
    "Cache-Control": "no-store, max-age=0",
    "Content-Type": "application/json; charset=utf-8",
  };
}

function cleanCode(value: unknown, max = 8): string | null {
  const code = String(value ?? "").trim().toUpperCase().slice(0, max);
  return /^[A-Z]{2}$/.test(code) ? code : null;
}

function requestIp(req: Request): string | null {
  const raw = req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? "";
  const first = raw.split(",")[0]?.trim() ?? "";
  if (!first || first.length > 64 || !/^[0-9a-fA-F:.]+$/.test(first)) return null;
  return first;
}

async function fetchJson(url: string, timeoutMs = 1200): Promise<Record<string, unknown> | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: { "Accept": "application/json", "User-Agent": "BridgePoint-Coarse-Geo/436" },
    });
    if (!response.ok) return null;
    const data = await response.json();
    return data && typeof data === "object" ? data as Record<string, unknown> : null;
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  const headers = cors(origin);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "GET") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers });
  if (!origin || !allowedOrigins.has(origin) || req.headers.get("apikey") !== publishableKey) {
    return new Response(JSON.stringify({ error: "NOT_ALLOWED" }), { status: 403, headers });
  }

  const ip = requestIp(req);
  const gatewayCountry = cleanCode(req.headers.get("cf-ipcountry"), 2);
  if (!ip) {
    return new Response(JSON.stringify({ version: 436, country_code: gatewayCountry, region_code: null, source: "GATEWAY_COUNTRY_ONLY", exact_ip_stored: false }), { status: 200, headers });
  }

  let data = await fetchJson(`https://ipapi.co/${encodeURIComponent(ip)}/json/`);
  let country = cleanCode(data?.country_code ?? data?.country, 2);
  let region = cleanCode(data?.region_code, 2);
  let source = "IPAPI_CO";

  if (!country || (country === "US" && !region)) {
    data = await fetchJson(`https://get.geojs.io/v1/ip/geo/${encodeURIComponent(ip)}.json`);
    country = country ?? cleanCode(data?.country_code, 2);
    region = region ?? cleanCode(data?.region_code, 2);
    source = "GEOJS_FALLBACK";
  }

  country = country ?? gatewayCountry;
  if (country !== "US") region = null;
  return new Response(JSON.stringify({
    version: 436,
    country_code: country,
    region_code: region,
    source,
    exact_ip_stored: false,
  }), { status: 200, headers });
});
