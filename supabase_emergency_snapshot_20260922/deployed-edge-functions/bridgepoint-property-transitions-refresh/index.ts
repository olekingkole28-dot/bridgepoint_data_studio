import { createClient } from "npm:@supabase/supabase-js@2";

/*
 * =====================================================================
 * BRIDGEPOINT V60B
 * CONNECTICUT PROPERTY TRANSITIONS INCREMENTAL REFRESH
 *
 * Official source:
 *   Connecticut OPM Real Estate Sales
 *   Socrata dataset 5mzw-sjtu
 *
 * Guarantees:
 *   - official CT source only
 *   - preserves historical BridgePoint classifier
 *   - lean records only
 *   - raw statewide payload never retained
 *   - resumable by list year + source offset
 *   - one existing list-year overlap for corrections
 *   - max 250 lean records per ingestion RPC
 *   - automatic downstream evidence/signals/scoring already handled
 *     by bridgepoint_ingest_property_transition_batch()
 * =====================================================================
 */

const DATASET_ID = "5mzw-sjtu";

const API_URL =
  `https://data.ct.gov/resource/${DATASET_ID}.json`;

const METADATA_URL =
  `https://data.ct.gov/api/views/${DATASET_ID}`;

/*
 * Preserve the source page used by the historical BridgePoint
 * property-transition downloader.
 */
const SOURCE_PAGE =
  "https://data.ct.gov/Housing-and-Development/" +
  "Real-Estate-Sales-2001-2023-GL/5mzw-sjtu";

const SELECT_FIELDS =
  "serialnumber,listyear,daterecorded,town,address," +
  "assessedvalue,saleamount,salesratio,propertytype," +
  "residentialtype,nonusecode,remarks,opm_remarks," +
  "geo_coordinates";

/*
 * Private trigger token.
 * This is NOT a Supabase database credential.
 *
 * We will use this same token in the V60 cron installer after
 * runtime testing succeeds.
 */
const TASK_TOKEN =
  "cb1ce4b3d57abca0052f13361c2a0ff6c98de086b421e93be88c6ad31ef6aa77";

const MIN_LIST_YEAR = 2001;

const RECENT_ROUTINE_SALE_FROM = "2021-01-01";
const RECENT_COMMERCIAL_SALE_FROM = "2019-01-01";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonObject = Record<string, unknown>;

type Classification = {
  primary_signal_key: string;
  signal_keys: string;
  severity: string;
  confidence: string;
  evidence_reason: string;
  evidence_scope: string;
};

type LeanRecord = {
  source_record_id: string;
  serial_number?: string;
  list_year?: string;
  recorded_at: string;
  town: string;
  address: string;
  assessed_value?: string;
  sale_amount?: string;
  sales_ratio?: string;
  property_type?: string;
  residential_type?: string;
  non_use_code?: string;
  assessor_remarks?: string;
  opm_remarks?: string;
  primary_signal_key: string;
  signal_keys: string;
  severity: string;
  confidence: string;
  evidence_reason: string;
  evidence_scope: string;
  longitude?: string;
  latitude?: string;
  source_url: string;
};

function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...CORS_HEADERS,
        "Content-Type":
          "application/json; charset=utf-8",
        "Cache-Control": "no-store",
      },
    },
  );
}

function text(value: unknown): string {
  return String(value ?? "")
    .trim()
    .replace(/\s+/g, " ");
}

function integerValue(
  value: unknown,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(
    maximum,
    Math.max(
      minimum,
      Math.trunc(parsed),
    ),
  );
}

function booleanValue(
  value: unknown,
  fallback: boolean,
): boolean {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "string") {
    if (value.toLowerCase() === "true") {
      return true;
    }

    if (value.toLowerCase() === "false") {
      return false;
    }
  }

  return fallback;
}

function numericText(
  value: unknown,
): string {
  const raw = text(value)
    .replace(/,/g, "")
    .replace(/\$/g, "");

  if (!raw) {
    return "";
  }

  const parsed = Number(raw);

  if (!Number.isFinite(parsed)) {
    return "";
  }

  let result =
    parsed.toFixed(4);

  result =
    result
      .replace(/0+$/, "")
      .replace(/\.$/, "");

  if (result === "-0") {
    result = "0";
  }

  return result;
}

function parseDate(
  value: unknown,
): string | null {
  const raw = text(value);

  if (!raw) {
    return null;
  }

  const candidate =
    raw.slice(0, 10);

  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(candidate)
  ) {
    return null;
  }

  const year =
    Number(candidate.slice(0, 4));

  const currentYear =
    new Date().getUTCFullYear();

  if (
    year < 2001 ||
    year > currentYear + 1
  ) {
    return null;
  }

  return candidate;
}

function usableAddress(
  value: string,
): boolean {
  const normalized =
    value.toUpperCase().trim();

  if (normalized.length < 3) {
    return false;
  }

  return ![
    "??",
    "N/A",
    "NA",
    "UNKNOWN",
    "MULTI ADDRESSES",
  ].includes(normalized);
}

function codeMatches(
  nonUseCode: string,
  number: number,
): boolean {
  const pattern =
    new RegExp(
      `^0?${number}(?:\\D|$)`,
      "i",
    );

  return pattern.test(
    nonUseCode.trim(),
  );
}

function classify(
  record: JsonObject,
  recorded: string,
): Classification | null {
  const nonUseCode =
    text(record.nonusecode);

  const assessorRemarks =
    text(record.remarks);

  const opmRemarks =
    text(record.opm_remarks);

  const propertyType =
    text(record.propertytype);

  const evidenceText =
    `${nonUseCode} ${assessorRemarks} ${opmRemarks}`
      .toUpperCase();

  const signals: string[] = [];
  const reasons: string[] = [];
  const severities: number[] = [];
  const confidences: number[] = [];

  const add = (
    signal: string,
    reason: string,
    severity: number,
    confidence: number,
  ) => {
    if (signals.includes(signal)) {
      return;
    }

    signals.push(signal);
    reasons.push(reason);
    severities.push(severity);
    confidences.push(confidence);
  };

  /*
   * ================================================================
   * FORECLOSURE
   * ================================================================
   */

  if (
    evidenceText.includes("FORECLOS") ||
    codeMatches(nonUseCode, 14) ||
    codeMatches(nonUseCode, 18)
  ) {
    add(
      "foreclosure_related_transfer",
      "Official sale record identifies a foreclosure or transfer in lieu of foreclosure",
      0.95,
      0.96,
    );
  }

  /*
   * ================================================================
   * DISTRESSED / BANK / REO / SHORT SALE
   * ================================================================
   */

  if (
    [
      "SHORT SALE",
      "BANK SALE",
      "BANK OWNED",
      "REO SALE",
    ].some(
      (term) =>
        evidenceText.includes(term),
    )
  ) {
    add(
      "distressed_property_transfer",
      "Official assessor or OPM remarks identify a short sale, bank sale, or bank-owned transfer",
      0.90,
      0.93,
    );
  }

  /*
   * ================================================================
   * ESTATE / PROBATE
   * ================================================================
   */

  if (
    [
      "ESTATE SALE",
      "EXECUTOR",
      "PROBATE",
      "A WILL",
    ].some(
      (term) =>
        evidenceText.includes(term),
    ) ||
    codeMatches(nonUseCode, 10)
  ) {
    add(
      "estate_or_probate_transfer",
      "Official sale record identifies an estate, executor, probate, or will-related transfer",
      0.72,
      0.91,
    );
  }

  /*
   * ================================================================
   * COURT / GOVERNMENT
   * ================================================================
   */

  if (
    codeMatches(nonUseCode, 11) ||
    codeMatches(nonUseCode, 15) ||
    evidenceText.includes("COURT ORDER")
  ) {
    add(
      "court_or_government_transfer",
      "Official non-use code identifies a court-ordered or government-agency transfer",
      0.78,
      0.94,
    );
  }

  /*
   * ================================================================
   * BELOW MARKET
   * ================================================================
   */

  if (
    evidenceText.includes(
      "BELOW MARKET",
    )
  ) {
    add(
      "below_market_transfer",
      "Official assessor or OPM remarks explicitly identify a below-market transfer",
      0.80,
      0.88,
    );
  }

  /*
   * ================================================================
   * IMPROVEMENT
   * ================================================================
   */

  if (
    [
      "NEW CONSTRUCTION",
      "RENOVAT",
      "REMODEL",
      "REHAB",
    ].some(
      (term) =>
        evidenceText.includes(term),
    )
  ) {
    add(
      "documented_property_improvement",
      "Official assessor or OPM remarks identify construction, renovation, remodeling, or rehabilitation",
      0.66,
      0.87,
    );
  }

  /*
   * ================================================================
   * PROPERTY CHANGE
   * ================================================================
   */

  if (
    codeMatches(nonUseCode, 7) ||
    evidenceText.includes(
      "CHANGE IN PROPERTY",
    ) ||
    evidenceText.includes(
      "ZONING VIOLATION",
    )
  ) {
    add(
      "documented_property_change",
      "Official sale record identifies a property change or zoning issue",
      0.68,
      0.88,
    );
  }

  /*
   * ================================================================
   * RECENT ROUTINE TRANSFER
   * ================================================================
   */

  if (
    recorded >=
    RECENT_ROUTINE_SALE_FROM
  ) {
    add(
      "recent_property_transfer",
      "Recorded Connecticut real-estate transfer",
      0.55,
      0.97,
    );
  }

  /*
   * ================================================================
   * COMMERCIAL / DEVELOPMENT
   * ================================================================
   */

  if (
    recorded >=
      RECENT_COMMERCIAL_SALE_FROM &&
    [
      "COMMERCIAL",
      "INDUSTRIAL",
      "APARTMENTS",
      "VACANT LAND",
    ].includes(
      propertyType.toUpperCase(),
    )
  ) {
    add(
      "commercial_or_development_transfer",
      "Recent commercial, industrial, apartment, or vacant-land transfer",
      0.63,
      0.94,
    );
  }

  if (!signals.length) {
    return null;
  }

  let primaryIndex = 0;

  for (
    let index = 1;
    index < severities.length;
    index += 1
  ) {
    if (
      severities[index] >
      severities[primaryIndex]
    ) {
      primaryIndex = index;
    }
  }

  const maximumSeverity =
    Math.max(...severities);

  const maximumConfidence =
    Math.max(...confidences);

  return {
    primary_signal_key:
      signals[primaryIndex],

    signal_keys:
      signals.join("|"),

    severity:
      maximumSeverity.toFixed(4),

    confidence:
      maximumConfidence.toFixed(4),

    evidence_reason:
      reasons.join("; "),

    evidence_scope:
      recorded >=
        RECENT_ROUTINE_SALE_FROM
        ? "CURRENT_OR_RECENT"
        : "HISTORICAL_PATTERN",
  };
}

function coordinates(
  record: JsonObject,
): [string, string] {
  const location =
    record.geo_coordinates;

  if (
    !location ||
    typeof location !== "object" ||
    Array.isArray(location)
  ) {
    return ["", ""];
  }

  const rawCoordinates =
    (location as JsonObject)
      .coordinates;

  if (
    !Array.isArray(rawCoordinates) ||
    rawCoordinates.length < 2
  ) {
    return ["", ""];
  }

  return [
    numericText(rawCoordinates[0]),
    numericText(rawCoordinates[1]),
  ];
}

async function sha256Hex(
  value: string,
): Promise<string> {
  const bytes =
    new TextEncoder().encode(value);

  const digest =
    await crypto.subtle.digest(
      "SHA-256",
      bytes,
    );

  return Array.from(
    new Uint8Array(digest),
  )
    .map(
      (byte) =>
        byte
          .toString(16)
          .padStart(2, "0"),
    )
    .join("");
}

async function sourceRecordId(
  record: JsonObject,
): Promise<string> {
  /*
   * Exact identity formula from historical downloader:
   *
   * listyear
   * serialnumber
   * daterecorded[:10]
   * town.upper()
   * address.upper()
   * saleamount
   */

  const stableParts = [
    text(record.listyear),
    text(record.serialnumber),
    text(record.daterecorded)
      .slice(0, 10),
    text(record.town)
      .toUpperCase(),
    text(record.address)
      .toUpperCase(),
    text(record.saleamount),
  ];

  const digest =
    await sha256Hex(
      stableParts.join("|"),
    );

  return (
    "CT_OPM_SALE:" +
    digest.slice(0, 32)
  );
}

async function leanRecord(
  record: JsonObject,
): Promise<LeanRecord | null> {
  const recorded =
    parseDate(
      record.daterecorded,
    );

  const town =
    text(record.town);

  const address =
    text(record.address);

  if (
    !recorded ||
    !town ||
    !usableAddress(address)
  ) {
    return null;
  }

  const classification =
    classify(
      record,
      recorded,
    );

  if (!classification) {
    return null;
  }

  const [
    longitude,
    latitude,
  ] =
    coordinates(record);

  const result: LeanRecord = {
    source_record_id:
      await sourceRecordId(record),

    recorded_at:
      recorded,

    town,

    address,

    primary_signal_key:
      classification
        .primary_signal_key,

    signal_keys:
      classification.signal_keys,

    severity:
      classification.severity,

    confidence:
      classification.confidence,

    evidence_reason:
      classification
        .evidence_reason,

    evidence_scope:
      classification
        .evidence_scope,

    source_url:
      SOURCE_PAGE,
  };

  const optionalValues:
    Record<string, string> = {
      serial_number:
        text(record.serialnumber),

      list_year:
        text(record.listyear),

      assessed_value:
        numericText(
          record.assessedvalue,
        ),

      sale_amount:
        numericText(
          record.saleamount,
        ),

      sales_ratio:
        numericText(
          record.salesratio,
        ),

      property_type:
        text(record.propertytype),

      residential_type:
        text(
          record.residentialtype,
        ),

      non_use_code:
        text(record.nonusecode),

      assessor_remarks:
        text(record.remarks),

      opm_remarks:
        text(record.opm_remarks),

      longitude,

      latitude,
    };

  for (
    const [key, value]
    of Object.entries(optionalValues)
  ) {
    if (value) {
      (
        result as unknown as
          Record<string, unknown>
      )[key] = value;
    }
  }

  return result;
}

async function readBody(
  request: Request,
): Promise<JsonObject> {
  const raw =
    await request.text();

  if (!raw.trim()) {
    return {};
  }

  const parsed =
    JSON.parse(raw);

  if (
    !parsed ||
    typeof parsed !== "object" ||
    Array.isArray(parsed)
  ) {
    throw new Error(
      "Request body must be a JSON object.",
    );
  }

  return parsed as JsonObject;
}

async function fetchJson(
  url: string,
  attempts = 4,
): Promise<unknown> {
  let lastError:
    unknown = null;

  for (
    let attempt = 1;
    attempt <= attempts;
    attempt += 1
  ) {
    try {
      const response =
        await fetch(
          url,
          {
            headers: {
              Accept:
                "application/json",

              "User-Agent":
                "BridgePoint-CT-Property-Transitions-V60",
            },

            signal:
              AbortSignal.timeout(
                45_000,
              ),
          },
        );

      const raw =
        await response.text();

      if (!response.ok) {
        throw new Error(
          `CT Socrata HTTP ${response.status}: ${raw.slice(0, 1500)}`,
        );
      }

      return JSON.parse(raw);
    } catch (error) {
      lastError = error;

      if (attempt < attempts) {
        await new Promise(
          (resolve) =>
            setTimeout(
              resolve,
              750 *
                2 ** attempt,
            ),
        );
      }
    }
  }

  throw (
    lastError instanceof Error
      ? lastError
      : new Error(
          String(lastError),
        )
  );
}

function metadataColumn(
  metadata: JsonObject,
  fieldName: string,
): JsonObject | null {
  const columns =
    metadata.columns;

  if (!Array.isArray(columns)) {
    return null;
  }

  for (const column of columns) {
    if (
      column &&
      typeof column === "object" &&
      !Array.isArray(column)
    ) {
      const item =
        column as JsonObject;

      if (
        text(item.fieldName) ===
        fieldName
      ) {
        return item;
      }
    }
  }

  return null;
}

function cachedLargest(
  column: JsonObject | null,
): string {
  if (!column) {
    return "";
  }

  const cached =
    column.cachedContents;

  if (
    !cached ||
    typeof cached !== "object" ||
    Array.isArray(cached)
  ) {
    return "";
  }

  return text(
    (cached as JsonObject)
      .largest,
  );
}

async function sourceState(): Promise<{
  rowsUpdatedAt: number;
  maxListYear: number;
  maxRecordedAt: string | null;
  datasetName: string;
}> {
  const raw =
    await fetchJson(
      METADATA_URL,
    );

  if (
    !raw ||
    typeof raw !== "object" ||
    Array.isArray(raw)
  ) {
    throw new Error(
      "CT dataset metadata was not an object.",
    );
  }

  const metadata =
    raw as JsonObject;

  const rowsUpdatedAt =
    Number(
      metadata.rowsUpdatedAt,
    );

  if (
    !Number.isFinite(
      rowsUpdatedAt,
    )
  ) {
    throw new Error(
      "CT dataset rowsUpdatedAt is unavailable.",
    );
  }

  const listYearColumn =
    metadataColumn(
      metadata,
      "listyear",
    );

  const dateColumn =
    metadataColumn(
      metadata,
      "daterecorded",
    );

  let maxListYear =
    Number(
      cachedLargest(
        listYearColumn,
      ),
    );

  let maxRecordedAt =
    parseDate(
      cachedLargest(
        dateColumn,
      ),
    );

  /*
   * Fallback to direct Socrata queries if metadata cache
   * does not expose either boundary.
   */
  if (
    !Number.isInteger(maxListYear)
  ) {
    const url =
      new URL(API_URL);

    url.searchParams.set(
      "$select",
      "listyear",
    );

    url.searchParams.set(
      "$order",
      "listyear DESC",
    );

    url.searchParams.set(
      "$limit",
      "1",
    );

    const result =
      await fetchJson(
        url.toString(),
      );

    if (
      Array.isArray(result) &&
      result.length
    ) {
      maxListYear =
        Number(
          (
            result[0] as
              JsonObject
          ).listyear,
        );
    }
  }

  if (!maxRecordedAt) {
    const url =
      new URL(API_URL);

    url.searchParams.set(
      "$select",
      "daterecorded",
    );

    url.searchParams.set(
      "$where",
      "daterecorded is not null",
    );

    url.searchParams.set(
      "$order",
      "daterecorded DESC",
    );

    url.searchParams.set(
      "$limit",
      "1",
    );

    const result =
      await fetchJson(
        url.toString(),
      );

    if (
      Array.isArray(result) &&
      result.length
    ) {
      maxRecordedAt =
        parseDate(
          (
            result[0] as
              JsonObject
          ).daterecorded,
        );
    }
  }

  if (
    !Number.isInteger(
      maxListYear,
    )
  ) {
    throw new Error(
      "Could not determine CT source max list year.",
    );
  }

  return {
    rowsUpdatedAt:
      Math.trunc(rowsUpdatedAt),

    maxListYear:
      Math.trunc(maxListYear),

    maxRecordedAt,

    datasetName:
      text(metadata.name),
  };
}

function sourcePageUrl(
  listYear: number,
  offset: number,
  pageSize: number,
): string {
  const url =
    new URL(API_URL);

  url.searchParams.set(
    "$select",
    SELECT_FIELDS,
  );

  url.searchParams.set(
    "$where",
    `listyear = ${listYear}`,
  );

  url.searchParams.set(
    "$order",
    "serialnumber,town,address,daterecorded",
  );

  url.searchParams.set(
    "$limit",
    String(pageSize),
  );

  url.searchParams.set(
    "$offset",
    String(offset),
  );

  return url.toString();
}

function adminKey(): string {
  /*
   * Current Supabase projects expose the new secret-key map.
   */
  const current =
    Deno.env.get(
      "SUPABASE_SECRET_KEYS",
    );

  if (current) {
    try {
      const parsed =
        JSON.parse(current);

      if (
        parsed &&
        typeof parsed.default ===
          "string" &&
        parsed.default
      ) {
        return parsed.default;
      }
    } catch {
      // Fall through to legacy key.
    }
  }

  /*
   * Legacy projects/functions still expose this automatically.
   */
  const legacy =
    Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

  if (legacy) {
    return legacy;
  }

  throw new Error(
    "Supabase backend secret key is unavailable.",
  );
}

function numberFromState(
  value: unknown,
  fallback = 0,
): number {
  const parsed =
    Number(value);

  return Number.isFinite(parsed)
    ? parsed
    : fallback;
}

Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    if (
      request.method === "OPTIONS"
    ) {
      return new Response(
        "ok",
        {
          headers:
            CORS_HEADERS,
        },
      );
    }

    if (
      request.method !== "POST"
    ) {
      return jsonResponse(
        {
          complete: false,
          error:
            "POST required",
        },
        405,
      );
    }

    let body:
      JsonObject = {};

    let supabase:
      ReturnType<
        typeof createClient
      > | null = null;

    let activeListYear:
      number | null = null;

    let nextOffset = 0;

    let startListYear:
      number | null = null;

    let endListYear:
      number | null = null;

    let sourceRowsUpdatedAt:
      number | null = null;

    let sourceMaxRecordedAt:
      string | null = null;

    let rawRowsScanned = 0;
    let leanRowsSent = 0;
    let recordsNew = 0;
    let recordsUpdated = 0;

    try {
      body =
        await readBody(
          request,
        );

      const dryRun =
        booleanValue(
          body.dry_run,
          false,
        );

      const force =
        booleanValue(
          body.force,
          false,
        );

      if (
        !dryRun &&
        body.task_token !==
          TASK_TOKEN
      ) {
        return jsonResponse(
          {
            complete: false,
            status:
              "unauthorized",
          },
          401,
        );
      }

      const pageSize =
        integerValue(
          body.page_size,
          500,
          100,
          2500,
        );

      const maxPages =
        integerValue(
          body.max_pages,
          4,
          1,
          10,
        );

      const supabaseUrl =
        Deno.env.get(
          "SUPABASE_URL",
        );

      if (!supabaseUrl) {
        throw new Error(
          "SUPABASE_URL is unavailable.",
        );
      }

      supabase =
        createClient(
          supabaseUrl,
          adminKey(),
          {
            auth: {
              persistSession:
                false,

              autoRefreshToken:
                false,
            },
          },
        );

      /*
       * ===============================================================
       * LOAD BRIDGEPOINT REFRESH STATE
       * ===============================================================
       */

      const {
        data:
          stateData,
        error:
          stateError,
      } =
        await supabase.rpc(
          "[REDACTED_LONG_LITERAL]",
        );

      if (stateError) {
        throw new Error(
          `State RPC failed: ${stateError.message}`,
        );
      }

      const state =
        (
          stateData ??
          {}
        ) as JsonObject;

      if (
        state.enabled === false
      ) {
        return jsonResponse({
          complete: true,
          status:
            "source_disabled",
          source_code:
            "CT_PROPERTY_TRANSITIONS",
        });
      }

      const refreshState =
        (
          state.refresh_state &&
          typeof state.refresh_state ===
            "object" &&
          !Array.isArray(
            state.refresh_state,
          )
        )
          ? state.refresh_state as JsonObject
          : {};

      const existingPhase =
        text(
          refreshState.phase,
        ).toUpperCase();

      /*
       * Respect the database scheduler's due time unless this
       * is an authenticated manual force invocation.
       */
      const nextScheduled =
        text(
          state
            .next_scheduled_check_at,
        );

      if (
        !dryRun &&
        !force &&
        nextScheduled
      ) {
        const due =
          Date.parse(
            nextScheduled,
          );

        if (
          Number.isFinite(due) &&
          due > Date.now()
        ) {
          return jsonResponse({
            complete: true,
            status: "not_due",
            source_code:
              "CT_PROPERTY_TRANSITIONS",
            next_scheduled_check_at:
              nextScheduled,
          });
        }
      }

      /*
       * ===============================================================
       * READ CURRENT OFFICIAL CT RELEASE
       * ===============================================================
       */

      const source =
        await sourceState();

      sourceRowsUpdatedAt =
        source.rowsUpdatedAt;

      sourceMaxRecordedAt =
        source.maxRecordedAt;

      const sourceMaxListYear =
        source.maxListYear;

      const lastWatermark =
        text(
          state.last_watermark,
        );

      const sameRelease =
        lastWatermark ===
        String(
          sourceRowsUpdatedAt,
        );

      const stateRelease =
        text(
          refreshState
            .source_rows_updated_at,
        );

      const resumableRelease =
        (
          existingPhase ===
            "RUNNING" ||
          existingPhase ===
            "ERROR"
        ) &&
        stateRelease ===
          String(
            sourceRowsUpdatedAt,
          );

      const databaseMaxListYear =
        numberFromState(
          state
            .database_max_list_year,
          0,
        );

      const configuration =
        (
          state.configuration &&
          typeof state.configuration ===
            "object" &&
          !Array.isArray(
            state.configuration,
          )
        )
          ? state.configuration as JsonObject
          : {};

      const overlap =
        integerValue(
          configuration
            .correction_overlap_list_years,
          1,
          0,
          5,
        );

      /*
       * ===============================================================
       * NO-CHANGE CHECK
       * ===============================================================
       */

      if (
        sameRelease &&
        existingPhase ===
          "SUCCESS" &&
        !force &&
        !dryRun
      ) {
        await supabase.rpc(
          "[REDACTED_LONG_LITERAL]",
          {
            p_phase:
              "SUCCESS",

            p_source_rows_updated_at:
              sourceRowsUpdatedAt,

            p_source_max_list_year:
              sourceMaxListYear,

            p_source_max_recorded_at:
              sourceMaxRecordedAt,

            p_start_list_year:
              null,

            p_end_list_year:
              sourceMaxListYear,

            p_active_list_year:
              null,

            p_next_offset:
              0,

            p_raw_rows_scanned:
              0,

            p_lean_rows_sent:
              0,

            p_records_new:
              0,

            p_records_updated:
              0,

            p_error:
              null,
          },
        );

        return jsonResponse({
          complete: true,
          status:
            "no_source_change",

          source_code:
            "CT_PROPERTY_TRANSITIONS",

          dataset_id:
            DATASET_ID,

          dataset_name:
            source.datasetName,

          source_rows_updated_at:
            sourceRowsUpdatedAt,

          source_max_list_year:
            sourceMaxListYear,

          source_max_recorded_at:
            sourceMaxRecordedAt,

          database_max_list_year:
            databaseMaxListYear,

          raw_payload_retained:
            false,
        });
      }

      /*
       * ===============================================================
       * RESUME EXISTING RELEASE OR CREATE NEW RELEASE PLAN
       * ===============================================================
       */

      if (resumableRelease) {
        startListYear =
          numberFromState(
            refreshState
              .start_list_year,
            databaseMaxListYear,
          );

        endListYear =
          numberFromState(
            refreshState
              .end_list_year,
            sourceMaxListYear,
          );

        activeListYear =
          numberFromState(
            refreshState
              .active_list_year,
            startListYear,
          );

        nextOffset =
          numberFromState(
            refreshState
              .next_offset,
            0,
          );

        rawRowsScanned =
          numberFromState(
            refreshState
              .raw_rows_scanned,
            0,
          );

        leanRowsSent =
          numberFromState(
            refreshState
              .lean_rows_sent,
            0,
          );

        recordsNew =
          numberFromState(
            refreshState
              .records_new,
            0,
          );

        recordsUpdated =
          numberFromState(
            refreshState
              .records_updated,
            0,
          );
      } else {
        /*
         * One-list-year overlap:
         *
         * DB max 2023 + overlap 1
         * => start again at 2023
         * => refresh 2023 corrections + ingest new 2024.
         */
        if (
          databaseMaxListYear >
          0
        ) {
          startListYear =
            Math.max(
              MIN_LIST_YEAR,
              databaseMaxListYear -
                overlap +
                1,
            );
        } else {
          startListYear =
            MIN_LIST_YEAR;
        }

        startListYear =
          Math.min(
            startListYear,
            sourceMaxListYear,
          );

        endListYear =
          sourceMaxListYear;

        activeListYear =
          startListYear;

        nextOffset = 0;

        rawRowsScanned = 0;
        leanRowsSent = 0;
        recordsNew = 0;
        recordsUpdated = 0;
      }

      /*
       * ===============================================================
       * DRY RUN
       *
       * Reads one official page and executes the exact classifier,
       * but changes nothing in Supabase.
       * ===============================================================
       */

      if (dryRun) {
        const previewUrl =
          sourcePageUrl(
            activeListYear!,
            0,
            Math.min(
              pageSize,
              500,
            ),
          );

        const previewRaw =
          await fetchJson(
            previewUrl,
          );

        if (
          !Array.isArray(
            previewRaw,
          )
        ) {
          throw new Error(
            "CT Socrata preview was not an array.",
          );
        }

        const previewLean =
          (
            await Promise.all(
              previewRaw.map(
                (record) =>
                  leanRecord(
                    record as JsonObject,
                  ),
              ),
            )
          ).filter(
            (
              value,
            ): value is LeanRecord =>
              value !== null,
          );

        const signalCounts:
          Record<string, number> =
          {};

        for (
          const record of
          previewLean
        ) {
          for (
            const signal of
            record.signal_keys
              .split("|")
          ) {
            signalCounts[signal] =
              (
                signalCounts[
                  signal
                ] ?? 0
              ) + 1;
          }
        }

        return jsonResponse({
          complete: true,
          status:
            "dry_run",

          database_changed:
            false,

          source_code:
            "CT_PROPERTY_TRANSITIONS",

          dataset_id:
            DATASET_ID,

          dataset_name:
            source.datasetName,

          source_rows_updated_at:
            sourceRowsUpdatedAt,

          source_max_list_year:
            sourceMaxListYear,

          source_max_recorded_at:
            sourceMaxRecordedAt,

          database_max_list_year:
            databaseMaxListYear,

          planned_start_list_year:
            startListYear,

          planned_end_list_year:
            endListYear,

          preview_source_rows:
            previewRaw.length,

          preview_lean_rows:
            previewLean.length,

          preview_signal_counts:
            signalCounts,

          raw_payload_retained:
            false,
        });
      }

      /*
       * ===============================================================
       * MARK/REFRESH CURRENT RELEASE AS RUNNING
       * ===============================================================
       */

      {
        const {
          error,
        } =
          await supabase.rpc(
            "[REDACTED_LONG_LITERAL]",
            {
              p_phase:
                "RUNNING",

              p_source_rows_updated_at:
                sourceRowsUpdatedAt,

              p_source_max_list_year:
                sourceMaxListYear,

              p_source_max_recorded_at:
                sourceMaxRecordedAt,

              p_start_list_year:
                startListYear,

              p_end_list_year:
                endListYear,

              p_active_list_year:
                activeListYear,

              p_next_offset:
                nextOffset,

              p_raw_rows_scanned:
                rawRowsScanned,

              p_lean_rows_sent:
                leanRowsSent,

              p_records_new:
                recordsNew,

              p_records_updated:
                recordsUpdated,

              p_error:
                null,
            },
          );

        if (error) {
          throw new Error(
            `Could not start transition refresh: ${error.message}`,
          );
        }
      }

      /*
       * ===============================================================
       * PROCESS A BOUNDED NUMBER OF SOURCE PAGES
       * ===============================================================
       */

      let pagesProcessed = 0;

      while (
        pagesProcessed <
          maxPages &&
        activeListYear! <=
          endListYear!
      ) {
        const url =
          sourcePageUrl(
            activeListYear!,
            nextOffset,
            pageSize,
          );

        const raw =
          await fetchJson(url);

        if (!Array.isArray(raw)) {
          throw new Error(
            "CT Socrata source page was not an array.",
          );
        }

        /*
         * Empty page means this list year is complete.
         */
        if (
          raw.length === 0
        ) {
          activeListYear! += 1;
          nextOffset = 0;

          continue;
        }

        const lean =
          (
            await Promise.all(
              raw.map(
                (record) =>
                  leanRecord(
                    record as JsonObject,
                  ),
              ),
            )
          ).filter(
            (
              value,
            ): value is LeanRecord =>
              value !== null,
          );

        /*
         * =============================================================
         * INGEST LEAN ROWS ONLY
         *
         * Existing DB RPC maximum = 250.
         * =============================================================
         */

        for (
          let index = 0;
          index < lean.length;
          index += 250
        ) {
          const batch =
            lean.slice(
              index,
              index + 250,
            );

          const {
            data:
              ingestResult,
            error:
              ingestError,
          } =
            await supabase.rpc(
              "[REDACTED_LONG_LITERAL]",
              {
                p_records:
                  batch,

                p_run_type:
                  "INCREMENTAL",
              },
            );

          if (ingestError) {
            throw new Error(
              `Transition ingest failed: ${ingestError.message}`,
            );
          }

          const result =
            (
              ingestResult ??
              {}
            ) as JsonObject;

          leanRowsSent +=
            batch.length;

          recordsNew +=
            numberFromState(
              result.records_new,
              0,
            );

          recordsUpdated +=
            numberFromState(
              result.records_updated,
              0,
            );
        }

        rawRowsScanned +=
          raw.length;

        nextOffset +=
          raw.length;

        pagesProcessed += 1;

        /*
         * A short source page proves end-of-year.
         */
        if (
          raw.length <
          pageSize
        ) {
          activeListYear! += 1;
          nextOffset = 0;
        }

        /*
         * Checkpoint only after the source page and all lean
         * ingestion batches completed successfully.
         */
        if (
          activeListYear! <=
          endListYear!
        ) {
          const {
            error:
              checkpointError,
          } =
            await supabase.rpc(
              "[REDACTED_LONG_LITERAL]",
              {
                p_phase:
                  "RUNNING",

                p_source_rows_updated_at:
                  sourceRowsUpdatedAt,

                p_source_max_list_year:
                  sourceMaxListYear,

                p_source_max_recorded_at:
                  sourceMaxRecordedAt,

                p_start_list_year:
                  startListYear,

                p_end_list_year:
                  endListYear,

                p_active_list_year:
                  activeListYear,

                p_next_offset:
                  nextOffset,

                p_raw_rows_scanned:
                  rawRowsScanned,

                p_lean_rows_sent:
                  leanRowsSent,

                p_records_new:
                  recordsNew,

                p_records_updated:
                  recordsUpdated,

                p_error:
                  null,
              },
            );

          if (
            checkpointError
          ) {
            throw new Error(
              `Transition checkpoint failed: ${checkpointError.message}`,
            );
          }
        }
      }

      /*
       * ===============================================================
       * RELEASE COMPLETE
       * ===============================================================
       */

      if (
        activeListYear! >
        endListYear!
      ) {
        const {
          data:
            completedState,
          error:
            completeError,
        } =
          await supabase.rpc(
            "[REDACTED_LONG_LITERAL]",
            {
              p_phase:
                "SUCCESS",

              p_source_rows_updated_at:
                sourceRowsUpdatedAt,

              p_source_max_list_year:
                sourceMaxListYear,

              p_source_max_recorded_at:
                sourceMaxRecordedAt,

              p_start_list_year:
                startListYear,

              p_end_list_year:
                endListYear,

              p_active_list_year:
                null,

              p_next_offset:
                0,

              p_raw_rows_scanned:
                rawRowsScanned,

              p_lean_rows_sent:
                leanRowsSent,

              p_records_new:
                recordsNew,

              p_records_updated:
                recordsUpdated,

              p_error:
                null,
            },
          );

        if (completeError) {
          throw new Error(
            `Transition completion failed: ${completeError.message}`,
          );
        }

        return jsonResponse({
          complete: true,
          status:
            "release_completed",

          source_code:
            "CT_PROPERTY_TRANSITIONS",

          dataset_id:
            DATASET_ID,

          source_rows_updated_at:
            sourceRowsUpdatedAt,

          source_max_list_year:
            sourceMaxListYear,

          source_max_recorded_at:
            sourceMaxRecordedAt,

          start_list_year:
            startListYear,

          end_list_year:
            endListYear,

          raw_rows_scanned:
            rawRowsScanned,

          lean_rows_sent:
            leanRowsSent,

          records_new:
            recordsNew,

          records_updated:
            recordsUpdated,

          raw_payload_retained:
            false,

          state:
            completedState,
        });
      }

      /*
       * ===============================================================
       * MORE PAGES REMAIN
       * ===============================================================
       */

      return jsonResponse({
        complete: false,
        status:
          "checkpoint_saved",

        source_code:
          "CT_PROPERTY_TRANSITIONS",

        dataset_id:
          DATASET_ID,

        source_rows_updated_at:
          sourceRowsUpdatedAt,

        source_max_list_year:
          sourceMaxListYear,

        source_max_recorded_at:
          sourceMaxRecordedAt,

        start_list_year:
          startListYear,

        end_list_year:
          endListYear,

        active_list_year:
          activeListYear,

        next_offset:
          nextOffset,

        pages_processed:
          pagesProcessed,

        raw_rows_scanned:
          rawRowsScanned,

        lean_rows_sent:
          leanRowsSent,

        records_new:
          recordsNew,

        records_updated:
          recordsUpdated,

        raw_payload_retained:
          false,
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);

      /*
       * Preserve the last fully completed checkpoint.
       */
      if (
        supabase &&
        sourceRowsUpdatedAt !==
          null
      ) {
        try {
          await supabase.rpc(
            "[REDACTED_LONG_LITERAL]",
            {
              p_phase:
                "ERROR",

              p_source_rows_updated_at:
                sourceRowsUpdatedAt,

              p_source_max_list_year:
                endListYear,

              p_source_max_recorded_at:
                sourceMaxRecordedAt,

              p_start_list_year:
                startListYear,

              p_end_list_year:
                endListYear,

              p_active_list_year:
                activeListYear,

              p_next_offset:
                nextOffset,

              p_raw_rows_scanned:
                rawRowsScanned,

              p_lean_rows_sent:
                leanRowsSent,

              p_records_new:
                recordsNew,

              p_records_updated:
                recordsUpdated,

              p_error:
                message,
            },
          );
        } catch {
          // Preserve original failure.
        }
      }

      return jsonResponse(
        {
          complete: false,
          status: "error",
          source_code:
            "CT_PROPERTY_TRANSITIONS",
          error:
            message,
          active_list_year:
            activeListYear,
          next_offset:
            nextOffset,
          raw_rows_scanned:
            rawRowsScanned,
          lean_rows_sent:
            leanRowsSent,
          records_new:
            recordsNew,
          records_updated:
            recordsUpdated,
          raw_payload_retained:
            false,
        },
        500,
      );
    }
  },
);