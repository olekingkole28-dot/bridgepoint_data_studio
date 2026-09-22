import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SITE = "https://bridgepointintelligence.online";
const HOST = "bridgepointintelligence.online";
const KEY = "abcdef1234567890";
const KEY_LOCATION = `${SITE}/indexnow-key.txt`;
const INDEXNOW = "https://api.indexnow.org/indexnow";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CURATED_EXTRA_URLS = [
  `${SITE}/free-tools/coordinate/`,
  `${SITE}/free-tools/`,
  `${SITE}/for-roofers/`,
  `${SITE}/for-restoration/`,
  `${SITE}/for-public-adjusters/`,
  `${SITE}/for-property-managers/`,
  `${SITE}/sample/`,
  `${SITE}/enterprise/trust/`,
];

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

async function logRun(row: Record<string, unknown>) {
  if (!SUPABASE_URL || !SERVICE_ROLE) return;
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/search_index_distribution_v646`, {
      method: "POST",
      headers: {
        apikey: SERVICE_ROLE,
        authorization: `Bearer ${SERVICE_ROLE}`,
        "content-type": "application/json",
        prefer: "return=minimal",
      },
      body: JSON.stringify(row),
    });
  } catch (_) {}
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ complete: false, error: "POST required" }, 405);
  const started = Date.now();
  try {
    const keyCheck = await fetch(`${KEY_LOCATION}?v=${Date.now()}`, { cache: "no-store" });
    const keyText = keyCheck.ok ? (await keyCheck.text()).trim() : "";
    if (!keyCheck.ok || keyText !== KEY) {
      const result = { complete: false, stage: "KEY_NOT_LIVE", key_status: keyCheck.status, duration_ms: Date.now() - started };
      await logRun({ run_status: "KEY_NOT_LIVE", url_count: 0, response_status: keyCheck.status, metadata: result });
      return json(result, 503);
    }

    const sitemapRes = await fetch(`${SITE}/sitemap.xml?v=${Date.now()}`, { cache: "no-store" });
    if (!sitemapRes.ok) throw new Error(`sitemap ${sitemapRes.status}`);
    const xml = await sitemapRes.text();
    const found = [...xml.matchAll(/<loc>\s*([^<]+?)\s*<\/loc>/gi)].map((m) => m[1].trim());
    const candidates = [...found, ...CURATED_EXTRA_URLS];
    const urls = [...new Set(candidates)].filter((u) => {
      try { const x = new URL(u); return x.protocol === "https:" && x.hostname === HOST; } catch { return false; }
    }).slice(0, 10000);
    if (!urls.includes(`${SITE}/`)) urls.unshift(`${SITE}/`);

    const push = await fetch(INDEXNOW, {
      method: "POST",
      headers: { "content-type": "application/json; charset=utf-8" },
      body: JSON.stringify({ host: HOST, key: KEY, keyLocation: KEY_LOCATION, urlList: urls }),
    });
    const body = (await push.text()).slice(0, 1000);
    const complete = push.status >= 200 && push.status < 300;
    const result = { complete, indexnow_status: push.status, url_count: urls.length, curated_extra_count: CURATED_EXTRA_URLS.length, duration_ms: Date.now() - started, response_preview: body };
    await logRun({ run_status: complete ? "SUBMITTED" : "FAILED", url_count: urls.length, response_status: push.status, metadata: result });
    return json(result, complete ? 200 : 502);
  } catch (error) {
    const result = { complete: false, error: String(error), duration_ms: Date.now() - started };
    await logRun({ run_status: "ERROR", url_count: 0, response_status: null, metadata: result });
    return json(result, 500);
  }
});