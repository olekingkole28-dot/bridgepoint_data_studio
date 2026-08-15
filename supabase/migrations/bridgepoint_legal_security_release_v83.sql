-- BridgePoint V83
-- Release legal notices and low-risk security/performance hardening.
-- These documents are a product draft and remain subject to review by licensed counsel.

update product.legal_documents_v82
set active=false
where document_key in('TERMS','PRIVACY','ACCEPTABLE_USE','DATA_DISCLAIMER','FIELD_TRACKING_NOTICE');

insert into product.legal_documents_v82(
  document_key,document_version,title,summary,content_markdown,required,active,effective_at)
values
('TERMS','2026-08-15.1','Terms of Service',
 'Account rules, trial and subscription disclosures, permitted use, data limits, liability, disputes, and cancellation.',
$doc$# BridgePoint Intelligence Terms of Service

Effective August 15, 2026. BridgePoint Intelligence ("BridgePoint," "we," "us," or "our") provides the software service described below. By creating an account, accepting these Terms electronically, starting a trial, purchasing a plan, or using the service, you agree to these Terms and the active Privacy Notice, Acceptable Use Policy, and Data & Scoring Disclaimer. You must be at least 18 and legally authorized to act for the person or organization on the account. If you do not agree, do not use the service.

## The service

BridgePoint provides property-intelligence, mapping, weather context, public-record context, scoring, routing, notes, team workflow, field coordination, notifications, and customer-authorized claim workflow. Features and source coverage vary by plan, geography, source availability, and device. Other states shown as locked are not sold or unlocked until their required data, quality, legal-access, automation, and billing checks are live.

BridgePoint is a decision-support tool. It is not a law firm, insurer, public adjuster, engineering firm, inspection service, appraisal service, meteorological service, lender, tax adviser, or emergency service, and it does not provide professional advice. A score, signal, map marker, radar image, pattern, address match, or alert is not proof of damage, ownership, permit status, code violation, insurance coverage, causation, customer intent, or a guaranteed job, claim, sale, or outcome. Verify material facts with the cited source and qualified professionals before acting.

## Accounts and organizations

Use accurate information, keep credentials and recovery codes private, use a separate account for every person, and promptly report suspected unauthorized access. Organization owners control seats and roles and are responsible for team users, lawful employment practices, required monitoring notices, and removal of access when a worker leaves. Live Field Assist requires a separate, voluntary in-app start action and device permission. Shared accounts, covert tracking, bypassing access controls, or misrepresenting authority are prohibited.

## Trials, subscriptions, promotions, and taxes

Unless checkout says otherwise, an eligible new paid plan includes a seven-day trial and automatically becomes a paid, recurring subscription at the price and interval displayed at checkout unless canceled before the trial ends. The first-ten-customer promotion, when shown and confirmed at checkout, provides 50% off the first six eligible monthly subscription charges after the trial; eligibility, redemption count, compatible plan, and the checkout display control. Promotions have no cash value, cannot be transferred or stacked, and do not apply retroactively. Annual or geographic offers apply only when their exact discount is displayed at checkout.

Subscriptions automatically renew until canceled. You may change or cancel a plan through the billing portal; cancellation normally takes effect at the end of the paid period unless law or checkout says otherwise. Stripe processes payment information. You authorize recurring charges, applicable taxes, and disclosed usage or seat charges. Except where law requires otherwise or checkout states otherwise, earned fees are non-refundable. Failed payment, chargeback abuse, or material breach may suspend access after any notice required by law.

## Customer content and privacy

You retain ownership of notes, uploaded material, and authorized business content you provide. You grant BridgePoint a limited license to host, process, secure, back up, and display that content only to provide, protect, and improve the service as described in the Privacy Notice. Do not upload protected health information, payment-card data, government credentials, unlawful contact lists, trade secrets you lack authority to disclose, or claim information without authorization. You are responsible for the legality, accuracy, and permissions for customer content.

## BridgePoint property and source rights

BridgePoint and its licensors retain all rights in the software, interface, models, scoring logic, documentation, compiled intelligence, trademarks, and non-customer content. Source data remains subject to its provider's terms, licenses, attribution, accuracy, retention, and access limits. You may use results inside your subscribed workflow but may not scrape, bulk export beyond plan limits, resell, sublicense, reverse engineer, train a competing model from the service, evade technical limits, or falsely present BridgePoint content as an official government, insurer, or inspection record.

## Lawful use

You must follow the Acceptable Use Policy and all applicable licensing, insurance, employment, electronic-monitoring, privacy, consumer-protection, advertising, telemarketing, texting, email, do-not-call, quiet-hours, door-to-door solicitation, trespass, driving, safety, fair-housing, and anti-discrimination laws. BridgePoint does not authorize contact with any person. You decide whether and how outreach is lawful and must honor opt-outs and property-access restrictions.

## Service changes, suspension, and termination

Sources, scores, packages, and features may change as records are corrected, providers change, or quality controls improve. We may remove an unsafe or unreliable result, limit abusive traffic, preserve evidence, or suspend access reasonably necessary to protect customers, sources, the public, or the service. You may stop using the service and cancel the subscription. Sections that logically survive termination—including payment obligations, ownership, disclaimers, liability limits, dispute terms, and lawful preservation—continue to apply.

## Disclaimers

To the maximum extent permitted by law, the service is provided "as is" and "as available," without implied warranties of merchantability, fitness for a particular purpose, title, non-infringement, uninterrupted operation, or accuracy. We do not warrant that a source is complete or current, that a property match is correct, that notifications arrive, or that use produces revenue. Nothing in these Terms excludes a warranty or remedy that applicable law does not allow parties to exclude.

## Limitation of liability

To the maximum extent permitted by law, BridgePoint and its suppliers will not be liable for indirect, incidental, special, consequential, exemplary, or punitive damages, lost profits, lost opportunities, lost data, business interruption, field injury, property access, customer outreach, or decisions made from unverified intelligence. BridgePoint's aggregate liability arising from the affected service will not exceed the subscription fees actually paid for that service during the six months before the event. These limits do not apply where prohibited by law or to liability that cannot lawfully be limited.

## Indemnity

To the extent permitted by law, an organization using BridgePoint will defend and indemnify BridgePoint from third-party claims arising from its customer content, unlawful outreach, trespass, discriminatory use, employment or monitoring practices, professional statements, credential sharing, or material violation of these Terms. This obligation does not cover claims caused by BridgePoint's own unlawful conduct and is subject to prompt notice and reasonable control of the defense.

## Disputes and governing law

Before filing a non-emergency claim, the parties will give written notice through the in-app support or legal channel and attempt good-faith resolution for 30 days. Connecticut law governs, without regard to conflict rules. Unless applicable law requires otherwise, exclusive venue lies in the state or federal courts located in Connecticut. Either party may seek urgent injunctive relief for security, confidentiality, intellectual-property, or access-control misuse. Nothing waives a non-waivable consumer right.

## General terms

These Terms, the active notices incorporated above, and the checkout order form are the entire agreement for the service. A checkout order controls only for conflicting price, plan, seat, geography, or billing terms. Invalid provisions are limited or severed without invalidating the rest. Failure to enforce a term is not a waiver. You may not assign the agreement without our consent; we may assign it in a merger, financing, sale, or reorganization. Neither party is liable for delay caused by events beyond reasonable control, except payment obligations. No third party is a beneficiary. Electronic notices and acceptances satisfy writing requirements to the extent permitted by law. Material changes will be presented in the service and new consent requested when required.
$doc$,true,true,'2026-08-15T00:00:00Z'),

('PRIVACY','2026-08-15.1','Privacy Notice',
 'Data categories, sources, purposes, processors, retention, location privacy, security, and individual rights.',
$doc$# BridgePoint Intelligence Privacy Notice

Effective August 15, 2026. This Notice explains how BridgePoint handles personal data. It applies to account holders, trial users, organization members, support contacts, and visitors to the BridgePoint application. Property and public-record information may concern owners or addresses but is not treated as proof of identity, behavior, condition, or eligibility.

## Data we collect

We collect account and profile details; authentication and security records; plan, entitlement, seat, invoice, and Stripe customer status; onboarding answers; settings and accessibility choices; searches and recently viewed properties; saved opportunities, lead stages, notes, calendar items, suggestions, privacy requests, and customer-authorized claim workflow; device, browser, IP, diagnostics, and audit logs; and precise device location only after an eligible user explicitly starts a field shift and grants device permission.

Property intelligence comes from identified public, licensed, provider-authorized, customer-authorized, or otherwise lawful sources. Each source can have different coverage, delay, correction, attribution, and license rules. We also derive signals, patterns, confidence measures, negative adjustments, and rankings from those records.

## Why we use data

We use data to authenticate users; provide and personalize plans; enforce geographic and role access; rank and explain opportunities; synchronize work; provide field coordination; process billing; deliver requested alerts; answer support and privacy requests; prevent fraud and abuse; diagnose and improve reliability; maintain backups and audit evidence; comply with law; and establish, exercise, or defend legal claims. We do not use precise field location for advertising or sell it.

## Sharing and processors

We disclose the minimum information reasonably needed to service providers such as Supabase for infrastructure and authentication and Stripe for billing. Providers process data under their own contractual and legal obligations. We may disclose information to an organization administrator according to the roles described in the service; at a user's direction; during a corporate transaction subject to appropriate protections; or when reasonably necessary to comply with lawful process, protect safety, investigate abuse, or defend rights. BridgePoint does not sell customer account data and does not share it for cross-context behavioral advertising.

## Precise location and team visibility

Live Field Assist collects latitude, longitude, accuracy, time, and available movement information only after Start field shift is pressed. A visible status indicates sharing. Authorized Company owners, co-owners, and managers may view a current field location for coordination and safety. A point leaves the live view after 15 minutes and is deleted after seven days. Stopping the shift or leaving Field Mode ends app sharing. Device or operating-system behavior may differ; users should verify the on-screen status. An employer remains responsible for any additional monitoring notice, consent, labor, and records duties.

## Retention

Retention depends on purpose. Live field points are deleted after seven days. Configuration recovery snapshots are retained for 30 days. Supabase project backups follow the active infrastructure plan. Account content is generally retained while the account is active and for a reasonable period after closure. Billing, acceptance, security, fraud, tax, dispute, and legally required records may be kept longer. Backups age out on their normal schedule. We delete or de-identify information when it is no longer reasonably needed, subject to legal holds and restoration integrity.

## Choices and rights

Settings control in-app alerts, optional device-push requests, display choices, daily notes, and location sharing. Billing controls plan changes and cancellation. Depending on applicable law, a person may request access, correction, deletion, or a portable copy; opt out of covered sale, targeted advertising, or qualifying profiling; withdraw consent where processing relies on consent; or appeal a denied request. File a request through Settings → Legal & Trust Center. We verify identity and authority before releasing or changing data. We generally respond within 45 days when the Connecticut Data Privacy Act applies and may use a lawful extension with notice. We will not discriminate for exercising a protected privacy right.

BridgePoint will recognize legally applicable universal opt-out signals for processing subject to such signals. BridgePoint currently states that it does not sell customer account data or use it for targeted advertising, so an opt-out may confirm that no covered activity is occurring.

## Security and international processing

We use role checks, row-level security, limited service credentials, audit records, encryption provided by infrastructure vendors, short location retention, and operational backups. No system is completely secure. Use a unique password and multi-factor authentication when available and report suspicious access. Service providers may process data in the United States or other locations under applicable safeguards.

## Children, changes, and contact

The service is for adults and organizations and is not directed to children under 13. We do not knowingly collect children's data through the service. Material changes will be dated, shown in the app, and presented for new consent when required. Contact BridgePoint or submit a privacy request through the in-app Legal & Trust Center so the request remains tied to a verified account.
$doc$,true,true,'2026-08-15T00:00:00Z'),

('ACCEPTABLE_USE','2026-08-15.1','Acceptable Use & Field Conduct',
 'Safety, truthful evidence use, anti-discrimination, lawful outreach, field access, and prohibited conduct.',
$doc$# Acceptable Use and Field Conduct

Use BridgePoint only for a legitimate, lawful business or homeowner purpose. Do not use it to discriminate in housing, lending, insurance, employment, contracting, pricing, service, or advertising; infer or target protected traits; redline or exclude protected communities; harass, intimidate, stalk, or surveil a person; trespass; evade a no-soliciting rule; impersonate a government agency, emergency service, insurer, adjuster, contractor, owner, or source provider; fabricate evidence; or state that radar, a score, a signal, a pattern, or public data proves damage, liability, coverage, code status, or customer need.

Before calling, emailing, texting, mailing, advertising, or visiting, comply with federal, state, and local licensing, registration, consumer-protection, telemarketing, text-message, commercial-email, do-not-call, quiet-hours, consent, opt-out, and door-to-door solicitation rules. Use accurate sender and subject information, include legally required identity and postal-address disclosures, provide a working opt-out, and honor opt-outs promptly. Do not upload or use purchased contact data unless acquisition, disclosure, consent, and intended use are lawful and documented.

Field users must remain in lawful public or invited areas, obtain permission before inspection or photography, avoid distracted driving, obey site and weather hazards, and verify a property and decision-maker before making a claim. Never use Live Field Assist covertly. Organization managers must provide any required electronic-monitoring or employment notice, limit viewing to legitimate coordination and safety, and avoid unlawful discipline or off-shift monitoring.

Do not share credentials, introduce malware, probe security, overload or scrape the service, bypass a paywall or geographic lock, reverse engineer, bulk resell data, remove attribution, interfere with another user, submit unlawful or infringing content, or use BridgePoint to train or operate a competing property-intelligence product without written permission.

BridgePoint may limit, suspend, preserve evidence, or terminate access when reasonably necessary to investigate a violation, protect safety, comply with lawful process, protect source licenses, or secure the service. Report suspected abuse through Settings → Suggestions & feedback or the Legal & Trust Center.
$doc$,true,true,'2026-08-15T00:00:00Z'),

('DATA_DISCLAIMER','2026-08-15.1','Data & Scoring Disclaimer',
 'How sources, property matching, direct signals, area context, patterns, negative scoring, radar, and timelines must be interpreted.',
$doc$# Data and Scoring Disclaimer

Every source has its own coverage, delay, accuracy, correction process, license, and update schedule. "Live" means BridgePoint is connected and refreshing on the stated schedule; it does not mean every provider reports instantly. Official, public, licensed, and customer-provided records can be incomplete, corrected, delayed, duplicated, geocoded incorrectly, or matched to the wrong property. Confirm the address, parcel, municipality, source date, matching method, and current source record before relying on material information.

A signal is one dated observation. Property-linked means BridgePoint associated the observation with a property record; it does not guarantee the source itself verified the current condition. Area context describes a broader geography and is never a property-specific claim. A pattern connects multiple observations and can corroborate timing or context, but a pattern is not direct evidence by itself.

V83 customer opportunities require at least one named, non-area direct signal mapped to the opportunity type, plus confidence, source, recency, and corroboration gates. The score adds direct evidence strength and subtracts visible quality penalties. The requested feed then keeps only the highest qualifying opportunity for each property identity, including package-specific feeds. A high score prioritizes human review; it does not predict a guaranteed sale, project, claim, loss, damage, permit, customer response, or financial outcome.

NOAA/NWS radar and weather signals provide general weather or exposure context. They are not a meteorologist-certified hail swath, forensic causation report, inspection, or proof of property damage. FEMA and NFIP area records are not proof that a specific property filed or received a claim. Building outlines, heights, and measurements are approximate unless the source explicitly states survey-grade accuracy. Claim-specific facts are customer-entered or received from an explicitly authorized integration and are kept separate from public evidence.

The property timeline names the signal, source/provider, effective date, confidence, severity, match method, evidence level, direct-model use, why it may matter, and a limitation. Users must still open or verify the underlying source and use licensed professionals where inspection, engineering, adjusting, coverage, valuation, legal, tax, or safety conclusions are required.
$doc$,true,true,'2026-08-15T00:00:00Z'),

('FIELD_TRACKING_NOTICE','2026-08-15.1','Live Field Assist Notice & Consent',
 'Separate consent for foreground precise-location sharing in an eligible Company workspace.',
$doc$# Live Field Assist Notice and Consent

Live Field Assist collects precise device location only after you press Start field shift, accept this notice, and grant device permission. While Field Mode remains open during that shift, the app sends available latitude, longitude, accuracy, time, heading, and movement information when you move or approximately once per minute. A visible in-app status shows that sharing is active.

Current location is visible only to you and authorized owners, co-owners, and managers in the same eligible Company workspace. It is used for coordination, dispatch, avoiding duplicate visits, and field safety. It is not sold or used for advertising. A point leaves the live view after 15 minutes and is deleted after seven days. You can stop at any time. Leaving Field Mode ends app sharing; verify that the status says location sharing is off.

Location can be sensitive and can reveal visits or movement. Do not start a shift if you do not agree. Do not use the feature while driving. Your employer or organization—not BridgePoint—is responsible for any additional electronic-monitoring, employment, union, consent, notice, records, off-duty, or disciplinary requirements and must not use Live Field Assist for covert or unlawful surveillance.
$doc$,false,true,'2026-08-15T00:00:00Z')
on conflict(document_key,document_version) do update set
  title=excluded.title,summary=excluded.summary,content_markdown=excluded.content_markdown,
  required=excluded.required,active=excluded.active,effective_at=excluded.effective_at;

-- Extension-owned spatial_ref_sys remains managed by PostGIS. Remove only anonymous
-- execution of the three exposed SECURITY DEFINER estimation helpers.
revoke execute on function public.st_estimatedextent(text,text) from public,anon;
revoke execute on function public.st_estimatedextent(text,text,text) from public,anon;
revoke execute on function public.st_estimatedextent(text,text,text,boolean) from public,anon;

-- Remove only exact duplicate indexes reported by the Supabase performance advisor.
drop index if exists ingest.idx_data_quality_rules_rule_key_unique;
drop index if exists notifications.idx_notifications_user;
drop index if exists product.idx_calendar_user_time;
drop index if exists product.idx_subscriptions_org;
drop index if exists product.idx_subscriptions_status;
drop index if exists product.idx_subscriptions_user;
drop index if exists solar.ct_rsip_projects_approved_idx;
drop index if exists solar.ct_rsip_projects_completed_idx;

comment on table product.legal_documents_v82 is
  'Versioned BridgePoint legal-product drafts. Production launch requires review and approval by licensed counsel for the operating entity and jurisdictions served.';
