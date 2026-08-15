-- BridgePoint V78
-- Customer claims workflow, private action history, and one chronological property timeline.

alter table customer_workspace.saved_opportunities_v70
  drop constraint if exists saved_opportunities_v70_lead_stage_check;
alter table customer_workspace.saved_opportunities_v70
  add constraint saved_opportunities_v70_lead_stage_check check(lead_stage in (
    'NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM',
    'INSPECTION_SCHEDULED','INSPECTED','CLAIM_FILED','ADJUSTER_ASSIGNED','ESTIMATE_IN_PROGRESS',
    'ESTIMATE_SUBMITTED','NEGOTIATION','APPROVED','WORK_SCHEDULED','IN_PROGRESS','COMPLETED',
    'PAID','CLOSED_LOST','WON','LOST'));

create table if not exists customer_workspace.claims_v78 (
  claim_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  saved_opportunity_id uuid not null unique
    references customer_workspace.saved_opportunities_v70(saved_opportunity_id) on delete cascade,
  property_id uuid not null references core.properties(property_id) on delete cascade,
  opportunity_id uuid,
  claim_number text,
  carrier_name text,
  policy_last4 text check(policy_last4 is null or policy_last4 ~ '^[A-Za-z0-9]{4}$'),
  date_of_loss date,
  damage_type text,
  claim_stage text not null default 'CLAIM_FILED' check(claim_stage in (
    'CLAIM_FILED','ADJUSTER_ASSIGNED','INSPECTION_SCHEDULED','INSPECTED',
    'ESTIMATE_IN_PROGRESS','ESTIMATE_SUBMITTED','NEGOTIATION','APPROVED',
    'WORK_SCHEDULED','IN_PROGRESS','COMPLETED','PAID','CLOSED_LOST')),
  adjuster_name text,
  adjuster_phone text,
  adjuster_email text,
  inspection_at timestamptz,
  estimate_amount numeric(14,2) check(estimate_amount is null or estimate_amount>=0),
  approved_amount numeric(14,2) check(approved_amount is null or approved_amount>=0),
  deductible_amount numeric(14,2) check(deductible_amount is null or deductible_amount>=0),
  work_start_at timestamptz,
  work_completed_at timestamptz,
  next_action_at timestamptz,
  notes_summary text check(notes_summary is null or length(notes_summary)<=4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists claims_v78_user_stage_idx
  on customer_workspace.claims_v78(user_id,claim_stage,updated_at desc);
create index if not exists claims_v78_property_idx
  on customer_workspace.claims_v78(user_id,property_id,updated_at desc);

create table if not exists customer_workspace.claim_events_v78 (
  claim_event_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  claim_id uuid not null references customer_workspace.claims_v78(claim_id) on delete cascade,
  property_id uuid not null references core.properties(property_id) on delete cascade,
  event_type text not null,
  claim_stage text,
  title text not null,
  description text,
  event_at timestamptz not null default now(),
  source_kind text not null default 'USER'
    check(source_kind in ('USER','AUTOMATION','AUTHORIZED_INTEGRATION')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists claim_events_v78_claim_time_idx
  on customer_workspace.claim_events_v78(user_id,claim_id,event_at desc);
create index if not exists claim_events_v78_property_time_idx
  on customer_workspace.claim_events_v78(user_id,property_id,event_at desc);

create table if not exists customer_workspace.claim_tasks_v78 (
  claim_task_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  claim_id uuid not null references customer_workspace.claims_v78(claim_id) on delete cascade,
  task_type text not null,
  title text not null,
  due_at timestamptz,
  status text not null default 'OPEN' check(status in ('OPEN','DONE','CANCELLED')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists claim_tasks_v78_due_idx
  on customer_workspace.claim_tasks_v78(user_id,status,due_at);

alter table customer_workspace.claims_v78 enable row level security;
alter table customer_workspace.claim_events_v78 enable row level security;
alter table customer_workspace.claim_tasks_v78 enable row level security;
revoke all on customer_workspace.claims_v78 from anon,authenticated;
revoke all on customer_workspace.claim_events_v78 from anon,authenticated;
revoke all on customer_workspace.claim_tasks_v78 from anon,authenticated;

create or replace function public.bridgepoint_open_claim_v78(
  p_saved_opportunity_id uuid,
  p_date_of_loss date default null,
  p_damage_type text default null,
  p_carrier_name text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); saved customer_workspace.saved_opportunities_v70%rowtype;
  cid uuid;
begin
  select * into saved from customer_workspace.saved_opportunities_v70
  where saved_opportunity_id=p_saved_opportunity_id and user_id=uid;
  if saved.saved_opportunity_id is null then raise exception 'Saved opportunity not found'; end if;

  insert into customer_workspace.claims_v78(
    user_id,saved_opportunity_id,property_id,opportunity_id,date_of_loss,damage_type,carrier_name,
    claim_stage,next_action_at)
  values(uid,saved.saved_opportunity_id,saved.property_id,saved.opportunity_id,p_date_of_loss,
    nullif(btrim(coalesce(p_damage_type,'')),''),nullif(btrim(coalesce(p_carrier_name,'')),''),
    'CLAIM_FILED',now()+interval '1 day')
  on conflict(saved_opportunity_id) do update set
    date_of_loss=coalesce(excluded.date_of_loss,customer_workspace.claims_v78.date_of_loss),
    damage_type=coalesce(excluded.damage_type,customer_workspace.claims_v78.damage_type),
    carrier_name=coalesce(excluded.carrier_name,customer_workspace.claims_v78.carrier_name),
    updated_at=now()
  returning claim_id into cid;

  insert into customer_workspace.claim_events_v78(
    user_id,claim_id,property_id,event_type,claim_stage,title,description,source_kind)
  values(uid,cid,saved.property_id,'CLAIM_OPENED','CLAIM_FILED','Claim workflow opened',
    concat_ws(' • ',nullif(btrim(coalesce(p_damage_type,'')),''),
      case when p_date_of_loss is not null then 'Loss date '||p_date_of_loss::text end,
      nullif(btrim(coalesce(p_carrier_name,'')),'')),'USER');

  insert into customer_workspace.claim_tasks_v78(user_id,claim_id,task_type,title,due_at)
  select uid,cid,'VERIFY_CLAIM','Verify claim number, carrier, and next contact',now()+interval '1 day'
  where not exists(select 1 from customer_workspace.claim_tasks_v78
    where claim_id=cid and task_type='VERIFY_CLAIM' and status='OPEN');

  update customer_workspace.saved_opportunities_v70 set
    lead_stage='CLAIM_FILED',next_action_at=coalesce(next_action_at,now()+interval '1 day'),updated_at=now()
  where saved_opportunity_id=saved.saved_opportunity_id;

  return jsonb_build_object('complete',true,'claim_id',cid,'claim_stage','CLAIM_FILED',
    'message','Claim workflow opened. Only customer-entered or authorized integration data is stored here.');
end $$;

create or replace function public.bridgepoint_update_claim_v78(
  p_claim_id uuid,
  p_claim_stage text,
  p_claim_number text default null,
  p_adjuster_name text default null,
  p_next_action_at timestamptz default null,
  p_estimate_amount numeric default null,
  p_approved_amount numeric default null,
  p_notes_summary text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); stage text:=upper(btrim(coalesce(p_claim_stage,'')));
  current_claim customer_workspace.claims_v78%rowtype; v_task_title text; v_task_type text;
begin
  if stage not in ('CLAIM_FILED','ADJUSTER_ASSIGNED','INSPECTION_SCHEDULED','INSPECTED',
    'ESTIMATE_IN_PROGRESS','ESTIMATE_SUBMITTED','NEGOTIATION','APPROVED','WORK_SCHEDULED',
    'IN_PROGRESS','COMPLETED','PAID','CLOSED_LOST') then raise exception 'Unsupported claim stage'; end if;
  select * into current_claim from customer_workspace.claims_v78
    where claim_id=p_claim_id and user_id=uid for update;
  if current_claim.claim_id is null then raise exception 'Claim not found'; end if;

  update customer_workspace.claims_v78 set claim_stage=stage,
    claim_number=coalesce(nullif(btrim(coalesce(p_claim_number,'')),''),claim_number),
    adjuster_name=coalesce(nullif(btrim(coalesce(p_adjuster_name,'')),''),adjuster_name),
    next_action_at=p_next_action_at,
    estimate_amount=coalesce(p_estimate_amount,estimate_amount),
    approved_amount=coalesce(p_approved_amount,approved_amount),
    notes_summary=coalesce(nullif(btrim(coalesce(p_notes_summary,'')),''),notes_summary),
    work_start_at=case when stage='IN_PROGRESS' then coalesce(work_start_at,now()) else work_start_at end,
    work_completed_at=case when stage in ('COMPLETED','PAID') then coalesce(work_completed_at,now()) else work_completed_at end,
    updated_at=now()
  where claim_id=p_claim_id and user_id=uid;

  update customer_workspace.saved_opportunities_v70 set lead_stage=stage,
    next_action_at=p_next_action_at,updated_at=now()
  where saved_opportunity_id=current_claim.saved_opportunity_id and user_id=uid;

  insert into customer_workspace.claim_events_v78(
    user_id,claim_id,property_id,event_type,claim_stage,title,description,source_kind)
  values(uid,p_claim_id,current_claim.property_id,'STAGE_CHANGED',stage,
    'Claim moved to '||initcap(replace(stage,'_',' ')),
    nullif(btrim(coalesce(p_notes_summary,'')),''),'USER');

  v_task_type:=case stage
      when 'CLAIM_FILED' then 'FOLLOW_UP_CARRIER'
      when 'ADJUSTER_ASSIGNED' then 'SCHEDULE_INSPECTION'
      when 'INSPECTION_SCHEDULED' then 'PREPARE_INSPECTION'
      when 'INSPECTED' then 'PREPARE_ESTIMATE'
      when 'ESTIMATE_SUBMITTED' then 'FOLLOW_UP_ESTIMATE'
      when 'APPROVED' then 'SCHEDULE_WORK'
      when 'COMPLETED' then 'CONFIRM_PAYMENT' end;
  v_task_title:=case stage
      when 'CLAIM_FILED' then 'Confirm claim and carrier contact'
      when 'ADJUSTER_ASSIGNED' then 'Schedule the adjuster inspection'
      when 'INSPECTION_SCHEDULED' then 'Prepare evidence for inspection'
      when 'INSPECTED' then 'Build and review the estimate'
      when 'ESTIMATE_SUBMITTED' then 'Follow up on estimate decision'
      when 'APPROVED' then 'Schedule approved work'
      when 'COMPLETED' then 'Confirm payment and closeout' end;
  if v_task_type is not null then
    insert into customer_workspace.claim_tasks_v78(user_id,claim_id,task_type,title,due_at)
    select uid,p_claim_id,v_task_type,v_task_title,coalesce(p_next_action_at,now()+interval '2 days')
    where not exists(select 1 from customer_workspace.claim_tasks_v78
      where claim_id=p_claim_id and task_type=v_task_type and status='OPEN');
  end if;
  return jsonb_build_object('complete',true,'claim_id',p_claim_id,'claim_stage',stage,'status','updated');
end $$;

create or replace function public.bridgepoint_my_work_v78(p_limit integer default 200)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); saved jsonb; notes jsonb; claims jsonb; tasks jsonb;
  lim integer:=least(greatest(coalesce(p_limit,200),1),500);
begin
  select coalesce(jsonb_agg(to_jsonb(s) order by s.next_action_at nulls last,s.updated_at desc),'[]'::jsonb)
    into saved from (select saved_opportunity_id,opportunity_id,property_id,title,address,score,reason,
      recommended_action,vertical_key,lead_stage,next_action_at,saved_at,updated_at
      from customer_workspace.saved_opportunities_v70 where user_id=uid
      order by next_action_at nulls last,updated_at desc limit lim) s;
  select coalesce(jsonb_agg(to_jsonb(n) order by n.follow_up_at nulls last,n.updated_at desc),'[]'::jsonb)
    into notes from (select note_id,property_id,opportunity_id,preset_key,note_text,follow_up_at,status,created_at,updated_at
      from customer_workspace.notes_v70 where user_id=uid and status='OPEN'
      order by follow_up_at nulls last,updated_at desc limit lim) n;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.next_action_at nulls last,c.updated_at desc),'[]'::jsonb)
    into claims from (select c.claim_id,c.saved_opportunity_id,c.property_id,c.opportunity_id,c.claim_number,
      c.carrier_name,c.date_of_loss,c.damage_type,c.claim_stage,c.adjuster_name,c.inspection_at,
      c.estimate_amount,c.approved_amount,c.deductible_amount,c.next_action_at,c.notes_summary,c.created_at,c.updated_at,
      s.address,s.title opportunity_title
      from customer_workspace.claims_v78 c join customer_workspace.saved_opportunities_v70 s
        on s.saved_opportunity_id=c.saved_opportunity_id
      where c.user_id=uid order by c.next_action_at nulls last,c.updated_at desc limit lim) c;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.due_at nulls last,t.created_at desc),'[]'::jsonb)
    into tasks from (select claim_task_id,claim_id,task_type,title,due_at,status,created_at,updated_at
      from customer_workspace.claim_tasks_v78 where user_id=uid and status='OPEN'
      order by due_at nulls last,created_at desc limit lim) t;
  return jsonb_build_object('complete',true,'version',78,'generated_at',now(),
    'saved_opportunities',saved,'open_notes',notes,'claims',claims,'claim_tasks',tasks,
    'lead_stages',jsonb_build_array('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION_SCHEDULED',
      'INSPECTED','CLAIM_FILED','ADJUSTER_ASSIGNED','ESTIMATE_IN_PROGRESS','ESTIMATE_SUBMITTED',
      'NEGOTIATION','APPROVED','WORK_SCHEDULED','IN_PROGRESS','COMPLETED','PAID','CLOSED_LOST'),
    'claims_data_policy','Public evidence is automatic. Claim details are customer-entered or received from an explicitly authorized integration.');
end $$;

create or replace function public.bridgepoint_property_timeline_v78(
  p_property_id uuid,p_limit integer default 120)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace','intelligence','pattern_engine','opportunity_engine' as $$
declare uid uuid:=api.require_user(); items jsonb; lim integer:=least(greatest(coalesce(p_limit,120),10),300);
begin
  if not exists(select 1 from core.properties where property_id=p_property_id and active) then
    raise exception 'Property not found'; end if;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.timeline_at desc),'[]'::jsonb) into items from (
    select * from (
      select 'SIGNAL'::text timeline_type,coalesce(s.effective_at,s.detected_at,s.created_at) timeline_at,
        s.title,coalesce(s.description,'Evidence detected by '||s.detector_key) description,
        s.detector_key source_label,s.confidence,s.severity,null::text stage,s.signal_id item_id
      from intelligence.signals s where s.entity_type='PROPERTY' and s.entity_id=p_property_id
      union all
      select 'PATTERN',coalesce(p.latest_signal_at,p.detected_at,p.updated_at),p.pattern_name,
        format('%s property signals across %s source families formed a corroborating evidence sequence.',
          p.signal_count,p.distinct_sources),p.pattern_family,p.pattern_confidence,null,p.intelligence_stage,p.detected_pattern_id
      from pattern_engine.patterns_v36 p where p.entity_type='PROPERTY' and p.entity_id=p_property_id
        and p.pattern_status='ACTIVE'
      union all
      select 'OPPORTUNITY',coalesce(o.latest_evidence_at,o.updated_at),o.opportunity_name,
        coalesce(o.reason,'Strict evidence score '||round(o.strict_score,1)::text),o.vertical_key,
        o.confidence_score,null,o.strict_tier,o.opportunity_id
      from opportunity_engine.strict_ranked_opportunities_v76 o
      where o.property_id=p_property_id and o.strict_score>=78
      union all
      select 'NOTE',n.created_at,initcap(replace(n.preset_key,'_',' '))||' note',n.note_text,
        'Your workspace',null,null,n.status,n.note_id
      from customer_workspace.notes_v70 n where n.user_id=uid and n.property_id=p_property_id
      union all
      select 'CLAIM',e.event_at,e.title,e.description,
        case e.source_kind when 'AUTHORIZED_INTEGRATION' then 'Authorized integration'
          when 'AUTOMATION' then 'BridgePoint workflow' else 'Your claims workspace' end,
        null,null,e.claim_stage,e.claim_event_id
      from customer_workspace.claim_events_v78 e where e.user_id=uid and e.property_id=p_property_id
    ) all_items order by timeline_at desc limit lim
  ) t;
  return jsonb_build_object('complete',true,'version',78,'property_id',p_property_id,
    'generated_at',now(),'item_count',jsonb_array_length(items),'timeline',items,
    'explanation','One chronological property history: automatic public evidence, detected patterns, strict opportunities, your notes, and your claim events.');
end $$;

create or replace function customer_workspace.refresh_claim_workflows_v78()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','customer_workspace' as $$
declare inserted_count integer:=0;
begin
  insert into customer_workspace.notifications_v74(
    user_id,notification_type,title,message,action_page,action_id,dedupe_key)
  select c.user_id,'FOLLOW_UP','Claim action due: '||coalesce(c.claim_number,c.damage_type,'Property claim'),
    case when c.next_action_at<now() then 'This claim follow-up is overdue.' else 'This claim follow-up is due within 24 hours.' end,
    'my_work',c.claim_id,'claim-follow-up:'||c.claim_id::text||':'||to_char(current_date,'YYYY-MM-DD')
  from customer_workspace.claims_v78 c
  join customer_workspace.notification_preferences_v74 p on p.user_id=c.user_id
  where c.claim_stage not in('PAID','CLOSED_LOST') and c.next_action_at is not null
    and c.next_action_at<=now()+interval '24 hours' and p.in_app_enabled and p.saved_follow_ups
  on conflict(user_id,dedupe_key) do nothing;
  get diagnostics inserted_count=row_count;
  return jsonb_build_object('complete',true,'notifications_created',inserted_count,'processed_at',now());
end $$;

do $$ begin
  perform cron.unschedule('bridgepoint-claim-workflows-v78');
exception when others then null; end $$;
select cron.schedule('bridgepoint-claim-workflows-v78','*/15 * * * *',
  $job$select customer_workspace.refresh_claim_workflows_v78();$job$);

revoke all on function public.bridgepoint_open_claim_v78(uuid,date,text,text) from public,anon;
revoke all on function public.bridgepoint_update_claim_v78(uuid,text,text,text,timestamptz,numeric,numeric,text) from public,anon;
revoke all on function public.bridgepoint_my_work_v78(integer) from public,anon;
revoke all on function public.bridgepoint_property_timeline_v78(uuid,integer) from public,anon;
revoke all on function customer_workspace.refresh_claim_workflows_v78() from public,anon,authenticated;
grant execute on function public.bridgepoint_open_claim_v78(uuid,date,text,text) to authenticated,service_role;
grant execute on function public.bridgepoint_update_claim_v78(uuid,text,text,text,timestamptz,numeric,numeric,text) to authenticated,service_role;
grant execute on function public.bridgepoint_my_work_v78(integer) to authenticated,service_role;
grant execute on function public.bridgepoint_property_timeline_v78(uuid,integer) to authenticated,service_role;
grant execute on function customer_workspace.refresh_claim_workflows_v78() to service_role;

comment on table customer_workspace.claims_v78 is
  'Private customer claims workflow. Public evidence is automatic; claim-specific fields require customer entry or an explicitly authorized integration.';
