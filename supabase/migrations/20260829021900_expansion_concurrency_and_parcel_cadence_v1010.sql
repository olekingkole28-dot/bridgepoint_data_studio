-- BridgePoint V1010
-- Match expansion admission to the verified 16XL envelope while preserving
-- the existing 24-client, long-query, queue and disk safety gates.
alter table automation.expansion_load_policy_v321
  drop constraint if exists expansion_load_policy_v321_max_heavy_expansions_check;

alter table automation.expansion_load_policy_v321
  add constraint expansion_load_policy_v321_max_heavy_expansions_check
  check (max_heavy_expansions between 1 and 10);

update automation.expansion_load_policy_v321
set max_heavy_expansions=10,
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'heavy_expansion_gate_version',1010,
      'heavy_expansion_gate_updated_at',now(),
      'heavy_expansion_gate_reason','Raised live heavy expansion admission from 5 to 10 for verified 16XL 64-core compute; retains 24 active-client, long-query, queue, and storage pressure gates'
    ),
    updated_at=now()
where singleton=true;

-- Keep guarded parcel lanes frequent enough to exploit healthy scheduler headroom.
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-priority-parcel-shard-v751-0'), schedule := '11 seconds');
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-priority-parcel-shard-v751-1'), schedule := '13 seconds');
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-priority-parcel-shard-v751-2'), schedule := '15 seconds');
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-priority-parcel-shard-v751-3'), schedule := '17 seconds');
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-priority-parcel-shard-v751-4'), schedule := '19 seconds');
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-priority-parcel-shard-v751-5'), schedule := '21 seconds');
