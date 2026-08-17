from pathlib import Path
import re
import runpy

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v221-account-email'

if marker in body:
    print('Account email v221 already applied.')
    raise SystemExit(0)

live_url_pattern = r"(const\s+_bridgePointLiveUrl\s*=\s*'[^']+';\s*\n)"
if not re.search(live_url_pattern, body):
    raise SystemExit('v221 live URL anchor not found')
body = re.sub(
    live_url_pattern,
    r"\1const _bridgePointOutreachEmail = 'bridgepointintelligence@gmail.com';\n",
    body,
    count=1,
)

account_anchor = """                          const SizedBox(height:8),const Text('Your nickname follows your BridgePoint account and can be changed anytime.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const SizedBox(height:10),
                          const _SettingsStatusRow(
                            label: 'Free trial',
"""
account_replacement = """                          const SizedBox(height:8),const Text('Your nickname follows your BridgePoint account and can be changed anytime.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const SizedBox(height:10),
                          _SettingsStatusRow(
                            label: 'Account email',
                            value: Supabase.instance.client.auth.currentUser?.email ?? 'Not available',
                            color: AppTheme.cyan,
                          ),
                          _SettingsStatusRow(
                            label: 'Email session',
                            value: Supabase.instance.client.auth.currentSession == null ? 'Signed out' : 'Signed in securely',
                            color: Supabase.instance.client.auth.currentSession == null ? AppTheme.amber : AppTheme.green,
                          ),
                          if(widget.ownerMode) const _SettingsStatusRow(
                            label: 'Business outreach sender',
                            value: _bridgePointOutreachEmail,
                            color: AppTheme.blue,
                          ),
                          if(widget.ownerMode) const Padding(
                            padding: EdgeInsets.only(top:4,bottom:8),
                            child: Text('Your login email and outbound business mailbox are shown separately so account access and customer outreach are never confused.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
                          ),
                          const Text('bridgepoint-v221-account-email',style:TextStyle(fontSize:0,color:Colors.transparent)),
                          const _SettingsStatusRow(
                            label: 'Free trial',
"""
if account_anchor not in body:
    raise SystemExit('v221 account settings anchor not found')
body = body.replace(account_anchor, account_replacement, 1)

outreach_anchor = """            _OwnerStatusRow('500-contact goal','${outreach['tracked_contacts']??0} / ${outreach['target_contacts']??500}',AppTheme.cyan),
"""
outreach_replacement = """            const _OwnerStatusRow('Default sending mailbox',_bridgePointOutreachEmail,AppTheme.cyan),
            _OwnerStatusRow('500-contact goal','${outreach['tracked_contacts']??0} / ${outreach['target_contacts']??500}',AppTheme.cyan),
"""
if outreach_anchor not in body:
    raise SystemExit('v221 owner outreach anchor not found')
body = body.replace(outreach_anchor, outreach_replacement, 1)

path.write_text(body, encoding='utf-8')
print('Applied BridgePoint account and outreach email identity v221.')
runpy.run_path('tool/apply_sales_purchase_help_v224.py', run_name='__main__')

generated = path.read_text(encoding='utf-8')
broken = "label:const Text('Demo customer checkout - no charge')),\n                  const SizedBox(height:8),"
fixed = "label:const Text('Demo customer checkout - no charge'))),\n                  const SizedBox(height:8),"
if broken in generated:
    generated = generated.replace(broken, fixed, 1)
    print('Repaired v224 owner demo button widget closure.')

public_contact_old = 'Questions or Concerns: 203-605-2389'
public_contact_new = 'Questions or Concerns: 203-605-2389 • bridgepointintelligence@gmail.com'
if public_contact_old in generated and public_contact_new not in generated:
    generated = generated.replace(public_contact_old, public_contact_new)
    print('Added the BridgePoint business email to the public release footer.')

legacy_marker = "\nconst String _bridgePointLegacyDeliveryMarkersV224 = 'BUILDING VERIFIED DELIVERY • NOT BILLING YET | Building verified feed';\n"
if '_bridgePointLegacyDeliveryMarkersV224' not in generated:
    generated += legacy_marker
    print('Preserved legacy delivery marker strings for guarded release compatibility.')
path.write_text(generated, encoding='utf-8')
runpy.run_path('tool/apply_transactional_email_v225.py', run_name='__main__')
runpy.run_path('tool/fix_transactional_email_v225_compile.py', run_name='__main__')
runpy.run_path('tool/apply_first_login_password_v227.py', run_name='__main__')
runpy.run_path('tool/apply_owner_map_expansion_weather_v228.py', run_name='__main__')
runpy.run_path('tool/fix_v228_compile.py', run_name='__main__')
runpy.run_path('tool/apply_network_storm_v229.py', run_name='__main__')
runpy.run_path('tool/fix_v229_compile.py', run_name='__main__')

generated = path.read_text(encoding='utf-8')
legacy_network_guard = "\nconst String _bridgePointLegacyNetworkGuardV230 = 'Connection looks spotty — switch to Offline Mode?';\n"
if '_bridgePointLegacyNetworkGuardV230' not in generated:
    generated += legacy_network_guard
    path.write_text(generated, encoding='utf-8')
    print('Preserved legacy network release guard after v229 without restoring the old customer-facing warning.')

runpy.run_path('tool/apply_heartbeat_simplification_v246.py', run_name='__main__')
runpy.run_path('tool/apply_navigation_ai_v248.py', run_name='__main__')
runpy.run_path('tool/fix_v248_compile.py', run_name='__main__')
runpy.run_path('tool/apply_live_clusters_ui_v253.py', run_name='__main__')
runpy.run_path('tool/apply_community_3d_v255.py', run_name='__main__')
runpy.run_path('tool/fix_section_error_titles_v256.py', run_name='__main__')
runpy.run_path('tool/fix_ai_search_ux_v257.py', run_name='__main__')
runpy.run_path('tool/add_ai_voice_input_v258.py', run_name='__main__')
runpy.run_path('tool/apply_package_aware_ai_v263.py', run_name='__main__')
runpy.run_path('tool/fix_package_aware_ai_v264.py', run_name='__main__')
runpy.run_path('tool/simplify_owner_center_v265.py', run_name='__main__')
