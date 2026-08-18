from pathlib import Path
import json
import re
import runpy

body=Path('lib/main.dart').read_text(encoding='utf-8')
web=Path('web/index.html').read_text(encoding='utf-8')
manifest=json.loads(Path('web/manifest.json').read_text(encoding='utf-8'))
errors=[]

def require(label,*needles):
    for needle in needles:
        if needle not in body:
            errors.append(f'{label}: missing {needle}')

def require_web(label,*needles):
    for needle in needles:
        if needle not in web:
            errors.append(f'{label}: missing {needle}')

def forbid(label,*needles):
    for needle in needles:
        if needle in body:
            errors.append(f'{label}: forbidden legacy/customer text still present: {needle}')

require('release identity',
        'https://bridgepointintelligence.online/',
        'bridgepoint-v290-semantic-immersive-backgrounds',
        'bridgepoint-v309-semantic-immersive-compile',
        'bridgepoint-v304-customer-plain-language',
        'bridgepoint-v306-live-density-heat',
        'bridgepoint-v312-cinematic-parallax-background')

require('immersive rendering',
        '_BridgePointCinematicAtmosphereV312',
        'painter:_BridgePointCinematicAtmosphereV312',
        '_bridgePointPageAccentV290',
        'scene:spec.scene',
        'panel.withOpacity(.90)',
        'disableAnimations',
        'parallax terrain',
        'atmospheric ribbons',
        'depth particles')

if 'CustomPaint(painter:_BridgePointSemanticScenePainterV290' in body:
    errors.append('immersive rendering: old semantic diagram painter is still active')
if 'CustomPaint(painter:_BridgePointSpatialAtmospherePainterV287' in body:
    errors.append('immersive rendering: old spatial grid painter is still active')

for label in [
    'Daily Brief','Opportunities','Intelligence Map','Properties','My Home','My Work','Field Mode',
    'Weather Center','Signals','Community','Pattern Intelligence','Packages','About BridgePoint','Sources',
    'Permit Context','Coverage','Models','Settings','Owner Center','Founder Command','Owner Demo'
]:
    if f"'{label}'" not in body:
        errors.append(f'immersive page map: missing page label {label}')

require('live map layers',
        '_showHeatmap',
        'DENSITY HEAT',
        "label:Text(_showHeatmap?'Density heat':'Heat'",
        'MarkerLayer(markers:heatMarkers)',
        'bridgepoint_live_clusters_v250',
        'Center on my current location',
        'NOAA LIVE RAIN RADAR • WEATHER MOTION')

require('customer/owner boundary',
        '_effectiveOwnerMode',
        'CUSTOMER PREVIEW',
        'DEMO • NO CHARGE',
        'This preview never opens a payment session.',
        "configuration['checkout_ready']==true&&configuration['available_for_self_checkout']==true")

require('accessibility',
        'Larger text',
        'Stronger contrast',
        'Reduce motion and scanning effects',
        'Simplified views (hide optional map layers)')

require('legal and privacy',
        'BridgePoint Legal & Trust Summary',
        'not professional advice or proof of damage, coverage, a permit, customer intent, or a guaranteed outcome',
        'privacy')

require('launch-critical customer workflows',
        'Send to CRM','Customize Dashboard','Save my info for next time','Your nickname',
        'Center on my current location','Property Image History','Add / update front photo',
        'BridgePoint Community Chat','Show more plans','Sign out')

require_web('automatic app install onboarding',
            'bridgepoint-v310-install-onboarding',
            'bridgepoint_app_installed_v310',
            'beforeinstallprompt',
            'appinstalled',
            '(display-mode: standalone)',
            'hasAuthSession',
            'Install BridgePoint',
            'Add to Home Screen',
            'bridgePointShowInstallGuide')

if manifest.get('display')!='standalone':
    errors.append(f"pwa manifest: display must be standalone, found {manifest.get('display')!r}")
if not manifest.get('name') or not manifest.get('icons'):
    errors.append('pwa manifest: app name/icons missing')

forbid('plain-language customer polish',
       'BridgePoint V81 uses negative scoring',
       'V36 compound property intelligence',
       'Search BridgePoint’s canonical property inventory.',
       'Automatically rendered from Supabase — no hard-coded source cards')

empty_patterns=[
    r'onPressed\s*:\s*\(\)\s*\{\s*\}',
    r'onTap\s*:\s*\(\)\s*\{\s*\}',
    r'onPressed\s*:\s*\(\s*\)\s*=>\s*null',
    r'onTap\s*:\s*\(\s*\)\s*=>\s*null',
]
for pat in empty_patterns:
    if re.search(pat,body,re.S):
        errors.append(f'interaction audit: empty/dead callback matched {pat}')

require('customer-safe evidence', '_bridgePointCustomerSafeKey')

if errors:
    print('BRIDGEPOINT FINAL RELEASE AUDIT FAILED')
    for item in errors:
        print(' -',item)
    raise SystemExit(1)

print('BRIDGEPOINT FINAL RELEASE AUDIT PASSED')
print(' - cinematic parallax background is the active workspace renderer')
print(' - live cluster/radar/location/density-heat map contract present')
print(' - automatic signed-in app-install onboarding present for PWA-capable browsers and iOS/Android fallbacks')
print(' - customer preview/no-charge and checkout gates present')
print(' - customer-facing technical-version wording removed')
print(' - accessibility/legal/privacy/customer-safe evidence contracts present')
print(' - no empty click handlers detected')

runpy.run_path('tool/fix_owner_expansion_resilience_v313.py',run_name='__main__')
runpy.run_path('tool/apply_dna_tunnel_background_v313.py',run_name='__main__')
runpy.run_path('tool/final_polish_audit_v313.py',run_name='__main__')

# Owner chose manual social posting. Preserve About/profile links but remove all automatic
# provider connection, OAuth and publishing controls from the final generated production source.
runpy.run_path('tool/remove_auto_social_publishing_v316.py',run_name='__main__')

# v318 restores the timed-out launch-hardening work after the v316 manual-social layer:
# package-exact customer navigation and moving NOAA precipitation/radar intensity context.
runpy.run_path('tool/apply_access_weather_v318.py',run_name='__main__')

# v319 adds the owner-only all/top Pattern Intelligence operating view and repairs every
# NOAA WMS radar renderer to use ISO time frames with preloaded, stronger precipitation motion.
runpy.run_path('tool/apply_owner_patterns_radar_v319.py',run_name='__main__')

# v320 adds source-failover/maintenance customer protection, unsupported-market handling,
# and the owner-only resilience operating panel backed by automated health and credit ledgers.
# The originally committed compressed payload has a one-character Base64 corruption; the
# recovery runner reconstructs it and still requires the exact recorded v320 output hash.
runpy.run_path('tool/recover_resilience_market_v320.py',run_name='__main__')

# Temporary v321 generated-source inspection. This is replaced by the guarded v321 patch after
# CI prints the exact post-v320 radar/map/coverage targets.
runpy.run_path('tool/inspect_v321_targets.py',run_name='__main__')
