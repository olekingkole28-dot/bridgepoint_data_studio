-- BridgePoint V80: five-seat company package, team roles, invitations, and
-- shared opportunity/note workflows. Claim details remain private by default.

insert into product.packages(
  package_key,package_name,description,package_type,monthly_price,yearly_price,
  trial_days,active,featured,display_order,configuration
) values (
  'company','BridgePoint Company',
  'A shared All Intelligence workspace for roofing, contracting, building, restoration, and property teams. Includes five seats, manager controls, shared opportunities, notes, routes, and follow-up visibility.',
  'standard',699,6990,7,true,true,90,
  jsonb_build_object(
    'audience','company','included_seats',5,'additional_seat_monthly_price',79,
    'shared_workspace',true,'manager_controls',true,'all_models',true,
    'includes',jsonb_build_array(
      'five team seats','All Intelligence models','shared opportunities and notes',
      'shared field routes and visits','manager and member roles','team activity visibility'
    ),'version',80
  )
)
on conflict(package_key) do update set
  package_name=excluded.package_name,description=excluded.description,
  package_type=excluded.package_type,monthly_price=excluded.monthly_price,
  yearly_price=excluded.yearly_price,trial_days=excluded.trial_days,
  active=true,featured=true,display_order=excluded.display_order,
  configuration=product.packages.configuration||excluded.configuration,
  updated_at=now();

insert into product.package_models(package_id,model_id,enabled,included)
select p.package_id,m.model_id,true,true
from product.packages p cross join scoring.models m
where p.package_key='company' and m.active
on conflict(package_id,model_id) do update set enabled=true,included=true;

insert into product.stripe_catalog_v64(
  package_key,stripe_product_id,stripe_monthly_price_id,
  stripe_annual_price_id,environment,active
) values (
  'company','prod_V4lng0PKoYoCD7','price_1U4cGLHzFzwDC13zrGnncYHs',
  'price_1U4cGPHzFzwDC13zc6tBr0qD','sandbox',true
)
on conflict(package_key) do update set
  stripe_product_id=excluded.stripe_product_id,
  stripe_monthly_price_id=excluded.stripe_monthly_price_id,
  stripe_annual_price_id=excluded.stripe_annual_price_id,
  environment=excluded.environment,active=true,updated_at=now();

create table if not exists product.organization_members_v80(
  organization_id uuid not null references core.organizations(organization_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_role text not null default 'MEMBER'
    check(member_role in('OWNER','CO_OWNER','MANAGER','MEMBER','VIEWER')),
  active boolean not null default true,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(organization_id,user_id)
);
create unique index if not exists organization_members_v80_one_active_team_idx
  on product.organization_members_v80(user_id) where active;

create table if not exists product.organization_invitations_v80(
  invitation_id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references core.organizations(organization_id) on delete cascade,
  invited_email text not null,
  member_role text not null default 'MEMBER'
    check(member_role in('CO_OWNER','MANAGER','MEMBER','VIEWER')),
  invited_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'PENDING'
    check(status in('PENDING','ACCEPTED','REVOKED','EXPIRED')),
  expires_at timestamptz not null default now()+interval '14 days',
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists organization_invitations_v80_pending_email_idx
  on product.organization_invitations_v80(organization_id,lower(invited_email))
  where status='PENDING';

create table if not exists product.organization_seat_entitlements_v80(
  organization_id uuid primary key references core.organizations(organization_id) on delete cascade,
  package_key text not null references product.packages(package_key),
  included_seats integer not null default 5 check(included_seats>=1),
  additional_seats integer not null default 0 check(additional_seats>=0),
  additional_seat_monthly_price numeric(10,2) not null default 79 check(additional_seat_monthly_price>=0),
  status text not null default 'TRIALING'
    check(status in('TRIALING','ACTIVE','PAST_DUE','CANCELLED','EXPIRED')),
  trial_ends_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table product.organization_members_v80 enable row level security;
alter table product.organization_invitations_v80 enable row level security;
alter table product.organization_seat_entitlements_v80 enable row level security;
revoke all on product.organization_members_v80 from public,anon,authenticated;
revoke all on product.organization_invitations_v80 from public,anon,authenticated;
revoke all on product.organization_seat_entitlements_v80 from public,anon,authenticated;

alter table customer_workspace.saved_opportunities_v70
  add column if not exists organization_id uuid references core.organizations(organization_id) on delete set null;
alter table customer_workspace.notes_v70
  add column if not exists organization_id uuid references core.organizations(organization_id) on delete set null;
create unique index if not exists saved_opportunities_v80_team_opportunity_idx
  on customer_workspace.saved_opportunities_v70(organization_id,opportunity_id)
  where organization_id is not null;
create index if not exists notes_v80_team_updated_idx
  on customer_workspace.notes_v70(organization_id,updated_at desc)
  where organization_id is not null;

-- Forward declaration used by the creation RPC; replaced below by the full
-- authenticated team-state implementation in the same migration.
create or replace function public.bridgepoint_team_workspace_v80()
returns jsonb language sql stable security definer
set search_path='pg_catalog' as $$
  select jsonb_build_object('complete',true,'has_company_workspace',false)
$$;

create or replace function product.accept_pending_company_invitation_v80()
returns trigger language plpgsql security definer
set search_path='pg_catalog','public','product','core','auth' as $$
declare inv product.organization_invitations_v80%rowtype;
begin
  if new.email is null then return new; end if;
  select * into inv from product.organization_invitations_v80
  where lower(invited_email)=lower(new.email) and status='PENDING' and expires_at>now()
  order by created_at limit 1;
  if not found then return new; end if;
  insert into product.organization_members_v80(organization_id,user_id,member_role)
  values(inv.organization_id,new.id,inv.member_role)
  on conflict(organization_id,user_id) do update set
    member_role=excluded.member_role,active=true,updated_at=now();
  insert into product.user_profiles(user_id,organization_id,display_name,onboarding_completed)
  values(new.id,inv.organization_id,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),false)
  on conflict(user_id) do update set organization_id=excluded.organization_id,updated_at=now();
  update product.organization_invitations_v80 set
    status='ACCEPTED',accepted_by=new.id,accepted_at=now(),updated_at=now()
  where invitation_id=inv.invitation_id;
  return new;
end $$;

drop trigger if exists bridgepoint_accept_company_invitation_v80 on auth.users;
create trigger bridgepoint_accept_company_invitation_v80
after insert or update of email on auth.users
for each row execute function product.accept_pending_company_invitation_v80();
revoke execute on function product.accept_pending_company_invitation_v80() from public,anon,authenticated;

create or replace function public.bridgepoint_create_company_workspace_v80(p_organization_name text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product','core' as $$
declare uid uuid:=api.require_user(); org uuid; v_package_id uuid; name text:=btrim(coalesce(p_organization_name,''));
begin
  if length(name)<2 or length(name)>120 then raise exception 'Company name must be 2 to 120 characters'; end if;
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  if org is not null then return public.bridgepoint_team_workspace_v80(); end if;

  insert into core.organizations(organization_name,organization_type,active,metadata)
  values(name,'CUSTOMER_COMPANY',true,jsonb_build_object('bridgepoint_customer_workspace',true,'created_by',uid,'version',80))
  returning organization_id into org;
  insert into product.organization_members_v80(organization_id,user_id,member_role)
  values(org,uid,'OWNER');
  insert into product.user_profiles(user_id,organization_id,company_name,onboarding_completed)
  values(uid,org,name,true)
  on conflict(user_id) do update set organization_id=excluded.organization_id,
    company_name=excluded.company_name,updated_at=now();
  insert into product.organization_seat_entitlements_v80(
    organization_id,package_key,included_seats,additional_seats,
    additional_seat_monthly_price,status,trial_ends_at
  ) values(org,'company',5,0,79,'TRIALING',now()+interval '7 days');
  select p.package_id into v_package_id from product.packages p where p.package_key='company';
  insert into product.subscriptions(
    user_id,organization_id,package_id,status,trial_started_at,trial_ends_at,metadata
  ) select uid,org,v_package_id,'trialing',now(),now()+interval '7 days',
    jsonb_build_object('company_workspace',true,'included_seats',5,'version',80)
  where v_package_id is not null and not exists(
    select 1 from product.subscriptions s
    where s.organization_id=org and s.package_id=v_package_id and s.status in('trialing','active')
  );
  update customer_workspace.saved_opportunities_v70 set organization_id=org
    where user_id=uid and organization_id is null;
  update customer_workspace.notes_v70 set organization_id=org
    where user_id=uid and organization_id is null;
  return public.bridgepoint_team_workspace_v80();
end $$;

create or replace function public.bridgepoint_team_workspace_v80()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','product','core','auth' as $$
declare uid uuid:=api.require_user(); org uuid; role text; payload jsonb; members jsonb; invites jsonb;
  included integer:=0; additional integer:=0; active_count integer:=0;
begin
  select m.organization_id,m.member_role into org,role
  from product.organization_members_v80 m where m.user_id=uid and m.active limit 1;
  if org is null then
    return jsonb_build_object('complete',true,'has_company_workspace',false,
      'package_key','company','included_seats',5,'monthly_price',699,'annual_price',6990,
      'message','Create a company workspace to share opportunities, notes, routes, and follow-ups with your team.');
  end if;
  select e.included_seats,e.additional_seats into included,additional
  from product.organization_seat_entitlements_v80 e where e.organization_id=org;
  select count(*) into active_count from product.organization_members_v80 where organization_id=org and active;
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id',m.user_id,'display_name',coalesce(p.display_name,u.raw_user_meta_data->>'display_name',split_part(u.email,'@',1)),
    'email',u.email,'member_role',m.member_role,'active',m.active,'joined_at',m.joined_at
  ) order by case m.member_role when 'OWNER' then 0 when 'CO_OWNER' then 1 when 'MANAGER' then 2 else 3 end,m.joined_at),'[]'::jsonb)
  into members
  from product.organization_members_v80 m join auth.users u on u.id=m.user_id
  left join product.user_profiles p on p.user_id=m.user_id
  where m.organization_id=org and m.active;
  if role in('OWNER','CO_OWNER','MANAGER') then
    select coalesce(jsonb_agg(jsonb_build_object(
      'invitation_id',i.invitation_id,'invited_email',i.invited_email,
      'member_role',i.member_role,'status',i.status,'expires_at',i.expires_at
    ) order by i.created_at desc),'[]'::jsonb) into invites
    from product.organization_invitations_v80 i
    where i.organization_id=org and i.status='PENDING' and i.expires_at>now();
  else invites:='[]'::jsonb; end if;
  select jsonb_build_object(
    'complete',true,'has_company_workspace',true,'organization_id',o.organization_id,
    'organization_name',o.organization_name,'current_role',role,
    'can_manage',role in('OWNER','CO_OWNER','MANAGER'),
    'can_administer',role in('OWNER','CO_OWNER'),
    'can_view_team_location',role in('OWNER','CO_OWNER','MANAGER'),
    'included_seats',coalesce(included,5),
    'additional_seats',coalesce(additional,0),'seat_limit',coalesce(included,5)+coalesce(additional,0),
    'active_members',active_count,'available_seats',greatest(coalesce(included,5)+coalesce(additional,0)-active_count,0),
    'members',members,'pending_invitations',invites
  ) into payload from core.organizations o where o.organization_id=org;
  return payload;
end $$;

create or replace function public.bridgepoint_invite_team_member_v80(p_email text,p_member_role text default 'MEMBER')
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product','auth' as $$
declare uid uuid:=api.require_user(); org uuid; caller_role text; target_role text:=upper(btrim(coalesce(p_member_role,'MEMBER')));
  email text:=lower(btrim(coalesce(p_email,''))); target_user uuid; seats integer; used integer; inv uuid;
begin
  if email !~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' then
    raise exception 'Enter a valid email address';
  end if;
  if target_role not in('CO_OWNER','MANAGER','MEMBER','VIEWER') then raise exception 'Unsupported team role'; end if;
  select m.organization_id,m.member_role into org,caller_role
    from product.organization_members_v80 m where m.user_id=uid and m.active limit 1;
  if org is null or caller_role not in('OWNER','CO_OWNER','MANAGER') then raise exception 'Team manager access required'; end if;
  if target_role='CO_OWNER' and caller_role<>'OWNER' then raise exception 'Only the primary owner can invite a co-owner'; end if;
  select coalesce(included_seats,5)+coalesce(additional_seats,0) into seats
    from product.organization_seat_entitlements_v80 where organization_id=org;
  select count(*) into used from product.organization_members_v80 where organization_id=org and active;
  used:=used+(select count(*) from product.organization_invitations_v80 where organization_id=org and status='PENDING' and expires_at>now());
  if used>=coalesce(seats,5) then raise exception 'No team seats are available'; end if;
  select id into target_user from auth.users where lower(auth.users.email)=email limit 1;
  if target_user is not null then
    if exists(select 1 from product.organization_members_v80 where user_id=target_user and active and organization_id<>org) then
      raise exception 'This person already belongs to another company workspace';
    end if;
    insert into product.organization_members_v80(organization_id,user_id,member_role)
    values(org,target_user,target_role)
    on conflict(organization_id,user_id) do update set member_role=excluded.member_role,active=true,updated_at=now();
    update product.user_profiles set organization_id=org,updated_at=now() where user_id=target_user;
    return jsonb_build_object('complete',true,'status','MEMBER_ADDED','email',email,'email_required',false);
  end if;
  insert into product.organization_invitations_v80(organization_id,invited_email,member_role,invited_by)
  values(org,email,target_role,uid)
  on conflict(organization_id,(lower(invited_email))) where status='PENDING'
  do update set member_role=excluded.member_role,invited_by=excluded.invited_by,
    expires_at=now()+interval '14 days',updated_at=now()
  returning invitation_id into inv;
  return jsonb_build_object('complete',true,'status','INVITATION_PENDING','invitation_id',inv,
    'organization_id',org,'email',email,'member_role',target_role,'email_required',true);
end $$;

create or replace function public.bridgepoint_update_team_member_v80(
  p_user_id uuid,p_member_role text,p_active boolean default true
) returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product' as $$
declare uid uuid:=api.require_user(); org uuid; caller_role text; target_role text:=upper(btrim(coalesce(p_member_role,'MEMBER'))); old_role text;
begin
  select organization_id,member_role into org,caller_role from product.organization_members_v80 where user_id=uid and active limit 1;
  if org is null or caller_role not in('OWNER','CO_OWNER','MANAGER') then raise exception 'Team manager access required'; end if;
  if target_role not in('OWNER','CO_OWNER','MANAGER','MEMBER','VIEWER') then raise exception 'Unsupported team role'; end if;
  select member_role into old_role from product.organization_members_v80 where organization_id=org and user_id=p_user_id;
  if old_role is null then raise exception 'Team member not found'; end if;
  if old_role='OWNER' and (p_active=false or target_role<>'OWNER') and
    (select count(*) from product.organization_members_v80 where organization_id=org and active and member_role='OWNER')<=1
  then raise exception 'A company workspace must keep at least one owner'; end if;
  if caller_role='MANAGER' and old_role in('OWNER','CO_OWNER') then raise exception 'Managers cannot change an owner'; end if;
  if caller_role='CO_OWNER' and (old_role='OWNER' or target_role='OWNER') then raise exception 'A co-owner cannot change the primary owner'; end if;
  if target_role='CO_OWNER' and caller_role<>'OWNER' then raise exception 'Only the primary owner can appoint a co-owner'; end if;
  update product.organization_members_v80 set member_role=target_role,active=coalesce(p_active,true),updated_at=now()
  where organization_id=org and user_id=p_user_id;
  return jsonb_build_object('complete',true,'status','UPDATED');
end $$;

create or replace function public.bridgepoint_save_opportunity_v70(
  p_opportunity_id uuid,p_property_id uuid,p_title text,p_address text,p_score numeric,
  p_reason text,p_recommended_action text,p_vertical_key text,p_next_action_at timestamptz default null
) returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace','product' as $$
declare uid uuid:=api.require_user(); org uuid; sid uuid;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  if org is null then
    insert into customer_workspace.saved_opportunities_v70(
      user_id,organization_id,opportunity_id,property_id,title,address,score,reason,recommended_action,vertical_key,next_action_at)
    values(uid,null,p_opportunity_id,p_property_id,btrim(p_title),nullif(btrim(p_address),''),
      p_score,nullif(btrim(p_reason),''),nullif(btrim(p_recommended_action),''),nullif(btrim(p_vertical_key),''),p_next_action_at)
    on conflict(user_id,opportunity_id) do update set score=excluded.score,reason=excluded.reason,
      recommended_action=excluded.recommended_action,next_action_at=coalesce(excluded.next_action_at,customer_workspace.saved_opportunities_v70.next_action_at),
      updated_at=now() returning saved_opportunity_id into sid;
  else
    insert into customer_workspace.saved_opportunities_v70(
      user_id,organization_id,opportunity_id,property_id,title,address,score,reason,recommended_action,vertical_key,next_action_at)
    values(uid,org,p_opportunity_id,p_property_id,btrim(p_title),nullif(btrim(p_address),''),
      p_score,nullif(btrim(p_reason),''),nullif(btrim(p_recommended_action),''),nullif(btrim(p_vertical_key),''),p_next_action_at)
    on conflict(organization_id,opportunity_id) where organization_id is not null
    do update set score=excluded.score,reason=excluded.reason,recommended_action=excluded.recommended_action,
      next_action_at=coalesce(excluded.next_action_at,customer_workspace.saved_opportunities_v70.next_action_at),
      updated_at=now() returning saved_opportunity_id into sid;
  end if;
  return jsonb_build_object('complete',true,'saved_opportunity_id',sid,'status','saved','shared_with_team',org is not null);
end $$;

create or replace function public.bridgepoint_save_customer_note_v70(
  p_property_id uuid,p_opportunity_id uuid,p_preset_key text,p_note_text text,p_follow_up_at timestamptz default null
) returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace','product' as $$
declare uid uuid:=api.require_user(); org uuid; nid uuid; preset text:=upper(btrim(coalesce(p_preset_key,'GENERAL')));
begin
  if preset not in('CALL','VISIT','QUOTE','FOLLOW_UP','NOT_INTERESTED','WON','LOST','GENERAL') then raise exception 'Unsupported note preset'; end if;
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  insert into customer_workspace.notes_v70(user_id,organization_id,property_id,opportunity_id,preset_key,note_text,follow_up_at)
  values(uid,org,p_property_id,p_opportunity_id,preset,btrim(p_note_text),p_follow_up_at) returning note_id into nid;
  return jsonb_build_object('complete',true,'note_id',nid,'status','saved','shared_with_team',org is not null);
end $$;

create or replace function public.bridgepoint_customer_notes_v70(p_property_id uuid default null,p_limit integer default 100)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace','product' as $$
declare uid uuid:=api.require_user(); org uuid; rows jsonb;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  select coalesce(jsonb_agg(to_jsonb(n) order by n.updated_at desc),'[]'::jsonb) into rows
  from (select note_id,user_id,property_id,opportunity_id,preset_key,note_text,follow_up_at,status,created_at,updated_at
    from customer_workspace.notes_v70
    where ((org is null and user_id=uid) or (org is not null and organization_id=org))
      and (p_property_id is null or property_id=p_property_id)
    order by updated_at desc limit least(greatest(coalesce(p_limit,100),1),500)) n;
  return jsonb_build_object('complete',true,'notes',rows,'shared_workspace',org is not null);
end $$;

create or replace function public.bridgepoint_update_lead_stage_v70(
  p_saved_opportunity_id uuid,p_lead_stage text,p_next_action_at timestamptz default null
) returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace','product' as $$
declare uid uuid:=api.require_user(); org uuid; stage text:=upper(btrim(coalesce(p_lead_stage,'')));
begin
  if stage not in('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM',
    'INSPECTION_SCHEDULED','INSPECTED','CLAIM_FILED','ADJUSTER_ASSIGNED','ESTIMATE_IN_PROGRESS',
    'ESTIMATE_SUBMITTED','NEGOTIATION','APPROVED','WORK_SCHEDULED','IN_PROGRESS','COMPLETED',
    'PAID','CLOSED_LOST','WON','LOST') then raise exception 'Unsupported lead stage'; end if;
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  update customer_workspace.saved_opportunities_v70 set lead_stage=stage,next_action_at=p_next_action_at,updated_at=now()
  where saved_opportunity_id=p_saved_opportunity_id
    and ((org is null and user_id=uid) or (org is not null and organization_id=org));
  if not found then raise exception 'Saved opportunity not found'; end if;
  return jsonb_build_object('complete',true,'status','updated','lead_stage',stage,'shared_with_team',org is not null);
end $$;

create or replace function public.bridgepoint_my_work_v78(p_limit integer default 200)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace','product' as $$
declare uid uuid:=api.require_user(); org uuid; saved jsonb; notes jsonb; claims jsonb; tasks jsonb;
  lim integer:=least(greatest(coalesce(p_limit,200),1),500);
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  select coalesce(jsonb_agg(to_jsonb(s) order by s.next_action_at nulls last,s.updated_at desc),'[]'::jsonb)
  into saved from (select saved_opportunity_id,user_id,opportunity_id,property_id,title,address,score,reason,
    recommended_action,vertical_key,lead_stage,next_action_at,saved_at,updated_at
    from customer_workspace.saved_opportunities_v70
    where ((org is null and user_id=uid) or (org is not null and organization_id=org))
    order by next_action_at nulls last,updated_at desc limit lim) s;
  select coalesce(jsonb_agg(to_jsonb(n) order by n.follow_up_at nulls last,n.updated_at desc),'[]'::jsonb)
  into notes from (select note_id,user_id,property_id,opportunity_id,preset_key,note_text,follow_up_at,status,created_at,updated_at
    from customer_workspace.notes_v70 where status='OPEN'
      and ((org is null and user_id=uid) or (org is not null and organization_id=org))
    order by follow_up_at nulls last,updated_at desc limit lim) n;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.next_action_at nulls last,c.updated_at desc),'[]'::jsonb)
  into claims from (select c.claim_id,c.saved_opportunity_id,c.property_id,c.opportunity_id,c.claim_number,
    c.carrier_name,c.date_of_loss,c.damage_type,c.claim_stage,c.adjuster_name,c.inspection_at,
    c.estimate_amount,c.approved_amount,c.deductible_amount,c.next_action_at,c.notes_summary,c.created_at,c.updated_at,
    s.address,s.title opportunity_title
    from customer_workspace.claims_v78 c join customer_workspace.saved_opportunities_v70 s on s.saved_opportunity_id=c.saved_opportunity_id
    where c.user_id=uid order by c.next_action_at nulls last,c.updated_at desc limit lim) c;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.due_at nulls last,t.created_at desc),'[]'::jsonb)
  into tasks from (select claim_task_id,claim_id,task_type,title,due_at,status,created_at,updated_at
    from customer_workspace.claim_tasks_v78 where user_id=uid and status='OPEN'
    order by due_at nulls last,created_at desc limit lim) t;
  return jsonb_build_object('complete',true,'version',80,'generated_at',now(),
    'saved_opportunities',saved,'open_notes',notes,'claims',claims,'claim_tasks',tasks,
    'shared_workspace',org is not null,
    'lead_stages',jsonb_build_array('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION_SCHEDULED',
      'INSPECTED','CLAIM_FILED','ADJUSTER_ASSIGNED','ESTIMATE_IN_PROGRESS','ESTIMATE_SUBMITTED',
      'NEGOTIATION','APPROVED','WORK_SCHEDULED','IN_PROGRESS','COMPLETED','PAID','CLOSED_LOST'),
    'claims_data_policy','Public evidence is automatic. Claim details remain private unless the customer explicitly authorizes sharing.');
end $$;

revoke execute on function public.bridgepoint_create_company_workspace_v80(text) from public,anon;
revoke execute on function public.bridgepoint_team_workspace_v80() from public,anon;
revoke execute on function public.bridgepoint_invite_team_member_v80(text,text) from public,anon;
revoke execute on function public.bridgepoint_update_team_member_v80(uuid,text,boolean) from public,anon;
grant execute on function public.bridgepoint_create_company_workspace_v80(text) to authenticated,service_role;
grant execute on function public.bridgepoint_team_workspace_v80() to authenticated,service_role;
grant execute on function public.bridgepoint_invite_team_member_v80(text,text) to authenticated,service_role;
grant execute on function public.bridgepoint_update_team_member_v80(uuid,text,boolean) to authenticated,service_role;

revoke execute on function public.bridgepoint_save_opportunity_v70(uuid,uuid,text,text,numeric,text,text,text,timestamptz) from public,anon;
revoke execute on function public.bridgepoint_save_customer_note_v70(uuid,uuid,text,text,timestamptz) from public,anon;
revoke execute on function public.bridgepoint_customer_notes_v70(uuid,integer) from public,anon;
revoke execute on function public.bridgepoint_update_lead_stage_v70(uuid,text,timestamptz) from public,anon;
revoke execute on function public.bridgepoint_my_work_v78(integer) from public,anon;
grant execute on function public.bridgepoint_save_opportunity_v70(uuid,uuid,text,text,numeric,text,text,text,timestamptz) to authenticated,service_role;
grant execute on function public.bridgepoint_save_customer_note_v70(uuid,uuid,text,text,timestamptz) to authenticated,service_role;
grant execute on function public.bridgepoint_customer_notes_v70(uuid,integer) to authenticated,service_role;
grant execute on function public.bridgepoint_update_lead_stage_v70(uuid,text,timestamptz) to authenticated,service_role;
grant execute on function public.bridgepoint_my_work_v78(integer) to authenticated,service_role;

comment on table product.organization_members_v80 is 'Authenticated company workspace roles. Direct access is denied; checked RPCs enforce seat and manager rules.';
comment on table product.organization_invitations_v80 is 'Pending team invitations accepted only by a matching authenticated email.';
