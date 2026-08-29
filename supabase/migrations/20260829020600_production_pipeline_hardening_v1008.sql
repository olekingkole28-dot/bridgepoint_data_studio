-- BridgePoint production hardening checkpoint V1008.
-- Persists the live V1004-V1007 fixes: scheduler failure truth, fast map-state summary,
-- timing-safe source compliance persistence, and 16XL foundation materializer tuning.

create or replace function automation.relevant_heavy_failure_count_v631(p_window interval default interval '5 minutes')
returns integer
language sql
security definer
set search_path to 'pg_catalog','cron'
as $function$
  select count(*)::int
  from cron.job_run_details d
  left join cron.job j on j.jobid=d.jobid
  where d.start_time>=now()-p_window
    and d.status='failed'
    and coalesce(j.active,true)
    and coalesce(d.return_message,'') <> 'job startup timeout'
    and (
      j.jobname ilike '%expansion%' or j.jobname ilike '%pattern%' or j.jobname ilike '%entity-reprocessing%' or
      j.jobname ilike '%score%' or j.jobname ilike '%opportunit%' or
      coalesce(d.return_message,'') ilike '%lock timeout%'
    );
$function$;

create or replace function automation.refresh_map_state_intelligence_summary_v975()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','core','opportunity_engine'
set statement_timeout to '45s'
as $function$
declare
  got_lock boolean;
  touched integer := 0;
begin
  got_lock := pg_try_advisory_xact_lock(hashtext('automation.refresh_map_state_intelligence_summary_v975'));
  if not got_lock then
    return jsonb_build_object('complete',true,'skipped',true,'reason','REFRESH_ALREADY_RUNNING','version',1005);
  end if;

  with states as (
    select unnest(array['AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY'])::text as state_code
  ), sig as (
    select state_code,
           count(*)::bigint as active_signal_count,
           count(distinct property_id)::bigint as properties_with_signals
    from automation.app_signal_map_feed_v371
    where state_code ~ '^[A-Z]{2}$'
      and lower(coalesce(status,'active'))='active'
    group by state_code
  ), opp as (
    select trim(p.state_code::text) as state_code,
           count(*)::bigint as verified_opportunity_count,
           count(distinct o.property_id)::bigint as properties_with_opportunities
    from opportunity_engine.verified_ranked_opportunities_v233 o
    join core.properties p on p.property_id=o.property_id
    where p.active
      and trim(p.state_code::text) ~ '^[A-Z]{2}$'
    group by 1
  )
  insert into automation.map_state_intelligence_summary_v975(
    state_code,active_signal_count,properties_with_signals,
    verified_opportunity_count,properties_with_opportunities,refreshed_at
  )
  select st.state_code,
         coalesce(sig.active_signal_count,0),coalesce(sig.properties_with_signals,0),
         coalesce(opp.verified_opportunity_count,0),coalesce(opp.properties_with_opportunities,0),now()
  from states st
  left join sig using(state_code)
  left join opp using(state_code)
  on conflict(state_code) do update set
    active_signal_count=excluded.active_signal_count,
    properties_with_signals=excluded.properties_with_signals,
    verified_opportunity_count=excluded.verified_opportunity_count,
    properties_with_opportunities=excluded.properties_with_opportunities,
    refreshed_at=excluded.refreshed_at;

  get diagnostics touched = row_count;
  return jsonb_build_object('complete',true,'skipped',false,'states_refreshed',touched,'refreshed_at',now(),'version',1005,'signal_source','APP_SIGNAL_MAP_FEED_V371');
end
$function$;

create or replace function automation.source_compliance_gate_v720()
returns trigger
language plpgsql
set search_path to 'pg_catalog','automation'
as $function$
declare
  m jsonb:=coalesce(new.metadata,'{}'::jsonb);
  geo text; sem text; authz text; prov text; rights text; priv text; law text; resid text; pclass text; activation text;
  rel numeric; official boolean:=false;
  eval jsonb;
begin
  if new.decision_status<>'ACCEPTED' then return new; end if;
  if tg_op='UPDATE' and old.decision_status='ACCEPTED' then return new; end if;

  official:=coalesce((m->>'official')::boolean,false);
  rel:=automation.expansion_category_relevance_v200(new.source_category,new.candidate_name,m);
  geo:=case when m->>'geo_scope' in('TARGET','NATIONAL') then 'PASS' when m->>'geo_scope' in('OTHER','FOREIGN') then 'FAIL' else 'UNKNOWN' end;
  sem:=case when rel>=80 then 'PASS' when rel<60 then 'FAIL' else 'UNKNOWN' end;
  authz:=case when official and coalesce(new.authority_score,0)>=70 then 'PASS' when coalesce((m->>'authority_rejected')::boolean,false) then 'FAIL' else 'UNKNOWN' end;
  prov:=case when official and coalesce(new.provider,'')<>'' and lower(coalesce(new.source_url,'')) like 'https://%' then 'PASS' else 'UNKNOWN' end;
  rights:=case
    when coalesce((m->>'rights_denied')::boolean,false) then 'FAIL'
    when coalesce((m->>'rights_verified')::boolean,false) or coalesce((m->>'license_verified')::boolean,false) then 'PASS'
    when upper(coalesce(m->>'rights_status',m->>'license_status',m->>'usage_rights_status','')) in('PASS','APPROVED','VERIFIED','PUBLIC_DOMAIN','OPEN_LICENSE') then 'PASS'
    else 'UNKNOWN' end;
  pclass:=upper(coalesce(m->>'personal_data_class',case when coalesce((m->>'contains_personal_data')::boolean,false) then 'PERSONAL' when m ? 'contains_personal_data' then 'NON_PERSONAL' else 'UNKNOWN' end));
  priv:=case
    when coalesce((m->>'privacy_rejected')::boolean,false) then 'FAIL'
    when coalesce((m->>'privacy_verified')::boolean,false) or upper(coalesce(m->>'privacy_status','')) in('PASS','APPROVED','VERIFIED') then 'PASS'
    when pclass='NON_PERSONAL' then 'NOT_APPLICABLE'
    else 'UNKNOWN' end;
  law:=case
    when upper(coalesce(m->>'local_law_status',m->>'legal_review_status','')) in('PASS','APPROVED','VERIFIED') then 'PASS'
    when upper(coalesce(m->>'local_law_status',m->>'legal_review_status','')) in('FAIL','REJECTED','PROHIBITED') then 'FAIL'
    else 'UNKNOWN' end;
  resid:=case
    when upper(coalesce(m->>'residency_status','')) in('PASS','APPROVED','VERIFIED') then 'PASS'
    when upper(coalesce(m->>'residency_status','')) in('FAIL','REJECTED') then 'FAIL'
    when m ? 'residency_required' and coalesce((m->>'residency_required')::boolean,false)=false then 'NOT_APPLICABLE'
    else 'UNKNOWN' end;

  activation:=case
    when 'FAIL' in(geo,sem,authz,prov,rights,priv,law,resid) then 'REJECTED'
    when geo='PASS' and sem='PASS' and authz='PASS' and prov='PASS' and rights in('PASS','NOT_APPLICABLE') and priv in('PASS','NOT_APPLICABLE') and law in('PASS','NOT_APPLICABLE') and resid in('PASS','NOT_APPLICABLE') then 'APPROVED'
    else 'QUARANTINED' end;

  eval:=jsonb_build_object(
    'geography_status',geo,'semantic_status',sem,'authority_status',authz,'provenance_status',prov,
    'rights_status',rights,'privacy_status',priv,'local_law_status',law,'residency_status',resid,
    'personal_data_class',pclass,'activation_status',activation,'relevance_score',rel,'official',official,
    'evaluated_at',now(),'gate_version',1006
  );

  if activation='REJECTED' then
    new.decision_status:='REJECTED';
    new.reviewed_at:=coalesce(new.reviewed_at,now());
    new.metadata:=m||jsonb_build_object('compliance_gate_v720','REJECTED','compliance_quarantined',false,'compliance_checked_at',now(),'compliance_evaluation_v1006',eval);
  elsif activation<>'APPROVED' then
    new.decision_status:='NEEDS_REVIEW';
    new.metadata:=m||jsonb_build_object(
      'compliance_gate_v720','QUARANTINED','compliance_quarantined',true,'compliance_checked_at',now(),
      'compliance_missing',jsonb_strip_nulls(jsonb_build_object(
        'rights',case when rights='UNKNOWN' then true end,'privacy',case when priv='UNKNOWN' then true end,
        'local_law',case when law='UNKNOWN' then true end,'residency',case when resid='UNKNOWN' then true end,
        'authority',case when authz='UNKNOWN' then true end,'provenance',case when prov='UNKNOWN' then true end)),
      'compliance_evaluation_v1006',eval
    );
  else
    new.metadata:=m||jsonb_build_object('compliance_gate_v720','APPROVED','compliance_quarantined',false,'compliance_checked_at',now(),'compliance_evaluation_v1006',eval);
  end if;
  return new;
end
$function$;

create or replace function automation.persist_source_compliance_v1006()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','automation'
as $function$
declare
  e jsonb:=coalesce(new.metadata->'compliance_evaluation_v1006','{}'::jsonb);
  activation text:=coalesce(e->>'activation_status','QUARANTINED');
begin
  if e='{}'::jsonb then return new; end if;

  insert into automation.source_compliance_validation_v720(
    candidate_id,state_code,source_category,geography_status,semantic_status,authority_status,provenance_status,
    rights_status,privacy_status,local_law_status,residency_status,personal_data_class,allowed_use_scope,
    activation_status,evidence,evaluated_at,approved_at,updated_at)
  values(
    new.candidate_id,new.state_code,new.source_category,
    coalesce(e->>'geography_status','UNKNOWN'),coalesce(e->>'semantic_status','UNKNOWN'),coalesce(e->>'authority_status','UNKNOWN'),coalesce(e->>'provenance_status','UNKNOWN'),
    coalesce(e->>'rights_status','UNKNOWN'),coalesce(e->>'privacy_status','UNKNOWN'),coalesce(e->>'local_law_status','UNKNOWN'),coalesce(e->>'residency_status','UNKNOWN'),
    coalesce(e->>'personal_data_class','UNKNOWN'),new.metadata->>'allowed_use_scope',activation,
    jsonb_build_object('source_url',new.source_url,'provider',new.provider,'official',coalesce((e->>'official')::boolean,false),'relevance_score',e->'relevance_score','gate_version',1006),
    now(),case when activation='APPROVED' then now() end,now())
  on conflict(candidate_id) do update set
    state_code=excluded.state_code,source_category=excluded.source_category,geography_status=excluded.geography_status,
    semantic_status=excluded.semantic_status,authority_status=excluded.authority_status,provenance_status=excluded.provenance_status,
    rights_status=excluded.rights_status,privacy_status=excluded.privacy_status,local_law_status=excluded.local_law_status,
    residency_status=excluded.residency_status,personal_data_class=excluded.personal_data_class,allowed_use_scope=excluded.allowed_use_scope,
    activation_status=excluded.activation_status,evidence=automation.source_compliance_validation_v720.evidence||excluded.evidence,
    evaluated_at=now(),approved_at=case when excluded.activation_status='APPROVED' then coalesce(automation.source_compliance_validation_v720.approved_at,now()) else automation.source_compliance_validation_v720.approved_at end,
    updated_at=now();
  return new;
end
$function$;

drop trigger if exists trg_source_compliance_persist_v1006 on automation.geographic_source_candidates_v86;
create trigger trg_source_compliance_persist_v1006
after insert or update of decision_status, metadata on automation.geographic_source_candidates_v86
for each row
when (new.metadata ? 'compliance_evaluation_v1006')
execute function automation.persist_source_compliance_v1006();

create or replace function automation.expansion_property_bulk_shard_v417(p_shard integer, p_shards integer default 3)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','public','product'
set statement_timeout to '50s'
as $function$
declare
  p automation.expansion_load_policy_v321%rowtype;
  q_pending bigint:=0; q_failed bigint:=0; db_gb numeric:=0;
  active_clients int:=0; long_clients int:=0; io_waits int:=0; lock_waits int:=0; r record;
  alias_result jsonb; one jsonb; batch_size int:=750;
begin
  if p_shards<1 or p_shard<0 or p_shard>=p_shards then raise exception 'Invalid shard'; end if;
  select * into p from automation.expansion_load_policy_v321 where singleton=true;
  select coalesce(pending,0),coalesce(failed,0) into q_pending,q_failed from automation.v40_property_queue_health;
  db_gb:=round(pg_database_size(current_database())::numeric/1073741824.0,2);

  select count(*)::int,
         count(*) filter(
           where query_start is not null
             and now()-query_start>make_interval(secs=>p.long_query_seconds)
             and coalesce(query,'') not ilike '%bridgepoint_expansion_worker_advance%'
             and coalesce(query,'') not ilike '%expansion_native_foundation_lane%'
             and coalesce(query,'') not ilike '%expansion_property_bulk_shard%'
             and coalesce(query,'') not ilike '%expansion_scheduler_tick%'
         )::int,
         count(*) filter(where wait_event_type='IO')::int,
         count(*) filter(where wait_event_type='Lock')::int
    into active_clients,long_clients,io_waits,lock_waits
  from pg_stat_activity a
  where a.datname=current_database() and a.pid<>pg_backend_pid()
    and a.backend_type='client backend' and a.state='active';

  if q_failed>0
     or q_pending>=p.property_queue_hard_limit
     or db_gb>=p.db_hard_limit_gb
     or active_clients>p.max_active_client_backends
     or long_clients>p.max_competing_long_queries
     or lock_waits>3
     or io_waits>10 then
    return jsonb_build_object('complete',true,'skipped',true,'reason','LOAD_GATE','shard',p_shard,'pending',q_pending,'failed',q_failed,'database_size_gb',db_gb,'active_clients',active_clients,'long_clients',long_clients,'io_waits',io_waits,'lock_waits',lock_waits,'version',1007);
  end if;

  if db_gb>=p.db_soft_limit_gb then
    batch_size:=250;
    if active_clients>20 or long_clients>=2 or io_waits>6 or lock_waits>2 then batch_size:=100; end if;
    if active_clients>22 or long_clients>=3 or io_waits>8 or lock_waits>3 then batch_size:=75; end if;
  else
    if active_clients<=6 and long_clients=0 and io_waits<=2 then
      batch_size:=1250;
    elsif active_clients<=14 and long_clients=0 and io_waits<=4 then
      batch_size:=750;
    elsif active_clients<=20 and long_clients<=1 and io_waits<=6 then
      batch_size:=500;
    else
      batch_size:=250;
    end if;
    if active_clients>22 or long_clients>=3 or io_waits>8 or lock_waits>3 then batch_size:=75; end if;
  end if;

  select t.run_id,t.state_code,t.canonical_property_count,t.acquisition_open into r
  from automation.expansion_materializer_targets_v398 t
  where t.shard_slot=p_shard
  order by t.acquisition_open desc,t.canonical_property_count,t.state_code
  limit 1;

  if r.run_id is null then
    return jsonb_build_object('complete',true,'shard',p_shard,'runs_processed',0,'reason','NO_CACHED_TARGET','version',1007);
  end if;

  if r.state_code='NY' then batch_size:=least(batch_size,150); end if;
  if r.acquisition_open then batch_size:=least(batch_size,1000); end if;

  alias_result:=automation.expansion_prepare_foundation_aliases_v339(r.run_id,batch_size);
  one:=public.bridgepoint_expansion_worker_materialize_properties_bulk_v338(r.run_id,batch_size);
  update automation.expansion_materializer_targets_v398
     set canonical_property_count=coalesce((one->>'canonical_property_count')::bigint,canonical_property_count),refreshed_at=now()
   where run_id=r.run_id;

  return jsonb_build_object('complete',true,'shard',p_shard,'state_code',r.state_code,'batch_size',batch_size,'before_count',r.canonical_property_count,
    'acquisition_open',r.acquisition_open,'aliases',alias_result,'result',one,'database_size_gb',db_gb,'active_clients',active_clients,'long_clients',long_clients,
    'io_waits',io_waits,'lock_waits',lock_waits,'selection_policy','ACQUISITION_OPEN_FIRST','version',1007);
end
$function$;

create or replace function automation.expansion_native_foundation_booster_v454(p_lane integer, p_lanes integer default 10)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','public','cron'
set statement_timeout to '58s'
as $function$
declare
  v_active int:=0; v_long int:=0; v_locks int:=0; v_io int:=0; v_fail int:=0;
  v_db_gb numeric:=0; v_property_pending bigint:=0; v_mode text; v_max_active int:=24;
begin
  if p_lanes<1 or p_lane<0 or p_lane>=p_lanes then raise exception 'Invalid lane'; end if;

  select count(*) filter(where a.backend_type='client backend' and a.state='active')::int,
         count(*) filter(where a.backend_type='client backend' and a.state='active' and a.query_start is not null and now()-a.query_start>interval '90 seconds')::int,
         count(*) filter(where a.backend_type='client backend' and a.state='active' and a.wait_event_type='Lock')::int,
         count(*) filter(where a.backend_type='client backend' and a.state='active' and a.wait_event_type='IO')::int
    into v_active,v_long,v_locks,v_io
  from pg_stat_activity a where a.datname=current_database() and a.pid<>pg_backend_pid();

  select automation.relevant_heavy_failure_count_v631(interval '5 minutes') into v_fail;
  select coalesce(pending,0) into v_property_pending from automation.v40_property_queue_health limit 1;
  select mode into v_mode from automation.overnight_throughput_governor_state_v395 where singleton=true;
  select max_active_client_backends into v_max_active from automation.expansion_load_policy_v321 where singleton=true;
  v_db_gb:=round(pg_database_size(current_database())::numeric/1073741824.0,2);

  if coalesce(v_mode,'BALANCED')<>'SPRINT'
     or v_db_gb>=(select hard_stop_database_gb from automation.capacity_policy_v627 where singleton=true)
     or v_active>least(coalesce(v_max_active,24),24)
     or v_long>3
     or v_locks>3
     or v_io>8
     or v_fail>4
     or v_property_pending>=2500 then
    return jsonb_build_object('complete',true,'skipped',true,'reason','16XL_PRESSURE_GATE','lane',p_lane,'mode',v_mode,'active_clients',v_active,'long_queries',v_long,'lock_waits',v_locks,'io_waits',v_io,'failures_5m',v_fail,'property_pending',v_property_pending,'database_size_gb',v_db_gb,'version',1007);
  end if;

  return automation.expansion_native_foundation_lane_v417(p_lane,p_lanes)
         || jsonb_build_object('booster_version',1007,'pressure_gate','GREEN');
end
$function$;
