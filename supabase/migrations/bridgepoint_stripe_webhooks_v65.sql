-- BridgePoint Intelligence v65
-- Idempotent Stripe webhook application for subscription state.
begin;

create or replace function public.bridgepoint_billing_apply_event_v65(p_event jsonb)
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,product
as $function$
declare
 v_id text:=p_event->>'id'; v_type text:=p_event->>'type'; v_object jsonb:=p_event#>'{data,object}';
 v_user uuid; v_package_key text; v_package_id uuid; v_customer text; v_subscription text; v_status text;
 v_start timestamptz; v_end timestamptz; v_cancel boolean:=false; v_inserted integer;
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
   if v_user is not null and v_customer is not null then
     insert into product.stripe_customers_v64(user_id,stripe_customer_id)
     values(v_user,v_customer) on conflict(user_id) do update set stripe_customer_id=excluded.stripe_customer_id,updated_at=now();
     select package_id into v_package_id from product.packages where package_key=v_package_key;
     update product.subscriptions set package_id=coalesce(v_package_id,package_id),external_provider='stripe',billing_provider='stripe',
       external_customer_id=v_customer,external_subscription_id=v_subscription,updated_at=now(),
       metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('checkout_session_id',v_object->>'id')
     where user_id=v_user and status='trialing';
     update product.launch_promotion_assignments_v63 set status='applied',applied_at=now(),updated_at=now()
     where assignment_id=nullif(v_object#>>'{metadata,promotion_assignment_id}','')::uuid and user_id=v_user;
   end if;
 elsif v_type in ('customer.subscription.created','customer.subscription.updated','customer.subscription.deleted') then
   v_user=nullif(v_object#>>'{metadata,bridgepoint_user_id}','')::uuid;
   v_package_key=v_object#>>'{metadata,bridgepoint_package_key}';
   v_customer=v_object->>'customer'; v_subscription=v_object->>'id';
   v_status=case
     when v_type='customer.subscription.deleted' then 'cancelled'
     when v_object->>'status'='canceled' then 'cancelled'
     when v_object->>'status' in ('trialing','active','past_due','paused') then v_object->>'status'
     when v_object->>'status' in ('unpaid','incomplete','incomplete_expired') then 'past_due'
     else 'active' end;
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
 end if;
 return jsonb_build_object('complete',true,'duplicate',false,'event_type',v_type);
end;$function$;

revoke execute on function public.bridgepoint_billing_apply_event_v65(jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_billing_apply_event_v65(jsonb) to service_role;
commit;
