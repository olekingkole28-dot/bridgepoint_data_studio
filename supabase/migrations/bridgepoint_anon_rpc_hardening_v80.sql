-- BridgePoint V80 security follow-up.
-- Close legacy anonymous SECURITY DEFINER RPC access without breaking the
-- authenticated Flutter API or service-role-only ingestion automation.

do $$
declare
  r record;
  signature text;
  customer_rpc_names constant text[] := array[
    'bridgepoint_ct_fire_status',
    'bridgepoint_flutter_packages',
    'bridgepoint_flutter_permit_context_v68',
    'bridgepoint_flutter_pricing_v63',
    'bridgepoint_flutter_properties',
    'bridgepoint_flutter_property_detail_v57',
    'bridgepoint_flutter_settings_v59',
    'bridgepoint_flutter_signals',
    'bridgepoint_flutter_sources',
    'bridgepoint_flutter_system_health_v59'
  ];
  service_rpc_names constant text[] := array[
    'bridgepoint_finalize_fema_ingestion_public',
    'bridgepoint_finalize_grid_ingestion_public',
    'bridgepoint_ingest_deep_spill_public_batch',
    'bridgepoint_ingest_deep_ust_public_batch',
    'bridgepoint_ingest_fema_lean_public_batch',
    'bridgepoint_ingest_grid_lean_public_batch',
    'bridgepoint_ingest_nfirs_pdr_lite_public_batch',
    'bridgepoint_ingest_property_transition_public_batch',
    'bridgepoint_ingest_usgs_hydrology_public_batch',
    'bridgepoint_materialize_fema_public_batch',
    'bridgepoint_materialize_grid_public_batch'
  ];
begin
  for r in
    select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) arguments
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and (p.proname=any(customer_rpc_names)
        or p.proname=any(service_rpc_names)
        or p.proname='st_estimatedextent')
  loop
    signature:=format('%I.%I(%s)',r.nspname,r.proname,r.arguments);
    execute format('revoke all on function %s from public,anon,authenticated',signature);
    if r.proname=any(customer_rpc_names) then
      execute format('grant execute on function %s to authenticated,service_role',signature);
    else
      execute format('grant execute on function %s to service_role',signature);
    end if;
  end loop;
end $$;

comment on function public.bridgepoint_flutter_pricing_v63()
is 'Authenticated pricing catalog. Anonymous SECURITY DEFINER access removed in V80.';
