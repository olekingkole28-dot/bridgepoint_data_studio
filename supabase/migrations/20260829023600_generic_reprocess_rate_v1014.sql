-- BridgePoint V1014
-- The two generic evidence reprocessors averaged ~4s/run with 0 failures over 30m,
-- while national_noaa_signal_reconciled carried a ~452k backlog.
select cron.alter_job(
  (select jobid from cron.job where jobname='bridgepoint-entity-reprocessing-v344-1'),
  schedule := '23 seconds',
  command := 'select public.bridgepoint_reprocess_entity_queue_v344(200);',
  active := true
);
select cron.alter_job(
  (select jobid from cron.job where jobname='bridgepoint-entity-reprocessing-v344-2'),
  schedule := '29 seconds',
  command := 'select public.bridgepoint_reprocess_entity_queue_v344(200);',
  active := true
);
