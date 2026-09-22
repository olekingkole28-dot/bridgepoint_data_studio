import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
let adminKey = legacy ?? "";
if (!adminKey) {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (raw) adminKey = JSON.parse(raw)["default"] ?? "";
}
if (!supabaseUrl || !adminKey) throw new Error("Missing Supabase admin environment");
const supabase = createClient(supabaseUrl, adminKey, { auth: { persistSession: false, autoRefreshToken: false } });

async function sha256Hex(input: string | Uint8Array): Promise<string> {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...hash].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const products = [
  {
    source_key: "NOAA_MRMS_MESH_V2633",
    layer_key: "HAIL_FIELD",
    url: "https://mrms.ncep.noaa.gov/2D/MESH/MRMS_MESH.latest.grib2.gz",
    resolution_m: 1000,
    variables: { product: "MESH", units: "mm", cadence_seconds: 120, domain: "CONUS" },
    truth_class: "RADAR_DERIVED_HAIL_SIZE_ESTIMATE",
  },
  {
    source_key: "NOAA_MRMS_PRECIPRATE_V2633",
    layer_key: "PRECIP_RATE_OBS",
    url: "https://mrms.ncep.noaa.gov/2D/PrecipRate/MRMS_PrecipRate.latest.grib2.gz",
    resolution_m: 1000,
    variables: { product: "PrecipRate", cadence_seconds: 120, domain: "CONUS" },
    truth_class: "MRMS_PRECIPITATION_RATE_ESTIMATE",
  },
  {
    source_key: "NOAA_MRMS_QPE01H_PASS2_V2633",
    layer_key: "PRECIP_ACCUMULATION",
    url: "https://mrms.ncep.noaa.gov/2D/MultiSensor_QPE_01H_Pass2/MRMS_MultiSensor_QPE_01H_Pass2.latest.grib2.gz",
    resolution_m: 1000,
    variables: { product: "MultiSensor_QPE_01H_Pass2", accumulation_hours: 1, domain: "CONUS" },
    truth_class: "MRMS_MULTI_SENSOR_QPE",
  },
];

Deno.serve(async (req: Request) => {
  try {
    const token = req.headers.get("x-bridgepoint-token") ?? "";
    if (!token) return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });
    const tokenHash = await sha256Hex(token);
    const { data: authRow, error: authError } = await supabase
      .from("bridgepoint_edge_auth_v2634")
      .select("token_hash")
      .eq("token_hash", tokenHash)
      .eq("enabled", true)
      .maybeSingle();
    if (authError || !authRow) return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });

    const { data: pressure, error: pressureError } = await supabase.rpc("bridgepoint_living_world_pressure_v2634");
    if (pressureError) throw pressureError;
    if (!pressure?.allowed) return Response.json({ ok: true, skipped: "PRESSURE_GATE", pressure }, { status: 202 });

    const results: unknown[] = [];
    for (const p of products) {
      try {
        const response = await fetch(p.url, { headers: { "User-Agent": "BridgePointIntelligence/2634", "Accept": "application/octet-stream,*/*" } });
        if (!response.ok) {
          results.push({ source_key: p.source_key, ok: false, http_status: response.status });
          continue;
        }
        const bytes = new Uint8Array(await response.arrayBuffer());
        if (bytes.length < 16) {
          results.push({ source_key: p.source_key, ok: false, error: "TOO_SMALL" });
          continue;
        }
        const digest = await sha256Hex(bytes);
        const lastModified = response.headers.get("last-modified");
        const validAt = lastModified && !Number.isNaN(Date.parse(lastModified)) ? new Date(lastModified) : new Date();
        const safeTime = validAt.toISOString().replace(/[:.]/g, "-");
        const objectPath = `${p.source_key}/${validAt.getUTCFullYear()}/${String(validAt.getUTCMonth()+1).padStart(2,"0")}/${String(validAt.getUTCDate()).padStart(2,"0")}/${safeTime}_${digest.slice(0,16)}.grib2.gz`;
        const upload = await supabase.storage.from("living-world-fields").upload(objectPath, bytes, {
          contentType: "application/gzip",
          cacheControl: "31536000",
          upsert: false,
        });
        if (upload.error && !String(upload.error.message ?? "").toLowerCase().includes("already exists")) throw upload.error;
        const storageUri = `supabase://living-world-fields/${objectPath}`;
        const { data: registered, error: registerError } = await supabase.rpc("[REDACTED_LONG_LITERAL]", {
          p_layer_key: p.layer_key,
          p_source_key: p.source_key,
          p_valid_at: validAt.toISOString(),
          p_storage_uri: storageUri,
          p_resolution_m: p.resolution_m,
          p_variables: p.variables,
          p_truth_class: p.truth_class,
          p_source_metadata: {
            provider: "NOAA/NWS MRMS",
            source_url: p.url,
            http_last_modified: lastModified,
            sha256: digest,
            compressed_bytes: bytes.length,
            raw_source_preserved: true,
            decode_status: "RAW_GRIB2_STORED",
            truth_boundary: "Raw operational MRMS source preserved before any rendering/derivation.",
          },
        });
        if (registerError) throw registerError;
        results.push({ source_key: p.source_key, ok: true, bytes: bytes.length, sha256: digest, storage_uri: storageUri, registered });
      } catch (error) {
        results.push({ source_key: p.source_key, ok: false, error: String(error) });
      }
    }
    return Response.json({ ok: true, version: 2634, results });
  } catch (error) {
    return Response.json({ ok: false, error: String(error) }, { status: 500 });
  }
});
