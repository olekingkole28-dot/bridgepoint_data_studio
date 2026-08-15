-- BridgePoint Intelligence v64
-- Stripe sandbox catalog, secure checkout context, webhook synchronization.

begin;

create table if not exists product.stripe_catalog_v64 (
  package_key text primary key references product.packages(package_key) on update cascade,
  stripe_product_id text not null unique,
  stripe_monthly_price_id text not null unique,
  stripe_annual_price_id text not null unique,
  environment text not null default 'sandbox' check (environment in ('sandbox','live')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists product.stripe_customers_v64 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  stripe_customer_id text not null unique,
  environment text not null default 'sandbox' check (environment in ('sandbox','live')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists product.stripe_webhook_events_v64 (
  stripe_event_id text primary key,
  event_type text not null,
  livemode boolean not null,
  processed_at timestamptz not null default now(),
  payload jsonb not null
);

alter table product.stripe_catalog_v64 enable row level security;
alter table product.stripe_customers_v64 enable row level security;
alter table product.stripe_webhook_events_v64 enable row level security;
revoke all on product.stripe_catalog_v64,product.stripe_customers_v64,product.stripe_webhook_events_v64 from public,anon,authenticated;

insert into product.stripe_catalog_v64(package_key,stripe_product_id,stripe_monthly_price_id,stripe_annual_price_id)
values
 ('home','prod_V4iAKuYzonmK0j','price_1U4YlGHzFzwDC13zRbgfl3bk','price_1U4YlKHzFzwDC13z35NpVgYj'),
 ('commercial','prod_V4iBE1t1XWINGt','price_1U4YlQHzFzwDC13zjnmBfl20','price_1U4YlUHzFzwDC13zKzqFuJFo'),
 ('solar','prod_V4iBC3K2VoCft0','price_1U4YlYHzFzwDC13zIGKhEfd5','price_1U4YlcHzFzwDC13zFWF3fja6'),
 ('investor','prod_V4iBKVDNITBchH','price_1U4YlgHzFzwDC13zUvmg8CZs','price_1U4YljHzFzwDC13zgJCtS2pP'),
 ('infrastructure','prod_V4iBok6LZGn8aD','price_1U4YloHzFzwDC13z06wPNfWf','price_1U4YlsHzFzwDC13ztS1KxUZ2'),
 ('custom_model','prod_V4iBQU5Sb5WzAn','price_1U4YlxHzFzwDC13zNPG4pRCJ','price_1U4Ym0HzFzwDC13zLwLl6Wsu'),
 ('all_intelligence','prod_V4iBDvSunGGNpA','price_1U4Ym5HzFzwDC13ztCXeCcGX','price_1U4Ym8HzFzwDC13zM6V4mpHl')
on conflict(package_key) do update set
 stripe_product_id=excluded.stripe_product_id,
 stripe_monthly_price_id=excluded.stripe_monthly_price_id,
 stripe_annual_price_id=excluded.stripe_annual_price_id,
 environment='sandbox',active=true,updated_at=now();

update product.packages p set configuration=coalesce(p.configuration,'{}'::jsonb)||jsonb_build_object(
 'stripe_sandbox_product_id',c.stripe_product_id,
 'stripe_sandbox_monthly_price_id',c.stripe_monthly_price_id,
 'stripe_sandbox_annual_price_id',c.stripe_annual_price_id,
 'checkout_ready',true
),updated_at=now()
from product.stripe_catalog_v64 c where c.package_key=p.package_key;

create or replace function public.bridgepoint_billing_checkout_context_v64(
 p_user_id uuid,p_package_key text,p_interval text
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,product,auth
as $function$
declare v jsonb;
begin
 if p_interval not in ('month','year') then raise exception 'Invalid billing interval'; end if;
 if exists(select 1 from product.platform_access_overrides o where o.user_id=p_user_id and o.bypass_subscriptions) then
   raise exception 'This account already has permanent platform access';
 end if;
 select jsonb_build_object(
   'user_id',u.id,'email',u.email,'package_id',p.package_id,'package_key',p.package_key,
   'package_name',p.package_name,'stripe_product_id',c.stripe_product_id,
   'stripe_price_id',case when p_interval='year' then c.stripe_annual_price_id else c.stripe_monthly_price_id end,
   'interval',p_interval,'trial_days',7,
   'coupon_id',case when a.assignment_id is not null and p_interval='month' then 'BRIDGEPOINT_FIRST10_50_6MO_V63' end,
   'promotion_assignment_id',a.assignment_id,
   'stripe_customer_id',sc.stripe_customer_id
 ) into v
 from auth.users u
 join product.packages p on p.package_key=p_package_key and p.active
 join product.stripe_catalog_v64 c on c.package_key=p.package_key and c.active
 left join product.launch_promotions_v63 lp on lp.promotion_key='FIRST10_50_6MONTHS' and lp.active
 left join product.launch_promotion_assignments_v63 a on a.promotion_id=lp.promotion_id and a.user_id=u.id and a.status in ('reserved','selected')
 left join product.stripe_customers_v64 sc on sc.user_id=u.id
 where u.id=p_user_id;
 if v is null then raise exception 'Billing package or user not found'; end if;
 return v;
end;$function$;

create or replace function public.bridgepoint_billing_record_checkout_v64(
 p_user_id uuid,p_stripe_customer_id text,p_stripe_subscription_id text,p_package_key text,p_assignment_id uuid default null
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,product
as $function$
declare v_package_id uuid;
begin
 select package_id into v_package_id from product.packages where package_key=p_package_key;
 insert into product.stripe_customers_v64(user_id,stripe_customer_id)
 values(p_user_id,p_stripe_customer_id)
 on conflict(user_id) do update set stripe_customer_id=excluded.stripe_customer_id,updated_at=now();
 update product.subscriptions set external_provider='stripe',billing_provider='stripe',
   external_customer_id=p_stripe_customer_id,external_subscription_id=p_stripe_subscription_id,
   package_id=v_package_id,updated_at=now()
 where user_id=p_user_id and status='trialing';
 if p_assignment_id is not null then
   update product.launch_promotion_assignments_v63 set status='applied',applied_at=now(),updated_at=now()
   where assignment_id=p_assignment_id and user_id=p_user_id;
 end if;
 return jsonb_build_object('complete',true);
end;$function$;

revoke execute on function public.bridgepoint_billing_checkout_context_v64(uuid,text,text) from public,anon,authenticated;
revoke execute on function public.bridgepoint_billing_record_checkout_v64(uuid,text,text,text,uuid) from public,anon,authenticated;
grant execute on function public.bridgepoint_billing_checkout_context_v64(uuid,text,text) to service_role;
grant execute on function public.bridgepoint_billing_record_checkout_v64(uuid,text,text,text,uuid) to service_role;

commit;
