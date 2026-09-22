import { createClient } from "npm:@supabase/supabase-js@2";

/*
 * BridgePoint Connecticut FEMA incremental refresh
 *
 * - Official OpenFEMA sources only
 * - Connecticut rows only
 * - Selected useful fields only
 * - No national/raw payload retention
 * - Stateful pagination across short Edge Function executions
 * - Finalizes matching/signals/scoring only when records changed
 */

const TASK_TOKEN =
  "b190f757820714210fa2e210b569757e5773b6ac74c83824939e13291c414b77";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonObject = Record<string, unknown>;

type DatasetSpec = {
  key: string;
  entity: string;
  version: number;
  recordType: string;
  filter: string;
  orderBy: string;
  fields: readonly string[];
  sourceIdFields: readonly string[];
  restrictToEligibleDisasters?: boolean;
};

const DECLARATION_FIELDS = [
  "id", "hash", "femaDeclarationString", "disasterNumber",
  "declarationType", "declarationDate", "fyDeclared", "incidentType",
  "designatedIncidentTypes", "declarationTitle", "incidentBeginDate",
  "incidentEndDate", "disasterCloseoutDate", "lastIAFilingDate",
  "ihProgramDeclared", "iaProgramDeclared", "paProgramDeclared",
  "hmProgramDeclared", "tribalRequest", "fipsStateCode",
  "fipsCountyCode", "placeCode", "designatedArea",
  "declarationRequestNumber", "incidentId", "region", "lastRefresh",
] as const;

const CLAIM_FIELDS = [
  "id", "asOfDate", "dateOfLoss", "yearOfLoss", "floodEvent",
  "causeOfDamage", "buildingDamageAmount", "contentsDamageAmount",
  "amountPaidOnBuildingClaim", "amountPaidOnContentsClaim",
  "amountPaidOnIncreasedCostOfComplianceClaim",
  "netBuildingPaymentAmount", "netContentsPaymentAmount",
  "netIccPaymentAmount", "totalBuildingInsuranceCoverage",
  "totalContentsInsuranceCoverage", "buildingPropertyValue",
  "contentsPropertyValue", "buildingReplacementCost",
  "contentsReplacementCost", "ratedFloodZone", "floodZoneCurrent",
  "waterDepth", "floodWaterDuration", "exteriorWaterDepth",
  "interiorWaterDepth", "primaryResidenceIndicator",
  "rentalPropertyIndicator", "smallBusinessIndicatorBuilding",
  "nonProfitIndicator", "houseWorship", "agricultureStructureIndicator",
  "stateOwnedIndicator", "occupancyType", "buildingDescriptionCode",
  "numberOfFloorsInTheInsuredBuilding", "numberOfUnits",
  "originalConstructionDate", "postFIRMConstructionIndicator",
  "elevatedBuildingIndicator", "floodproofedIndicator", "foundationType",
  "reportedZipCode", "countyCode", "censusGeoid", "latitude",
  "longitude", "nfipRatedCommunityNumber", "nfipCommunityNumberCurrent",
  "nfipCommunityName", "mostRecentPaymentDate",
] as const;

const MULTIPLE_LOSS_FIELDS = [
  "id", "asOfDate", "stateAbbreviation", "fipsCountyCode", "county",
  "zipCode", "reportedCity", "communityIdNumber", "communityName",
  "censusBlockGroup", "nfipRl", "nfipSrl", "fmaRl", "fmaSrl",
  "floodZone", "latitude", "longitude", "occupancyType",
  "originalConstructionDate", "originalNBDate",
  "postFIRMConstructionIndicator", "primaryResidenceIndicator",
  "mitigatedIndicator", "insuredIndicator", "totalLosses",
  "mostRecentDateofLoss",
] as const;

const OWNER_FIELDS = [
  "id", "disasterNumber", "state", "county", "city", "zipCode",
  "validRegistrations", "averageFemaInspectedDamage", "totalInspected",
  "totalDamage", "noFemaInspectedDamage",
  "femaInspectedDamageBetween1And10000",
  "femaInspectedDamageBetween10001And20000",
  "femaInspectedDamageBetween20001And30000",
  "femaInspectedDamageGreaterThan30000", "approvedForFemaAssistance",
  "totalApprovedIhpAmount", "repairReplaceAmount", "rentalAmount",
  "otherNeedsAmount", "approvedBetween1And10000",
  "approvedBetween10001And25000", "approvedBetween25001AndMax",
  "totalMaxGrants",
] as const;

const RENTER_FIELDS = [
  "id", "disasterNumber", "state", "county", "city", "zipCode",
  "validRegistrations", "totalInspected", "totalInspectedWithNoDamage",
  "totalWithModerateDamage", "totalWithMajorDamage",
  "totalWithSubstantialDamage", "approvedForFemaAssistance",
  "totalApprovedIhpAmount", "repairReplaceAmount", "rentalAmount",
  "otherNeedsAmount", "approvedBetween1And10000",
  "approvedBetween10001And25000", "approvedBetween25001AndMax",
  "totalMaxGrants",
] as const;

const PUBLIC_ASSISTANCE_FIELDS = [
  "hash", "disasterNumber", "declarationDate", "incidentType",
  "pwNumber", "applicationTitle", "applicantId", "damageCategoryCode",
  "damageCategoryDescrip", "projectStatus", "projectProcessStep",
  "projectSize", "county", "countyCode", "stateAbbreviation",
  "stateNumberCode", "projectAmount", "federalShareObligated",
  "totalObligated", "firstObligationDate", "lastObligationDate",
  "mitigationAmount", "gmProjectId", "gmApplicantId", "lastRefresh",
] as const;

const HMA_FIELDS = [
  "id", "subapplicationIdentifier", "program", "fiscalYear", "region",
  "applicantName", "subapplicantName", "subapplicantCity",
  "subapplicantStateAbbreviation", "subapplicantZipCode",
  "dateSubmittedToFema", "subapplicationTitle",
  "proposedProjectStartDate", "proposedProjectEndDate", "fundingCategory",
  "subapplicantType", "status", "subapplicationType", "benefitingCounties",
  "primaryActivity", "primarySubactivity", "secondaryActivity",
  "secondarySubactivity", "primaryHazard", "secondaryHazard",
  "natureBasedSolution", "populationAffected", "construction",
  "mitigationPlanCovered", "numberBuildingLocations",
  "numberInfrastructureLocations", "numberVacantLandLocations",
  "federalShareAmount", "nonFederalShareAmount", "totalSubapplicationAmount",
  "totalObligatedAmount", "totalPaymentAmount", "benefitCostRatio",
  "bcaTotalBenefits", "bcaTotalCosts", "disasterNumber", "selectionStatus",
  "selectionFederalShareAmount",
] as const;

const DATASETS: Record<string, DatasetSpec> = {
  fema_disaster_declarations_2000_present: {
    key: "fema_disaster_declarations_2000_present",
    entity: "DisasterDeclarationsSummaries",
    version: 2,
    recordType: "FEMA_DISASTER_DECLARATION_AREA",
    filter: "state eq 'CT' and declarationDate ge '2000-01-01T00:00:00.000Z'",
    orderBy: "disasterNumber asc",
    fields: DECLARATION_FIELDS,
    sourceIdFields: ["id"],
  },
  fema_nfip_claims_2000_present: {
    key: "fema_nfip_claims_2000_present",
    entity: "NfipClaims",
    version: 3,
    recordType: "FEMA_NFIP_FLOOD_CLAIM",
    filter: "state eq 'CT' and dateOfLoss ge '2000-01-01T00:00:00.000Z'",
    orderBy: "id asc",
    fields: CLAIM_FIELDS,
    sourceIdFields: ["id"],
  },
  fema_nfip_multiple_loss_properties_current: {
    key: "fema_nfip_multiple_loss_properties_current",
    entity: "NfipMultipleLossProperties",
    version: 1,
    recordType: "FEMA_NFIP_MULTIPLE_LOSS_PROPERTY",
    filter: "stateAbbreviation eq 'CT'",
    orderBy: "id asc",
    fields: MULTIPLE_LOSS_FIELDS,
    sourceIdFields: ["id"],
  },
  fema_housing_assistance_owners_2000_present: {
    key: "fema_housing_assistance_owners_2000_present",
    entity: "HousingAssistanceOwners",
    version: 2,
    recordType: "FEMA_OWNER_ASSISTANCE_AREA",
    filter: "state eq 'CT'",
    orderBy: "id asc",
    fields: OWNER_FIELDS,
    sourceIdFields: ["id"],
    restrictToEligibleDisasters: true,
  },
  fema_housing_assistance_renters_2000_present: {
    key: "fema_housing_assistance_renters_2000_present",
    entity: "HousingAssistanceRenters",
    version: 2,
    recordType: "FEMA_RENTER_ASSISTANCE_AREA",
    filter: "state eq 'CT'",
    orderBy: "id asc",
    fields: RENTER_FIELDS,
    sourceIdFields: ["id"],
    restrictToEligibleDisasters: true,
  },
  fema_public_assistance_projects_2000_present: {
    key: "fema_public_assistance_projects_2000_present",
    entity: "PublicAssistanceFundedProjectsDetails",
    version: 2,
    recordType: "FEMA_PUBLIC_ASSISTANCE_PROJECT",
    filter: "stateAbbreviation eq 'CT' and declarationDate ge '2000-01-01T00:00:00.000Z'",
    orderBy: "gmProjectId asc",
    fields: PUBLIC_ASSISTANCE_FIELDS,
    sourceIdFields: ["hash", "gmProjectId", "pwNumber"],
  },
  fema_hazard_mitigation_projects_2000_present: {
    key: "fema_hazard_mitigation_projects_2000_present",
    entity: "HmaSubapplications",
    version: 2,
    recordType: "FEMA_HAZARD_MITIGATION_PROJECT",
    filter: "subapplicantStateAbbreviation eq 'CT' and fiscalYear ge 2000",
    orderBy: "id asc",
    fields: HMA_FIELDS,
    sourceIdFields: ["id", "subapplicationIdentifier"],
  },
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function boundedInteger(
  value: unknown,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.trunc(parsed)));
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    if (value.toLowerCase() === "true") return true;
    if (value.toLowerCase() === "false") return false;
  }
  return fallback;
}

async function readBody(request: Request): Promise<JsonObject> {
  const raw = await request.text();
  if (!raw.trim()) return {};
  const parsed = JSON.parse(raw);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("The request body must be a JSON object.");
  }
  return parsed as JsonObject;
}

function camelToSnake(value: string): string {
  return value
    .replace(/(.)([A-Z][a-z]+)/g, "$1_$2")
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .toLowerCase();
}

async function fallbackId(row: JsonObject): Promise<string> {
  const ordered = Object.fromEntries(
    Object.entries(row).sort(([left], [right]) => left.localeCompare(right)),
  );
  const bytes = new TextEncoder().encode(JSON.stringify(ordered));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

async function normalizeRecord(
  spec: DatasetSpec,
  source: JsonObject,
): Promise<JsonObject> {
  const identity = spec.sourceIdFields
    .map((field) => source[field])
    .filter((value) => value !== null && value !== undefined && String(value).trim())
    .map((value) => String(value).trim());

  const result: JsonObject = {
    source_dataset_key: spec.key,
    source_record_id: identity.length ? identity.join("|") : await fallbackId(source),
    record_type: spec.recordType,
  };

  for (const field of spec.fields) {
    if (field === "id") continue;
    const value = source[field];
    if (value === null || value === undefined || value === "") continue;
    result[camelToSnake(field)] = value;
  }
  return result;
}

function openFemaUrl(spec: DatasetSpec, skip: number, top: number): string {
  const parameters = new URLSearchParams({
    "$filter": spec.filter,
    "$select": spec.fields.join(","),
    "$orderby": spec.orderBy,
    "$top": String(top),
    "$skip": String(skip),
  });
  if (skip === 0) parameters.set("$count", "true");
  return `https://www.fema.gov/api/open/v${spec.version}/${spec.entity}?${parameters}`;
}

async function fetchJson(url: string, attempts = 4): Promise<JsonObject> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
          "User-Agent": "BridgePoint-FEMA-CT-Lean-Automation/1.0",
        },
        signal: AbortSignal.timeout(45_000),
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(`OpenFEMA HTTP ${response.status}: ${text.slice(0, 1500)}`);
      }
      const value = JSON.parse(text);
      if (!value || typeof value !== "object" || Array.isArray(value)) {
        throw new Error("OpenFEMA returned an unexpected response.");
      }
      return value as JsonObject;
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        await new Promise((resolve) => setTimeout(resolve, 750 * 2 ** attempt));
      }
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

async function eligibleDisasterNumbers(): Promise<Set<number>> {
  const declarationSpec = DATASETS.fema_disaster_declarations_2000_present;
  const response = await fetchJson(openFemaUrl(declarationSpec, 0, 1000));
  const rows = response[declarationSpec.entity];
  if (!Array.isArray(rows)) {
    throw new Error("Could not load eligible Connecticut FEMA disasters.");
  }
  return new Set(
    rows
      .map((row) => Number((row as JsonObject).disasterNumber))
      .filter((value) => Number.isInteger(value)),
  );
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (request.method !== "POST") return jsonResponse({ complete: false, error: "POST required" }, 405);

  const started = Date.now();
  let body: JsonObject = {};
  let claimedDataset: string | null = null;
  let workerId: string | null = null;

  try {
    body = await readBody(request);
    const dryRun = booleanValue(body.dry_run, false);
    if (!dryRun && body.task_token !== TASK_TOKEN) {
      return jsonResponse({ complete: false, status: "unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      throw new Error("Supabase runtime credentials are unavailable.");
    }
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const batchSize = boundedInteger(body.batch_size, 250, 25, 250);
    const maxPages = boundedInteger(body.max_pages, 4, 1, 6);

    if (dryRun) {
      const audits = await Promise.all(
        Object.values(DATASETS).map(async (spec) => {
          const response = await fetchJson(openFemaUrl(spec, 0, 1));
          const metadata = response.metadata as JsonObject | undefined;
          return {
            dataset_key: spec.key,
            reachable: Array.isArray(response[spec.entity]),
            source_count: metadata?.count ?? null,
            selected_fields: spec.fields.length,
          };
        }),
      );
      return jsonResponse({
        complete: true,
        status: "dry_run",
        database_changed: false,
        raw_payload_retained: false,
        datasets: audits,
        duration_ms: Date.now() - started,
      });
    }

    workerId = crypto.randomUUID();
    const requestedDataset = typeof body.dataset_key === "string"
      ? body.dataset_key
      : null;
    const force = booleanValue(body.force, false);

    const { data: claim, error: claimError } = await supabase.rpc(
      "bridgepoint_claim_fema_refresh_job",
      {
        p_worker_id: workerId,
        p_requested_dataset: requestedDataset,
        p_force: force,
      },
    );
    if (claimError) throw new Error(`Refresh claim failed: ${claimError.message}`);
    if (!claim || claim.complete === true) {
      return jsonResponse({
        complete: true,
        status: "nothing_due",
        raw_payload_retained: false,
        duration_ms: Date.now() - started,
      });
    }

    claimedDataset = String(claim.dataset_key);
    const spec = DATASETS[claimedDataset];
    if (!spec) throw new Error(`Unknown claimed dataset: ${claimedDataset}`);
    let offset = Number(claim.offset ?? 0);
    let allowedDisasters: Set<number> | null = null;
    if (spec.restrictToEligibleDisasters) {
      allowedDisasters = await eligibleDisasterNumbers();
    }

    const pages: JsonObject[] = [];
    let cycleCompleted = false;
    let finalization: unknown = null;

    for (let pageNumber = 1; pageNumber <= maxPages; pageNumber += 1) {
      const response = await fetchJson(openFemaUrl(spec, offset, batchSize));
      const sourceRows = response[spec.entity];
      if (!Array.isArray(sourceRows)) {
        throw new Error(`OpenFEMA response omitted ${spec.entity}.`);
      }

      const approvedRows = sourceRows.filter((row) => {
        if (!allowedDisasters) return true;
        return allowedDisasters.has(Number((row as JsonObject).disasterNumber));
      });
      const normalized = await Promise.all(
        approvedRows.map((row) => normalizeRecord(spec, row as JsonObject)),
      );

      let ingest: JsonObject = {
        records_new: 0,
        records_updated: 0,
        records_duplicate: 0,
      };
      if (normalized.length) {
        const { data, error } = await supabase.rpc(
          "bridgepoint_ingest_fema_lean_batch",
          {
            p_dataset_key: spec.key,
            p_records: normalized,
            p_run_type: "AUTOMATIC_REFRESH",
          },
        );
        if (error) throw new Error(`FEMA ingest failed: ${error.message}`);
        ingest = data as JsonObject;
      }

      const received = sourceRows.length;
      const nextOffset = offset + received;
      const pageComplete = received < batchSize;
      const { data: update, error: updateError } = await supabase.rpc(
        "bridgepoint_update_fema_refresh_job",
        {
          p_worker_id: workerId,
          p_dataset_key: spec.key,
          p_next_offset: nextOffset,
          p_page_received: received,
          p_records_kept: normalized.length,
          p_records_new: Number(ingest.records_new ?? 0),
          p_records_updated: Number(ingest.records_updated ?? 0),
          p_records_duplicate: Number(ingest.records_duplicate ?? 0),
          p_complete: pageComplete,
          p_error: null,
        },
      );
      if (updateError) throw new Error(`Refresh checkpoint failed: ${updateError.message}`);

      pages.push({
        page: pageNumber,
        offset,
        source_rows_received: received,
        approved_rows_kept: normalized.length,
        records_new: ingest.records_new ?? 0,
        records_updated: ingest.records_updated ?? 0,
        records_duplicate: ingest.records_duplicate ?? 0,
      });
      offset = nextOffset;

      if (pageComplete) {
        cycleCompleted = true;
        const cycleChanges = Number((update as JsonObject).cycle_changes ?? 0);
        if (cycleChanges > 0 && booleanValue(body.finalize, true)) {
          const { data, error } = await supabase.rpc(
            "bridgepoint_finalize_fema_ingestion",
          );
          if (error) throw new Error(`FEMA finalization failed: ${error.message}`);
          finalization = data;
        }
        break;
      }
    }

    return jsonResponse({
      complete: cycleCompleted,
      status: cycleCompleted ? "dataset_refresh_completed" : "dataset_refresh_checkpointed",
      dataset_key: spec.key,
      next_offset: cycleCompleted ? 0 : offset,
      pages_processed: pages.length,
      pages,
      finalization,
      raw_payload_retained: false,
      matching_precision: "ZIP_OR_COUNTY_AREA_ONLY",
      duration_ms: Date.now() - started,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (supabaseUrl && serviceKey && claimedDataset && workerId) {
        const supabase = createClient(supabaseUrl, serviceKey, {
          auth: { persistSession: false, autoRefreshToken: false },
        });
        await supabase.rpc("bridgepoint_update_fema_refresh_job", {
          p_worker_id: workerId,
          p_dataset_key: claimedDataset,
          p_next_offset: 0,
          p_page_received: 0,
          p_records_kept: 0,
          p_records_new: 0,
          p_records_updated: 0,
          p_records_duplicate: 0,
          p_complete: false,
          p_error: message.slice(0, 4000),
        });
      }
    } catch {
      // Preserve the original error.
    }
    return jsonResponse({
      complete: false,
      status: "failed",
      error: message,
      dataset_key: claimedDataset,
      raw_payload_retained: false,
      duration_ms: Date.now() - started,
    }, 500);
  }
});