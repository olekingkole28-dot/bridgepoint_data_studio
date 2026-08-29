-- BridgePoint V1013
-- V1012 cleared 1000 rows in ~21-35s and 3000 rows in ~30s under live load.
-- Run 3000/minute to outrun the national backfill feed while retaining 55s guard headroom.
select cron.alter_job(
  (select jobid from cron.job where jobname='bridgepoint-foundation-no-signal-bulk-v1012'),
  schedule := '* * * * *',
  command := 'select automation.bulk_complete_no_signal_foundation_v1012(3000);',
  active := true
);
