-- BridgePoint allowed-model access contract v1.
--
-- bridgepoint_interactive_performance_v216.sql calls
-- product.user_allowed_model_keys_v204(user_id), but its function definition is
-- not present in the checked-in migration set. The deployed database may have
-- an out-of-band definition. Create this function only when it is absent so an
-- existing deployed contract is not silently replaced.
--
-- Access rules follow the checked-in package/subscription model:
--   * platform_access_overrides.access_all_models grants all active models
--     until expires_at;
--   * trialing subscriptions grant access only through trial_ends_at;
--   * active subscriptions grant access through current_period_end;
--   * a model must be active and linked through an enabled + included
--     product.package_models row to an active product.packages row.

begin;

do $bootstrap$
begin
  if to_regprocedure('product.has_platform_override(uuid)') is null then
    execute $create_override$
      create function product.has_platform_override(p_user_id uuid)
      returns boolean
      language sql
      stable
      security definer
      set search_path = 'pg_catalog', 'product'
      as $function$
        select exists (
          select 1
          from product.platform_access_overrides o
          where o.user_id = p_user_id
            and coalesce(o.bypass_subscriptions, false)
            and (o.expires_at is null or o.expires_at > now())
        )
      $function$;
    $create_override$;
  end if;

  if to_regprocedure('product.user_allowed_model_keys_v204(uuid)') is null then
    execute $create_function$
      create function product.user_allowed_model_keys_v204(p_user_id uuid)
      returns table(model_key text)
      language sql
      stable
      security definer
      set search_path = 'pg_catalog', 'product', 'scoring'
      as $function$
        select distinct m.model_key::text
        from scoring.models m
        where coalesce(m.active, true)
          and exists (
            select 1
            from product.platform_access_overrides o
            where o.user_id = p_user_id
              and coalesce(o.access_all_models, false)
              and (o.expires_at is null or o.expires_at > now())
          )

        union

        select distinct m.model_key::text
        from product.subscriptions s
        join product.packages p
          on p.package_id = s.package_id
         and coalesce(p.active, true)
        join product.package_models pm
          on pm.package_id = p.package_id
         and pm.enabled
         and pm.included
        join scoring.models m
          on m.model_id = pm.model_id
         and coalesce(m.active, true)
        where s.user_id = p_user_id
          and (
            (
              s.status = 'active'
              and (s.current_period_end is null or s.current_period_end > now())
            )
            or
            (
              s.status = 'trialing'
              and s.trial_ends_at is not null
              and s.trial_ends_at > now()
            )
          )
      $function$;
    $create_function$;
  end if;
end;
$bootstrap$;

-- This helper is not an authenticated client API. It is invoked by the
-- security-definer dashboard RPC and should not be callable as a data oracle.
revoke all on function product.has_platform_override(uuid)
  from public, anon, authenticated;
grant execute on function product.has_platform_override(uuid)
  to service_role;

revoke all on function product.user_allowed_model_keys_v204(uuid)
  from public, anon, authenticated;
grant execute on function product.user_allowed_model_keys_v204(uuid)
  to service_role;

commit;
