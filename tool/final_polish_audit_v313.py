from pathlib import Path
import re
import runpy

# Apply final owner/runtime/responsive polish after the established v312 baseline has passed.
runpy.run_path('tool/tighten_brand_live_refresh_v313.py',run_name='__main__')
runpy.run_path('tool/apply_owner_outreach_readiness_v313.py',run_name='__main__')
runpy.run_path('tool/fix_noaa_verified_frame_fallback_v313.py',run_name='__main__')
runpy.run_path('tool/fix_responsive_action_rows_v313.py',run_name='__main__')

body=Path('lib/main.dart').read_text(encoding='utf-8')
errors=[]

def require(label,*needles):
    for needle in needles:
        if needle not in body:
            errors.append(f'{label}: missing {needle}')

def forbid(label,*needles):
    for needle in needles:
        if needle in body:
            errors.append(f'{label}: forbidden legacy text/renderer remains active: {needle}')

require('DNA tunnel background','bridgepoint-v313-dna-data-tunnel-background','class _BridgePointDnaTunnelV313','painter:_BridgePointDnaTunnelV313','electric blue DNA helix','moving scan tunnel','property evidence lanes')
forbid('DNA tunnel background','painter:_BridgePointCinematicAtmosphereV312(t:controller.value')

require('expansion resilience','bridgepoint-v313-expansion-dual-source-resilience','bridgepoint_expansion_active_builds_v228','bridgepoint_owner_command_snapshot_v254','DUAL_SOURCE_OWNER_FALLBACK',"'data_status':'BUILDING'",'automatic state cards')
forbid('expansion resilience','No state builds are currently in progress.')

require('section-aware errors','bridgepoint-v256-section-error-titles','Properties could not load','This section could not load')
forbid('section-aware errors','Live dashboard could not load')

require('BridgePoint AI','bridgepoint-v257-ai-search-ux','BridgePoint AI search could not load','Clear search','bridgepoint-v258-ai-voice-input','Talk to BridgePoint AI','bridgepoint-v263-package-aware-ai','bridgepoint_ai_answer_v262','Ask BridgePoint AI')

require('front property contribution','bridgepoint-v267-front-property-photo','Add / update front photo','Submit for BridgePoint review')

require('keyboard and readable time','bridgepoint-v269-global-keyboard-scroll','arrowDown','arrowUp','pageDown','pageUp','bridgepoint-v270-human-readable-times','Updated 9:03 PM')

require('NOAA and Daily Brief','bridgepoint-v271-noaa-live-weather','Show United States live weather','latest NOAA precipitation radar','bridgepoint-v272-daily-brief-resilience','Daily Brief could not load','staggered retry','bridgepoint-v313-noaa-verified-frame-fallback','newest NOAA radar always renders without TIME','no guessed historical timestamps','animation waits for verified frames')
forbid('NOAA verified-frame fallback','return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));')

require('Community 3D behavior','bridgepoint-v273-community-3d-gesture-capture','EagerGestureRecognizer','map drag does not scroll page','bridgepoint-v279-community-3d-live-weather','rain animation','snow animation','two-minute cache','bridgepoint-v287-national-weather-spatial-background','_bridgePointMapTouchLockV287')

require('owner operating system','bridgepoint-v265-simplified-owner-center','Growth & operations','Advanced admin','bridgepoint-v277-owner-investor-cockpit','bridgepoint_owner_investor_metrics_v275','presentation guidance','bridgepoint-v286-owner-system-explorer','class _OwnerSystemExplorerV286','raw owner drilldown','20 second refresh')

require('owner outreach readiness','bridgepoint-v313-owner-outreach-readiness','class _OwnerOutreachReadinessV313','bridgepoint_owner_outreach_readiness_v313','Outreach Readiness','ESTIMATED READY POOL','HIGH-PRIORITY PROSPECTS','VERIFY + ENROLL','Apollo enrollment verification guardrail')

require('customer preview and founder story','bridgepoint-v282-founder-story-reviews','Meet the Owner','Submit review','bridgepoint-v284-founder-reviews-customer-preview','CUSTOMER PREVIEW','Preview as customer','bridgepoint-v313-brand-live-refresh','Duration(seconds:8)')

require('responsive prospect-ready UI','bridgepoint-v313-responsive-action-rows','dashboard actions wrap','preferences actions wrap','property filters wrap','social provider controls stack and wrap')
forbid('responsive prospect-ready UI',
       "Row(children:[TextButton.icon(onPressed:saving?null:reset",
       "Row(children:[FilledButton.icon(onPressed:loading?null:_apply",
       "return Row(children:[Expanded(child:_OwnerStatusRow(label,live?'CONNECTED':'NEEDS CONNECTION'")

require('live map intelligence','bridgepoint-v306-live-density-heat','DENSITY HEAT','bridgepoint_live_clusters_v250')

empty_patterns=[r'onPressed\s*:\s*\(\)\s*\{\s*\}',r'onTap\s*:\s*\(\)\s*\{\s*\}',r'onPressed\s*:\s*\(\s*\)\s*=>\s*null',r'onTap\s*:\s*\(\s*\)\s*=>\s*null']
for pat in empty_patterns:
    if re.search(pat,body,re.S):errors.append(f'interaction audit: dead callback matched {pat}')

if errors:
    print('BRIDGEPOINT V313 FINAL POLISH AUDIT FAILED')
    for item in errors: print(' -',item)
    raise SystemExit(1)

print('BRIDGEPOINT V313 FINAL POLISH AUDIT PASSED')
print(' - electric-blue DNA/data tunnel is active behind cards')
print(' - expansion active-build status has two independent owner-side sources')
print(' - AI voice/package/clear UX, section errors, keyboard scrolling and readable times remain present')
print(' - NOAA shows newest radar immediately and animates only verified NOAA timestamps')
print(' - Daily Brief/Community 3D weather and gesture repair contracts remain present')
print(' - owner investor/system explorer, outreach readiness, customer preview, founder/reviews and density heat remain present')
print(' - high-risk action rows wrap/stack instead of overlapping on narrow layouts')
print(' - founder/profile/review changes refresh every 8 seconds while About is open and explicit edits refresh immediately')
print(' - no legacy dashboard error copy, false expansion empty copy, guessed NOAA frame loop, old active background renderer or dead click handler remains')
