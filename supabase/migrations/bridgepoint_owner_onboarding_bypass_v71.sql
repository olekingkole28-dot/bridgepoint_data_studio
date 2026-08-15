-- BridgePoint V71: platform owners never enter customer package onboarding.

create or replace function public.bridgepoint_onboarding_state_v70()
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','api','accounts','customer_workspace'
as $$
declare
  uid uuid;
  p customer_workspace.profiles_v70%rowtype;
  is_owner boolean;
begin
  uid := api.require_user();
  is_owner := accounts.is_platform_admin();

  if is_owner then
    return jsonb_build_object(
      'complete', true,
      'onboarding_complete', true,
      'owner_bypass', true,
      'recommended_package_key', 'all',
      'profile', jsonb_build_object(
        'industry', 'BridgePoint Intelligence',
        'role_name', 'Platform owner',
        'primary_goal', 'Operate and grow BridgePoint',
        'territory', 'All available intelligence',
        'experience_level', 'Founder',
        'recommended_package_key', 'all',
        'onboarding_complete', true
      )
    );
  end if;

  select * into p
  from customer_workspace.profiles_v70
  where user_id=uid;

  return jsonb_build_object(
    'complete', true,
    'onboarding_complete', coalesce(p.onboarding_complete,false),
    'owner_bypass', false,
    'profile', case when p.user_id is null then null else to_jsonb(p)-'user_id' end
  );
end $$;

revoke all on function public.bridgepoint_onboarding_state_v70() from public,anon;
grant execute on function public.bridgepoint_onboarding_state_v70() to authenticated,service_role;

insert into customer_workspace.profiles_v70(
  user_id,industry,role_name,primary_goal,territory,experience_level,
  recommended_package_key,onboarding_complete
)
select
  u.id,'BridgePoint Intelligence','Platform owner','Operate and grow BridgePoint',
  'All available intelligence','Founder','all',true
from auth.users u
join bp_system.founder_allowlist_v63 f
  on f.email=lower(trim(u.email)) and f.active
on conflict(user_id) do update set
  industry=excluded.industry,
  role_name=excluded.role_name,
  primary_goal=excluded.primary_goal,
  territory=excluded.territory,
  experience_level=excluded.experience_level,
  recommended_package_key='all',
  onboarding_complete=true,
  updated_at=now();

