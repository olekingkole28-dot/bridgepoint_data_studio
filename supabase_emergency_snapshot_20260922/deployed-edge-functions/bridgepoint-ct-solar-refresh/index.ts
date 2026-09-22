import { createClient } from "npm:@supabase/supabase-js@2";

type JsonObject = Record<string, unknown>;

const DATASET_ID = "fvw8-89kt";

const SOURCE_URL =
  `https://data.ct.gov/resource/${DATASET_ID}.json`;

const SOURCE_CODE =
  "CT_GREEN_BANK_RSIP";

const SOURCE_NAME =
  "CT Green Bank RSIP";

const PAGE_SIZE = 500;

const MAX_PAGES_PER_RUN = 20;


function response(
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

  const defaultKey =
    parsed?.default;

  if (
    typeof defaultKey === "string"
    && defaultKey.length > 0
  ) {
    return defaultKey;
  }

  for (
    const value of
    Object.values(parsed)
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
  Deno.env.get("SUPABASE_URL");

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


function clean(
  value: unknown,
): string {
  if (
    value === null
    || value === undefined
  ) {
    return "";
  }

  return String(value)
    .trim();
}


function first(
  ...values: unknown[]
): string {
  for (const value of values) {
    const cleaned =
      clean(value);

    if (cleaned !== "") {
      return cleaned;
    }
  }

  return "";
}


function dateOnly(
  value: unknown,
): string {
  const text =
    clean(value);

  if (!text) {
    return "";
  }

  /*
   * Socrata Floating Timestamp commonly returns:
   * YYYY-MM-DDTHH:mm:ss.SSS
   *
   * Historical BridgePoint RSIP identity used
   * the date portion.
   */
  return text.length >= 10
    ? text.slice(0, 10)
    : text;
}


async function sha256Hex(
  value: string,
): Promise<string> {
  const bytes =
    new TextEncoder()
      .encode(value);

  const digest =
    await crypto.subtle.digest(
      "SHA-256",
      bytes,
    );

  return Array
    .from(
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


async function makeSourceId(
  row: JsonObject,
): Promise<string> {
  /*
   * EXACT historical BridgePoint RSIP identity:
   *
   * approved_date
   * completed_date
   * municipality
   * city
   * zip
   * contractor
   * kw_stc
   * total_system_cost
   * incentive_amount
   */

  const identity = [
    dateOnly(
      row.approved_date,
    ),

    dateOnly(
      row.completed_date,
    ),

    clean(
      row.municipality,
    ),

    clean(
      row.city,
    ),

    first(
      row.zip,
      row.zip_code,
    ),

    clean(
      row.contractor,
    ),

    clean(
      row.kw_stc,
    ),

    clean(
      row.total_system_cost,
    ),

    clean(
      row.incentive_amount,
    ),
  ].join("|");

  return await sha256Hex(
    identity,
  );
}


function mapSolarize(
  value: unknown,
): string {
  if (
    value === true
    || value === 1
  ) {
    return "true";
  }

  if (
    value === false
    || value === 0
  ) {
    return "false";
  }

  const text =
    clean(value)
      .toLowerCase();

  if (
    text === "true"
    || text === "yes"
    || text === "1"
  ) {
    return "true";
  }

  if (
    text === "false"
    || text === "no"
    || text === "0"
  ) {
    return "false";
  }

  return "";
}


async function transformRow(
  row: JsonObject,
): Promise<JsonObject> {
  return {
    source_id:
      await makeSourceId(row),

    approved_date:
      dateOnly(
        row.approved_date,
      ),

    completed_date:
      dateOnly(
        row.completed_date,
      ),

    municipality:
      clean(
        row.municipality,
      ),

    city:
      clean(
        row.city,
      ),

    zip_code:
      first(
        row.zip,
        row.zip_code,
      ),

    county:
      clean(
        row.county,
      ),

    system_kw:
      clean(
        row.kw_stc,
      ),

    expected_annual_generation:
      clean(
        row.expected_annual_generation,
      ),

    incentive_amount:
      clean(
        row.incentive_amount,
      ),

    total_system_cost:
      clean(
        row.total_system_cost,
      ),

    contractor:
      clean(
        row.contractor,
      ),

    system_owner:
      clean(
        row.system_owner,
      ),

    financing_type:
      first(
        row.system_financing_type,
        row.financing_type,
      ),

    utility_company:
      clean(
        row.utility_company,
      ),

    incentive_type:
      clean(
        row.incentive_type,
      ),

    sub_program:
      clean(
        row.sub_program,
      ),

    solarize:
      mapSolarize(
        row.solarize_indicator
        ?? row.solarize,
      ),

    distressed_community:
      clean(
        row.distressed_community,
      ),

    source:
      SOURCE_NAME,

    source_dataset:
      DATASET_ID,
  };
}


async function rpc<T>(
  name: string,
  args: Record<string, unknown>,
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


async function fetchJson(
  url: URL,
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
          Accept:
            "application/json",

          "User-Agent":
            "BridgePoint-Intelligence/"
            + "CT-RSIP-V52",
        };


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
          url.toString(),
          {
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
            "Unexpected Socrata response.",
          );
        }

        return payload;
      }


      const detail =
        (
          await result.text()
        ).slice(
          0,
          1000,
        );


      lastError =
        `HTTP ${result.status}: `
        + detail;


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
    `RSIP source request failed: ${lastError}`,
  );
}


function bootstrapUrl(): URL {
  const url =
    new URL(
      SOURCE_URL,
    );

  url.searchParams.set(
    "$select",
    ":id,:updated_at",
  );

  url.searchParams.set(
    "$order",
    ":updated_at DESC,:id DESC",
  );

  url.searchParams.set(
    "$limit",
    "1",
  );

  return url;
}


function incrementalUrl(
  updatedAt: string,
  rowId: string,
): URL {
  const url =
    new URL(
      SOURCE_URL,
    );

  url.searchParams.set(
    "$select",
    ":*,*",
  );

  url.searchParams.set(
    "$order",
    ":updated_at ASC,:id ASC",
  );

  url.searchParams.set(
    "$limit",
    String(PAGE_SIZE),
  );


  const escapedTime =
    updatedAt.replaceAll(
      "'",
      "''",
    );

  const escapedId =
    rowId.replaceAll(
      "'",
      "''",
    );


  url.searchParams.set(
    "$where",
    `(`
    + `:updated_at > '${escapedTime}'`
    + ` OR `
    + `(`
    + `:updated_at = '${escapedTime}'`
    + ` AND :id > '${escapedId}'`
    + `)`
    + `)`,
  );


  return url;
}


Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    try {
      if (
        request.method
        !== "POST"
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


      const body =
        await request.json();


      const state =
        await rpc<any>(
          "bridgepoint_ct_solar_refresh_state_v52",
          {},
        );


      const suppliedToken =
        clean(
          body?.task_token,
        );


      if (
        !state?.task_token
        || suppliedToken
           !== state.task_token
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


      if (
        state.enabled
        !== true
      ) {
        return response({
          complete: true,
          status:
            "source_disabled",
        });
      }


      if (
        state.due
        !== true
        && body?.force
           !== true
      ) {
        return response({
          complete: true,
          status:
            "not_due",
          next_check:
            state
              .next_scheduled_check_at,
        });
      }


      let cursor:
        {
          updated_at: string;
          id: string;
        }
        | null = null;


      if (
        typeof state
          .last_watermark
          === "string"
        && state
          .last_watermark
          .trim()
          !== ""
      ) {
        try {
          const parsed =
            JSON.parse(
              state
                .last_watermark,
            );

          if (
            parsed?.updated_at
            && parsed?.id
          ) {
            cursor = {
              updated_at:
                String(
                  parsed
                    .updated_at,
                ),

              id:
                String(
                  parsed.id,
                ),
            };
          }
        } catch {
          cursor = null;
        }
      }


      /*
       * Historical load already contains
       * all 48,354 current source rows.
       *
       * First automatic run therefore only
       * establishes the high-water mark.
       */
      if (!cursor) {
        const rows =
          await fetchJson(
            bootstrapUrl(),
          );


        if (
          rows.length === 0
        ) {
          await rpc(
            "bridgepoint_ct_solar_refresh_commit_v52",
            {
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
            },
          );


          return response({
            complete: true,
            status:
              "bootstrapped_empty",
          });
        }


        const newest =
          rows[0];


        const watermark =
          JSON.stringify({
            updated_at:
              String(
                newest[
                  ":updated_at"
                ],
              ),

            id:
              String(
                newest[
                  ":id"
                ],
              ),
          });


        await rpc(
          "bridgepoint_ct_solar_refresh_commit_v52",
          {
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
          },
        );


        return response({
          complete: true,
          status:
            "bootstrapped",

          historical_reload:
            false,

          watermark:
            JSON.parse(
              watermark,
            ),
        });
      }


      let recordsFound = 0;
      let recordsStaged = 0;
      let pages = 0;
      let hasMore = false;


      for (
        let page = 0;
        page
          < MAX_PAGES_PER_RUN;
        page++
      ) {
        const rows =
          await fetchJson(
            incrementalUrl(
              cursor
                .updated_at,

              cursor.id,
            ),
          );


        if (
          rows.length === 0
        ) {
          hasMore = false;
          break;
        }


        recordsFound +=
          rows.length;


        const transformed:
          JsonObject[] = [];


        for (
          const row of rows
        ) {
          transformed.push(
            await transformRow(
              row,
            ),
          );
        }


        /*
         * Existing exact Solar RPC.
         */
        await rpc(
          "bridgepoint_ingest_ct_solar_rsip",
          {
            p_rows:
              transformed,
          },
        );


        recordsStaged +=
          transformed.length;


        const lastRow =
          rows[
            rows.length - 1
          ];


        cursor = {
          updated_at:
            String(
              lastRow[
                ":updated_at"
              ],
            ),

          id:
            String(
              lastRow[
                ":id"
              ],
            ),
        };


        pages++;


        hasMore =
          rows.length
          === PAGE_SIZE;


        if (!hasMore) {
          break;
        }
      }


      /*
       * Rebuild area contexts only after
       * source upserts completed.
       */
      if (
        recordsStaged > 0
      ) {
        await rpc(
          "rebuild_rsip_context",
          {},
        );


        await rpc(
          "refresh_ct_rsip_zip_context",
          {},
        );


        /*
         * Clear prior progress so properties
         * affected by changed ZIP adoption
         * context can be rematerialized.
         *
         * This function will be supplied by
         * the V52 SQL installer.
         */
        await rpc(
          "bridgepoint_reset_ct_rsip_materialization_v52",
          {},
        );
      }


      const watermark =
        JSON.stringify(
          cursor,
        );


      await rpc(
        "bridgepoint_ct_solar_refresh_commit_v52",
        {
          p_watermark:
            watermark,

          p_records_found:
            recordsFound,

          p_records_staged:
            recordsStaged,

          p_has_more:
            hasMore,

          p_status:
            hasMore
              ? "CONTINUING"
              : "COMPLETED",

          p_error:
            null,
        },
      );


      return response({
        complete:
          !hasMore,

        status:
          hasMore
            ? "continuing"
            : "completed",

        records_found:
          recordsFound,

        records_submitted:
          recordsStaged,

        pages_processed:
          pages,

        watermark:
          cursor,

        downstream_context_refreshed:
          recordsStaged > 0,
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);


      try {
        await rpc(
          "bridgepoint_ct_solar_refresh_commit_v52",
          {
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
          },
        );
      } catch {
        // preserve original error
      }


      console.error(
        message,
      );


      return response(
        {
          complete: false,
          status: "failed",
          error: message,
        },
        500,
      );
    }
  },
);