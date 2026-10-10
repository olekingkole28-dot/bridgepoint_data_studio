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
