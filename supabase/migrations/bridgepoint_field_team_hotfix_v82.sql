create or replace function public.bridgepoint_field_team_v81()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','product','customer_workspace','auth' as $$
declare uid uuid:=api.require_user(); org uuid; v_role text; eligible boolean:=false; team_rows jsonb:='[]'::jsonb; own_shift uuid;
begin
  select m.organization_id,m.member_role,
    coalesce(e.location_tracking_enabled,false) and e.status in('TRIALING','ACTIVE')
  into org,v_role,eligible from product.organization_members_v80 m
  left join product.organization_seat_entitlements_v80 e on e.organization_id=m.organization_id
  where m.user_id=uid and m.active limit 1;
  if org is null then return jsonb_build_object('complete',true,'eligible',false,'company_plan_required',true,'team',team_rows); end if;
  select field_shift_id into own_shift from customer_workspace.field_shifts_v81 where user_id=uid and status='ACTIVE' limit 1;
  if eligible then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.display_name),'[]'::jsonb) into team_rows from (
      select m.user_id,coalesce(p.display_name,u.raw_user_meta_data->>'display_name',split_part(u.email,'@',1)) display_name,
        m.member_role,s.field_shift_id,s.started_at,s.last_location_at,
        l.latitude,l.longitude,l.accuracy_m,l.heading_degrees,l.speed_mps,l.captured_at,
        case when l.captured_at>=now()-interval '90 seconds' then 'LIVE'
             when l.captured_at>=now()-interval '15 minutes' then 'RECENT' else 'STALE' end location_status
      from product.organization_members_v80 m
      join auth.users u on u.id=m.user_id
      left join product.user_profiles p on p.user_id=m.user_id
      left join customer_workspace.field_shifts_v81 s on s.user_id=m.user_id and s.organization_id=org and s.status='ACTIVE'
      left join lateral(
        select fl.latitude,fl.longitude,fl.accuracy_m,fl.heading_degrees,fl.speed_mps,fl.captured_at
        from customer_workspace.field_locations_v81 fl where fl.field_shift_id=s.field_shift_id order by fl.captured_at desc limit 1
      ) l on true
      where m.organization_id=org and m.active and s.field_shift_id is not null
        and (v_role in('OWNER','CO_OWNER','MANAGER') or m.user_id=uid)
        and (l.captured_at is null or l.captured_at>=now()-interval '15 minutes')
    ) x;
  end if;
  return jsonb_build_object('complete',true,'eligible',eligible,'company_plan_required',not eligible,
    'current_role',v_role,'can_view_team',v_role in('OWNER','CO_OWNER','MANAGER'),
    'own_active_shift_id',own_shift,'retention_days',7,'team',team_rows,
    'privacy','Only active field shifts are visible. Team locations disappear from the live view after 15 minutes and are deleted after seven days.');
end $$;
revoke execute on function public.bridgepoint_field_team_v81() from public,anon;
grant execute on function public.bridgepoint_field_team_v81() to authenticated,service_role;
