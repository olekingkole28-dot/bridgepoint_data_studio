from pathlib import Path
import re

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v309-semantic-immersive-compile'
if marker in body:
    print('v309 already applied')
    raise SystemExit(0)

old="i%4==0?.08:.035"
new="i%4==0 ? 0.08 : 0.035"
count=body.count(old)
if count!=1:
    raise SystemExit(f'v309 Signals ternary anchor count {count}')
body=body.replace(old,new,1)

# Guard against the same compact conditional-decimal ambiguity being introduced
# elsewhere in the semantic scene painter.
semantic_start=body.find('class _BridgePointSemanticScenePainterV290')
semantic_end=body.find('class _BridgePointSpatialAtmospherePainterV287',semantic_start)
if semantic_start<0 or semantic_end<0:
    raise SystemExit('v309 semantic painter bounds unavailable')
semantic=body[semantic_start:semantic_end]
ambiguous=re.findall(r'\d\?\.\d',semantic)
if ambiguous:
    raise SystemExit(f'v309 ambiguous conditional decimals remain: {ambiguous}')

body += "\nconst String _bridgePointSemanticImmersiveCompileV309='bridgepoint-v309-semantic-immersive-compile | Signals ternary numeric syntax repaired';\n"
path.write_text(body,encoding='utf-8')
print('Repaired v290 semantic immersive Signals ternary compile point v309.')