from pathlib import Path

ROOT = Path('lib')
replacements = {
    "bridgepoint_property_geometry_v837": "bridgepoint_property_geometry_v854",
    "bridgepoint_property_source_3d_v843": "bridgepoint_property_source_3d_v855",
    "bridgepoint_digital_twin_summary_v509": "bridgepoint_digital_twin_summary_v856",
    "bridgepoint_property_timeline_v78": "bridgepoint_property_timeline_v857",
}
changed=[]
for path in ROOT.rglob('*.dart'):
    s=path.read_text(encoding='utf-8')
    out=s
    for old,new in replacements.items():
        out=out.replace(old,new)
    if out!=s:
        path.write_text(out,encoding='utf-8')
        changed.append(path.as_posix())

if not changed:
    raise SystemExit('V858 found no hardened RPC call sites to update')
print('V858 hardened property RPC callers:')
for item in changed:
    print(' -',item)
