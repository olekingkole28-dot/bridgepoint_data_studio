-- BridgePoint Intelligence v61
-- Private-schema execution hardening and remaining advisor errors.

begin;

alter view automation.available_functions_v29 set (security_invoker = true);

-- public.spatial_ref_sys is owned and managed by the PostGIS extension.
-- It is intentionally left unchanged so spatial/map functions remain supported.

do $block$
declare r record;
begin
    for r in
        select p.oid::regprocedure as signature
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where p.prosecdef
          and n.nspname in (
            'accounts','automation','bp_system','capital','contract','core',
            'deep','deep_ust','fema','geo','grid','infrastructure','ingest',
            'ingestion','intel','intelligence','learning','learning_engine',
            'market','marketplace','normalization','notifications','opportunities',
            'opportunity_engine','orchestration','outcomes','pattern_engine',
            'product','projects','property_engine','resolution','sales','scoring',
            'scoring_engine','search','signal_engine','solar','staging','test_engine',
            'timeline','transitions','usgs','validation_engine','workflow'
          )
    loop
        execute format(
            'revoke execute on function %s from public, anon, authenticated',
            r.signature
        );
        execute format('grant execute on function %s to service_role', r.signature);
    end loop;
end
$block$;

-- This helper is intentionally callable from authenticated RLS policies.
grant execute on function accounts.is_platform_admin() to authenticated, service_role;

-- Authenticated API endpoints remain the only browser entry points for trials/settings.
grant execute on function api.require_user() to authenticated, service_role;
grant execute on function api.my_settings_v59() to authenticated, service_role;
grant execute on function api.save_settings_v59(jsonb) to authenticated, service_role;
grant execute on function api.my_trial_status() to authenticated, service_role;
grant execute on function api.start_my_trial(uuid) to authenticated, service_role;

commit;
