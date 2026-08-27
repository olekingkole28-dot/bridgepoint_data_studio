-- BridgePoint V943: distinguish operational source routes from unique source breadth.

create or replace function public.bridgepoint_owner_source_truth_v943()
returns jsonb
language plpgsql
stable security definer
set search_path to 'pg_catalog','public','api','accounts','automation'
as $function$
declare
  v_registry bigint; v_enabled bigint; v_endpoints bigint; v_providers bigint;
  v_categories bigint; v_healthy bigint; v_failing bigint; v_unknown bigint;
  v_duplicate_routes bigint; v_recent_inserted bigint; v_last_success timestamptz;
begin
  perform api.require_user();
  if not accounts.is_platform_admin() then raise exception 'Owner access required'; end if;

  select count(*),count(*) filter(where enabled),
    count(distinct nullif(btrim(source_url),'')),count(distinct nullif(btrim(provider),'')),
    count(distinct nullif(btrim(source_category),'')),
    count(*) filter(where upper(coalesce(health_status,''))='HEALTHY'),
    count(*) filter(where upper(coalesce(health_status,''))='FAILING'),
    count(*) filter(where coalesce(btrim(health_status),'')='' or upper(health_status) not in ('HEALTHY','FAILING','STALE')),
    coalesce(sum(last_run_records_inserted),0),max(last_successful_import_at)
  into v_registry,v_enabled,v_endpoints,v_providers,v_categories,v_healthy,v_failing,v_unknown,v_recent_inserted,v_last_success
  from automation.source_registry;

  select coalesce(sum(n-1),0) into v_duplicate_routes
  from (select count(*)::bigint n from automation.source_registry
        where source_url is not null and btrim(source_url)<>''
        group by btrim(source_url) having count(*)>1) d;

  return jsonb_build_object(
    'complete',true,'version',943,'generated_at',now(),
    'registry_routes',v_registry,'enabled_routes',v_enabled,'distinct_endpoints',v_endpoints,
    'distinct_providers',v_providers,'distinct_categories',v_categories,
    'healthy_routes',v_healthy,'failing_routes',v_failing,'other_health_routes',v_unknown,
    'duplicate_routing_rows',v_duplicate_routes,'latest_run_inserted',v_recent_inserted,
    'last_successful_import_at',v_last_success,
    'display_rule','Show distinct endpoints/providers as source breadth. Registry-route count is operational routing and must not be presented as the number of unique datasets.');
end
$function$;

revoke all on function public.bridgepoint_owner_source_truth_v943() from public,anon;
grant execute on function public.bridgepoint_owner_source_truth_v943() to authenticated,service_role;
