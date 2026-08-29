-- BridgePoint V1008
-- The V965 display cleanup probe returned 0 repaired rows, so move it out of the hot 2-minute path.
select cron.alter_job(
  410,
  '*/30 * * * *',
  'select automation.repair_property_display_truth_v965(1000);',
  null,
  null,
  true
);
