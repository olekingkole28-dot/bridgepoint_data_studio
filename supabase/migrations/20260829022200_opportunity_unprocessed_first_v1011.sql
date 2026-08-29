-- BridgePoint V1011
-- Opportunity reconciliation was hourly and repeatedly selected the same top-scored
-- properties. Prefer never-processed properties, then stale ones, guard overlap,
-- and run every two minutes.
create or replace function opportunity_engine.run_v38(p_limit integer default 1000)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','opportunity_engine','scoring_engine'
set statement_timeout to '90s'
as $function$
declare
    v_run_id uuid;
    v_property record;
    v_result jsonb;
    v_processed bigint := 0;
    v_created bigint := 0;
    v_updated bigint := 0;
    v_failed bigint := 0;
    v_limit integer := greatest(least(coalesce(p_limit,1000),100000),1);
    v_remaining integer;
begin
    if not pg_try_advisory_xact_lock(hashtextextended('opportunity_engine.run_v38.v1011',0)) then
      return jsonb_build_object('status','skipped','reason','OPPORTUNITY_RUN_ALREADY_ACTIVE','version',1011);
    end if;

    insert into opportunity_engine.runs_v38(status,metadata)
    values('running',jsonb_build_object('engine','opportunity_intelligence_v38','selection_policy','UNPROCESSED_FIRST_STALE_SECOND','version',1011))
    returning opportunity_run_id into v_run_id;

    for v_property in
      select s.property_id
      from scoring_engine.current_property_scores_v37 s
      where s.intelligence_score >= 5
        and not exists (select 1 from opportunity_engine.opportunities_v38 o where o.property_id=s.property_id)
      order by s.intelligence_score desc,s.property_id
      limit v_limit
    loop
      v_processed:=v_processed+1;
      v_result:=opportunity_engine.detect_property_v38(v_property.property_id,v_run_id);
      v_created:=v_created+coalesce((v_result->>'created')::integer,0);
      v_updated:=v_updated+coalesce((v_result->>'updated')::integer,0);
      v_failed:=v_failed+coalesce((v_result->>'failed')::integer,0);
    end loop;

    v_remaining:=greatest(v_limit-v_processed,0);
    if v_remaining>0 then
      for v_property in
        select s.property_id,max(o.updated_at) as last_opportunity_at
        from scoring_engine.current_property_scores_v37 s
        join opportunity_engine.opportunities_v38 o on o.property_id=s.property_id
        where s.intelligence_score>=5
        group by s.property_id,s.intelligence_score
        order by max(o.updated_at) asc,s.intelligence_score desc,s.property_id
        limit v_remaining
      loop
        v_processed:=v_processed+1;
        v_result:=opportunity_engine.detect_property_v38(v_property.property_id,v_run_id);
        v_created:=v_created+coalesce((v_result->>'created')::integer,0);
        v_updated:=v_updated+coalesce((v_result->>'updated')::integer,0);
        v_failed:=v_failed+coalesce((v_result->>'failed')::integer,0);
      end loop;
    end if;

    update opportunity_engine.runs_v38
    set properties_processed=v_processed,opportunities_created=v_created,opportunities_updated=v_updated,
        opportunities_failed=v_failed,status=case when v_failed>0 then 'completed_with_errors' else 'completed' end,
        completed_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('selection_policy','UNPROCESSED_FIRST_STALE_SECOND','version',1011)
    where opportunity_run_id=v_run_id;

    return jsonb_build_object('status',case when v_failed>0 then 'completed_with_errors' else 'completed' end,
      'opportunity_run_id',v_run_id,'properties_processed',v_processed,'opportunities_created',v_created,
      'opportunities_updated',v_updated,'opportunities_failed',v_failed,'selection_policy','UNPROCESSED_FIRST_STALE_SECOND','version',1011);
exception when others then
    if v_run_id is not null then
      update opportunity_engine.runs_v38 set status='failed',completed_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('error',sqlerrm,'version',1011)
      where opportunity_run_id=v_run_id;
    end if;
    raise;
end
$function$;

select cron.alter_job((select jobid from cron.job where jobname='bridgepoint-opportunity-reconciliation'), schedule := '*/2 * * * *');
