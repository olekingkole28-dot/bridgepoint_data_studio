-- BridgePoint V72: billing/trial/promotion entitlement correctness.

-- Founder accounts use permanent access and must not appear as customer trials.
update product.subscriptions s
set status='cancelled',
    canceled_at=coalesce(s.canceled_at,now()),
    cancel_at_period_end=false,
    metadata=coalesce(s.metadata,'{}'::jsonb)||jsonb_build_object(
      'founder_exempt',true,'cancel_reason','permanent_platform_access','version',72
    ),
    updated_at=now()
where exists (
  select 1 from product.platform_access_overrides o
  where o.user_id=s.user_id and o.bypass_subscriptions
)
and s.status='trialing'
and s.external_subscription_id is null;

-- A signup alone does not consume a founding-customer slot. A slot is claimed
-- when an authenticated customer actually chooses a package for Checkout.
drop trigger if exists bridgepoint_assign_first_ten_offer_v63 on auth.users;

alter table product.launch_promotion_assignments_v63
  drop constraint if exists launch_promotion_assignments__promotion_id_reservation_numb_key;
create unique index if not exists launch_promo_active_slot_v72
  on product.launch_promotion_assignments_v63(promotion_id,reservation_number)
  where status in ('reserved','selected','applied');

create or replace function product.claim_launch_offer_v72(
  p_user_id uuid,p_package_id uuid
) returns product.launch_promotion_assignments_v63
language plpgsql security definer
set search_path='pg_catalog','product'
as $$
declare
  promo product.launch_promotions_v63%rowtype;
  assignment product.launch_promotion_assignments_v63%rowtype;
  slot integer;
begin
  perform pg_advisory_xact_lock(hashtext('FIRST10_50_6MONTHS'));

  select * into promo from product.launch_promotions_v63 p
  where p.promotion_key='FIRST10_50_6MONTHS' and p.active
    and p.starts_at<=now() and (p.ends_at is null or p.ends_at>now());
  if not found then return null; end if;

  update product.launch_promotion_assignments_v63
  set status='expired',updated_at=now(),
      metadata=metadata||jsonb_build_object('expired_reason','checkout_not_completed_within_24h')
  where promotion_id=promo.promotion_id and status='selected'
    and selected_at<now()-interval '24 hours';

  select * into assignment
  from product.launch_promotion_assignments_v63 a
  where a.promotion_id=promo.promotion_id and a.user_id=p_user_id
    and a.status in ('reserved','selected','applied')
  limit 1;

  if assignment.assignment_id is not null then
    if assignment.status<>'applied' then
      update product.launch_promotion_assignments_v63
      set selected_package_id=p_package_id,status='selected',
          selected_at=now(),updated_at=now()
      where assignment_id=assignment.assignment_id
      returning * into assignment;
    end if;
    return assignment;
  end if;

  select s into slot from generate_series(1,promo.max_assignments) s
  where not exists (
    select 1 from product.launch_promotion_assignments_v63 a
    where a.promotion_id=promo.promotion_id and a.reservation_number=s
      and a.status in ('reserved','selected','applied')
  ) order by s limit 1;
  if slot is null then return null; end if;

  insert into product.launch_promotion_assignments_v63(
    promotion_id,user_id,reservation_number,percent_off,status,
    selected_package_id,selected_at,metadata
  ) values (
    promo.promotion_id,p_user_id,slot,promo.percent_off,'selected',
    p_package_id,now(),jsonb_build_object('claimed_at_checkout',true,'version',72)
  ) returning * into assignment;
  return assignment;
end $$;

revoke all on function product.claim_launch_offer_v72(uuid,uuid) from public,anon,authenticated;
grant execute on function product.claim_launch_offer_v72(uuid,uuid) to service_role;

create or replace function public.bridgepoint_billing_checkout_context_v64(
  p_user_id uuid,p_package_key text,p_interval text
) returns jsonb language plpgsql security definer
set search_path='pg_catalog','product','auth' as $$
declare
  result jsonb;
  package_row product.packages%rowtype;
  assignment product.launch_promotion_assignments_v63%rowtype;
  trial_days_remaining integer:=0;
begin
  if p_interval not in ('month','year') then raise exception 'Invalid billing interval'; end if;
  if exists(select 1 from product.platform_access_overrides o where o.user_id=p_user_id and o.bypass_subscriptions) then
    raise exception 'This account already has permanent platform access';
  end if;

  select * into package_row from product.packages p
  where p.package_key=p_package_key and p.active;
  if package_row.package_id is null then raise exception 'Billing package not found'; end if;

  assignment:=product.claim_launch_offer_v72(p_user_id,package_row.package_id);

  select greatest(0,ceil(extract(epoch from (s.trial_ends_at-now()))/86400.0)::integer)
  into trial_days_remaining
  from product.subscriptions s
  where s.user_id=p_user_id and s.status='trialing' and s.trial_ends_at>now()
  order by s.trial_ends_at desc limit 1;
  trial_days_remaining:=coalesce(trial_days_remaining,0);

  select jsonb_build_object(
    'user_id',u.id,'email',u.email,
    'package_id',package_row.package_id,'package_key',package_row.package_key,
    'package_name',package_row.package_name,'stripe_product_id',c.stripe_product_id,
    'stripe_price_id',case when p_interval='year' then c.stripe_annual_price_id else c.stripe_monthly_price_id end,
    'interval',p_interval,'trial_days_remaining',trial_days_remaining,
    'coupon_id',case when assignment.assignment_id is not null and assignment.status<>'applied' and p_interval='month'
                     then 'BRIDGEPOINT_FIRST10_50_6MO_V63' end,
    'promotion_assignment_id',assignment.assignment_id,
    'stripe_customer_id',sc.stripe_customer_id
  ) into result
  from auth.users u
  join product.stripe_catalog_v64 c on c.package_key=package_row.package_key and c.active
  left join product.stripe_customers_v64 sc on sc.user_id=u.id
  where u.id=p_user_id;
  if result is null then raise exception 'Billing package or user not found'; end if;
  return result;
end $$;

revoke all on function public.bridgepoint_billing_checkout_context_v64(uuid,text,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_billing_checkout_context_v64(uuid,text,text) to service_role;

create or replace function public.bridgepoint_billing_apply_event_v65(p_event jsonb)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','product' as $$
declare
 v_id text:=p_event->>'id'; v_type text:=p_event->>'type'; v_object jsonb:=p_event#>'{data,object}';
 v_user uuid; v_package_key text; v_package_id uuid; v_customer text; v_subscription text; v_status text;
 v_start timestamptz; v_end timestamptz; v_cancel boolean:=false; v_inserted integer; v_assignment uuid;
begin
 if v_id is null or v_type is null then raise exception 'Invalid Stripe event'; end if;
 insert into product.stripe_webhook_events_v64(stripe_event_id,event_type,livemode,payload)
 values(v_id,v_type,coalesce((p_event->>'livemode')::boolean,false),p_event)
 on conflict do nothing;
 get diagnostics v_inserted=row_count;
 if v_inserted=0 then return jsonb_build_object('complete',true,'duplicate',true); end if;

 if v_type='checkout.session.completed' then
   v_user=nullif(coalesce(v_object->>'client_reference_id',v_object#>>'{metadata,bridgepoint_user_id}'),'')::uuid;
   v_package_key=v_object#>>'{metadata,bridgepoint_package_key}';
   v_customer=v_object->>'customer'; v_subscription=v_object->>'subscription';
   v_assignment=nullif(v_object#>>'{metadata,promotion_assignment_id}','')::uuid;
   if v_user is not null and v_customer is not null then
     insert into product.stripe_customers_v64(user_id,stripe_customer_id)
     values(v_user,v_customer) on conflict(user_id) do update
       set stripe_customer_id=excluded.stripe_customer_id,updated_at=now();
     select package_id into v_package_id from product.packages where package_key=v_package_key;
     update product.subscriptions set package_id=coalesce(v_package_id,package_id),
       external_provider='stripe',billing_provider='stripe',external_customer_id=v_customer,
       external_subscription_id=v_subscription,updated_at=now(),
       metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('checkout_session_id',v_object->>'id')
     where user_id=v_user and status='trialing';
     if not found then
       insert into product.subscriptions(user_id,package_id,status,external_provider,billing_provider,
         external_customer_id,external_subscription_id,metadata)
       values(v_user,v_package_id,'active','stripe','stripe',v_customer,v_subscription,
         jsonb_build_object('checkout_session_id',v_object->>'id'));
     end if;
     update product.launch_promotion_assignments_v63 set status='applied',applied_at=now(),updated_at=now()
     where assignment_id=v_assignment and user_id=v_user and status='selected';
   end if;
 elsif v_type='checkout.session.expired' then
   v_assignment=nullif(v_object#>>'{metadata,promotion_assignment_id}','')::uuid;
   update product.launch_promotion_assignments_v63 set status='expired',updated_at=now(),
     metadata=metadata||jsonb_build_object('expired_reason','stripe_checkout_expired')
   where assignment_id=v_assignment and status='selected';
 elsif v_type in ('customer.subscription.created','customer.subscription.updated','customer.subscription.deleted') then
   v_user=nullif(v_object#>>'{metadata,bridgepoint_user_id}','')::uuid;
   v_package_key=v_object#>>'{metadata,bridgepoint_package_key}';
   v_customer=v_object->>'customer'; v_subscription=v_object->>'id';
   v_status=case when v_type='customer.subscription.deleted' or v_object->>'status'='canceled' then 'cancelled'
     when v_object->>'status' in ('trialing','active','past_due','paused') then v_object->>'status'
     when v_object->>'status' in ('unpaid','incomplete','incomplete_expired') then 'past_due' else 'active' end;
   v_start=case when (v_object->>'current_period_start')~'^[0-9]+$' then to_timestamp((v_object->>'current_period_start')::double precision) end;
   v_end=case when (v_object->>'current_period_end')~'^[0-9]+$' then to_timestamp((v_object->>'current_period_end')::double precision) end;
   v_cancel=coalesce((v_object->>'cancel_at_period_end')::boolean,false);
   select package_id into v_package_id from product.packages where package_key=v_package_key;
   if v_user is not null then
     update product.subscriptions set status=v_status,package_id=coalesce(v_package_id,package_id),
       external_provider='stripe',billing_provider='stripe',external_customer_id=v_customer,
       external_subscription_id=v_subscription,current_period_start=v_start,current_period_end=v_end,
       cancel_at_period_end=v_cancel,canceled_at=case when v_status='cancelled' then now() else null end,
       metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('stripe_status',v_object->>'status'),updated_at=now()
     where user_id=v_user and (external_subscription_id=v_subscription or status='trialing');
     if not found then
       insert into product.subscriptions(user_id,package_id,status,current_period_start,current_period_end,cancel_at_period_end,
         external_provider,billing_provider,external_customer_id,external_subscription_id,metadata)
       values(v_user,v_package_id,v_status,v_start,v_end,v_cancel,'stripe','stripe',v_customer,v_subscription,
         jsonb_build_object('stripe_status',v_object->>'status'));
     end if;
   end if;
 elsif v_type in ('invoice.paid','invoice.payment_failed') then
   v_subscription=coalesce(v_object->>'subscription',v_object#>>'{parent,subscription_details,subscription}');
   if v_subscription is not null then
     update product.subscriptions set
       status=case when v_type='invoice.paid' then 'active' else 'past_due' end,
       metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('last_invoice_event',v_type,'last_invoice_id',v_object->>'id'),
       updated_at=now()
     where external_subscription_id=v_subscription;
   end if;
 end if;
 return jsonb_build_object('complete',true,'duplicate',false,'event_type',v_type);
end $$;

revoke all on function public.bridgepoint_billing_apply_event_v65(jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_billing_apply_event_v65(jsonb) to service_role;

