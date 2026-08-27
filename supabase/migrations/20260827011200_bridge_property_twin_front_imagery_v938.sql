-- BridgePoint V938
-- Connect Property FRONT_IMAGERY requests to the existing governed national media worker.
-- Production protocol proof completed 2026-08-27: request -> media job -> worker -> no-coverage -> retry; test rows removed.

create or replace function automation.bridge_property_twin_front_imagery_v938(p_limit integer default 250)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','core'
set statement_timeout to '12s'
as $function$
declare
  lim int:=least(greatest(coalesce(p_limit,250),10),1000);
  v_completed int:=0;
  v_retried int:=0;
  v_failed_retried int:=0;
  v_seeded int:=0;
  v_marked_running int:=0;
begin
  if not pg_try_advisory_xact_lock(hashtext('bridgepoint-property-twin-front-imagery-v938')) then
    return jsonb_build_object('complete',true,'skipped',true,'reason','LOCKED','version',938);
  end if;

  with done as (
    select q.property_id
    from automation.property_twin_enrichment_queue_v918 q
    where q.capability_key='FRONT_IMAGERY'
      and q.status<>'COMPLETE'
      and exists (
        select 1 from core.property_media_v137 m
        where m.property_id=q.property_id and m.active
          and upper(m.media_type) in ('FIELD_PHOTO','STREET_VIEW','PHOTO','EXTERIOR','ASSESSOR_PHOTO','COMMUNITY_PHOTO')
      )
    order by q.priority desc,q.requested_at
    limit lim
    for update of q skip locked
  )
  update automation.property_twin_enrichment_queue_v918 q
  set status='COMPLETE',next_retry_at=null,last_error=null,updated_at=now()
  from done d
  where q.property_id=d.property_id and q.capability_key='FRONT_IMAGERY';
  get diagnostics v_completed=row_count;

  with cooled as (
    select q.property_id
    from automation.property_twin_enrichment_queue_v918 q
    where q.capability_key='FRONT_IMAGERY' and q.status='RUNNING'
      and not exists (
        select 1 from core.property_media_v137 m
        where m.property_id=q.property_id and m.active
          and upper(m.media_type) in ('FIELD_PHOTO','STREET_VIEW','PHOTO','EXTERIOR','ASSESSOR_PHOTO','COMMUNITY_PHOTO')
      )
      and exists (
        select 1 from automation.property_media_jobs_v161 j
        where j.property_id=q.property_id and j.job_type='DISCOVER_BEST_MEDIA' and j.status='SUCCEEDED'
          and j.result->>'reason'='NO_USABLE_FRONT_FACING_COVERAGE'
          and coalesce(j.completed_at,j.updated_at)>q.updated_at-interval '2 minutes'
      )
    order by q.updated_at
    limit lim
    for update of q skip locked
  )
  update automation.property_twin_enrichment_queue_v918 q
  set status='RETRY',attempts=q.attempts+1,next_retry_at=now()+interval '7 days',
      last_error='No usable verified front-facing imagery at current source coverage; retry after coverage/source refresh.',updated_at=now()
  from cooled c
  where q.property_id=c.property_id and q.capability_key='FRONT_IMAGERY';
  get diagnostics v_retried=row_count;

  with failed as (
    select q.property_id
    from automation.property_twin_enrichment_queue_v918 q
    where q.capability_key='FRONT_IMAGERY' and q.status='RUNNING'
      and exists (
        select 1 from automation.property_media_jobs_v161 j
        where j.property_id=q.property_id and j.job_type='DISCOVER_BEST_MEDIA' and j.status='FAILED'
          and coalesce(j.completed_at,j.updated_at)>q.updated_at-interval '2 minutes'
      )
    order by q.updated_at
    limit lim
    for update of q skip locked
  )
  update automation.property_twin_enrichment_queue_v918 q
  set status='RETRY',attempts=q.attempts+1,next_retry_at=now()+interval '6 hours',
      last_error='Front-imagery worker exhausted its current attempts; retry scheduled.',updated_at=now()
  from failed f
  where q.property_id=f.property_id and q.capability_key='FRONT_IMAGERY';
  get diagnostics v_failed_retried=row_count;

  with candidates as (
    select q.property_id,trim(p.state_code::text) state_code,q.priority
    from automation.property_twin_enrichment_queue_v918 q
    join core.properties p on p.property_id=q.property_id and p.active
    where q.capability_key='FRONT_IMAGERY'
      and q.status in ('QUEUED','RETRY')
      and coalesce(q.next_retry_at,now())<=now()
      and p.latitude is not null and p.longitude is not null
      and not exists (
        select 1 from core.property_media_v137 m
        where m.property_id=q.property_id and m.active
          and upper(m.media_type) in ('FIELD_PHOTO','STREET_VIEW','PHOTO','EXTERIOR','ASSESSOR_PHOTO','COMMUNITY_PHOTO')
      )
      and not exists (
        select 1 from automation.property_media_jobs_v161 j
        where j.property_id=q.property_id and j.job_type='DISCOVER_BEST_MEDIA'
          and j.status in ('QUEUED','RUNNING','WAITING_REVIEW')
      )
    order by q.priority desc,q.requested_at
    limit lim
    for update of q skip locked
  ), ins as (
    insert into automation.property_media_jobs_v161(property_id,state_code,job_type,status,priority,next_attempt_at,result)
    select property_id,state_code,'DISCOVER_BEST_MEDIA','QUEUED',least(greatest(priority,1),100),now(),
           jsonb_build_object('seed_source','PROPERTY_TWIN_FRONT_IMAGERY_V938','requested_at',now())
    from candidates
    on conflict do nothing
    returning property_id
  )
  select count(*) into v_seeded from ins;

  with active as (
    select q.property_id
    from automation.property_twin_enrichment_queue_v918 q
    where q.capability_key='FRONT_IMAGERY'
      and q.status in ('QUEUED','RETRY')
      and exists (
        select 1 from automation.property_media_jobs_v161 j
        where j.property_id=q.property_id and j.job_type='DISCOVER_BEST_MEDIA'
          and j.status in ('QUEUED','RUNNING','WAITING_REVIEW')
      )
    order by q.priority desc,q.requested_at
    limit lim
    for update of q skip locked
  )
  update automation.property_twin_enrichment_queue_v918 q
  set status='RUNNING',next_retry_at=null,last_error=null,updated_at=now()
  from active a
  where q.property_id=a.property_id and q.capability_key='FRONT_IMAGERY';
  get diagnostics v_marked_running=row_count;

  return jsonb_build_object(
    'complete',true,'version',938,
    'completed_from_real_media',v_completed,
    'no_coverage_retries',v_retried,
    'worker_failure_retries',v_failed_retried,
    'media_jobs_seeded',v_seeded,
    'requests_marked_running',v_marked_running,
    'contract','PROPERTY_TWIN_REQUEST_TO_GOVERNED_MEDIA_WORKER_V938'
  );
end
$function$;

revoke all on function automation.bridge_property_twin_front_imagery_v938(integer) from public,anon,authenticated;
grant execute on function automation.bridge_property_twin_front_imagery_v938(integer) to service_role;

select cron.unschedule(jobid)
from cron.job
where jobname='bridgepoint-property-twin-front-imagery-v938';

select cron.schedule(
  'bridgepoint-property-twin-front-imagery-v938',
  '* * * * *',
  $$select automation.bridge_property_twin_front_imagery_v938(500);$$
);
