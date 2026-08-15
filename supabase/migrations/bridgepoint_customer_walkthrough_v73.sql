-- BridgePoint V73: optional, per-user guided product walkthrough.

alter table customer_workspace.profiles_v70
  add column if not exists walkthrough_status text not null default 'NOT_STARTED'
    check(walkthrough_status in('NOT_STARTED','STARTED','COMPLETED','DISMISSED')),
  add column if not exists walkthrough_started_at timestamptz,
  add column if not exists walkthrough_completed_at timestamptz,
  add column if not exists walkthrough_dismissed_at timestamptz;

create or replace function public.bridgepoint_walkthrough_state_v73()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','accounts','customer_workspace' as $$
declare uid uuid:=api.require_user(); profile customer_workspace.profiles_v70%rowtype;
begin
  if accounts.is_platform_admin() then
    return jsonb_build_object('complete',true,'should_offer',false,'status','OWNER_BYPASS');
  end if;
  select * into profile from customer_workspace.profiles_v70 where user_id=uid;
  return jsonb_build_object(
    'complete',true,
    'status',coalesce(profile.walkthrough_status,'NOT_STARTED'),
    'should_offer',profile.user_id is not null and profile.onboarding_complete
      and profile.walkthrough_status='NOT_STARTED'
  );
end $$;

create or replace function public.bridgepoint_set_walkthrough_v73(p_status text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); requested text:=upper(btrim(coalesce(p_status,'')));
begin
  if requested not in('STARTED','COMPLETED','DISMISSED') then raise exception 'Unsupported walkthrough status'; end if;
  update customer_workspace.profiles_v70 set
    walkthrough_status=requested,
    walkthrough_started_at=case when requested='STARTED' then coalesce(walkthrough_started_at,now()) else walkthrough_started_at end,
    walkthrough_completed_at=case when requested='COMPLETED' then now() else walkthrough_completed_at end,
    walkthrough_dismissed_at=case when requested='DISMISSED' then now() else walkthrough_dismissed_at end,
    updated_at=now()
  where user_id=uid;
  if not found then raise exception 'Complete onboarding before starting the walkthrough'; end if;
  return jsonb_build_object('complete',true,'status',requested);
end $$;

revoke all on function public.bridgepoint_walkthrough_state_v73() from public,anon;
revoke all on function public.bridgepoint_set_walkthrough_v73(text) from public,anon;
grant execute on function public.bridgepoint_walkthrough_state_v73() to authenticated,service_role;
grant execute on function public.bridgepoint_set_walkthrough_v73(text) to authenticated,service_role;

