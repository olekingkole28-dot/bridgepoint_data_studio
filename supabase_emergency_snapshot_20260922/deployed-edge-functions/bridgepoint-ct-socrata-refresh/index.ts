import { createClient } from "npm:@supabase/supabase-js@2";

type SourceCode =
  | "CT_DEEP_REACT"
  | "CT_BUSINESS_MASTER";

type Cursor = {
  updated_at: string;
  id: string;
};

type RefreshState = {
  source_code: string;
  enabled: boolean;
  due: boolean;
  task_token: string;
  last_watermark: string | null;
  next_scheduled_check_at: string | null;
};

const SOURCES: Record<
  SourceCode,
  {
    datasetId: string;
    label: string;
  }
> = {
  CT_DEEP_REACT: {
    datasetId: "xcxg-6jqp",
    label: "Connecticut DEEP REACT",
  },

  CT_BUSINESS_MASTER: {
    datasetId: "n7gp-d28j",
    label: "Connecticut Business Master",
  },
};


function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body, null, 2),
    {
      status,
      headers: {
        "Content-Type": "application/json",
      },
    },
  );
}


function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}


function clamp(
  value: number,
  minimum: number,
  maximum: number,
): number {
  return Math.max(
    minimum,
    Math.min(maximum, value),
  );
}


function escapeSoqlLiteral(
  value: string,
): string {
  return value.replaceAll("'", "''");
}


function getAdminKey(): string {
  const legacy =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (legacy) {
    return legacy;
  }

  const raw =
    Deno.env.get("SUPABASE_SECRET_KEYS");

  if (!raw) {
    throw new Error(
      "No Supabase server-side secret key is available.",
    );
  }

  const parsed = JSON.parse(raw);

  if (
    typeof parsed?.default === "string"
    && parsed.default.length > 0
  ) {
    return parsed.default;
  }

  for (const value of Object.values(parsed)) {
    if (
      typeof value === "string"
      && value.length > 0
    ) {
      return value;
    }
  }

  throw new Error(
    "SUPABASE_SECRET_KEYS did not contain a usable key.",
  );
}


function parseWatermark(
  value: unknown,
): Cursor | null {
  if (
    typeof value !== "string"
    || value.trim() === ""
  ) {
    return null;
  }

  try {
    const parsed = JSON.parse(value);

    if (
      typeof parsed?.updated_at === "string"
      && typeof parsed?.id === "string"
    ) {
      return {
        updated_at: parsed.updated_at,
        id: parsed.id,
      };
    }
  } catch {
    /*
     * Legacy/fallback watermark:
     * treat plain text as a timestamp.
     */
    return {
      updated_at: value,
      id: "",
    };
  }

  return null;
}


function extractCursor(
  row: Record<string, unknown>,
): Cursor {
  const updatedAt =
    row[":updated_at"];

  const id =
    row[":id"];

  if (
    typeof updatedAt !== "string"
    || updatedAt.length === 0
  ) {
    throw new Error(
      "Socrata row did not contain :updated_at.",
    );
  }

  if (
    typeof id !== "string"
    || id.length === 0
  ) {
    throw new Error(
      "Socrata row did not contain :id.",
    );
  }

  return {
    updated_at: updatedAt,
    id,
  };
}


const SUPABASE_URL =
  Deno.env.get("SUPABASE_URL");

if (!SUPABASE_URL) {
  throw new Error(
    "SUPABASE_URL is unavailable.",
  );
}


const supabase = createClient(
  SUPABASE_URL,
  getAdminKey(),
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);


async function callRpc<T>(
  functionName: string,
  args: Record<string, unknown>,
): Promise<T> {
  const { data, error } =
    await supabase.rpc(
      functionName,
      args,
    );

  if (error) {
    throw new Error(
      `${functionName}: ${error.message}`,
    );
  }

  return data as T;
}


async function fetchSocrata(
  url: URL,
): Promise<
  Array<Record<string, unknown>>
> {
  const appToken =
    Deno.env.get("SOCRATA_APP_TOKEN");

  let lastError = "";

  for (
    let attempt = 1;
    attempt <= 6;
    attempt++
  ) {
    try {
      const headers: Record<string, string> = {
        Accept: "application/json",
        "User-Agent":
          "BridgePoint-Intelligence/CT-Socrata-V51",
      };

      if (appToken) {
        headers["X-App-Token"] =
          appToken;
      }

      const response =
        await fetch(
          url.toString(),
          {
            method: "GET",
            headers,
          },
        );

      if (response.ok) {
        const data =
          await response.json();

        if (!Array.isArray(data)) {
          throw new Error(
            "Socrata response was not an array.",
          );
        }

        return data;
      }

      const responseText =
        await response.text();

      lastError =
        `HTTP ${response.status}: `
        + responseText.slice(0, 1000);

      /*
       * Retry infrastructure/rate-limit failures.
       */
      if (
        response.status === 429
        || response.status === 500
        || response.status === 502
        || response.status === 503
        || response.status === 504
        || response.status === 520
        || response.status === 521
        || response.status === 522
        || response.status === 523
        || response.status === 524
        || response.status === 525
      ) {
        await sleep(
          Math.min(
            15000,
            attempt * 2000,
          ),
        );

        continue;
      }

      throw new Error(lastError);
    } catch (error) {
      lastError =
        error instanceof Error
          ? error.message
          : String(error);

      if (attempt === 6) {
        break;
      }

      await sleep(
        Math.min(
          15000,
          attempt * 2000,
        ),
      );
    }
  }

  throw new Error(
    `Socrata request failed after retries: ${lastError}`,
  );
}


function buildBootstrapUrl(
  datasetId: string,
): URL {
  const url =
    new URL(
      `https://data.ct.gov/resource/${datasetId}.json`,
    );

  url.searchParams.set(
    "$select",
    ":id,:updated_at",
  );

  url.searchParams.set(
    "$order",
    ":updated_at DESC, :id DESC",
  );

  url.searchParams.set(
    "$limit",
    "1",
  );

  return url;
}


function buildIncrementalUrl(
  datasetId: string,
  cursor: Cursor,
  pageSize: number,
): URL {
  const url =
    new URL(
      `https://data.ct.gov/resource/${datasetId}.json`,
    );

  /*
   * :*,* means:
   * include Socrata system fields AND source fields.
   */
  url.searchParams.set(
    "$select",
    ":*,*",
  );

  url.searchParams.set(
    "$order",
    ":updated_at ASC, :id ASC",
  );

  url.searchParams.set(
    "$limit",
    String(pageSize),
  );

  const timestamp =
    escapeSoqlLiteral(
      cursor.updated_at,
    );

  const id =
    escapeSoqlLiteral(
      cursor.id,
    );

  if (cursor.id.length > 0) {
    url.searchParams.set(
      "$where",
      `(`
      + `:updated_at > '${timestamp}'`
      + ` OR `
      + `(`
      + `:updated_at = '${timestamp}'`
      + ` AND `
      + `:id > '${id}'`
      + `)`
      + `)`,
    );
  } else {
    url.searchParams.set(
      "$where",
      `:updated_at > '${timestamp}'`,
    );
  }

  return url;
}


Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonResponse(
        {
          complete: false,
          status: "method_not_allowed",
        },
        405,
      );
    }

    let sourceCode: SourceCode | null =
      null;

    try {
      const body =
        await request.json();

      sourceCode =
        String(
          body?.source_code ?? "",
        ).toUpperCase() as SourceCode;

      if (!(sourceCode in SOURCES)) {
        return jsonResponse(
          {
            complete: false,
            status: "unsupported_source",
            supplied_source:
              body?.source_code ?? null,
          },
          400,
        );
      }


      const source =
        SOURCES[sourceCode];

      const pageSize =
        clamp(
          Number(
            body?.page_size ?? 500,
          ),
          50,
          500,
        );

      const maxPages =
        clamp(
          Number(
            body?.max_pages ?? 8,
          ),
          1,
          20,
        );

      const force =
        body?.force === true;


      /*
       * Read registry state through a SECURITY DEFINER
       * public RPC installed in the next SQL step.
       */
      const state =
        await callRpc<RefreshState>(
          "bridgepoint_ct_socrata_refresh_state_v51",
          {
            p_source_code:
              sourceCode,
          },
        );


      /*
       * Custom task authentication.
       *
       * Function can safely run without Edge JWT verification
       * because SQL owns this private rotating task token.
       */
      const suppliedToken =
        String(
          body?.task_token ?? "",
        );

      if (
        !state?.task_token
        || suppliedToken
           !== state.task_token
      ) {
        return jsonResponse(
          {
            complete: false,
            status: "unauthorized",
          },
          401,
        );
      }


      if (!state.enabled) {
        return jsonResponse({
          complete: true,
          status: "source_disabled",
          source_code: sourceCode,
        });
      }


      if (
        !force
        && state.due !== true
      ) {
        return jsonResponse({
          complete: true,
          status: "not_due",
          source_code: sourceCode,
          next_scheduled_check_at:
            state.next_scheduled_check_at,
        });
      }


      let cursor =
        parseWatermark(
          state.last_watermark,
        );


      /*
       * ---------------------------------------------------------
       * FIRST AUTOMATIC RUN
       * ---------------------------------------------------------
       *
       * Historical bulk ingestion is already complete.
       *
       * Therefore DO NOT download 1.3 million Business Master
       * rows again.
       *
       * First automatic run simply records Socrata's current
       * high-water mark.
       * ---------------------------------------------------------
       */
      if (!cursor) {
        const bootstrapRows =
          await fetchSocrata(
            buildBootstrapUrl(
              source.datasetId,
            ),
          );

        if (
          bootstrapRows.length === 0
        ) {
          const result =
            await callRpc(
              "bridgepoint_ct_socrata_refresh_commit_v51",
              {
                p_source_code:
                  sourceCode,

                p_watermark:
                  null,

                p_records_found:
                  0,

                p_records_staged:
                  0,

                p_has_more:
                  false,

                p_status:
                  "BOOTSTRAPPED_EMPTY",

                p_error:
                  null,

                p_detail: {
                  dataset_id:
                    source.datasetId,
                  label:
                    source.label,
                },
              },
            );

          return jsonResponse({
            complete: true,
            status:
              "bootstrapped_empty",
            source_code:
              sourceCode,
            commit_result:
              result,
          });
        }


        cursor =
          extractCursor(
            bootstrapRows[0],
          );


        const watermark =
          JSON.stringify(cursor);


        const result =
          await callRpc(
            "bridgepoint_ct_socrata_refresh_commit_v51",
            {
              p_source_code:
                sourceCode,

              p_watermark:
                watermark,

              p_records_found:
                0,

              p_records_staged:
                0,

              p_has_more:
                false,

              p_status:
                "BOOTSTRAPPED",

              p_error:
                null,

              p_detail: {
                dataset_id:
                  source.datasetId,

                label:
                  source.label,

                bootstrap_watermark:
                  cursor,
              },
            },
          );


        return jsonResponse({
          complete: true,
          status: "bootstrapped",
          source_code:
            sourceCode,
          dataset_id:
            source.datasetId,
          watermark:
            cursor,
          historical_reload:
            false,
          commit_result:
            result,
        });
      }


      /*
       * ---------------------------------------------------------
       * INCREMENTAL MODE
       * ---------------------------------------------------------
       */

      let totalFound = 0;
      let totalStaged = 0;
      let pagesProcessed = 0;

      let hasMore = false;

      let lastStageResult:
        unknown = null;


      for (
        let page = 0;
        page < maxPages;
        page++
      ) {
        const requestUrl =
          buildIncrementalUrl(
            source.datasetId,
            cursor,
            pageSize,
          );


        const rows =
          await fetchSocrata(
            requestUrl,
          );


        if (rows.length === 0) {
          hasMore = false;
          break;
        }


        totalFound +=
          rows.length;


        /*
         * Shared SQL dispatcher.
         *
         * CT_DEEP_REACT
         *   -> bridgepoint_stage_ct_deep_react(jsonb)
         *
         * CT_BUSINESS_MASTER
         *   -> bridgepoint_stage_ct_business_master(jsonb)
         *
         * The dispatcher is installed next.
         */
        lastStageResult =
          await callRpc(
            "bridgepoint_ct_socrata_stage_v51",
            {
              p_source_code:
                sourceCode,

              p_records:
                rows,
            },
          );


        /*
         * We count submitted rows here.
         * Existing staging RPC remains responsible for
         * determining insert/update/duplicate behavior.
         */
        totalStaged +=
          rows.length;


        const finalRow =
          rows[
            rows.length - 1
          ];


        cursor =
          extractCursor(
            finalRow,
          );


        pagesProcessed++;


        if (
          rows.length < pageSize
        ) {
          hasMore = false;
          break;
        }


        hasMore = true;
      }


      const watermark =
        JSON.stringify(cursor);


      const status =
        hasMore
          ? "CONTINUING"
          : "COMPLETED";


      const commitResult =
        await callRpc(
          "bridgepoint_ct_socrata_refresh_commit_v51",
          {
            p_source_code:
              sourceCode,

            p_watermark:
              watermark,

            p_records_found:
              totalFound,

            p_records_staged:
              totalStaged,

            p_has_more:
              hasMore,

            p_status:
              status,

            p_error:
              null,

            p_detail: {
              dataset_id:
                source.datasetId,

              label:
                source.label,

              pages_processed:
                pagesProcessed,

              page_size:
                pageSize,

              max_pages:
                maxPages,

              last_stage_result:
                lastStageResult,
            },
          },
        );


      return jsonResponse({
        complete:
          !hasMore,

        status:
          status.toLowerCase(),

        source_code:
          sourceCode,

        dataset_id:
          source.datasetId,

        records_found:
          totalFound,

        records_submitted_to_staging:
          totalStaged,

        pages_processed:
          pagesProcessed,

        has_more:
          hasMore,

        watermark:
          cursor,

        commit_result:
          commitResult,
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);


      /*
       * Best effort failure registration.
       * Never advance the watermark after failure.
       */
      if (sourceCode) {
        try {
          await callRpc(
            "bridgepoint_ct_socrata_refresh_commit_v51",
            {
              p_source_code:
                sourceCode,

              p_watermark:
                null,

              p_records_found:
                0,

              p_records_staged:
                0,

              p_has_more:
                true,

              p_status:
                "FAILED",

              p_error:
                message,

              p_detail: {
                failed_at:
                  new Date()
                    .toISOString(),
              },
            },
          );
        } catch {
          // Preserve original failure.
        }
      }


      console.error(
        "BridgePoint CT Socrata refresh failed:",
        message,
      );


      return jsonResponse(
        {
          complete: false,
          status: "failed",
          source_code:
            sourceCode,
          error:
            message,
        },
        500,
      );
    }
  },
);