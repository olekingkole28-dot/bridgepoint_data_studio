-- BridgePoint V1004
-- Prevent a still-ingesting state from starving a source-complete state that shares the same materializer shard.
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
  active_clients int:=0; long_clients int:=0; r record;
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
         )::int
    into active_clients,long_clients
  from pg_stat_activity a
  where a.datname=current_database() and a.pid<>pg_backend_pid()
    and a.backend_type='client backend' and a.state='active';

  if q_failed>0 or q_pending>=p.property_queue_hard_limit or db_gb>=p.db_hard_limit_gb or active_clients>p.max_active_client_backends then
    return jsonb_build_object('complete',true,'skipped',true,'reason','LOAD_GATE','shard',p_shard,'pending',q_pending,'failed',q_failed,'database_size_gb',db_gb,'active_clients',active_clients,'version',1004);
  end if;

  if db_gb<p.db_soft_limit_gb and active_clients<=4 and long_clients=0 and q_pending<p.property_queue_soft_limit then
    batch_size:=1250;
  elsif db_gb>=p.db_soft_limit_gb or active_clients>6 or long_clients>0 then
    batch_size:=250;
  end if;
  if active_clients>8 or long_clients>=2 then batch_size:=75; end if;

  select t.run_id,t.state_code,t.canonical_property_count,t.acquisition_open,
         greatest(coalesce(d.expected_rows,t.canonical_property_count)-t.canonical_property_count,0)::bigint as known_canonical_gap
    into r
  from automation.expansion_materializer_targets_v398 t
  left join automation.state_foundation_denominators_v403 d on d.state_code=t.state_code
  where t.shard_slot=p_shard
  order by greatest(coalesce(d.expected_rows,t.canonical_property_count)-t.canonical_property_count,0) desc,
           t.acquisition_open desc,
           t.canonical_property_count,
           t.state_code
  limit 1;

  if r.run_id is null then
    return jsonb_build_object('complete',true,'shard',p_shard,'runs_processed',0,'reason','NO_CACHED_TARGET','version',1004);
  end if;

  if r.state_code='NY' then batch_size:=least(batch_size,150); end if;
  if r.acquisition_open then batch_size:=least(batch_size,1000); end if;

  alias_result:=automation.expansion_prepare_foundation_aliases_v339(r.run_id,batch_size);
  one:=public.bridgepoint_expansion_worker_materialize_properties_bulk_v338(r.run_id,batch_size);
  update automation.expansion_materializer_targets_v398
     set canonical_property_count=coalesce((one->>'canonical_property_count')::bigint,canonical_property_count),refreshed_at=now()
   where run_id=r.run_id;

  return jsonb_build_object('complete',true,'shard',p_shard,'state_code',r.state_code,'batch_size',batch_size,'before_count',r.canonical_property_count,
    'known_canonical_gap',r.known_canonical_gap,'acquisition_open',r.acquisition_open,'aliases',alias_result,'result',one,'database_size_gb',db_gb,'active_clients',active_clients,'long_clients',long_clients,
    'selection_policy','LARGEST_KNOWN_CANONICAL_GAP_FIRST','version',1004);
end
$function$;
