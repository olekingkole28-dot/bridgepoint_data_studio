# Global Intelligence — Production Operations Status (2026-10-10)

This note records the narrow scheduler changes made to the existing production Supabase project, BridgePoint Intelligence v.01. It is not a blanket legal certification and it does not turn on every inactive legacy job.

## Schedulers changed

| Job | Schedule | Change | Safety gate |
|---|---|---|---|
| `bridgepoint-global-earthquake-v5830` (job 988) | Every 15 minutes | Activated existing USGS global-earthquake dispatcher. | Its database dispatcher already applies HTTP queue, active-session, I/O, lock and failure-backoff checks; it skips dispatch when queue is 10+ or load is elevated. |
| `bridgepoint-wmo-swic-v5823` (job 984) | Every 2 minutes | Activated existing SWIC worker and added pressure guards to the scheduled command. | Enqueue only when HTTP queue < 44, active client sessions < 20, I/O waits < 8 and lock waits < 2. Sends task token from the existing private worker-secret table; no token stored in this repository. |
| `bridgepoint-global-gdacs-v5833` (job 1030) | Every 30 minutes | Added and activated a scheduled call to the existing GDACS ingest worker. | Same HTTP queue/database pressure guards as SWIC. Uses task token from existing private worker-secret table. |

All job schedules use the existing ingestion code and idempotent event upserts. No new schema or external provider credentials were added.

## Status at deployment/change time

- USGS worker and dispatcher were already deployed. Its scheduler had been inactive; last scheduled run before reactivation was 2026-10-07.
- SWIC worker was already deployed. Its scheduler had been inactive; last successful SWIC refresh in its state table was 2026-10-07.
- GDACS ingest worker was deployed and its event-family coverage was marked `APPROVED_CC_BY_4_0_ATTRIBUTION_REQUIRED`; last recorded successful import was 2026-09-27. No GDACS cron job existed before this change.
- The shared `net.http_request_queue` ranged from 32 to 42 items during this change, mostly existing ArcGIS and projected-GML calls. Because of this, the pressure gates can skip requests while the queue is elevated.
- A one-off SWIC request was enqueued as request ID 1413241. At the most recent check, its response and a newer SWIC success timestamp had not yet been confirmed. Treat the worker as scheduled/activated but not yet verified successful until the state table updates.

## Verification queries

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname in (
  'bridgepoint-global-earthquake-v5830',
  'bridgepoint-wmo-swic-v5823',
  'bridgepoint-global-gdacs-v5833'
)
order by jobname;
```

```sql
select jobid, start_time, end_time, status, return_message
from cron.job_run_details
where jobid in (984, 988, 1030)
order by start_time desc
limit 30;
```

```sql
select * from automation.wmo_swic_refresh_state_v5823 where singleton;
select source_code, last_successful_import_at, last_run_records_found,
       last_run_records_inserted, consecutive_failures, health_status, last_error
from automation.source_registry
where source_code in (
  'USGS_EARTHQUAKE_GLOBAL_V5829',
  'GDACS_TROPICAL_CYCLONE_GLOBAL_V5833',
  'GDACS_FLOOD_GLOBAL_V5833'
);
```

## Important limitation

A successful `cron.job_run_details` row only proves the SQL scheduler command ran. It does not necessarily prove the asynchronous HTTP request succeeded or that new observations were inserted. Confirm `net._http_response`, the source-specific worker state, and `last_successful_import_at` after each poll cycle.

## Explicitly left disabled / pending

- Existing live-weather detail and geometry dispatchers remain inactive because their state previously showed thousands of pressure skips and the shared request queue was already elevated.
- WMO attribution to the originating warning authority must be preserved.
- NOAA/NWS new adapters, Copernicus Sentinel catalog ingestion, FEMA updates, and any paid aviation/maritime integration remain gated on feed-specific technical testing and use/redistribution review.
- No exact live military deployments, troop movements or person-level geolocation ingestion was added.
