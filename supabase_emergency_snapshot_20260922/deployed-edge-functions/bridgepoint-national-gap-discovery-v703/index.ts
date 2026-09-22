import { createClient } from "npm:@supabase/supabase-js@2";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H = { "content-type": "application/json" };
const V = 1458;
const lc = (x: any) => String(x ?? "").toLowerCase();

async function json(url: string) {
  const r = await fetch(url, {
    signal: AbortSignal.timeout(35000),
    headers: { accept: "application/json", "user-agent": "BridgePointIntelligence/1.0" },
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${t.slice(0, 240)}`);
  try { return JSON.parse(t); } catch { throw new Error(`Unparseable JSON: ${url}`); }
}

function govish(...v: any[]) {
  const s = lc(v.join(" "));
  return /(^|[./])([a-z0-9-]+\.)*gov([/:]|$)/.test(s) || s.includes(".gov/") || s.includes(".gov ");
}
function orgToken(url: string) {
  const m = lc(url).match(/services[0-9]*\.arcgis\.com\/([^/]+)/);
  return m?.[1] || "";
}
function esc(s: string) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
function stateEvidence(blob: string, stateName: string, stateCode: string) {
  const raw = String(blob || ""), s = lc(raw), name = lc(stateName), code = String(stateCode || "").toUpperCase();
  if (name && (s.includes(name) || s.includes("state of " + name))) return true;
  if (code && new RegExp(`\\.${esc(code.toLowerCase())}\\.gov(?:[/:]|$)`, "i").test(raw)) return true;
  const cue = "(?:state|county|parish|borough|municipal|assessor|cadastral|parcel|parcels|gis|property|tax|recorder|register of deeds|land records|court|license|licensing|permit|mortgage|foreclosure)";
  const c = esc(code);
  return !!code && (new RegExp(`\\b${cue}[^A-Za-z0-9]{0,8}${c}\\b`, "i").test(raw) || new RegExp(`\\b${c}[^A-Za-z0-9]{0,8}${cue}\\b`, "i").test(raw));
}
function parcelSemantic(title: string, url: string, tags: any[] = [], desc = "") {
  const s = lc(`${title} ${url} ${(tags || []).join(" ")} ${desc}`);
  const positive = /\b(parcel|parcels|cadastral|cadastre|taxlot|tax lot|taxlots|tax lots|parcel boundary|parcel boundaries|assessment parcel|property parcel|parcel fabric)\b/.test(s);
  const negative = /\b(city boundar|school district|attendance|zoning|militia district|voting|precinct|census tract|zip code|building footprint|address point|park boundary|open space|watershed|aquifer|soil|wetland|fire district|supervisorial|tax rate area|damage assessment|brownfield|utility parcel|easement)\b/.test(s);
  return positive && !negative;
}
function lifecycleSemantic(cat: string, title: string, url: string, tags: any[] = [], desc = "") {
  const s = lc(`${title} ${url} ${(tags || []).join(" ")} ${desc}`);
  if (cat === "TITLE_DEED") return /\b(deed|deeds|land record|land records|recorded instrument|recorder|register of deeds|conveyance|grantor|grantee|book page|instrument number)\b/.test(s) && !/\b(sample|training|fiction|historic map only)\b/.test(s);
  if (cat === "LIEN_MORTGAGE") return /\b(mortgage|mortgages|deed of trust|lien|liens|release|satisfaction|assignment|recorded instrument|recorder|land records)\b/.test(s) && !/\b(loan marketing|mortgage rate|lender branch|bank location)\b/.test(s);
  if (cat === "FORECLOSURE_DISTRESS") return /\b(foreclosure|lis pendens|tax sale|sheriff sale|judicial sale|trustee sale|delinquent tax|delinquent property|foreclosure auction)\b/.test(s) && !/\b(foreclosure risk model|predicted foreclosure|mortgage marketing)\b/.test(s);
  if (cat === "REPAIR_REBUILD") return /\b(building permit|building permits|permit|permits|reconstruction|repair|reroof|re-roof|roof replacement|demolition|inspection|certificate of occupancy|final inspection|closeout|alteration|renovation)\b/.test(s) && !/\b(parking permit|business license only|event permit)\b/.test(s);
  if (cat === "CONTRACTOR_LICENSE") return /\b(contractor|trade license|trade licenses|home improvement|professional license|license registry|licensed contractor|electrical license|plumbing license|roofing license)\b/.test(s) && !/\b(driver license|hunting license|fishing license|liquor license)\b/.test(s);
  return true;
}
function statewide(title: string, provider: string, stateName: string, stateCode: string) {
  const s = lc(`${title} ${provider}`), name = lc(stateName);
  const local = /\b(county|city|town|township|municipal|municipality|parish|borough|village|district|regional)\b/.test(lc(title));
  const named = s.includes(name) || s.includes("statewide") || s.includes("state of " + name) || s.includes("all counties") || stateEvidence(`${title} ${provider}`, stateName, stateCode);
  return named && !local;
}
function score(off: boolean, sw: boolean) {
  const authority = off ? 96 : 55, coverage = sw ? 98 : 48, freshness = 82;
  return { authority_score: authority, coverage_score: coverage, freshness_score: freshness, quality_score: Math.round(authority * .45 + coverage * .35 + freshness * .20) };
}
function sets(tr: any) {
  return {
    domains: new Set((tr?.socrata_domains || []).map((x: any) => lc(x))),
    orgs: new Set((tr?.arcgis_org_tokens || []).map((x: any) => lc(x))),
    providers: new Set((tr?.providers || []).map((x: any) => lc(x))),
  };
}
const semName = (cat: string) => cat === "PROPERTY_PARCEL" ? "PARCEL_STATEWIDE_MULTIQUERY_V1458" : (["TITLE_DEED", "LIEN_MORTGAGE", "FORECLOSURE_DISTRESS", "REPAIR_REBUILD", "CONTRACTOR_LICENSE"].includes(cat) ? "CLAIMS_LIFECYCLE_HIGH_PRECISION_V1458" : "CATEGORY_DEFAULT");

async function arc(t: any, tr: any) {
  const queries = t.source_category === "PROPERTY_PARCEL"
    ? [`${t.jurisdiction_name} statewide parcels GIS`, `${t.jurisdiction_name} tax parcels assessor cadastral`, `${t.jurisdiction_name} parcel fabric open data`, `${t.jurisdiction_name} all counties parcels`]
    : [`${t.jurisdiction_name} ${t.query_hint}`];
  const settled = await Promise.allSettled(queries.map(q => json(`https://www.arcgis.com/sharing/rest/search?f=json&num=60&sortField=modified&sortOrder=desc&q=${encodeURIComponent(q)}`)));
  const merged: any[] = [], itemSeen = new Set<string>();
  for (const r of settled) {
    if (r.status !== "fulfilled") continue;
    for (const x of (r.value?.results || [])) {
      const k = String(x.id || x.url || "");
      if (k && !itemSeen.has(k)) { itemSeen.add(k); merged.push(x); }
    }
  }
  const ts = sets(tr), out: any[] = [];
  for (const x of merged) {
    if (!["Feature Service", "Map Service"].includes(String(x.type || ""))) continue;
    const u = String(x.url || ""), p = String(x.owner || x.orgId || "ArcGIS"), tags = x.tags || [], desc = String(x.description || x.snippet || ""), blob = `${x.title || ""} ${desc} ${p} ${u} ${tags.join(" ")}`;
    if (!stateEvidence(blob, t.jurisdiction_name, t.state_code)) continue;
    if (t.source_category === "PROPERTY_PARCEL" && !parcelSemantic(String(x.title || ""), u, tags, desc)) continue;
    if (!lifecycleSemantic(t.source_category, String(x.title || ""), u, tags, desc)) continue;
    const tok = orgToken(u), trusted = !!tok && ts.orgs.has(tok), off = govish(u, p, blob) || trusted || ts.providers.has(lc(p)), sw = statewide(x.title || "", `${p} ${u} ${tags.join(" ")}`, t.jurisdiction_name, t.state_code), qv = score(off, sw);
    out.push({ source_category: t.source_category, candidate_name: String(x.title || `${t.jurisdiction_name} ${t.requirement_name}`).slice(0, 300), provider: p, source_url: u, access_method: String(x.type || "").toUpperCase().replaceAll(" ", "_"), official: off, ...qv, metadata: { portal: "ArcGIS Online", item_id: x.id, owner: x.owner, org_id: x.orgId, modified: x.modified, tags, statewide_candidate: sw, target_geo_evidence: true, publisher_trust_inherited: trusted, publisher_fingerprint: tok || null, requirement_key: t.requirement_key, gap_discovery_version: V, semantic_filter: semName(t.source_category), multiquery_statewide_hunt_v1458: t.source_category === "PROPERTY_PARCEL" } });
  }
  return out.sort((a, b) => Number(b.metadata?.statewide_candidate) - Number(a.metadata?.statewide_candidate) || b.quality_score - a.quality_score).slice(0, 30);
}

async function soc(t: any, tr: any) {
  const q = t.source_category === "PROPERTY_PARCEL" ? `${t.jurisdiction_name} parcel cadastral assessor tax lot` : `${t.jurisdiction_name} ${t.query_hint}`;
  const j = await json(`https://api.us.socrata.com/api/catalog/v1?limit=60&q=${encodeURIComponent(q)}`), ts = sets(tr);
  return (j.results || []).map((x: any) => {
    const z = x.resource || {}, m = x.metadata || {}, domain = String(m.domain || ""), u = String(x.permalink || z.permalink || ""), p = domain || String(m.source || "Socrata"), desc = String(z.description || ""), blob = `${z.name || ""} ${desc} ${domain} ${p} ${u}`;
    if (!stateEvidence(blob, t.jurisdiction_name, t.state_code)) return null;
    if (t.source_category === "PROPERTY_PARCEL" && !parcelSemantic(String(z.name || ""), u, [], desc)) return null;
    if (!lifecycleSemantic(t.source_category, String(z.name || ""), u, [], desc)) return null;
    const trusted = ts.domains.has(lc(domain)), off = govish(domain, u, p) || trusted, sw = statewide(z.name || "", `${domain} ${p}`, t.jurisdiction_name, t.state_code), qv = score(off, sw);
    return { source_category: t.source_category, candidate_name: String(z.name || `${t.jurisdiction_name} ${t.requirement_name}`).slice(0, 300), provider: p, source_url: u, access_method: "SOCRATA", official: off, ...qv, metadata: { portal: "Socrata", resource_id: z.id, domain, statewide_candidate: sw, target_geo_evidence: true, publisher_trust_inherited: trusted, publisher_fingerprint: lc(domain) || null, description: desc.slice(0, 800), requirement_key: t.requirement_key, gap_discovery_version: V, semantic_filter: semName(t.source_category) } };
  }).filter(Boolean).slice(0, 18);
}

async function datagov(t: any) {
  const q = `${t.jurisdiction_name} ${t.query_hint}`;
  const j = await json(`https://catalog.data.gov/api/3/action/package_search?rows=40&q=${encodeURIComponent(q)}`), out: any[] = [];
  for (const d of (j?.result?.results || [])) {
    const title = String(d?.title || d?.name || ""), desc = String(d?.notes || ""), org = String(d?.organization?.title || d?.author || d?.maintainer || "Data.gov catalog"), tags = (d?.tags || []).map((x: any) => String(x?.display_name || x?.name || ""));
    const dsblob = `${title} ${desc} ${org} ${tags.join(" ")}`;
    if (!stateEvidence(dsblob, t.jurisdiction_name, t.state_code)) continue;
    for (const r of (d?.resources || []).slice(0, 8)) {
      const u = String(r?.url || r?.download_url || ""); if (!u) continue;
      const rn = String(r?.name || r?.description || title), fmt = String(r?.format || r?.mimetype || "WEB"), blob = `${title} ${rn} ${desc} ${org} ${u} ${tags.join(" ")}`;
      if (!lifecycleSemantic(t.source_category, `${title} ${rn}`, u, tags, desc)) continue;
      if (t.source_category === "PROPERTY_PARCEL" && !parcelSemantic(`${title} ${rn}`, u, tags, desc)) continue;
      const off = govish(u, org, blob), sw = statewide(title, `${org} ${u} ${tags.join(" ")}`, t.jurisdiction_name, t.state_code), qv = score(off, sw);
      out.push({ source_category: t.source_category, candidate_name: `${title}${rn && rn !== title ? " — " + rn : ""}`.slice(0, 300), provider: org, source_url: u, access_method: `DATAGOV_${fmt.toUpperCase().replace(/[^A-Z0-9]+/g, "_")}`.slice(0, 80), official: off, ...qv, metadata: { portal: "Data.gov CKAN metadata catalog", dataset_id: d?.id || d?.name, resource_id: r?.id, resource_format: fmt, statewide_candidate: sw, target_geo_evidence: true, metadata_catalog_only: true, requires_endpoint_validation: true, requirement_key: t.requirement_key, gap_discovery_version: V, semantic_filter: semName(t.source_category) } });
      if (out.length >= 18) return out;
    }
  }
  return out;
}

Deno.serve(async (req: Request) => {
  try {
    const b = await req.json().catch(() => ({})), s = createClient(U, S, { auth: { persistSession: false } }), ok = await s.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: String(b.task_token || "") });
    if (ok.error || ok.data !== true) return new Response(JSON.stringify({ complete: false, error: "Invalid task token" }), { status: 401, headers: H });
    const cl = await s.rpc("bridgepoint_claim_parity_gap_discovery_v703", { p_limit: Math.min(Math.max(Number(b.limit || 4), 1), 8) });
    if (cl.error) throw cl.error;
    const out = [];
    for (const t of cl.data?.targets || []) {
      try {
        const trust = await s.rpc("bridgepoint_trusted_state_publishers_v705", { p_state_code: t.state_code });
        if (trust.error) throw trust.error;
        const all = (await Promise.allSettled([arc(t, trust.data), soc(t, trust.data), datagov(t)])).flatMap((x: any) => x.status === "fulfilled" ? x.value : []);
        const seen = new Set<string>(), cand = all.filter((x: any) => { if (!x?.source_url) return false; const k = lc(`${x.source_category}|${x.source_url}`); if (seen.has(k)) return false; seen.add(k); return true; });
        const st = await s.rpc("bridgepoint_store_gap_discovery_v703", { p_state_code: t.state_code, p_requirement_key: t.requirement_key, p_candidates: cand });
        if (st.error) throw st.error;
        out.push({ state: t.state_code, requirement: t.requirement_key, candidates: cand.length, statewide: cand.filter((x: any) => x?.metadata?.statewide_candidate).length, result: st.data });
      } catch (e) { out.push({ state: t.state_code, requirement: t.requirement_key, error: String((e as any)?.message || e) }); }
    }
    return new Response(JSON.stringify({ complete: true, version: V, claimed: cl.data?.claimed || 0, results: out }), { headers: H });
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, version: V, error: String((e as any)?.message || e) }), { status: 400, headers: H });
  }
});