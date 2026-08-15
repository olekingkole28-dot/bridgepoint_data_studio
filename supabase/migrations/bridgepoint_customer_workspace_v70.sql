-- BridgePoint V70: guided onboarding, package recommendation, private notes and feedback.

create schema if not exists customer_workspace;

create table if not exists customer_workspace.profiles_v70 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  industry text not null,
  role_name text not null,
  primary_goal text not null,
  territory text not null,
  experience_level text not null,
  recommended_package_key text not null,
  onboarding_complete boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists customer_workspace.notes_v70 (
  note_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid references core.properties(property_id) on delete cascade,
  opportunity_id uuid,
  preset_key text not null check (preset_key in
    ('CALL','VISIT','QUOTE','FOLLOW_UP','NOT_INTERESTED','WON','LOST','GENERAL')),
  note_text text not null check (length(note_text) between 1 and 4000),
  follow_up_at timestamptz,
  status text not null default 'OPEN' check (status in ('OPEN','DONE','ARCHIVED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists notes_v70_user_updated_idx on customer_workspace.notes_v70(user_id,updated_at desc);
create index if not exists notes_v70_property_idx on customer_workspace.notes_v70(user_id,property_id,updated_at desc);

create table if not exists customer_workspace.feedback_v70 (
  feedback_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('SUGGESTION','BUG','DATA_REQUEST','QUESTION','COMPLIMENT')),
  page_key text,
  message text not null check (length(message) between 3 and 4000),
  status text not null default 'NEW' check (status in ('NEW','REVIEWED','PLANNED','RESOLVED','CLOSED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists feedback_v70_user_created_idx on customer_workspace.feedback_v70(user_id,created_at desc);

create table if not exists customer_workspace.saved_opportunities_v70 (
  saved_opportunity_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  opportunity_id uuid not null,
  property_id uuid not null references core.properties(property_id) on delete cascade,
  title text not null,
  address text,
  score numeric,
  reason text,
  recommended_action text,
  vertical_key text,
  lead_stage text not null default 'NEW' check (lead_stage in
    ('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM','WON','LOST')),
  next_action_at timestamptz,
  saved_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,opportunity_id)
);
create index if not exists saved_opportunities_v70_calendar_idx
  on customer_workspace.saved_opportunities_v70(user_id,next_action_at,lead_stage);

alter table customer_workspace.profiles_v70 enable row level security;
alter table customer_workspace.notes_v70 enable row level security;
alter table customer_workspace.feedback_v70 enable row level security;
alter table customer_workspace.saved_opportunities_v70 enable row level security;
revoke all on all tables in schema customer_workspace from anon,authenticated;

create or replace function public.bridgepoint_onboarding_state_v70()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; p customer_workspace.profiles_v70%rowtype;
begin
  uid:=api.require_user();
  select * into p from customer_workspace.profiles_v70 where user_id=uid;
  return jsonb_build_object('complete',true,'onboarding_complete',coalesce(p.onboarding_complete,false),
    'profile',case when p.user_id is null then null else to_jsonb(p)-'user_id' end);
end $$;

create or replace function public.bridgepoint_complete_onboarding_v70(
  p_industry text,p_role_name text,p_primary_goal text,p_territory text,p_experience_level text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; recommended text; industry text:=lower(btrim(coalesce(p_industry,'')));
begin
  uid:=api.require_user();
  if btrim(coalesce(p_role_name,''))='' or btrim(coalesce(p_primary_goal,''))=''
     or btrim(coalesce(p_territory,''))='' or btrim(coalesce(p_experience_level,''))='' or industry='' then
    raise exception 'All onboarding answers are required';
  end if;
  recommended:=case
    when industry in ('roofing','exterior contractor') then 'roofing_opportunity'
    when industry in ('commercial real estate','commercial services') then 'bridgepoint_commercial'
    when industry in ('property investing','real estate investing') then 'property_investor'
    when industry in ('solar','energy') then 'solar_opportunity'
    when industry in ('development','construction development') then 'development_opportunity'
    when industry in ('home services','restoration','public adjusting') then 'bridgepoint_home'
    else 'all' end;
  insert into customer_workspace.profiles_v70(user_id,industry,role_name,primary_goal,territory,experience_level,recommended_package_key)
  values(uid,btrim(p_industry),btrim(p_role_name),btrim(p_primary_goal),btrim(p_territory),btrim(p_experience_level),recommended)
  on conflict(user_id) do update set industry=excluded.industry,role_name=excluded.role_name,
    primary_goal=excluded.primary_goal,territory=excluded.territory,
    experience_level=excluded.experience_level,recommended_package_key=excluded.recommended_package_key,
    onboarding_complete=true,updated_at=now();
  return jsonb_build_object('complete',true,'recommended_package_key',recommended,
    'reason',case recommended
      when 'roofing_opportunity' then 'Roofing Opportunity emphasizes storm, roof-age and exterior-condition evidence.'
      when 'bridgepoint_commercial' then 'BridgePoint Commercial emphasizes business, development and commercial-property evidence.'
      when 'property_investor' then 'Property Investor emphasizes transitions, distress and redevelopment evidence.'
      when 'solar_opportunity' then 'Solar Opportunity emphasizes roof, energy and solar-program evidence.'
      when 'development_opportunity' then 'Development Opportunity emphasizes construction, land-use and change evidence.'
      when 'bridgepoint_home' then 'BridgePoint Home combines the strongest residential service opportunities.'
      else 'All Intelligence is the best starting point because your answers span multiple opportunity types.' end);
end $$;

create or replace function public.bridgepoint_save_customer_note_v70(
  p_property_id uuid,p_opportunity_id uuid,p_preset_key text,p_note_text text,p_follow_up_at timestamptz default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; nid uuid; preset text:=upper(btrim(coalesce(p_preset_key,'GENERAL')));
begin
  uid:=api.require_user();
  if preset not in ('CALL','VISIT','QUOTE','FOLLOW_UP','NOT_INTERESTED','WON','LOST','GENERAL') then raise exception 'Unsupported note preset'; end if;
  insert into customer_workspace.notes_v70(user_id,property_id,opportunity_id,preset_key,note_text,follow_up_at)
  values(uid,p_property_id,p_opportunity_id,preset,btrim(p_note_text),p_follow_up_at) returning note_id into nid;
  return jsonb_build_object('complete',true,'note_id',nid,'status','saved');
end $$;

create or replace function public.bridgepoint_customer_notes_v70(p_property_id uuid default null,p_limit integer default 100)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; rows jsonb;
begin
  uid:=api.require_user();
  select coalesce(jsonb_agg(to_jsonb(n) order by n.updated_at desc),'[]'::jsonb) into rows
  from (select note_id,property_id,opportunity_id,preset_key,note_text,follow_up_at,status,created_at,updated_at
        from customer_workspace.notes_v70 where user_id=uid and (p_property_id is null or property_id=p_property_id)
        order by updated_at desc limit least(greatest(coalesce(p_limit,100),1),500)) n;
  return jsonb_build_object('complete',true,'notes',rows);
end $$;

create or replace function public.bridgepoint_submit_feedback_v70(p_category text,p_page_key text,p_message text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; fid uuid; category text:=upper(btrim(coalesce(p_category,'SUGGESTION')));
begin
  uid:=api.require_user();
  if category not in ('SUGGESTION','BUG','DATA_REQUEST','QUESTION','COMPLIMENT') then raise exception 'Unsupported feedback category'; end if;
  insert into customer_workspace.feedback_v70(user_id,category,page_key,message)
  values(uid,category,nullif(btrim(p_page_key),''),btrim(p_message)) returning feedback_id into fid;
  return jsonb_build_object('complete',true,'feedback_id',fid,'status','received');
end $$;

create or replace function public.bridgepoint_save_opportunity_v70(
  p_opportunity_id uuid,p_property_id uuid,p_title text,p_address text,p_score numeric,
  p_reason text,p_recommended_action text,p_vertical_key text,p_next_action_at timestamptz default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; sid uuid;
begin
  uid:=api.require_user();
  insert into customer_workspace.saved_opportunities_v70(
    user_id,opportunity_id,property_id,title,address,score,reason,recommended_action,vertical_key,next_action_at)
  values(uid,p_opportunity_id,p_property_id,btrim(p_title),nullif(btrim(p_address),''),p_score,
    nullif(btrim(p_reason),''),nullif(btrim(p_recommended_action),''),nullif(btrim(p_vertical_key),''),p_next_action_at)
  on conflict(user_id,opportunity_id) do update set score=excluded.score,reason=excluded.reason,
    recommended_action=excluded.recommended_action,next_action_at=coalesce(excluded.next_action_at,customer_workspace.saved_opportunities_v70.next_action_at),
    updated_at=now() returning saved_opportunity_id into sid;
  return jsonb_build_object('complete',true,'saved_opportunity_id',sid,'status','saved');
end $$;

create or replace function public.bridgepoint_update_lead_stage_v70(
  p_saved_opportunity_id uuid,p_lead_stage text,p_next_action_at timestamptz default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; stage text:=upper(btrim(coalesce(p_lead_stage,'')));
begin
  uid:=api.require_user();
  if stage not in ('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM','WON','LOST') then raise exception 'Unsupported lead stage'; end if;
  update customer_workspace.saved_opportunities_v70 set lead_stage=stage,
    next_action_at=p_next_action_at,updated_at=now()
  where saved_opportunity_id=p_saved_opportunity_id and user_id=uid;
  if not found then raise exception 'Saved opportunity not found'; end if;
  return jsonb_build_object('complete',true,'status','updated','lead_stage',stage);
end $$;

create or replace function public.bridgepoint_my_work_v70(p_limit integer default 200)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; saved jsonb; notes jsonb;
begin
  uid:=api.require_user();
  select coalesce(jsonb_agg(to_jsonb(s) order by s.next_action_at nulls last,s.updated_at desc),'[]'::jsonb) into saved
  from (select saved_opportunity_id,opportunity_id,property_id,title,address,score,reason,recommended_action,
        vertical_key,lead_stage,next_action_at,saved_at,updated_at
        from customer_workspace.saved_opportunities_v70 where user_id=uid
        order by next_action_at nulls last,updated_at desc limit least(greatest(coalesce(p_limit,200),1),500)) s;
  select coalesce(jsonb_agg(to_jsonb(n) order by n.follow_up_at nulls last,n.updated_at desc),'[]'::jsonb) into notes
  from (select note_id,property_id,opportunity_id,preset_key,note_text,follow_up_at,status,created_at,updated_at
        from customer_workspace.notes_v70 where user_id=uid and status='OPEN'
        order by follow_up_at nulls last,updated_at desc limit least(greatest(coalesce(p_limit,200),1),500)) n;
  return jsonb_build_object('complete',true,'generated_at',now(),'saved_opportunities',saved,'open_notes',notes,
    'lead_stages',jsonb_build_array('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM','WON','LOST'));
end $$;

revoke all on function public.bridgepoint_onboarding_state_v70() from public,anon;
revoke all on function public.bridgepoint_complete_onboarding_v70(text,text,text,text,text) from public,anon;
revoke all on function public.bridgepoint_save_customer_note_v70(uuid,uuid,text,text,timestamptz) from public,anon;
revoke all on function public.bridgepoint_customer_notes_v70(uuid,integer) from public,anon;
revoke all on function public.bridgepoint_submit_feedback_v70(text,text,text) from public,anon;
revoke all on function public.bridgepoint_save_opportunity_v70(uuid,uuid,text,text,numeric,text,text,text,timestamptz) from public,anon;
revoke all on function public.bridgepoint_update_lead_stage_v70(uuid,text,timestamptz) from public,anon;
revoke all on function public.bridgepoint_my_work_v70(integer) from public,anon;
grant execute on function public.bridgepoint_onboarding_state_v70() to authenticated;
grant execute on function public.bridgepoint_complete_onboarding_v70(text,text,text,text,text) to authenticated;
grant execute on function public.bridgepoint_save_customer_note_v70(uuid,uuid,text,text,timestamptz) to authenticated;
grant execute on function public.bridgepoint_customer_notes_v70(uuid,integer) to authenticated;
grant execute on function public.bridgepoint_submit_feedback_v70(text,text,text) to authenticated;
grant execute on function public.bridgepoint_save_opportunity_v70(uuid,uuid,text,text,numeric,text,text,text,timestamptz) to authenticated;
grant execute on function public.bridgepoint_update_lead_stage_v70(uuid,text,timestamptz) to authenticated;
grant execute on function public.bridgepoint_my_work_v70(integer) to authenticated;
