-- BridgePoint V1012
-- Drain the huge national_property_intelligence_backfill without fabricating scores.
-- Properties with no active evidence in either signal system are evaluated truthfully
-- in bulk; signal-bearing properties remain for the full pattern/score/opportunity workers.
create or replace function automation.bulk_complete_no_signal_foundation_v1012(p_limit integer default 2000)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','core','signal_engine','intelligence','scoring_engine'
set statement_timeout to '55s'
as $function$
declare
  v_limit int:=least(greatest(coalesce(p_limit,2000),100),10000);
  v_started timestamptz:=clock_timestamp();
  v_done bigint:=0;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('bulk-no-signal-foundation-v1012',0)) then
    return jsonb_build_object('complete',true,'skipped',true,'reason','ALREADY_RUNNING','version',1012);
  end if;

  with claimed as materialized (
    select q.entity_id,coalesce(nullif(q.metadata->>'state_code',''),upper(p.state_code::text)) as state_code,q.reason
    from automation.entity_reprocess_queue q
    join core.properties p on p.property_id=q.entity_id
    where q.entity_type='property' and q.reason='national_property_intelligence_backfill'
      and q.status in('PENDING','ERROR') and q.attempts<5
      and not exists (select 1 from signal_engine.signals_v35 s where s.entity_type='property' and s.entity_id=q.entity_id and s.signal_status='active' limit 1)
      and not exists (
        select 1 from intelligence.signals s
        join intelligence.signal_types st on st.signal_type_id=s.signal_type_id
        where s.entity_type='property' and s.entity_id=q.entity_id and st.is_active
          and lower(coalesce(s.status,'active'))='active'
          and coalesce(s.effective_at,s.detected_at)<=now()
          and (s.expires_at is null or s.expires_at>now())
        limit 1
      )
    order by q.last_queued_at,q.entity_id
    for update of q skip locked
    limit v_limit
  ), evaluated as (
    insert into scoring_engine.property_intelligence_evaluations_v755(
      property_id,state_code,evaluation_status,has_active_signals,pattern_status,score_status,opportunity_status,
      evaluated_at,next_recheck_at,last_trigger,metadata,updated_at)
    select c.entity_id,c.state_code,'EVALUATED_NO_ACTIVE_SIGNALS',false,'NO_ACTIVE_SIGNALS','NO_ACTIVE_SIGNALS','NO_ELIGIBLE_OPPORTUNITY',
           now(),now()+interval '30 days','NATIONAL_PROPERTY_FOUNDATION_V1012',
           jsonb_build_object('truth_rule','No score or opportunity is fabricated when no active evidence exists.','source_reason',c.reason,'bulk_processor_version',1012),now()
    from claimed c
    on conflict(property_id) do update set
      state_code=excluded.state_code,evaluation_status='EVALUATED_NO_ACTIVE_SIGNALS',has_active_signals=false,
      pattern_status='NO_ACTIVE_SIGNALS',score_status='NO_ACTIVE_SIGNALS',opportunity_status='NO_ELIGIBLE_OPPORTUNITY',
      evaluated_at=now(),next_recheck_at=excluded.next_recheck_at,last_trigger=excluded.last_trigger,
      metadata=scoring_engine.property_intelligence_evaluations_v755.metadata||excluded.metadata,updated_at=now()
    returning property_id
  ), finished as (
    update automation.entity_reprocess_queue q
       set status='COMPLETED',attempts=attempts+1,completed_at=now(),last_error=null,
           metadata=(coalesce(q.metadata,'{}'::jsonb)-'score_result'-'opportunity_result')||jsonb_build_object(
             'processed_at',now(),'processor','NATIONAL_PROPERTY_FOUNDATION_V1012','state_code',c.state_code,
             'intelligence_status','EVALUATED_NO_ACTIVE_SIGNALS','pattern_status','NO_ACTIVE_SIGNALS',
             'score_status','NO_ACTIVE_SIGNALS','opportunity_status','NO_ELIGIBLE_OPPORTUNITY','truthful_no_score',true,'bulk_processor_version',1012)
      from claimed c
     where q.entity_type='property' and q.entity_id=c.entity_id
    returning q.entity_id
  )
  select count(*) into v_done from finished;

  return jsonb_build_object('complete',true,'skipped',false,'processed',v_done,'requested_limit',v_limit,
    'duration_ms',round(extract(epoch from(clock_timestamp()-v_started))*1000,1),'version',1012);
end
$function$;

-- Keep the two full per-property lanes for signal-bearing properties; use one
-- set-based lane for the large no-signal majority.
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-foundation-intelligence-v750-02'), active := false);
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-foundation-intelligence-v750-03'), active := false);
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-foundation-intelligence-v750-04'), active := false);
select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-foundation-intelligence-v750-05'), active := false);

select case when exists(select 1 from cron.job where jobname='bridgepoint-foundation-no-signal-bulk-v1012')
  then (select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-foundation-no-signal-bulk-v1012'), schedule := '* * * * *', command := 'select automation.bulk_complete_no_signal_foundation_v1012(1000);', active := true)::text)
  else cron.schedule('bridgepoint-foundation-no-signal-bulk-v1012','* * * * *','select automation.bulk_complete_no_signal_foundation_v1012(1000);')::text
end;
