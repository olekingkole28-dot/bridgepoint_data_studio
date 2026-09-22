import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const JSON_HEADERS = { ...CORS, 'content-type': 'application/json' };
const ARCGIS_ROOT = 'https://services3.arcgis.com/0Fs3HcaFfvzXvm7w/ArcGIS/rest/services';
const SUPPORTED_SCENARIOS = new Set(['SSP245', 'SSP370', 'SSP585']);
const SUPPORTED_HORIZONS = new Set([2030, 2040, 2050, 2060, 2070, 2080, 2090, 2100]);
const SUPPORTED_BASELINES = new Set([1950, 1960, 1970, 1980, 1990, 2000, 2010, 2020]);

const HOT_FIELDS = [
  'GEOID','NAME','STATE_GEOID','STATE_NAME','STATE_ABBREV','DECADE','Begin_Date','End_Date',
  'TMAXDAYSGE85F_MEAN','TMAXDAYSGE90F_MEAN','TMAXDAYSGE95F_MEAN','TMAXDAYSGE100F_MEAN',
  'TMAXDAYSGE105F_MEAN','TMAXDAYSGE110F_MEAN','TMAXDAYSGE115F_MEAN'
];
const PRECIP_FIELDS = [
  'GEOID','NAME','STATE_GEOID','STATE_NAME','STATE_ABBREV','DECADE','Begin_Date','End_Date',
  'PRANNUAL','PRMAX1DAY','PRMAX5DAY','PRMAX10DAY','PRABVNZ90TH','PRABVNZ95TH','PRABVNZ99TH',
  'DRYDAYS','WETDAYS','CONSECDD','CONSECWD'
];

function finiteNumber(value: unknown): number | null {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function selected(attributes: Record<string, unknown>, fields: string[]) {
  const out: Record<string, unknown> = {};
  for (const key of fields) {
    if (!(key in attributes)) continue;
    const raw = attributes[key];
    if (key === 'GEOID' || key === 'NAME' || key === 'STATE_GEOID' || key === 'STATE_NAME' || key === 'STATE_ABBREV') {
      out[key] = raw == null ? null : String(raw);
    } else if (key === 'Begin_Date' || key === 'End_Date') {
      const ms = finiteNumber(raw);
      out[key] = ms == null ? null : new Date(ms).toISOString();
    } else {
      out[key] = finiteNumber(raw);
    }
  }
  return out;
}

async function arcgisCountyRecord(serviceName: string, lat: number, lon: number, decade: number, fields: string[]) {
  const url = new URL(`${ARCGIS_ROOT}/${serviceName}/FeatureServer/0/query`);
  url.searchParams.set('f', 'json');
  url.searchParams.set('where', `DECADE=${decade}`);
  url.searchParams.set('geometry', `${lon},${lat}`);
  url.searchParams.set('geometryType', 'esriGeometryPoint');
  url.searchParams.set('inSR', '4326');
  url.searchParams.set('spatialRel', 'esriSpatialRelIntersects');
  url.searchParams.set('outFields', fields.join(','));
  url.searchParams.set('returnGeometry', 'false');
  url.searchParams.set('resultRecordCount', '2');

  const response = await fetch(url, {
    headers: { accept: 'application/json', 'user-agent': 'BridgePointIntelligence/1.0' },
    signal: AbortSignal.timeout(12000),
  });
  const text = await response.text();
  let payload: any = {};
  try { payload = JSON.parse(text); } catch { throw new Error(`Provider returned invalid JSON (${response.status})`); }
  if (!response.ok || payload?.error) {
    const detail = payload?.error?.message || text.slice(0, 300);
    throw new Error(`CMRA LOCA2 query failed (${response.status}): ${detail}`);
  }
  const features = Array.isArray(payload?.features) ? payload.features : [];
  if (!features.length || !features[0]?.attributes) throw new Error(`No county projection record for decade ${decade}`);
  return {
    attributes: selected(features[0].attributes, fields),
    query_url: url.toString(),
  };
}

function numericDelta(projected: Record<string, unknown>, baseline: Record<string, unknown>, keys: string[]) {
  const out: Record<string, unknown> = {};
  for (const key of keys) {
    const p = finiteNumber(projected[key]);
    const b = finiteNumber(baseline[key]);
    if (p == null || b == null) {
      out[key] = { absolute: null, percent: null };
      continue;
    }
    out[key] = {
      absolute: Number((p - b).toFixed(3)),
      percent: Math.abs(b) > 1e-9 ? Number((((p - b) / Math.abs(b)) * 100).toFixed(2)) : null,
    };
  }
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { status: 200, headers: CORS });
  let stage = 'START';
  try {
    if (req.method !== 'POST') return new Response(JSON.stringify({ complete: false, error: 'POST required' }), { status: 405, headers: JSON_HEADERS });

    stage = 'AUTH';
    const auth = req.headers.get('authorization') || '';
    const user = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    });
    const me = await user.auth.getUser();
    if (me.error || !me.data.user) return new Response(JSON.stringify({ complete: false, error: 'Sign in required' }), { status: 401, headers: JSON_HEADERS });

    const body = await req.json().catch(() => ({}));
    const propertyId = String(body?.property_id || '').trim();
    const scenario = String(body?.scenario_key || 'SSP245').trim().toUpperCase();
    const horizon = Number(body?.horizon_decade ?? 2050);
    const baseline = Number(body?.baseline_decade ?? 2000);
    const forceRefresh = body?.force_refresh === true;
    if (!/^[0-9a-f-]{36}$/i.test(propertyId)) throw new Error('Valid property_id required');
    if (!SUPPORTED_SCENARIOS.has(scenario)) throw new Error('scenario_key must be SSP245, SSP370, or SSP585');
    if (!SUPPORTED_HORIZONS.has(horizon)) throw new Error('Unsupported horizon_decade');
    if (!SUPPORTED_BASELINES.has(baseline)) throw new Error('Unsupported baseline_decade');

    stage = 'AUTHORIZE_PROPERTY';
    const contextCall = await user.rpc('bridgepoint_climate_projection_context_v511', { p_property_id: propertyId });
    if (contextCall.error) throw contextCall.error;
    const context = contextCall.data as Record<string, any>;
    if (!context?.complete) throw new Error(String(context?.error || 'Property climate access unavailable'));
    const lat = finiteNumber(context.latitude);
    const lon = finiteNumber(context.longitude);
    const stateCode = String(context.state_code || '').trim().toUpperCase();
    if (lat == null || lon == null || !stateCode) throw new Error('Property coordinates/state unavailable');

    stage = 'CACHE_CHECK';
    if (!forceRefresh) {
      const cached = await user.rpc('bridgepoint_cached_climate_projection_v511', {
        p_property_id: propertyId,
        p_scenario_key: scenario,
        p_horizon_decade: horizon,
        p_baseline_decade: baseline,
      });
      if (!cached.error && cached.data?.cached === true && cached.data?.stale !== true) {
        return new Response(JSON.stringify({ ...cached.data, edge_function: 'bridgepoint-climate-projection-v511', cache_hit: true }), { headers: JSON_HEADERS });
      }
    }

    stage = 'PROVIDER_FETCH';
    const hotService = `LOCA2_Ensemble_${scenario}_Hot_Days_1950_2100`;
    const precipService = `LOCA2_Ensemble_${scenario}_Precipitation_Totals_1950_2100`;
    const [hotTarget, hotBase, precipTarget, precipBase] = await Promise.all([
      arcgisCountyRecord(hotService, lat, lon, horizon, HOT_FIELDS),
      arcgisCountyRecord(hotService, lat, lon, baseline, HOT_FIELDS),
      arcgisCountyRecord(precipService, lat, lon, horizon, PRECIP_FIELDS),
      arcgisCountyRecord(precipService, lat, lon, baseline, PRECIP_FIELDS),
    ]);

    const geography = hotTarget.attributes;
    const geoid = String(geography.GEOID || precipTarget.attributes.GEOID || '').trim();
    const geographyName = String(geography.NAME || precipTarget.attributes.NAME || context.county || '').trim();
    const providerState = String(geography.STATE_ABBREV || precipTarget.attributes.STATE_ABBREV || stateCode).trim().toUpperCase();
    if (providerState && providerState !== stateCode) throw new Error(`Projection geography state mismatch: expected ${stateCode}, got ${providerState}`);
    if (String(hotTarget.attributes.GEOID || '') !== String(precipTarget.attributes.GEOID || '')) throw new Error('Hot-days and precipitation services resolved to different counties');

    const hotMetricKeys = HOT_FIELDS.filter((key) => key.startsWith('TMAX'));
    const precipMetricKeys = PRECIP_FIELDS.filter((key) => !['GEOID','NAME','STATE_GEOID','STATE_NAME','STATE_ABBREV','DECADE','Begin_Date','End_Date'].includes(key));
    const variables = {
      hot_days: { baseline: hotBase.attributes, projected: hotTarget.attributes },
      precipitation_totals: { baseline: precipBase.attributes, projected: precipTarget.attributes },
    };
    const deltas = {
      hot_days: numericDelta(hotTarget.attributes, hotBase.attributes, hotMetricKeys),
      precipitation_totals: numericDelta(precipTarget.attributes, precipBase.attributes, precipMetricKeys),
    };
    const provenance = {
      provider: 'U.S. Climate Resilience Toolkit / CMRA',
      dataset_family: 'LOCA2 Ensemble 1950-2100',
      source_key: 'USGCRP_CMRA_LOCA2',
      scenario_key: scenario,
      geography_level: 'COUNTY',
      query_geometry: 'PROPERTY_POINT_INTERSECT',
      services: {
        hot_days: hotService,
        precipitation_totals: precipService,
      },
      provider_urls: {
        hot_days_target: hotTarget.query_url,
        hot_days_baseline: hotBase.query_url,
        precipitation_target: precipTarget.query_url,
        precipitation_baseline: precipBase.query_url,
      },
      selected_fields_only: true,
      raw_provider_payload_stored: false,
      bridgepoint_interpretation: 'County-scale climate projection context; not a building-scale hazard forecast.',
      retrieved_at: new Date().toISOString(),
    };

    stage = 'PERSIST';
    const persisted = await service.rpc('bridgepoint_persist_climate_projection_v511', {
      p_property_id: propertyId,
      p_scenario_key: scenario,
      p_horizon_decade: horizon,
      p_baseline_decade: baseline,
      p_geoid: geoid,
      p_geography_name: geographyName,
      p_state_code: stateCode,
      p_variables: variables,
      p_deltas_from_baseline: deltas,
      p_source_provenance: provenance,
      p_source_updated_at: null,
    });
    if (persisted.error) throw persisted.error;

    stage = 'READ_BACK';
    const readBack = await user.rpc('bridgepoint_cached_climate_projection_v511', {
      p_property_id: propertyId,
      p_scenario_key: scenario,
      p_horizon_decade: horizon,
      p_baseline_decade: baseline,
    });
    if (readBack.error) throw readBack.error;

    return new Response(JSON.stringify({
      ...readBack.data,
      cache_hit: false,
      edge_function: 'bridgepoint-climate-projection-v511',
      provider: 'U.S. Climate Resilience Toolkit / CMRA LOCA2',
      source_resolution: 'COUNTY_PROJECTION_CONTEXT',
      model_use_status: 'SOURCE_INPUT',
      no_building_scale_projection_claim: true,
    }), { headers: JSON_HEADERS });
  } catch (error) {
    const message = String((error as any)?.message || error).slice(0, 1800);
    return new Response(JSON.stringify({ complete: false, error: message, stage, policy_version: 511 }), { status: 400, headers: JSON_HEADERS });
  }
});
