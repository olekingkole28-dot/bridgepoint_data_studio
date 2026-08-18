from pathlib import Path
import re

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')

# Remove the entire automatic social publishing/OAuth panel from the generated production UI.
start='class _OwnerGrowthPanel extends StatefulWidget{'
end='class _EmergencyAdminPanel extends StatefulWidget{'
if start not in body:
    raise SystemExit('v316 removal failed: _OwnerGrowthPanel start anchor missing')
if end not in body:
    raise SystemExit('v316 removal failed: _EmergencyAdminPanel end anchor missing')

before, rest = body.split(start,1)
_, after = rest.split(end,1)
body = before + "const _bridgePointManualSocialOnlyV316='bridgepoint-v316-manual-social-only';\n\n" + end + after

# Remove the panel invocation from Owner Center. Public About BridgePoint social links are intentionally untouched.
body=body.replace("        const SizedBox(height:18),const _OwnerGrowthPanel(),\n","")

# Automatic posting provider controls must not survive in the production source after this layer.
for forbidden in [
    'bridgepoint-social-publisher-v120',
    'bridgepoint-social-connect-v122',
    'Publish connected now',
    'Post #$slot to ALL connected socials',
    'configureProvider(String platform)',
    'connectProvider(String platform)',
    'Activate 60-day calendar',
]:
    if forbidden in body:
        raise SystemExit(f'v316 removal failed: automatic social publishing marker remains: {forbidden}')

# Keep About BridgePoint social/profile links.
for required in ['bridgepoint_brand_contact_v215','Add / edit socials','About BridgePoint']:
    if required not in body:
        raise SystemExit(f'v316 removal failed: required public social/about marker missing: {required}')

path.write_text(body,encoding='utf-8')
print('BRIDGEPOINT V316 MANUAL SOCIAL MODE APPLIED')
print(' - automatic social publishing/OAuth UI removed')
print(' - automatic post buttons and 60-day activation controls removed')
print(' - About BridgePoint public social links retained')
