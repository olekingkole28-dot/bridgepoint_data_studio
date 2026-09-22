import { createClient } from "npm:@supabase/supabase-js@2";

type JsonObject = Record<string, unknown>;

type Watermark = {
  updated_at: string;
  id: string;
};

type DeepJob = {
  source_key: string;
  source_code: string;
  dataset_id: string;
  enabled: boolean;
  due: boolean;
  last_watermark?: unknown;
  next_scheduled_check_at?: string | null;
};

const PAGE_SIZE = 250;

/*
 * Existing DEEP ingest functions cap batches at 250.
 *
 * Two pages per invocation keeps the Edge request bounded even
 * if Socrata republishes an entire dataset and makes every row
 * appear updated.
 *
 * V55's database scheduler will continue automatically until
 * has_more becomes false.
 */
const MAX_PAGES_PER_SOURCE = 2;

const SOCRATA_DOMAIN =
  "https://data.ct.gov";

const RUN_TYPE =
  "INCREMENTAL_AUTO_V55";


function response(
  body: unknown,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(
      body,
      null,
      2,
    ),
    {
      status,
      headers: {
        "Content-Type":
          "application/json",
      },
    },
  );
}


function clean(
  value: unknown,
): string {
  if (
    value === null
    || value === undefined
  ) {
    return "";
  }

  return String(value).trim();
}


function getAdminKey(): string {
  const legacy =
    Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

  if (legacy) {
    return legacy;
  }


  const raw =
    Deno.env.get(
      "SUPABASE_SECRET_KEYS",
    );

  if (!raw) {
    throw new Error(
      "No Supabase server secret available.",
    );
  }


  const parsed =
    JSON.parse(raw);


  if (
    typeof parsed?.default === "string"
    && parsed.default.length > 0
  ) {
    return parsed.default;
  }


  for (
    const value
    of Object.values(parsed)
  ) {
    if (
      typeof value === "string"
      && value.length > 0
    ) {
      return value;
    }
  }


  throw new Error(
    "SUPABASE_SECRET_KEYS contained no usable key.",
  );
}


const SUPABASE_URL =
  Deno.env.get(
    "SUPABASE_URL",
  );

if (!SUPABASE_URL) {
  throw new Error(
    "SUPABASE_URL unavailable.",
  );
}


const supabase =
  createClient(
    SUPABASE_URL,
    getAdminKey(),
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    },
  );


async function rpc<T>(
  name: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      name,
      args,
    );


  if (error) {
    throw new Error(
      `${name}: ${error.message}`,
    );
  }


  return data as T;
}


function parseWatermark(
  value: unknown,
): Watermark | null {
  if (
    value === null
    || value === undefined
    || value === ""
  ) {
    return null;
  }


  let parsed: unknown =
    value;


  if (
    typeof value === "string"
  ) {
    try {
      parsed =
        JSON.parse(value);
    } catch {
      return null;
    }
  }


  if (
    !parsed
    || typeof parsed !== "object"
  ) {
    return null;
  }


  const row =
    parsed as JsonObject;


  const updatedAt =
    clean(
      row.updated_at,
    );


  const id =
    clean(
      row.id,
    );


  if (
    !updatedAt
    || !id
  ) {
    return null;
  }


  return {
    updated_at:
      updatedAt,

    id,
  };
}


function watermarkFromRow(
  row: JsonObject,
): Watermark {
  const updatedAt =
    clean(
      row[":updated_at"],
    );


  const id =
    clean(
      row[":id"],
    );


  if (
    !updatedAt
    || !id
  ) {
    throw new Error(
      "Socrata response did not contain :updated_at and :id.",
    );
  }


  return {
    updated_at:
      updatedAt,

    id,
  };
}


function socrataLiteral(
  value: string,
): string {
  return (
    "'"
    +
    value.replace(
      /'/g,
      "''",
    )
    +
    "'"
  );
}


async function fetchWithRetry(
  url: string,
): Promise<JsonObject[]> {
  let lastError = "";


  for (
    let attempt = 1;
    attempt <= 6;
    attempt++
  ) {
    try {
      const headers:
        Record<string, string> = {
          "Accept":
            "application/json",

          "User-Agent":
            "BridgePoint-Intelligence-DEEP-V55",
        };


      /*
       * Optional.
       *
       * BridgePoint does not require a Socrata token for these
       * public datasets, but will automatically use one later
       * if SOCRATA_APP_TOKEN is configured.
       */
      const appToken =
        Deno.env.get(
          "SOCRATA_APP_TOKEN",
        );


      if (appToken) {
        headers[
          "X-App-Token"
        ] = appToken;
      }


      const result =
        await fetch(
          url,
          {
            method: "GET",
            headers,
          },
        );


      if (result.ok) {
        const payload =
          await result.json();


        if (
          !Array.isArray(payload)
        ) {
          throw new Error(
            "Unexpected Socrata response shape.",
          );
        }


        return payload as JsonObject[];
      }


      const detail =
        (
          await result.text()
        ).slice(
          0,
          1500,
        );


      lastError =
        `Socrata HTTP ${result.status}: ${detail}`;


      if (
        result.status === 429
        || result.status >= 500
      ) {
        await new Promise(
          (resolve) =>
            setTimeout(
              resolve,
              attempt * 2000,
            ),
        );

        continue;
      }


      throw new Error(
        lastError,
      );
    } catch (error) {
      lastError =
        error instanceof Error
          ? error.message
          : String(error);


      if (attempt === 6) {
        break;
      }


      await new Promise(
        (resolve) =>
          setTimeout(
            resolve,
            attempt * 2000,
          ),
      );
    }
  }


  throw new Error(
    `Socrata request failed: ${lastError}`,
  );
}


async function fetchHighWatermark(
  datasetId: string,
): Promise<Watermark | null> {
  const url =
    new URL(
      `${SOCRATA_DOMAIN}/resource/${datasetId}.json`,
    );


  url.searchParams.set(
    "$select",
    ":updated_at,:id",
  );


  url.searchParams.set(
    "$order",
    ":updated_at DESC,:id DESC",
  );


  url.searchParams.set(
    "$limit",
    "1",
  );


  const rows =
    await fetchWithRetry(
      url.toString(),
    );


  if (
    rows.length === 0
  ) {
    return null;
  }


  return watermarkFromRow(
    rows[0],
  );
}


async function fetchIncrementalPage(
  datasetId: string,
  watermark: Watermark,
): Promise<JsonObject[]> {
  const url =
    new URL(
      `${SOCRATA_DOMAIN}/resource/${datasetId}.json`,
    );


  /*
   * :*,* returns Socrata system fields plus all source fields.
   *
   * The database adapter receives the raw row and converts it
   * into BridgePoint's existing lean ingestion contracts.
   */
  url.searchParams.set(
    "$select",
    ":*,*",
  );


  const updatedAt =
    socrataLiteral(
      watermark.updated_at,
    );


  const id =
    socrataLiteral(
      watermark.id,
    );


  url.searchParams.set(
    "$where",

    "("
    +
    `:updated_at > ${updatedAt}`
    +
    " OR "
    +
    "("
    +
    `:updated_at = ${updatedAt}`
    +
    " AND "
    +
    `:id > ${id}`
    +
    ")"
    +
    ")",
  );


  url.searchParams.set(
    "$order",
    ":updated_at ASC,:id ASC",
  );


  url.searchParams.set(
    "$limit",
    String(
      PAGE_SIZE,
    ),
  );


  return await fetchWithRetry(
    url.toString(),
  );
}


async function commit(
  sourceKey: string,
  watermark: Watermark | null,
  recordsFound: number,
  recordsSubmitted: number,
  hasMore: boolean,
  status: string,
  error: string | null,
): Promise<unknown> {
  return await rpc(
    "bridgepoint_deep_refresh_commit_v55",
    {
      p_source_key:
        sourceKey,

      p_watermark:
        watermark
          ? JSON.stringify(
              watermark,
            )
          : null,

      p_records_found:
        recordsFound,

      p_records_submitted:
        recordsSubmitted,

      p_has_more:
        hasMore,

      p_status:
        status,

      p_error:
        error,
    },
  );
}


async function ingestRows(
  job: DeepJob,
  rows: JsonObject[],
): Promise<unknown> {
  /*
   * IMPORTANT:
   *
   * The Edge worker does NOT invent or recalculate UST IDs.
   *
   * V55 SQL will:
   *
   *   - resolve existing UST records using
   *       REACT Case Number
   *       + Substance
   *       + Substance Other
   *
   *   - reuse the existing historical source_record_id and
   *     release_group_id whenever that natural identity exists
   *
   *   - create deterministic IDs only for genuinely new rows
   *
   * This preserves all 2,195 existing UST identities.
   */


  if (
    job.source_key ===
      "SPILL_CURRENT"
    ||
    job.source_key ===
      "SPILL_HIST"
  ) {
    return await rpc(
      "bridgepoint_ingest_deep_spill_incremental_v55",
      {
        p_dataset_id:
          job.dataset_id,

        p_rows:
          rows,

        p_run_type:
          RUN_TYPE,
      },
    );
  }


  if (
    job.source_key ===
    "UST_RELEASES"
  ) {
    return await rpc(
      "bridgepoint_ingest_deep_ust_incremental_v55",
      {
        p_dataset_id:
          job.dataset_id,

        p_rows:
          rows,

        p_run_type:
          RUN_TYPE,
      },
    );
  }


  throw new Error(
    `Unsupported DEEP source_key: ${job.source_key}`,
  );
}


async function processJob(
  job: DeepJob,
  force: boolean,
): Promise<JsonObject> {
  if (
    job.enabled !== true
  ) {
    return {
      source_key:
        job.source_key,

      dataset_id:
        job.dataset_id,

      status:
        "disabled",

      complete:
        true,
    };
  }


  if (
    job.due !== true
    && !force
  ) {
    return {
      source_key:
        job.source_key,

      dataset_id:
        job.dataset_id,

      status:
        "not_due",

      complete:
        true,

      next_check:
        job
          .next_scheduled_check_at
          ?? null,
    };
  }


  let watermark =
    parseWatermark(
      job.last_watermark,
    );


  /*
   * FIRST V55 RUN
   *
   * BridgePoint already contains the historical loads.
   * Establish the present source high-watermark only.
   *
   * No historical rows are resent.
   */
  if (!watermark) {
    const highWatermark =
      await fetchHighWatermark(
        job.dataset_id,
      );


    await commit(
      job.source_key,
      highWatermark,
      0,
      0,
      false,
      highWatermark
        ? "BOOTSTRAPPED"
        : "BOOTSTRAPPED_EMPTY",
      null,
    );


    return {
      source_key:
        job.source_key,

      dataset_id:
        job.dataset_id,

      complete:
        true,

      status:
        highWatermark
          ? "bootstrapped"
          : "bootstrapped_empty",

      historical_reload:
        false,

      watermark:
        highWatermark,
    };
  }


  let totalFound =
    0;

  let totalSubmitted =
    0;

  let pagesProcessed =
    0;

  let lastIngestResult:
    unknown = null;

  let hasMore =
    false;


  for (
    let page = 0;
    page < MAX_PAGES_PER_SOURCE;
    page++
  ) {
    const rows =
      await fetchIncrementalPage(
        job.dataset_id,
        watermark,
      );


    if (
      rows.length === 0
    ) {
      hasMore =
        false;


      await commit(
        job.source_key,
        watermark,
        totalFound,
        totalSubmitted,
        false,
        "COMPLETED",
        null,
      );


      return {
        source_key:
          job.source_key,

        dataset_id:
          job.dataset_id,

        complete:
          true,

        status:
          "completed",

        pages_processed:
          pagesProcessed,

        records_found:
          totalFound,

        records_submitted:
          totalSubmitted,

        has_more:
          false,

        watermark,

        ingest_result:
          lastIngestResult,
      };
    }


    const nextWatermark =
      watermarkFromRow(
        rows[
          rows.length - 1
        ],
      );


    /*
     * Do not advance the watermark until BridgePoint ingestion
     * has completed successfully.
     */
    lastIngestResult =
      await ingestRows(
        job,
        rows,
      );


    totalFound +=
      rows.length;

    totalSubmitted +=
      rows.length;

    pagesProcessed++;


    hasMore =
      rows.length ===
      PAGE_SIZE;


    watermark =
      nextWatermark;


    /*
     * Commit after every successfully ingested page.
     *
     * If page 2 later fails, page 1 never has to be repeated.
     */
    await commit(
      job.source_key,
      watermark,
      rows.length,
      rows.length,
      hasMore,
      hasMore
        ? "CONTINUING"
        : "COMPLETED",
      null,
    );


    if (!hasMore) {
      break;
    }
  }


  return {
    source_key:
      job.source_key,

    dataset_id:
      job.dataset_id,

    complete:
      !hasMore,

    status:
      hasMore
        ? "continuing"
        : "completed",

    pages_processed:
      pagesProcessed,

    records_found:
      totalFound,

    records_submitted:
      totalSubmitted,

    has_more:
      hasMore,

    watermark,

    ingest_result:
      lastIngestResult,
  };
}


Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    if (
      request.method !== "POST"
    ) {
      return response(
        {
          complete: false,
          error:
            "POST required.",
        },
        405,
      );
    }


    try {
      const body =
        await request.json()
          .catch(
            () => ({}),
          );


      /*
       * V55 SQL installer will create this RPC.
       *
       * Expected shape:
       *
       * {
       *   task_token: "...",
       *   jobs: [
       *     {
       *       source_key: "SPILL_CURRENT",
       *       source_code: "CT_DEEP_SPILL_RELEASES",
       *       dataset_id: "ffju-s5c5",
       *       ...
       *     },
       *     {
       *       source_key: "SPILL_HIST",
       *       source_code: "CT_DEEP_SPILL_RELEASES",
       *       dataset_id: "wr2a-rnsg",
       *       ...
       *     },
       *     {
       *       source_key: "UST_RELEASES",
       *       source_code: "CT_DEEP_UST_RELEASES",
       *       dataset_id: "yc6z-jrb5",
       *       ...
       *     }
       *   ]
       * }
       */
      const state =
        await rpc<any>(
          "bridgepoint_deep_refresh_state_v55",
        );


      const suppliedToken =
        clean(
          body?.task_token,
        );


      if (
        !state?.task_token
        ||
        suppliedToken !==
          state.task_token
      ) {
        return response(
          {
            complete: false,
            status:
              "unauthorized",
          },
          401,
        );
      }


      const jobs:
        DeepJob[] =
        Array.isArray(
          state.jobs,
        )
          ? state.jobs
          : [];


      if (
        jobs.length === 0
      ) {
        return response({
          complete: true,
          status:
            "no_sources",
          results: [],
        });
      }


      const force =
        body?.force === true;


      const results:
        JsonObject[] = [];

      const failures:
        JsonObject[] = [];


      /*
       * Run sources sequentially.
       *
       * We intentionally do NOT make three heavy downstream
       * ingestion calls in parallel against Postgres.
       */
      for (
        const job
        of jobs
      ) {
        try {
          const result =
            await processJob(
              job,
              force,
            );


          results.push(
            result,
          );
        } catch (error) {
          const message =
            error instanceof Error
              ? error.message
              : String(error);


          try {
            await commit(
              job.source_key,
              parseWatermark(
                job.last_watermark,
              ),
              0,
              0,
              false,
              "FAILED",
              message,
            );
          } catch {
            // Preserve original source failure.
          }


          const failure = {
            source_key:
              job.source_key,

            dataset_id:
              job.dataset_id,

            complete:
              false,

            status:
              "failed",

            error:
              message,
          };


          results.push(
            failure,
          );

          failures.push(
            failure,
          );
        }
      }


      return response(
        {
          complete:
            failures.length === 0,

          status:
            failures.length === 0
              ? "completed"
              : "partial_failure",

          sources_considered:
            jobs.length,

          failures:
            failures.length,

          results,
        },

        failures.length === 0
          ? 200
          : 500,
      );
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);


      console.error(
        message,
      );


      return response(
        {
          complete: false,
          status:
            "failed",
          error:
            message,
        },
        500,
      );
    }
  },
);