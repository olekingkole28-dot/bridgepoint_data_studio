import { createClient } from "npm:@supabase/supabase-js@2";

type JsonObject = Record<string, unknown>;

type ThresholdSite = {
  monitoring_location_id: string;
  site_no: string | null;
  station_name: string | null;

  history_count: number | null;

  p80_flow_cfs: number | null;
  p90_flow_cfs: number | null;
  p95_flow_cfs: number | null;

  period_high_flow_cfs: number | null;
};

type LatestObservation = {
  monitoring_location_id: string;
  parameter_code: string;

  observed_at: string;
  value: number;

  approval_status: string | null;
  qualifier: string | null;

  time_series_id: string | null;
};


const SOURCE_CODE =
  "USGS_CT_HYDROLOGY";

const USGS_ENDPOINT =
  "https://api.waterdata.usgs.gov/"
  + "ogcapi/v0/collections/"
  + "latest-continuous/items";

const FLOW_PARAMETER =
  "00060";

const GAGE_PARAMETER =
  "00065";

/*
 * Your existing BridgePoint threshold model is
 * explicitly site-relative p80 / p90 / p95.
 *
 * p80 = elevated
 * p90 = high
 * p95 = extreme
 *
 * Severity therefore retains the threshold level
 * itself rather than inventing another scoring scale.
 */
const MAX_OBSERVATION_AGE_HOURS =
  12;

const SITE_BATCH_SIZE =
  40;


function jsonResponse(
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


function numeric(
  value: unknown,
): number | null {
  if (
    value === null
    || value === undefined
    || value === ""
  ) {
    return null;
  }

  const parsed =
    Number(value);

  return Number.isFinite(parsed)
    ? parsed
    : null;
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


function chunks<T>(
  values: T[],
  size: number,
): T[][] {
  const output: T[][] = [];

  for (
    let index = 0;
    index < values.length;
    index += size
  ) {
    output.push(
      values.slice(
        index,
        index + size,
      ),
    );
  }

  return output;
}


async function fetchUsGsBatch(
  siteIds: string[],
): Promise<JsonObject[]> {
  /*
   * Official USGS OGC CQL:
   *
   * monitoring_location_id IN (...)
   * AND
   * parameter_code IN ('00060','00065')
   */

  const cql = {
    op: "and",
    args: [
      {
        op: "in",
        args: [
          {
            property:
              "monitoring_location_id",
          },
          siteIds,
        ],
      },
      {
        op: "in",
        args: [
          {
            property:
              "parameter_code",
          },
          [
            FLOW_PARAMETER,
            GAGE_PARAMETER,
          ],
        ],
      },
    ],
  };


  let lastError = "";


  for (
    let attempt = 1;
    attempt <= 6;
    attempt++
  ) {
    try {
      const headers:
        Record<string, string> = {
          "Content-Type":
            "application/query-cql-json",

          "Accept":
            "application/geo+json",

          "User-Agent":
            "BridgePoint-Intelligence/"
            + "USGS-CT-V53",
        };


      /*
       * USGS does not require a key for normal use.
       * If one is added later, BridgePoint can use it
       * without changing this function.
       */
      const usgsApiKey =
        Deno.env.get(
          "USGS_API_KEY",
        );

      if (usgsApiKey) {
        headers[
          "X-Api-Key"
        ] = usgsApiKey;
      }


      const url =
        new URL(
          USGS_ENDPOINT,
        );

      url.searchParams.set(
        "f",
        "json",
      );

      url.searchParams.set(
        "limit",
        "5000",
      );


      const result =
        await fetch(
          url.toString(),
          {
            method: "POST",
            headers,
            body:
              JSON.stringify(cql),
          },
        );


      if (result.ok) {
        const payload =
          await result.json();


        if (
          !payload
          || !Array.isArray(
            payload.features,
          )
        ) {
          throw new Error(
            "Unexpected USGS GeoJSON response.",
          );
        }


        return payload.features;
      }


      const detail =
        (
          await result.text()
        ).slice(
          0,
          1500,
        );


      lastError =
        `USGS HTTP ${result.status}: `
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
    `USGS request failed: ${lastError}`,
  );
}


function normalizeFeature(
  feature: JsonObject,
): LatestObservation | null {
  const properties =
    feature?.properties;

  if (
    !properties
    || typeof properties !== "object"
  ) {
    return null;
  }


  const p =
    properties as JsonObject;


  const monitoringLocationId =
    clean(
      p.monitoring_location_id,
    );


  const parameterCode =
    clean(
      p.parameter_code,
    );


  const observedAt =
    clean(
      p.time,
    );


  const value =
    numeric(
      p.value,
    );


  if (
    !monitoringLocationId
    || !parameterCode
    || !observedAt
    || value === null
  ) {
    return null;
  }


  if (
    parameterCode !== FLOW_PARAMETER
    && parameterCode !== GAGE_PARAMETER
  ) {
    return null;
  }


  return {
    monitoring_location_id:
      monitoringLocationId,

    parameter_code:
      parameterCode,

    observed_at:
      observedAt,

    value,

    approval_status:
      clean(
        p.approval_status,
      ) || null,

    qualifier:
      clean(
        p.qualifier,
      ) || null,

    time_series_id:
      clean(
        p.time_series_id,
      ) || null,
  };
}


function observationAgeHours(
  timestamp: string,
): number {
  const millis =
    Date.parse(timestamp);

  if (
    !Number.isFinite(millis)
  ) {
    return Number.POSITIVE_INFINITY;
  }


  return (
    Date.now()
    - millis
  ) / 3_600_000;
}


function newerObservation(
  current: LatestObservation | undefined,
  candidate: LatestObservation,
): LatestObservation {
  if (!current) {
    return candidate;
  }


  const currentTime =
    Date.parse(
      current.observed_at,
    );

  const candidateTime =
    Date.parse(
      candidate.observed_at,
    );


  if (
    Number.isFinite(
      candidateTime,
    )
    && (
      !Number.isFinite(
        currentTime,
      )
      || candidateTime > currentTime
    )
  ) {
    return candidate;
  }


  return current;
}


function classifyFlow(
  flow: number,
  site: ThresholdSite,
): {
  eventType: string;
  severity: number;
} | null {
  /*
   * Do not assert property flooding.
   *
   * These are streamgage-condition alerts only.
   */

  if (
    site.p95_flow_cfs !== null
    && flow >= site.p95_flow_cfs
  ) {
    return {
      eventType:
        "USGS_FLOW_AT_OR_ABOVE_P95",

      severity:
        95,
    };
  }


  if (
    site.p90_flow_cfs !== null
    && flow >= site.p90_flow_cfs
  ) {
    return {
      eventType:
        "USGS_FLOW_AT_OR_ABOVE_P90",

      severity:
        90,
    };
  }


  if (
    site.p80_flow_cfs !== null
    && flow >= site.p80_flow_cfs
  ) {
    return {
      eventType:
        "USGS_FLOW_AT_OR_ABOVE_P80",

      severity:
        80,
    };
  }


  return null;
}


function sourceRecordId(
  monitoringLocationId: string,
  observedAt: string,
): string {
  /*
   * Same observation timestamp = same record.
   *
   * If USGS revises the value later,
   * BridgePoint's existing source_hash logic
   * updates that record rather than duplicating it.
   */

  return (
    "USGS_CURRENT:"
    + monitoringLocationId
    + ":"
    + observedAt
  );
}


Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    try {
      if (
        request.method !== "POST"
      ) {
        return jsonResponse(
          {
            complete: false,
            error:
              "POST required.",
          },
          405,
        );
      }


      const body =
        await request.json()
          .catch(
            () => ({}),
          );


      /*
       * V53 database installer will create this RPC.
       *
       * It returns:
       *   task token
       *   source cadence
       *   lease state
       *   all 87 monitored sites
       *   the 81 stored threshold profiles
       */
      const state =
        await rpc<any>(
          "bridgepoint_usgs_refresh_state_v53",
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
        return jsonResponse(
          {
            complete: false,
            status:
              "unauthorized",
          },
          401,
        );
      }


      if (
        state.enabled !== true
      ) {
        return jsonResponse({
          complete: true,
          status:
            "source_disabled",
        });
      }


      if (
        state.due !== true
        && body?.force !== true
      ) {
        return jsonResponse({
          complete: true,
          status:
            "not_due",
          next_check:
            state
              .next_scheduled_check_at,
        });
      }


      const rawSites =
        Array.isArray(
          state.sites,
        )
          ? state.sites
          : [];


      const sites:
        ThresholdSite[] =
        rawSites.map(
          (
            row: Record<
              string,
              unknown
            >,
          ) => ({
            monitoring_location_id:
              clean(
                row
                  .monitoring_location_id,
              ),

            site_no:
              clean(
                row.site_no,
              ) || null,

            station_name:
              clean(
                row.station_name,
              ) || null,

            history_count:
              numeric(
                row.history_count,
              ),

            p80_flow_cfs:
              numeric(
                row.p80_flow_cfs,
              ),

            p90_flow_cfs:
              numeric(
                row.p90_flow_cfs,
              ),

            p95_flow_cfs:
              numeric(
                row.p95_flow_cfs,
              ),

            period_high_flow_cfs:
              numeric(
                row
                  .period_high_flow_cfs,
              ),
          }),
        )
        .filter(
          (site) =>
            site
              .monitoring_location_id
              !== "",
        );


      if (
        sites.length === 0
      ) {
        throw new Error(
          "No BridgePoint USGS monitoring sites returned.",
        );
      }


      const siteIds =
        sites.map(
          (site) =>
            site
              .monitoring_location_id,
        );


      const allFeatures:
        JsonObject[] = [];


      for (
        const siteBatch
        of chunks(
          siteIds,
          SITE_BATCH_SIZE,
        )
      ) {
        const features =
          await fetchUsGsBatch(
            siteBatch,
          );

        allFeatures.push(
          ...features,
        );
      }


      /*
       * There can theoretically be more than one
       * continuous time series for one parameter/site.
       *
       * BridgePoint keeps the newest observation for
       * each site + parameter.
       */
      const flowBySite =
        new Map<
          string,
          LatestObservation
        >();

      const gageBySite =
        new Map<
          string,
          LatestObservation
        >();


      let validObservations =
        0;


      for (
        const feature
        of allFeatures
      ) {
        const observation =
          normalizeFeature(
            feature,
          );

        if (!observation) {
          continue;
        }


        validObservations++;


        if (
          observation
            .parameter_code
          === FLOW_PARAMETER
        ) {
          flowBySite.set(
            observation
              .monitoring_location_id,

            newerObservation(
              flowBySite.get(
                observation
                  .monitoring_location_id,
              ),
              observation,
            ),
          );
        }


        if (
          observation
            .parameter_code
          === GAGE_PARAMETER
        ) {
          gageBySite.set(
            observation
              .monitoring_location_id,

            newerObservation(
              gageBySite.get(
                observation
                  .monitoring_location_id,
              ),
              observation,
            ),
          );
        }
      }


      const alerts:
        JsonObject[] = [];


      let sitesWithFlow =
        0;

      let staleFlowSites =
        0;

      let sitesBelowThreshold =
        0;

      let sitesMissingThreshold =
        0;

      let newestObservedAt:
        string | null = null;


      for (
        const site
        of sites
      ) {
        const flow =
          flowBySite.get(
            site
              .monitoring_location_id,
          );


        if (!flow) {
          continue;
        }


        sitesWithFlow++;


        if (
          observationAgeHours(
            flow.observed_at,
          )
          >
          MAX_OBSERVATION_AGE_HOURS
        ) {
          staleFlowSites++;
          continue;
        }


        if (
          newestObservedAt === null
          ||
          Date.parse(
            flow.observed_at,
          )
          >
          Date.parse(
            newestObservedAt,
          )
        ) {
          newestObservedAt =
            flow.observed_at;
        }


        if (
          site.p80_flow_cfs === null
        ) {
          sitesMissingThreshold++;
          continue;
        }


        const classification =
          classifyFlow(
            flow.value,
            site,
          );


        if (!classification) {
          sitesBelowThreshold++;
          continue;
        }


        const gage =
          gageBySite.get(
            site
              .monitoring_location_id,
          );


        const freshGage =
          gage
          &&
          observationAgeHours(
            gage.observed_at,
          )
          <=
          MAX_OBSERVATION_AGE_HOURS
            ? gage
            : null;


        alerts.push({
          source_record_id:
            sourceRecordId(
              site
                .monitoring_location_id,
              flow.observed_at,
            ),

          monitoring_location_id:
            site
              .monitoring_location_id,

          observed_at:
            flow.observed_at,

          event_type:
            classification
              .eventType,

          current_flow_cfs:
            flow.value,

          current_gage_height:
            freshGage
              ? freshGage.value
              : null,

          gage_height_observed_at:
            freshGage
              ? freshGage
                  .observed_at
              : null,

          p80_flow_cfs:
            site.p80_flow_cfs,

          p90_flow_cfs:
            site.p90_flow_cfs,

          p95_flow_cfs:
            site.p95_flow_cfs,

          site_history_count:
            site.history_count,

          /*
           * Severity is the actual threshold tier.
           * Confidence is intentionally omitted so
           * your existing ingest engine applies its
           * established default.
           */
          severity:
            classification
              .severity,

          source_url:
            USGS_ENDPOINT,
        });
      }


      /*
       * Existing ingest contract caps a batch at 500.
       * Connecticut has only 87 BridgePoint sites,
       * so the entire alert set safely fits.
       */
      let ingestResult:
        unknown = null;


      if (
        alerts.length > 0
      ) {
        ingestResult =
          await rpc(
            "bridgepoint_ingest_usgs_hydrology_batch",
            {
              p_dataset_key:
                "CURRENT_ALERTS",

              p_records:
                alerts,

              p_run_type:
                "INCREMENTAL_HOURLY",
            },
          );
      }


      /*
       * The V53 commit function will update registry
       * health/cadence without pretending every gauge
       * creates a property-level flooding assertion.
       */
      await rpc(
        "bridgepoint_usgs_refresh_commit_v53",
        {
          p_status:
            "COMPLETED",

          p_observations_found:
            validObservations,

          p_sites_with_flow:
            sitesWithFlow,

          p_alerts_qualified:
            alerts.length,

          p_newest_observed_at:
            newestObservedAt,

          p_error:
            null,
        },
      );


      return jsonResponse({
        complete: true,

        status:
          "completed",

        monitored_sites:
          sites.length,

        threshold_profiles:
          sites.filter(
            (site) =>
              site.p80_flow_cfs
              !== null,
          ).length,

        source_features_received:
          allFeatures.length,

        valid_observations:
          validObservations,

        sites_with_current_flow:
          sitesWithFlow,

        stale_flow_sites:
          staleFlowSites,

        sites_missing_threshold:
          sitesMissingThreshold,

        sites_below_p80:
          sitesBelowThreshold,

        elevated_alerts:
          alerts.length,

        newest_observed_at:
          newestObservedAt,

        property_flooding_asserted:
          false,

        ingest_result:
          ingestResult,
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);


      try {
        await rpc(
          "bridgepoint_usgs_refresh_commit_v53",
          {
            p_status:
              "FAILED",

            p_observations_found:
              0,

            p_sites_with_flow:
              0,

            p_alerts_qualified:
              0,

            p_newest_observed_at:
              null,

            p_error:
              message,
          },
        );
      } catch {
        // Preserve original failure.
      }


      console.error(
        message,
      );


      return jsonResponse(
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