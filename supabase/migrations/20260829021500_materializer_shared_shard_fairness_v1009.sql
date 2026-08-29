-- BridgePoint V1009
-- Prevent completed-source states from being starved when they share a materializer
-- shard with a state whose acquisition is still open. Each lane prefers a state
-- different from the one it processed last.
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
    return jsonb_build_object('complete',true,'skipped',true,'reason','LOAD_GATE','shard',p_shard,'pending',q_pending,'failed',q_failed,'database_size_gb',db_gb,'active_clients',active_clients,'long_clients',long_clients,'io_waits',io_waits,'lock_waits',lock_waits,'version',1009);
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
  left join automation.expansion_native_worker_health_v397 h on h.lane=p_shard
  where t.shard_slot=p_shard
  order by (t.state_code = h.last_state_code) asc nulls last,
           t.acquisition_open desc,
           t.canonical_property_count,
           t.state_code
  limit 1;

  if r.run_id is null then
    return jsonb_build_object('complete',true,'shard',p_shard,'runs_processed',0,'reason','NO_CACHED_TARGET','version',1009);
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
    'io_waits',io_waits,'lock_waits',lock_waits,'selection_policy','ROUND_ROBIN_LAST_STATE_FAIRNESS','version',1009);
end
$function$;
