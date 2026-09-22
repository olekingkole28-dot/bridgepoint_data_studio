const NOAA_DIRECTORY =
  "https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/";

const JSON_HEADERS = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

type JsonRecord = Record<string, string | null>;

type ParsedCsv = {
  records: JsonRecord[];
  rowsScanned: number;
  headers: string[];
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: JSON_HEADERS,
  });
}

function getSupabaseSecretKey(): string {
  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (legacyKey) {
    return legacyKey;
  }

  const namedKeysText = Deno.env.get("SUPABASE_SECRET_KEYS");

  if (namedKeysText) {
    const namedKeys = JSON.parse(namedKeysText);
    const firstKey =
      namedKeys.default ??
      Object.values(namedKeys)[0];

    if (typeof firstKey === "string") {
      return firstKey;
    }
  }

  throw new Error(
    "No Supabase service-role or secret key is available.",
  );
}

async function findLatestNoaaFile(year: number): Promise<{
  fileName: string;
  sourceUrl: string;
  creationDate: string;
}> {
  const response = await fetch(NOAA_DIRECTORY, {
    headers: {
      "User-Agent": "BridgePoint-Intelligence/1.0",
      "Accept": "text/html",
    },
  });

  if (!response.ok) {
    throw new Error(
      `NOAA directory returned HTTP ${response.status}`,
    );
  }

  const directoryHtml = await response.text();

  const pattern = new RegExp(
    `StormEvents_details-ftp_v1\\.0_d${year}_c(\\d{8})\\.csv\\.gz`,
    "gi",
  );

  const matches = Array.from(
    directoryHtml.matchAll(pattern),
  ).map((match) => ({
    fileName: match[0],
    creationDate: match[1],
  }));

  if (matches.length === 0) {
    throw new Error(
      `No NOAA Storm Events details file was found for ${year}.`,
    );
  }

  matches.sort((a, b) =>
    b.creationDate.localeCompare(a.creationDate)
  );

  const newest = matches[0];

  return {
    ...newest,
    sourceUrl:
      NOAA_DIRECTORY +
      encodeURIComponent(newest.fileName),
  };
}

async function downloadAndDecompress(
  sourceUrl: string,
): Promise<{
  csvText: string;
  compressedBytes: number;
  decompressedBytes: number;
}> {
  const response = await fetch(sourceUrl, {
    headers: {
      "User-Agent": "BridgePoint-Intelligence/1.0",
      "Accept": "application/gzip, application/octet-stream",
    },
  });

  if (!response.ok) {
    throw new Error(
      `NOAA file returned HTTP ${response.status}`,
    );
  }

  const compressed = new Uint8Array(
    await response.arrayBuffer(),
  );

  let csvText: string;

  const isGzip =
    compressed.length >= 2 &&
    compressed[0] === 0x1f &&
    compressed[1] === 0x8b;

  if (isGzip) {
    const decompressedStream = new Blob([compressed])
      .stream()
      .pipeThrough(new DecompressionStream("gzip"));

    csvText = await new Response(
      decompressedStream,
    ).text();
  } else {
    csvText = new TextDecoder().decode(compressed);
  }

  return {
    csvText,
    compressedBytes: compressed.byteLength,
    decompressedBytes:
      new TextEncoder().encode(csvText).byteLength,
  };
}

function parseConnecticutRecords(
  csvText: string,
): ParsedCsv {
  const records: JsonRecord[] = [];

  let headers: string[] = [];
  let stateIndex = -1;
  let stateFipsIndex = -1;

  let currentRow: string[] = [];
  let currentField = "";
  let insideQuotes = false;
  let rowsScanned = 0;

  const finishField = () => {
    currentRow.push(currentField);
    currentField = "";
  };

  const finishRow = () => {
    const isBlankRow =
      currentRow.length === 1 &&
      currentRow[0].trim() === "";

    if (isBlankRow) {
      currentRow = [];
      return;
    }

    if (headers.length === 0) {
      headers = currentRow.map((header, index) => {
        const cleaned = header.trim();

        return index === 0
          ? cleaned.replace(/^\uFEFF/, "")
          : cleaned;
      });

      stateIndex = headers.indexOf("STATE");
      stateFipsIndex = headers.indexOf("STATE_FIPS");

      if (stateIndex < 0 || stateFipsIndex < 0) {
        throw new Error(
          "NOAA CSV is missing STATE or STATE_FIPS.",
        );
      }

      currentRow = [];
      return;
    }

    rowsScanned += 1;

    const state =
      (currentRow[stateIndex] ?? "")
        .trim()
        .toUpperCase();

    const stateFips =
      (currentRow[stateFipsIndex] ?? "")
        .trim()
        .padStart(2, "0");

    const isConnecticut =
      state === "CONNECTICUT" ||
      stateFips === "09";

    if (isConnecticut) {
      const record: JsonRecord = {};

      for (let index = 0; index < headers.length; index++) {
        const value = currentRow[index] ?? "";

        record[headers[index]] =
          value === "" ? null : value;
      }

      const eventId = record.EVENT_ID;

      if (
        typeof eventId === "string" &&
        eventId.trim() !== ""
      ) {
        records.push(record);
      }
    }

    currentRow = [];
  };

  for (let index = 0; index < csvText.length; index++) {
    const character = csvText[index];

    if (insideQuotes) {
      if (character === '"') {
        if (csvText[index + 1] === '"') {
          currentField += '"';
          index += 1;
        } else {
          insideQuotes = false;
        }
      } else {
        currentField += character;
      }

      continue;
    }

    if (character === '"') {
      insideQuotes = true;
    } else if (character === ",") {
      finishField();
    } else if (character === "\n") {
      finishField();
      finishRow();
    } else if (character !== "\r") {
      currentField += character;
    }
  }

  if (
    currentField.length > 0 ||
    currentRow.length > 0
  ) {
    finishField();
    finishRow();
  }

  return {
    records,
    rowsScanned,
    headers,
  };
}

async function callIngestionRpc(
  records: JsonRecord[],
  runType: string,
  sourceFile: string,
  creationDate: string,
): Promise<Record<string, unknown>> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");

  if (!supabaseUrl) {
    throw new Error("SUPABASE_URL is unavailable.");
  }

  const secretKey = getSupabaseSecretKey();

  const response = await fetch(
    `${supabaseUrl}/rest/v1/rpc/bridgepoint_ingest_noaa_event_batch`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": secretKey,
        "Authorization": `Bearer ${secretKey}`,
        "Prefer": "return=representation",
        "X-Client-Info":
          "bridgepoint-noaa-ingest-v1",
      },
      body: JSON.stringify({
        p_records: records,
        p_run_type: runType,
        p_watermark_start: sourceFile,
        p_watermark_end: creationDate,
      }),
    },
  );

  const responseText = await response.text();

  let result: Record<string, unknown>;

  try {
    result = JSON.parse(responseText);
  } catch {
    throw new Error(
      `Supabase RPC returned non-JSON: ${responseText}`,
    );
  }

  if (!response.ok) {
    throw new Error(
      `Supabase RPC HTTP ${response.status}: ${responseText}`,
    );
  }

  if (result.complete === false) {
    throw new Error(
      `NOAA ingestion RPC failed: ${responseText}`,
    );
  }

  return result;
}

Deno.serve(async (request: Request) => {
  const startedAt = Date.now();

  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        ...JSON_HEADERS,
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      {
        complete: false,
        error: "Use an HTTP POST request.",
      },
      405,
    );
  }

  try {
    let options: Record<string, unknown> = {};

    const requestText = await request.text();

    if (requestText.trim() !== "") {
      options = JSON.parse(requestText);
    }

    const currentYear = new Date().getUTCFullYear();

    const year = Number(
      options.year ?? currentYear,
    );

    if (
      !Number.isInteger(year) ||
      year < 2000 ||
      year > currentYear
    ) {
      return jsonResponse(
        {
          complete: false,
          error:
            `year must be between 2000 and ${currentYear}`,
        },
        400,
      );
    }

    const dryRun = options.dry_run === true;

    const requestedBatchSize = Number(
      options.batch_size ?? 250,
    );

    const batchSize = Math.max(
      1,
      Math.min(
        Number.isFinite(requestedBatchSize)
          ? Math.floor(requestedBatchSize)
          : 250,
        500,
      ),
    );

    const requestedRunType = String(
      options.run_type ??
        (dryRun ? "MANUAL" : "SCHEDULED"),
    ).toUpperCase();

    const allowedRunTypes = new Set([
      "SCHEDULED",
      "MANUAL",
      "BACKFILL",
      "REPAIR",
      "REPROCESS",
    ]);

    if (!allowedRunTypes.has(requestedRunType)) {
      return jsonResponse(
        {
          complete: false,
          error: "Unsupported run_type.",
        },
        400,
      );
    }

    const latestFile = await findLatestNoaaFile(year);

    const download = await downloadAndDecompress(
      latestFile.sourceUrl,
    );

    const parsed = parseConnecticutRecords(
      download.csvText,
    );

    if (parsed.records.length === 0) {
      throw new Error(
        `The NOAA ${year} file contained no Connecticut events.`,
      );
    }

    if (dryRun) {
      return jsonResponse({
        complete: true,
        status: "dry_run",
        database_changed: false,
        year,
        source_file: latestFile.fileName,
        source_url: latestFile.sourceUrl,
        source_creation_date:
          latestFile.creationDate,
        national_rows_scanned:
          parsed.rowsScanned,
        connecticut_events_found:
          parsed.records.length,
        compressed_bytes:
          download.compressedBytes,
        decompressed_bytes:
          download.decompressedBytes,
        detected_columns:
          parsed.headers.length,
        sample_events: parsed.records
          .slice(0, 10)
          .map((record) => ({
            event_id: record.EVENT_ID,
            event_type: record.EVENT_TYPE,
            begin_date_time:
              record.BEGIN_DATE_TIME,
            county_or_zone: record.CZ_NAME,
          })),
        duration_ms: Date.now() - startedAt,
      });
    }

    const totals = {
      records_found: 0,
      records_parsed: 0,
      records_new: 0,
      records_updated: 0,
      records_duplicate: 0,
      records_rejected: 0,
      records_review: 0,
      events_created: 0,
      events_updated: 0,
      events_queued_for_reprocessing: 0,
    };

    const batchResults: Record<string, unknown>[] = [];

    for (
      let offset = 0;
      offset < parsed.records.length;
      offset += batchSize
    ) {
      const batch = parsed.records.slice(
        offset,
        offset + batchSize,
      );

      const result = await callIngestionRpc(
        batch,
        requestedRunType,
        latestFile.fileName,
        latestFile.creationDate,
      );

      for (const key of Object.keys(totals)) {
        const value = Number(result[key] ?? 0);

        if (Number.isFinite(value)) {
          totals[
            key as keyof typeof totals
          ] += value;
        }
      }

      batchResults.push({
        batch_number:
          Math.floor(offset / batchSize) + 1,
        records_sent: batch.length,
        import_run_id: result.import_run_id,
        status: result.status,
        records_new: result.records_new,
        records_updated: result.records_updated,
        records_duplicate:
          result.records_duplicate,
        records_rejected:
          result.records_rejected,
        records_review: result.records_review,
        events_created: result.events_created,
        events_updated: result.events_updated,
        events_queued:
          result.events_queued_for_reprocessing,
      });
    }

    return jsonResponse({
      complete: true,
      status: "completed",
      year,
      source_file: latestFile.fileName,
      source_url: latestFile.sourceUrl,
      source_creation_date:
        latestFile.creationDate,
      national_rows_scanned:
        parsed.rowsScanned,
      connecticut_events_found:
        parsed.records.length,
      batch_size: batchSize,
      batches_completed:
        batchResults.length,
      totals,
      batch_results: batchResults,
      downstream_execution_enabled: false,
      duration_ms: Date.now() - startedAt,
    });
  } catch (error) {
    console.error(error);

    return jsonResponse(
      {
        complete: false,
        status: "failed",
        error:
          error instanceof Error
            ? error.message
            : String(error),
        duration_ms: Date.now() - startedAt,
      },
      500,
    );
  }
});