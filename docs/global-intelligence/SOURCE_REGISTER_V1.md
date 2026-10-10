# Global Intelligence — Source Register and Adapter Plan

These are source candidates, not a claim that every adapter is active or cleared for commercial redistribution. Before enabling a source, record its owner, endpoint/API, coverage, cadence, rights/terms, attribution, retention, authentication, blind spots and last verification date.

| Layer | Candidate | Purpose | Gate / limitation |
|---|---|---|---|
| Earthquakes | USGS Earthquake Hazards Program — https://earthquake.usgs.gov/earthquakes/feed/ | Seismic event context | Reports may be revised; preserve IDs and source timestamps. |
| Volcano status | USGS Volcano Hazards Program — https://volcanoes.usgs.gov/ | Public volcano status | Preserve original authority and status vocabulary. |
| Global natural events | NASA EONET — https://eonet.gsfc.nasa.gov/ | Public natural-event context | Event geometry/status may change; not proof of property damage. |
| Disaster alerts | GDACS — https://www.gdacs.org/ | International disaster alert context | Preserve alert semantics; declarations/alerts do not prove parcel damage. |
| Space weather | NOAA SWPC — https://www.swpc.noaa.gov/ | Official-source alerts | An alert does not prove local outage or impact. |
| Weather alerts | NWS API — https://www.weather.gov/documentation/services-web-api | Property-area hazard context | Exposure is not verified damage; respect rate limits. |
| Satellite imagery | Copernicus Data Space — https://documentation.v1.dataspace.copernicus.eu/APIs.html | Catalog and historical change analysis | Not continuous live video; verify resolution, latency and product terms. |
| Property/infrastructure geometry | Jurisdictional cadastre, local open data and open mapping sources | Canonical property and surroundings | Terms/completeness vary by jurisdiction. Keep source and geometry truth explicit. |
| Aviation | ADS-B Exchange Enterprise API — https://www.adsbexchange.com/products/enterprise-api/ | Potential licensed civil aviation/logistics context | Subscription, use and redistribution terms require review before activation. |
| Maritime | Global Fishing Watch API — https://api-doc.globalfishingwatch.org/ and authorized AIS providers | Commercial maritime trends and historical aggregates | AIS coverage is incomplete; gaps do not establish deliberate disabling or exact vessel position. |
| Federal disaster context | FEMA OpenFEMA — https://www.fema.gov/about/openfema/api | Public declarations/recovery context | Program data has its own cadence; a declaration is not parcel-level damage proof. |

## Source readiness states

- **Discovered:** endpoint/catalog identified.
- **Rights reviewed:** terms, attribution, retention, permitted use and redistribution checked.
- **Integration tested:** development adapter passes parsing, schema and freshness checks.
- **Enabled:** production ingestion intentionally active.
- **Verified:** latest run passes source-specific quality checks.
- **Stale/degraded:** data age or quality exceeds a documented threshold.
- **Disabled:** intentionally off; this is not a zero event count.

Never call a source live solely because a connector is enabled. Keep publisher observation time and BridgePoint ingestion time separate.

## Recommended V1 domains

- Public hazard events: `GLOBAL_HAZARDS`, `SEISMIC`, `VOLCANO`.
- Space weather: `SPACE_WEATHER`.
- Exclude feeds intended to provide exact live military deployment, troop movement or person-level tracking.
- Do not infer location or intent from isolated social posts, transponder gaps or a single imagery anomaly.

## Minimum provenance fields

`source_key`, `source_record_id`, `domain`, `record_type`, `observed_at`, `ingested_at`, `expires_at` (when applicable), `source_url`, `rights_class`, `geometry_truth`, `provenance`, `schema_version`, `quality_status`, and field-level notes for BridgePoint-derived values.

If sources disagree, retain both records with distinct timestamps and provenance instead of silently overwriting source truth.


## Source-use screen and scheduler audit — 2026-10-10

This section records an engineering-level review of published terms and current BridgePoint scheduler state. It is **not a legal opinion or external counsel sign-off**. If a source's contract, dataset license, or downstream redistribution right is unclear, leave ingestion disabled until that permission is documented.

| Source / dataset | Initial commercial-use screen | Attribution / controls | Operational status on 2026-10-10 |
|---|---|---|---|
| USGS earthquake feed | Existing BridgePoint source registry labels the worker `APPROVED_PUBLIC_DOMAIN`; USGS says USGS-produced data are generally US public domain, with exceptions for third-party works. | Preserve USGS credit, feature ID, observation/update time and revisions. Do not present the event catalog as a forecast or complete sensor picture. | Schedule active at 15-minute cadence. Dispatcher pressure gate widened from queue <10 to queue <44 while preserving advisory lock, in-flight request handling and failure backoff. Source registry recorded a fresh import at 2026-10-10 04:23:15 UTC: 260 records found, 55 inserted, zero failures; the async HTTP response for request ID 1413303 was still pending in the latest check. |
| GDACS tropical-cyclone and flood event feeds | Existing BridgePoint source metadata labels these feeds `APPROVED_CC_BY_4_0_ATTRIBUTION_REQUIRED`; the product must retain GDACS attribution and the dataset-specific terms. | Attribute GDACS / the originating issuing authority; keep alerts as modeled early-warning context, not confirmed local damage or ground truth. | Scheduled Edge Function call active every 30 minutes. Test ingestion completed at 2026-10-10 04:21:23 UTC: 14 tropical-cyclone events inserted and 25 flood events inserted, zero consecutive failures and HEALTHY status. HTTP completion remained pending in the request queue view at last check. |
| WMO Severe Weather Information Centre (SWIC) | The official SWIC notes say warnings may be reused by media or other websites; it also says the warning issuer (RSMC, TCWC or NMHS) should be identified. Engineering screen supports cautious website reuse with issuer attribution; confirm any unusual downstream contract/use with counsel. | Preserve origin/issuer where present, published/observed time, map-data disclaimers and warning validity. | Worker schedule reactivated every 2 minutes with queue/database pressure gates. Latest state update was 2026-10-10 04:22:33 UTC, but five CAP detail-fetch failures were reported; treat this as active but degraded/partial ingestion until detail errors decline. |
| NWS API | NWS says API data are open data and free for any purpose subject to reasonable rate limits; its disclaimer bars misleading endorsement and says not to modify content then present it as official government material. | Use a descriptive User-Agent; cache according to feed cadence; keep issue/effective/expiry timestamps; retain NOAA/NWS source attribution and non-endorsement language. | Source-level terms screened; a new adapter is not being activated here. The existing live-weather dispatcher has accumulated thousands of pressure skips and needs queue-health remediation before reactivation. |
| Copernicus Sentinel data | Sentinel data legal notice permits free, full and open access, including commercial distribution and adaptation, subject to legal restrictions and required source notices. This conclusion applies to Sentinel data/service information, not automatically to every image, document, map or other item displayed in the portal. | Use notices such as “Copernicus Sentinel data [Year]”; retain product ID, acquisition time, processing time, resolution, footprint, license and algorithm version. Do not label imagery change candidates as confirmed activity. | Rights screen passed for Sentinel datasets; STAC/catalog adapter, API-specific conditions and data-quality tests still required. No polling worker enabled yet. |
| FEMA OpenFEMA | Public federal API does not waive dataset-specific privacy/usage controls. BridgePoint's existing FEMA recovery/claims rows are classed as coarse or context-only in metadata. | Do not infer person-level benefits, household status or verified parcel damage from redacted/coarse program records. Keep records at intended geographic precision. | Existing datasets are stale and several ingestion schedules are inactive; no bulk recovery/claims workers were reactivated as part of this rollout. |
| OpenStreetMap / OpenFreeMap | OSM data uses ODbL, with attribution and share-alike obligations for databases built upon the data. OpenFreeMap service/tile terms must be reviewed separately from the underlying OSM data license. | Include proper OSM credit and license disclosure. Do not treat public OSM tiles or geocoding endpoints as an unlimited bulk-download API. | Existing bridge-transport source remains a rendering baseline with zero discovered/materialized records in its source registry. No new bulk pull enabled. |
| Global Fishing Watch APIs | Published API terms are noncommercial; commercial use in BridgePoint needs a separate written license or permission. | Do not import or redistribute the data under the currently published noncommercial terms. | Blocked for commercial ingestion pending written permission. |
| ADS-B Exchange Enterprise API | Live aircraft positions/history require use under its applicable enterprise/API contract. Availability of an API is not blanket permission for every re-use. | Review contract terms, redistribution and display rights, filtering, retention, and permitted customer/government use before integration. | Not connected. No live military deployment or troop-location feed is planned for the general product. |

### Operational guardrails

- Production cron currently has a substantial number of inactive legacy jobs. This rollout only enabled the three bounded public-hazard feeds above; it did not turn on all 800+ inactive jobs.
- The shared asynchronous HTTP queue was approximately 32–42 requests during the rollout, with most outstanding calls targeting existing ArcGIS and projected-GML workers. Source schedulers use pressure gates and must not bypass those controls.
- If the queue remains above the threshold, a cron job can be active yet intentionally skip new ingestion. Verify both the cron flag and the source's last successful import / worker-state timestamp. The USGS dispatcher pressure-gate widening is captured in a new migration file in the feature branch; its migration-history ledger still needs reconciliation.
- Never claim a worker is continuously ingesting solely because its Edge Function status is ACTIVE.
