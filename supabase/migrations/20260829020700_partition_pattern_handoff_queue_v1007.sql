-- BridgePoint V1007
-- Generic entity workers must not compete with pattern-score handoff workers for PATTERN_V36_EVALUATED rows.
create or replace function public.bridgepoint_reprocess_next_queued_entity()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation','core'
set statement_timeout to '45s'
as $function$
declare
  entity_record record;
  v_state text;
  area_result jsonb := jsonb_build_object('skipped',true,'reason','NOT_AREA_CONTEXT');
  pattern_result jsonb := jsonb_build_object('skipped',true,'reason','NOT_REQUIRED');
  score_result jsonb;
  opportunity_result jsonb;
begin
  select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
  from automation.entity_reprocess_queue q
  where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason='semantic_repair_corrected_evidence'
  order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason='expansion_context_date_corrected'
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason='code_enforcement_updated'
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason='event_signal_reconciled'
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason='national_noaa_signal_reconciled'
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason='noaa_area_context_changed'
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5
      and q.source_event_id is not null
      and q.reason not in ('expansion_property_foundation_created','PATTERN_V36_EVALUATED','event_signal_reconciled','national_noaa_signal_reconciled','noaa_area_context_changed')
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    select q.entity_type,q.entity_id,q.source_code,q.source_event_id,q.reason,q.attempts,q.metadata into entity_record
    from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5 and q.reason in('expansion_context_updated','expansion_context_date_corrected')
    order by q.status,q.last_queued_at,q.entity_id for update skip locked limit 1;
  end if;

  if not found then
    return jsonb_build_object('complete',true,'processed',false,'message','The generic evidence-backed property queue is empty. Pattern handoffs are owned by PATTERN_SCORE_HANDOFF_V370.','processor_version',1007);
  end if;

  v_state:=nullif(entity_record.metadata->>'state_code','');
  if v_state is null then select p.state_code::text into v_state from core.properties p where p.property_id=entity_record.entity_id; end if;

  update automation.entity_reprocess_queue set status='PROCESSING',attempts=attempts+1,last_error=null
  where entity_type=entity_record.entity_type and entity_id=entity_record.entity_id;

  begin
    if entity_record.reason='noaa_area_context_changed' then
      area_result:=public.bridgepoint_materialize_property_area_weather(entity_record.entity_id);
    end if;
    if entity_record.reason in ('semantic_repair_corrected_evidence','code_enforcement_updated','expansion_context_updated','expansion_context_date_corrected','event_signal_reconciled','national_noaa_signal_reconciled','noaa_area_context_changed') then
      pattern_result:=automation.engine_detect_patterns_v36(jsonb_build_object('entity_type','property','entity_id',entity_record.entity_id,'trigger','ENTITY_REPROCESSING_V1007','state_code',v_state));
      if lower(coalesce(pattern_result->>'status','completed')) in ('failed','error') then raise exception 'Pattern detection returned failure: %',pattern_result::text; end if;
    end if;
    score_result:=automation.engine_score_properties_v37(jsonb_build_object('property_id',entity_record.entity_id,'trigger','AUTOMATIC_EVENT_REPROCESSING','source_code',entity_record.source_code,'source_event_id',entity_record.source_event_id,'state_code',v_state,'dispatcher_version',1007));
    if lower(coalesce(score_result->>'status','completed')) in ('failed','error') then raise exception 'Property scoring returned failure: %',score_result::text; end if;
    opportunity_result:=automation.engine_generate_opportunities_v38(jsonb_build_object('property_id',entity_record.entity_id,'trigger','AUTOMATIC_EVENT_REPROCESSING','source_code',entity_record.source_code,'source_event_id',entity_record.source_event_id,'state_code',v_state,'dispatcher_version',1007));
    if lower(coalesce(opportunity_result->>'status','completed')) in ('failed','error') then raise exception 'Opportunity generation returned failure: %',opportunity_result::text; end if;
    update automation.entity_reprocess_queue
    set status='COMPLETED',completed_at=now(),last_error=null,
        metadata=(coalesce(metadata,'{}'::jsonb)-'score_result'-'opportunity_result')||jsonb_build_object('processed_at',now(),'processor','BRIDGEPOINT_ENTITY_REPROCESSING_V1007_GENERIC_ONLY','state_code',v_state,'area_events_matched',coalesce(nullif(area_result->>'matched_area_events','')::integer,0),'pattern_status',coalesce(pattern_result->>'status','completed'),'score_status',coalesce(score_result->>'status','completed'),'opportunity_status',coalesce(opportunity_result->>'status','completed'))
    where entity_type=entity_record.entity_type and entity_id=entity_record.entity_id;
    return jsonb_build_object('complete',false,'processed',true,'entity_id',entity_record.entity_id,'state_code',v_state,'reason',entity_record.reason,'pattern_result',pattern_result,'score_result',score_result,'opportunity_result',opportunity_result,'processor_version',1007,'dispatch_mode','GENERIC_QUEUE_EXCLUDES_PATTERN_HANDOFF');
  exception when others then
    update automation.entity_reprocess_queue set status='ERROR',last_error=sqlerrm,metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('failed_at',now(),'sqlstate',sqlstate,'processor','BRIDGEPOINT_ENTITY_REPROCESSING_V1007_GENERIC_ONLY','state_code',v_state)
    where entity_type=entity_record.entity_type and entity_id=entity_record.entity_id;
    return jsonb_build_object('complete',false,'processed',false,'status','error','entity_id',entity_record.entity_id,'state_code',v_state,'sqlstate',sqlstate,'error',sqlerrm,'processor_version',1007);
  end;
end
$function$;

create or replace function public.bridgepoint_reprocess_entity_queue_v344(p_max_entities integer default 100)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
set statement_timeout to '110s'
as $function$
declare
  v_limit integer:=least(greatest(coalesce(p_max_entities,100),1),200);
  i integer; r jsonb; processed integer:=0; failed integer:=0; has_more boolean:=false;
begin
  for i in 1..v_limit loop
    r:=public.bridgepoint_reprocess_next_queued_entity();
    if coalesce((r->>'complete')::boolean,false) then exit; end if;
    if coalesce((r->>'processed')::boolean,false) then processed:=processed+1; else failed:=failed+1; exit; end if;
    if clock_timestamp() - statement_timestamp() > interval '90 seconds' then exit; end if;
  end loop;
  select exists(
    select 1 from automation.entity_reprocess_queue q
    where q.entity_type='property' and q.status in ('PENDING','ERROR') and q.attempts<5
      and q.reason not in ('expansion_property_foundation_created','PATTERN_V36_EVALUATED')
    limit 1
  ) into has_more;
  return jsonb_build_object('complete',not has_more,'entities_processed',processed,'entities_failed',failed,
    'has_more',has_more,'version',1007,'queue_partition','GENERIC_EXCLUDES_PATTERN_HANDOFF');
end
$function$;

-- Retire the three legacy booster handoff crons. Governed handoff jobs 179-181 own this queue now.
select cron.alter_job(236,null,null,null,null,false);
select cron.alter_job(237,null,null,null,null,false);
select cron.alter_job(238,null,null,null,null,false);
