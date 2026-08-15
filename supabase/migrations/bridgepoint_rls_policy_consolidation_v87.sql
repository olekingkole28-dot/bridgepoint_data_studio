-- BridgePoint V87: consolidate overlapping customer-facing RLS policies.
-- This keeps the same or stricter access while removing duplicate permissive
-- evaluations and wrapping auth.uid() in a scalar subquery for scale.

-- Customer notifications: customers may read and mark their own notifications;
-- platform administrators and explicit owner overrides retain operational access.
drop policy if exists bp_notifications_self on notifications.notifications;
drop policy if exists notifications_own_all on notifications.notifications;
drop policy if exists notifications_sql20_read on notifications.notifications;
drop policy if exists notifications_sql20_update on notifications.notifications;
create policy notifications_read_v87 on notifications.notifications
  for select to authenticated
  using (
    user_id=(select auth.uid())
    or accounts.is_platform_admin()
    or product.has_platform_override((select auth.uid()))
  );
create policy notifications_update_v87 on notifications.notifications
  for update to authenticated
  using (
    user_id=(select auth.uid())
    or accounts.is_platform_admin()
    or product.has_platform_override((select auth.uid()))
  )
  with check (
    user_id=(select auth.uid())
    or accounts.is_platform_admin()
    or product.has_platform_override((select auth.uid()))
  );

-- Personal customer workspace tables.
drop policy if exists bp_calendar_self on product.calendar_items;
drop policy if exists calendar_items_own_all on product.calendar_items;
create policy calendar_items_access_v87 on product.calendar_items
  for all to authenticated
  using (user_id=(select auth.uid()) or accounts.is_platform_admin())
  with check (user_id=(select auth.uid()) or accounts.is_platform_admin());

drop policy if exists bp_favorites_self on product.favorites;
drop policy if exists favorites_own_all on product.favorites;
create policy favorites_access_v87 on product.favorites
  for all to authenticated
  using (user_id=(select auth.uid()) or accounts.is_platform_admin())
  with check (user_id=(select auth.uid()) or accounts.is_platform_admin());

drop policy if exists bp_onboarding_answers_self on product.onboarding_answers;
drop policy if exists onboarding_answers_own_all on product.onboarding_answers;
create policy onboarding_answers_access_v87 on product.onboarding_answers
  for all to authenticated
  using (user_id=(select auth.uid()) or accounts.is_platform_admin())
  with check (user_id=(select auth.uid()) or accounts.is_platform_admin());

drop policy if exists bp_onboarding_questions_read on product.onboarding_questions;
drop policy if exists onboarding_questions_authenticated_read on product.onboarding_questions;
create policy onboarding_questions_read_v87 on product.onboarding_questions
  for select to authenticated
  using (coalesce(active,true) or accounts.is_platform_admin());

drop policy if exists bp_package_models_read on product.package_models;
drop policy if exists package_models_authenticated_read on product.package_models;
create policy package_models_read_v87 on product.package_models
  for select to authenticated using (true);

drop policy if exists bp_packages_read on product.packages;
drop policy if exists packages_authenticated_read on product.packages;
create policy packages_read_v87 on product.packages
  for select to authenticated
  using (coalesce(active,true) or accounts.is_platform_admin());

drop policy if exists bp_subscriptions_self on product.subscriptions;
drop policy if exists subscriptions_own_read on product.subscriptions;
create policy subscriptions_read_v87 on product.subscriptions
  for select to authenticated
  using (
    user_id=(select auth.uid())
    or accounts.is_platform_admin()
    or product.has_platform_override((select auth.uid()))
    or exists(
      select 1 from product.organization_members_v80 m
      where m.organization_id=product.subscriptions.organization_id
        and m.user_id=(select auth.uid()) and m.active
    )
  );

-- Automation rules: system rules are readable; only owners/overrides can write.
drop policy if exists automation_rules_read on automation.rules;
drop policy if exists automation_rules_write on automation.rules;
create policy automation_rules_read_v87 on automation.rules
  for select to authenticated
  using (is_system_rule or owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
create policy automation_rules_insert_v87 on automation.rules
  for insert to authenticated
  with check (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
create policy automation_rules_update_v87 on automation.rules
  for update to authenticated
  using (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  with check (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
create policy automation_rules_delete_v87 on automation.rules
  for delete to authenticated
  using (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));

drop policy if exists automation_rule_actions_read on automation.rule_actions;
drop policy if exists automation_rule_actions_write on automation.rule_actions;
create policy automation_rule_actions_read_v87 on automation.rule_actions
  for select to authenticated
  using (exists(
    select 1 from automation.rules r where r.rule_id=rule_actions.rule_id
      and (r.is_system_rule or r.owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  ));
create policy automation_rule_actions_insert_v87 on automation.rule_actions
  for insert to authenticated
  with check (exists(
    select 1 from automation.rules r where r.rule_id=rule_actions.rule_id
      and (r.owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  ));
create policy automation_rule_actions_update_v87 on automation.rule_actions
  for update to authenticated
  using (exists(
    select 1 from automation.rules r where r.rule_id=rule_actions.rule_id
      and (r.owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  ))
  with check (exists(
    select 1 from automation.rules r where r.rule_id=rule_actions.rule_id
      and (r.owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  ));
create policy automation_rule_actions_delete_v87 on automation.rule_actions
  for delete to authenticated
  using (exists(
    select 1 from automation.rules r where r.rule_id=rule_actions.rule_id
      and (r.owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  ));

-- Score/model visibility no longer has duplicate broad read policies.
drop policy if exists bp24_entity_scores_read on scoring.entity_scores;
drop policy if exists entity_scores_admin_read on scoring.entity_scores;
create policy entity_scores_read_v87 on scoring.entity_scores
  for select to authenticated using (true);

drop policy if exists bp24_models_read on scoring.models;
drop policy if exists scoring_models_authenticated_read on scoring.models;
create policy scoring_models_read_v87 on scoring.models
  for select to authenticated
  using (visibility=any(array['platform'::text,'public'::text,'marketplace'::text]) or accounts.is_platform_admin());

-- Action templates: system templates are readable; owners/overrides can write.
drop policy if exists action_templates_owner_write on workflow.action_templates;
drop policy if exists action_templates_read on workflow.action_templates;
create policy action_templates_read_v87 on workflow.action_templates
  for select to authenticated
  using (is_system_template or owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
create policy action_templates_insert_v87 on workflow.action_templates
  for insert to authenticated
  with check (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
create policy action_templates_update_v87 on workflow.action_templates
  for update to authenticated
  using (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())))
  with check (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
create policy action_templates_delete_v87 on workflow.action_templates
  for delete to authenticated
  using (owner_user_id=(select auth.uid()) or product.has_platform_override((select auth.uid())));
