-- BridgePoint V82
-- Legal acceptance/audit records, privacy requests, emergency administrator
-- readiness, and recoverable daily configuration snapshots.

create table if not exists product.legal_documents_v82(
  document_key text not null,
  document_version text not null,
  title text not null,
  summary text not null,
  content_markdown text not null,
  required boolean not null default true,
  active boolean not null default true,
  effective_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key(document_key,document_version)
);

insert into product.legal_documents_v82(document_key,document_version,title,summary,content_markdown,required,active,effective_at)
values
('TERMS','2026-08-15','Terms of Service','The rules for using BridgePoint, trials, subscriptions, evidence, customer work, and account security.',
$doc$# BridgePoint Intelligence Terms of Service

Effective August 15, 2026. These terms govern access to BridgePoint Intelligence. You must be at least 18 and authorized to bind the account or organization you use.

BridgePoint provides property-intelligence software, workflow tools, public-source context, scoring, routing, notes, and alerts. It does not provide legal, insurance, engineering, appraisal, meteorological, lending, medical, tax, or other professional advice. Scores and alerts identify matters for investigation; they do not prove damage, ownership, insurability, code violations, permit status, claim coverage, customer intent, or a guaranteed sale.

You are responsible for verifying evidence, obeying property-access rules, licensing requirements, advertising and solicitation laws, do-not-call rules, safety requirements, employment policies, and all laws applying to your work. You must keep credentials private, use separate accounts for each person, and notify BridgePoint of suspected unauthorized access.

Trials and subscriptions follow the price, billing interval, seat count, and cancellation terms shown at checkout. Stripe processes payment information. Except where law requires otherwise, fees already earned are non-refundable. Plans may be changed through the billing portal.

You retain ownership of customer notes and authorized business content you enter. BridgePoint retains its software, models, designs, documentation, and compiled intelligence. You may not scrape, resell, reverse engineer, defeat access controls, misuse personal data, or use the service for unlawful discrimination, harassment, trespass, fraud, or deceptive claims.

The service is provided on an as-available basis. To the maximum extent permitted by law, implied warranties are disclaimed and indirect, special, consequential, or punitive damages are excluded. BridgePoint's aggregate liability will not exceed the subscription fees paid for the affected service during the six months before the event, except where a limitation is prohibited by law. These provisions require review by BridgePoint's licensed attorney before public launch.

Connecticut law governs these terms without regard to conflicts rules. Before filing a claim, the parties will attempt good-faith informal resolution. Nothing waives rights that cannot legally be waived.
$doc$,true,true,'2026-08-15T00:00:00Z'),
('PRIVACY','2026-08-15','Privacy Notice','What BridgePoint collects, why it is used, retention, processors, and privacy choices.',
$doc$# BridgePoint Intelligence Privacy Notice

Effective August 15, 2026. BridgePoint collects account details, authentication records, billing status, preferences, saved opportunities, notes, support messages, device and security logs, and—only when a user starts a field shift—precise field location. Property intelligence is drawn from identified public, licensed, customer-authorized, or otherwise lawful sources.

Data is used to provide and secure the service, personalize packages, rank and explain opportunities, synchronize team work, process billing, deliver requested alerts, diagnose failures, prevent abuse, and meet legal obligations. Stripe and Supabase process limited data as service providers. BridgePoint does not sell customer account data or precise field location and does not use precise field location for advertising.

Live field locations are visible only to authorized Company owners, co-owners, and managers. They leave the live view after 15 minutes and are deleted after seven days. Billing records, acceptance logs, security records, and other business records may be retained longer when reasonably necessary for contracts, fraud prevention, disputes, taxes, or law.

Depending on applicable law, individuals may request access, correction, deletion, or a portable copy of personal data and may appeal a denied request. Requests can be filed through Legal & Trust Center in Settings. BridgePoint will verify identity before acting. Connecticut universal opt-out signals will be honored where legally applicable to covered processing.

BridgePoint is intended for adults and business users, not children under 13. Reasonable administrative, technical, and organizational safeguards are used, but no system is completely risk-free. Material changes will be presented in the app and new consent will be requested when required.
$doc$,true,true,'2026-08-15T00:00:00Z'),
('ACCEPTABLE_USE','2026-08-15','Acceptable Use & Field Conduct','Safety, ethical outreach, anti-discrimination, property access, and lawful communications.',
$doc$# Acceptable Use and Field Conduct

Use BridgePoint only for lawful, legitimate business or homeowner purposes. Do not use it to discriminate in housing, lending, insurance, employment, contracting, or advertising; infer protected traits; target or exclude people because of protected status; harass or intimidate anyone; trespass; misrepresent public evidence; impersonate a government agency, insurer, adjuster, contractor, or property owner; or claim that radar, a score, or a signal proves damage.

Before outreach, comply with federal, state, and local telemarketing, text-message, email, licensing, registration, quiet-hours, do-not-call, and door-to-door solicitation requirements. Commercial email must use accurate headers and subjects, identify the sender and advertising nature when required, include a valid postal address and working opt-out, and honor opt-outs promptly. Do not upload purchased contact lists unless their acquisition and intended use are lawful and documented.

Field users must stay in lawful public or invited areas, follow safety guidance, obtain permission before photography or inspection, avoid distracted driving, and verify information before making customer-facing statements. Managers must provide any legally required electronic-monitoring notice before enabling workers to use Live Field Assist.

BridgePoint may suspend access, preserve evidence, or cooperate with lawful process when it reasonably believes the service is being abused or security is at risk.
$doc$,true,true,'2026-08-15T00:00:00Z'),
('DATA_DISCLAIMER','2026-08-15','Data & Scoring Disclaimer','How to interpret sources, radar, matches, patterns, scores, and negative adjustments.',
$doc$# Data and Scoring Disclaimer

Every source has its own coverage, delay, accuracy, license, and update schedule. “Live” means BridgePoint is connected and refreshing on the stated schedule; it does not mean every source reports instantly. Official records can be incomplete, corrected, delayed, duplicated, or linked to the wrong property. Users must inspect source dates and verify material facts.

An opportunity score ranks evidence for review. Confidence estimates evidence reliability. A signal is an observation; a pattern connects observations; a direct match satisfies a model rule. V81 subtracts negative points for missing direct matches, missing corroboration, weak source diversity, older evidence, and lower confidence, and deduplicates All Intelligence to the best qualifying opportunity per property. No score predicts a guaranteed sale, project, claim, loss, permit, or outcome.

NOAA/NWS radar is general weather context, not a verified hail swath, forensic report, property inspection, or proof of damage. Building outlines and heights are approximate unless a source explicitly states survey-grade accuracy. Users must rely on licensed professionals for inspections, measurements, coverage advice, and legal conclusions.
$doc$,true,true,'2026-08-15T00:00:00Z'),
('FIELD_TRACKING_NOTICE','2026-08-15','Live Field Assist Notice & Consent','Foreground precise-location sharing for Company teams.',
$doc$# Live Field Assist Notice and Consent

Live Field Assist collects precise device location only after you press Start field shift and grant device permission. While Field Mode remains open, the app sends location, accuracy, time, and optional movement direction approximately when you move or once per minute. A permanent indicator shows that sharing is active.

Your location is visible only to you and authorized owners, co-owners, and managers in your Company workspace. It is used to coordinate help, avoid duplicate visits, and support field safety and dispatch. It is not sold or used for advertising. You can stop at any time. Leaving Field Mode ends sharing. Locations leave the live view after 15 minutes and are permanently deleted after seven days.

Your employer or organization—not BridgePoint—is responsible for giving any additional employee-monitoring notice, obtaining any consent required by law or policy, and ensuring tracking is not used for unlawful surveillance or discipline. Do not start sharing if you do not agree.
$doc$,false,true,'2026-08-15T00:00:00Z')
on conflict(document_key,document_version) do update set title=excluded.title,summary=excluded.summary,
  content_markdown=excluded.content_markdown,required=excluded.required,active=excluded.active,effective_at=excluded.effective_at;

create table if not exists product.user_legal_acceptances_v82(
  acceptance_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  document_key text not null,
  document_version text not null,
  accepted_at timestamptz not null default now(),
  acceptance_source text not null default 'APP',
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  unique(user_id,document_key,document_version),
  foreign key(document_key,document_version) references product.legal_documents_v82(document_key,document_version)
);

create table if not exists product.privacy_requests_v82(
  privacy_request_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check(request_type in('ACCESS','CORRECTION','DELETION','PORTABILITY','APPEAL','OTHER')),
  request_message text,
  status text not null default 'RECEIVED' check(status in('RECEIVED','VERIFYING','IN_PROGRESS','COMPLETED','DENIED')),
  due_at timestamptz not null default now()+interval '45 days',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table product.legal_documents_v82 enable row level security;
alter table product.user_legal_acceptances_v82 enable row level security;
alter table product.privacy_requests_v82 enable row level security;
revoke all on product.legal_documents_v82 from public,anon,authenticated;
revoke all on product.user_legal_acceptances_v82 from public,anon,authenticated;
revoke all on product.privacy_requests_v82 from public,anon,authenticated;

create or replace function public.bridgepoint_legal_state_v82()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','product' as $$
declare uid uuid:=api.require_user(); docs jsonb; missing integer:=0;
begin
  select coalesce(jsonb_agg(jsonb_build_object('document_key',d.document_key,'document_version',d.document_version,
    'title',d.title,'summary',d.summary,'content_markdown',d.content_markdown,'required',d.required,
    'accepted',a.acceptance_id is not null,'accepted_at',a.accepted_at) order by d.document_key),'[]'::jsonb),
    count(*) filter(where d.required and a.acceptance_id is null)
  into docs,missing from product.legal_documents_v82 d
  left join product.user_legal_acceptances_v82 a on a.user_id=uid and a.document_key=d.document_key and a.document_version=d.document_version
  where d.active;
  return jsonb_build_object('complete',true,'required_acceptance_missing',missing>0,'missing_count',missing,'documents',docs,
    'attorney_review_status','REQUIRED_BEFORE_PUBLIC_LAUNCH');
end $$;

create or replace function public.bridgepoint_accept_legal_v82(p_document_keys text[],p_acceptance_source text default 'APP')
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product' as $$
declare uid uuid:=api.require_user(); accepted_count integer:=0;
begin
  if p_document_keys is null or cardinality(p_document_keys)=0 then raise exception 'Select at least one document'; end if;
  insert into product.user_legal_acceptances_v82(user_id,document_key,document_version,acceptance_source)
  select uid,d.document_key,d.document_version,left(coalesce(p_acceptance_source,'APP'),40)
  from product.legal_documents_v82 d where d.active and d.document_key=any(p_document_keys)
  on conflict(user_id,document_key,document_version) do nothing;
  get diagnostics accepted_count=row_count;
  return public.bridgepoint_legal_state_v82()||jsonb_build_object('accepted_now',accepted_count);
end $$;

create or replace function public.bridgepoint_submit_privacy_request_v82(p_request_type text,p_message text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product' as $$
declare uid uuid:=api.require_user(); kind text:=upper(btrim(coalesce(p_request_type,''))); request_id uuid;
begin
  if kind not in('ACCESS','CORRECTION','DELETION','PORTABILITY','APPEAL','OTHER') then raise exception 'Unsupported privacy request'; end if;
  insert into product.privacy_requests_v82(user_id,request_type,request_message)
  values(uid,kind,nullif(btrim(coalesce(p_message,'')),'')) returning privacy_request_id into request_id;
  return jsonb_build_object('complete',true,'privacy_request_id',request_id,'status','RECEIVED','identity_verification_required',true);
end $$;

create or replace function product.record_signup_legal_v82()
returns trigger language plpgsql security definer
set search_path='pg_catalog','product' as $$
begin
  if coalesce((new.raw_user_meta_data->>'legal_accepted')::boolean,false) then
    insert into product.user_legal_acceptances_v82(user_id,document_key,document_version,acceptance_source,metadata)
    select new.id,d.document_key,d.document_version,'SIGNUP',jsonb_build_object('signup_recorded',true)
    from product.legal_documents_v82 d where d.active and d.required
    on conflict(user_id,document_key,document_version) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists bridgepoint_record_signup_legal_v82 on auth.users;
create trigger bridgepoint_record_signup_legal_v82 after insert on auth.users
for each row execute function product.record_signup_legal_v82();
revoke execute on function product.record_signup_legal_v82() from public,anon,authenticated;

-- Require the current tracking notice before a location-sharing shift starts.
create or replace function public.bridgepoint_start_field_shift_v81(p_shift_label text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product','customer_workspace' as $$
declare uid uuid:=api.require_user(); org uuid; shift_id uuid; tracking_allowed boolean:=false;
begin
  if not exists(select 1 from product.legal_documents_v82 d join product.user_legal_acceptances_v82 a
    on a.user_id=uid and a.document_key=d.document_key and a.document_version=d.document_version
    where d.document_key='FIELD_TRACKING_NOTICE' and d.active) then
    raise exception 'Accept the current Live Field Assist notice before sharing location';
  end if;
  select m.organization_id,coalesce(e.location_tracking_enabled,false) into org,tracking_allowed
  from product.organization_members_v80 m join product.organization_seat_entitlements_v80 e on e.organization_id=m.organization_id
  where m.user_id=uid and m.active and e.status in('TRIALING','ACTIVE') limit 1;
  if org is null or not tracking_allowed then raise exception 'Live Field Assist is available on an active BridgePoint Company plan'; end if;
  select field_shift_id into shift_id from customer_workspace.field_shifts_v81 where user_id=uid and status='ACTIVE' limit 1;
  if shift_id is null then
    insert into customer_workspace.field_shifts_v81(organization_id,user_id,shift_label)
    values(org,uid,nullif(btrim(coalesce(p_shift_label,'')),'')) returning field_shift_id into shift_id;
  end if;
  return jsonb_build_object('complete',true,'field_shift_id',shift_id,'status','ACTIVE',
    'privacy','Location is shared only while this field shift is active and retained for seven days.');
end $$;

create table if not exists accounts.emergency_access_policy_v82(
  platform_owner_auth_user_id uuid primary key references auth.users(id) on delete cascade,
  maximum_backup_admins integer not null default 1 check(maximum_backup_admins between 1 and 3),
  policy_status text not null default 'READY_FOR_EMAIL' check(policy_status in('READY_FOR_EMAIL','INVITATION_PENDING','BACKUP_ACTIVE')),
  updated_at timestamptz not null default now()
);
insert into accounts.emergency_access_policy_v82(platform_owner_auth_user_id)
select auth_user_id from accounts.user_profiles where platform_role='platform_owner' and is_active
on conflict(platform_owner_auth_user_id) do nothing;

create table if not exists accounts.emergency_admin_invitations_v82(
  emergency_invitation_id uuid primary key default gen_random_uuid(),
  platform_owner_auth_user_id uuid not null references auth.users(id) on delete cascade,
  invited_email text not null,
  organization_id uuid references core.organizations(organization_id) on delete set null,
  status text not null default 'PENDING' check(status in('PENDING','ACCEPTED','REVOKED','EXPIRED')),
  expires_at timestamptz not null default now()+interval '7 days',
  accepted_auth_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  updated_at timestamptz not null default now()
);
create unique index if not exists emergency_admin_invitations_v82_pending_idx
  on accounts.emergency_admin_invitations_v82(platform_owner_auth_user_id) where status='PENDING';
alter table accounts.emergency_access_policy_v82 enable row level security;
alter table accounts.emergency_admin_invitations_v82 enable row level security;
revoke all on accounts.emergency_access_policy_v82 from public,anon,authenticated;
revoke all on accounts.emergency_admin_invitations_v82 from public,anon,authenticated;

create or replace function public.bridgepoint_emergency_admin_state_v82()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','accounts','auth' as $$
declare uid uuid:=api.require_user(); policy record; invite record; active_admins jsonb;
begin
  if not accounts.is_platform_owner() then raise exception 'Platform owner access required'; end if;
  select * into policy from accounts.emergency_access_policy_v82 where platform_owner_auth_user_id=uid;
  select * into invite from accounts.emergency_admin_invitations_v82 where platform_owner_auth_user_id=uid and status='PENDING' order by created_at desc limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('auth_user_id',up.auth_user_id,'display_name',up.display_name,'email',u.email,
    'active',up.is_active,'platform_role',up.platform_role)),'[]'::jsonb) into active_admins
  from accounts.user_profiles up join auth.users u on u.id=up.auth_user_id
  where up.platform_role='platform_admin';
  return jsonb_build_object('complete',true,'ready',true,'policy_status',coalesce(policy.policy_status,'READY_FOR_EMAIL'),
    'maximum_backup_admins',coalesce(policy.maximum_backup_admins,1),'pending_invitation',case when invite.emergency_invitation_id is null then null else jsonb_build_object(
      'emergency_invitation_id',invite.emergency_invitation_id,'invited_email',invite.invited_email,'expires_at',invite.expires_at) end,
    'active_backup_admins',active_admins,
    'message','Enter a trusted person’s email when ready. They receive a separate verified account; no shared password is created.');
end $$;

create or replace function public.bridgepoint_prepare_emergency_admin_v82(p_email text,p_confirmation text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','accounts','product','auth' as $$
declare uid uuid:=api.require_user(); email text:=lower(btrim(coalesce(p_email,''))); org uuid; invite_id uuid;
begin
  if not accounts.is_platform_owner() then raise exception 'Platform owner access required'; end if;
  if p_confirmation<>'GRANT BACKUP ADMIN' then raise exception 'Type GRANT BACKUP ADMIN to confirm'; end if;
  if email !~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' then raise exception 'Enter a valid email address'; end if;
  if exists(select 1 from auth.users where id=uid and lower(auth.users.email)=email) then raise exception 'Use a different person’s email'; end if;
  if (select count(*) from accounts.user_profiles where platform_role='platform_admin' and is_active)>=1 then raise exception 'The backup administrator slot is already active'; end if;
  select organization_id into org from product.organization_members_v80 where user_id=uid and member_role='OWNER' and active limit 1;
  update accounts.emergency_admin_invitations_v82 set status='REVOKED',updated_at=now()
    where platform_owner_auth_user_id=uid and status='PENDING';
  insert into accounts.emergency_admin_invitations_v82(platform_owner_auth_user_id,invited_email,organization_id)
  values(uid,email,org) returning emergency_invitation_id into invite_id;
  update accounts.emergency_access_policy_v82 set policy_status='INVITATION_PENDING',updated_at=now() where platform_owner_auth_user_id=uid;
  return jsonb_build_object('complete',true,'emergency_invitation_id',invite_id,'email',email,
    'status','PENDING','email_required',true,'expires_at',now()+interval '7 days');
end $$;

create or replace function accounts.accept_emergency_admin_v82()
returns trigger language plpgsql security definer
set search_path='pg_catalog','accounts','product','auth' as $$
declare inv accounts.emergency_admin_invitations_v82%rowtype; name text;
begin
  if new.email is null then return new; end if;
  select * into inv from accounts.emergency_admin_invitations_v82
  where lower(invited_email)=lower(new.email) and status='PENDING' and expires_at>now() order by created_at desc limit 1;
  if not found then return new; end if;
  name:=coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(new.email,'@',1));
  insert into accounts.user_profiles(user_id,auth_user_id,display_name,platform_role,is_active)
  values(gen_random_uuid(),new.id,name,'platform_admin',true)
  on conflict(auth_user_id) do update set platform_role='platform_admin',is_active=true,updated_at=now();
  insert into product.user_profiles(user_id,organization_id,display_name,company_name,onboarding_completed,onboarding_completed_at)
  select new.id,inv.organization_id,name,o.organization_name,true,now() from core.organizations o where o.organization_id=inv.organization_id
  on conflict(user_id) do update set organization_id=excluded.organization_id,display_name=excluded.display_name,
    company_name=excluded.company_name,onboarding_completed=true,onboarding_completed_at=coalesce(product.user_profiles.onboarding_completed_at,now()),updated_at=now();
  if inv.organization_id is not null then
    insert into product.organization_members_v80(organization_id,user_id,member_role)
    values(inv.organization_id,new.id,'CO_OWNER') on conflict(organization_id,user_id) do update set member_role='CO_OWNER',active=true,updated_at=now();
  end if;
  update accounts.emergency_admin_invitations_v82 set status='ACCEPTED',accepted_auth_user_id=new.id,accepted_at=now(),updated_at=now()
    where emergency_invitation_id=inv.emergency_invitation_id;
  update accounts.emergency_access_policy_v82 set policy_status='BACKUP_ACTIVE',updated_at=now()
    where platform_owner_auth_user_id=inv.platform_owner_auth_user_id;
  return new;
end $$;
drop trigger if exists bridgepoint_accept_emergency_admin_v82 on auth.users;
create trigger bridgepoint_accept_emergency_admin_v82 after insert or update of email on auth.users
for each row execute function accounts.accept_emergency_admin_v82();
revoke execute on function accounts.accept_emergency_admin_v82() from public,anon,authenticated;

create or replace function public.bridgepoint_revoke_emergency_admin_v82(p_auth_user_id uuid,p_confirmation text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','accounts','product' as $$
declare uid uuid:=api.require_user();
begin
  if not accounts.is_platform_owner() then raise exception 'Platform owner access required'; end if;
  if p_confirmation<>'REVOKE BACKUP ADMIN' then raise exception 'Type REVOKE BACKUP ADMIN to confirm'; end if;
  update accounts.user_profiles set is_active=false,updated_at=now() where auth_user_id=p_auth_user_id and platform_role='platform_admin';
  if not found then raise exception 'Backup administrator not found'; end if;
  update product.organization_members_v80 set active=false,updated_at=now() where user_id=p_auth_user_id and member_role='CO_OWNER';
  update accounts.emergency_access_policy_v82 set policy_status='READY_FOR_EMAIL',updated_at=now() where platform_owner_auth_user_id=uid;
  return jsonb_build_object('complete',true,'status','REVOKED');
end $$;

create table if not exists automation.system_configuration_snapshots_v82(
  snapshot_id bigint generated always as identity primary key,
  snapshot_at timestamptz not null default now(),
  snapshot_kind text not null default 'DAILY_CONFIGURATION',
  snapshot jsonb not null
);
revoke all on automation.system_configuration_snapshots_v82 from public,anon,authenticated;
create or replace function automation.capture_system_configuration_v82()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','automation','product','scoring','opportunity_engine','pattern_engine','cron' as $$
declare v_snapshot_id bigint; payload jsonb;
begin
  select jsonb_build_object('captured_at',now(),
    'packages',(select coalesce(jsonb_agg(to_jsonb(p) order by p.package_key),'[]'::jsonb) from product.packages p),
    'source_registry',(select coalesce(jsonb_agg(to_jsonb(s) order by s.source_code),'[]'::jsonb) from automation.source_registry s),
    'models',(select coalesce(jsonb_agg(to_jsonb(m) order by m.model_key),'[]'::jsonb) from scoring.models m),
    'opportunity_definitions',(select coalesce(jsonb_agg(to_jsonb(d) order by d.opportunity_key),'[]'::jsonb) from opportunity_engine.definitions_v38 d),
    'pattern_definitions',(select coalesce(jsonb_agg(to_jsonb(d) order by d.pattern_key),'[]'::jsonb) from pattern_engine.definitions_v36 d),
    'scheduled_jobs',(select coalesce(jsonb_agg(to_jsonb(j) order by j.jobname),'[]'::jsonb) from cron.job j),
    'counts',jsonb_build_object('properties',(select count(*) from core.properties where active),
      'quality_opportunities',(select count(*) from opportunity_engine.quality_ranked_opportunities_v81),
      'users',(select count(*) from auth.users))) into payload;
  insert into automation.system_configuration_snapshots_v82 as stored(snapshot) values(payload) returning stored.snapshot_id into v_snapshot_id;
  delete from automation.system_configuration_snapshots_v82 where snapshot_at<now()-interval '30 days';
  return jsonb_build_object('complete',true,'snapshot_id',v_snapshot_id,'captured_at',now());
end $$;
revoke all on function automation.capture_system_configuration_v82() from public,anon,authenticated;
do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-configuration-snapshot-v82') then perform cron.unschedule('bridgepoint-configuration-snapshot-v82'); end if;
  perform cron.schedule('bridgepoint-configuration-snapshot-v82','43 3 * * *','select automation.capture_system_configuration_v82();');
end $$;
select automation.capture_system_configuration_v82();

revoke execute on function public.bridgepoint_legal_state_v82() from public,anon;
revoke execute on function public.bridgepoint_accept_legal_v82(text[],text) from public,anon;
revoke execute on function public.bridgepoint_submit_privacy_request_v82(text,text) from public,anon;
revoke execute on function public.bridgepoint_emergency_admin_state_v82() from public,anon;
revoke execute on function public.bridgepoint_prepare_emergency_admin_v82(text,text) from public,anon;
revoke execute on function public.bridgepoint_revoke_emergency_admin_v82(uuid,text) from public,anon;
grant execute on function public.bridgepoint_legal_state_v82() to authenticated,service_role;
grant execute on function public.bridgepoint_accept_legal_v82(text[],text) to authenticated,service_role;
grant execute on function public.bridgepoint_submit_privacy_request_v82(text,text) to authenticated,service_role;
grant execute on function public.bridgepoint_emergency_admin_state_v82() to authenticated,service_role;
grant execute on function public.bridgepoint_prepare_emergency_admin_v82(text,text) to authenticated,service_role;
grant execute on function public.bridgepoint_revoke_emergency_admin_v82(uuid,text) to authenticated,service_role;

comment on table product.user_legal_acceptances_v82 is 'Versioned, append-only user acceptance evidence for active BridgePoint legal documents.';
comment on table accounts.emergency_admin_invitations_v82 is 'One verified backup platform administrator invitation controlled only by the platform owner.';
comment on table automation.system_configuration_snapshots_v82 is 'Thirty-day configuration recovery snapshots. Supabase Pro daily backups remain the primary database backup.';
