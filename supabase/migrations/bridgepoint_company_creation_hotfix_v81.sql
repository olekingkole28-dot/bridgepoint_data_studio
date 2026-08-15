create or replace function public.bridgepoint_create_company_workspace_v80(p_organization_name text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product','core','customer_workspace' as $$
declare uid uuid:=api.require_user(); org uuid; v_package_id uuid; name text:=btrim(coalesce(p_organization_name,''));
begin
  if length(name)<2 or length(name)>120 then raise exception 'Company name must be 2 to 120 characters'; end if;
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  if org is not null then return public.bridgepoint_team_workspace_v80(); end if;
  insert into core.organizations(organization_name,organization_type,active,metadata)
  values(name,'CUSTOMER_COMPANY',true,jsonb_build_object('bridgepoint_customer_workspace',true,'created_by',uid,'version',81))
  returning organization_id into org;
  insert into product.organization_members_v80(organization_id,user_id,member_role) values(org,uid,'OWNER');
  insert into product.user_profiles(user_id,organization_id,company_name,onboarding_completed)
  values(uid,org,name,true) on conflict(user_id) do update set organization_id=excluded.organization_id,
    company_name=excluded.company_name,updated_at=now();
  insert into product.organization_seat_entitlements_v80(
    organization_id,package_key,included_seats,additional_seats,additional_seat_monthly_price,status,trial_ends_at,location_tracking_enabled)
  values(org,'company',5,0,79,'TRIALING',now()+interval '7 days',true);
  insert into product.organization_preferences_v81(organization_id,field_note_enabled,updated_by) values(org,true,uid)
    on conflict(organization_id) do nothing;
  select p.package_id into v_package_id from product.packages p where p.package_key='company';
  insert into product.subscriptions(user_id,organization_id,package_id,status,trial_started_at,trial_ends_at,metadata)
  select uid,org,v_package_id,'trialing',now(),now()+interval '7 days',
    jsonb_build_object('company_workspace',true,'included_seats',5,'version',81,'owner_access_override',accounts.is_platform_admin())
  where v_package_id is not null and not exists(select 1 from product.subscriptions s
    where s.organization_id=org and s.package_id=v_package_id and s.status in('trialing','active'));
  update customer_workspace.saved_opportunities_v70 set organization_id=org where user_id=uid and organization_id is null;
  update customer_workspace.notes_v70 set organization_id=org where user_id=uid and organization_id is null;
  return public.bridgepoint_team_workspace_v80();
end $$;
revoke execute on function public.bridgepoint_create_company_workspace_v80(text) from public,anon;
grant execute on function public.bridgepoint_create_company_workspace_v80(text) to authenticated,service_role;
