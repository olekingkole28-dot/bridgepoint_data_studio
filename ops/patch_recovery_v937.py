from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match in {path}, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')

shell = Path('lib/v2/bridgepoint_recovery_shell_v3.dart')
dossier = Path('lib/v2/bridgepoint_property_dossier_recovered_v7.dart')

replace_once(
    shell,
    '/// Recovery V3 deliberately limits permanent navigation to five entrances.',
    '/// Recovery V3 deliberately limits permanent navigation to four entrances.',
    'four-entry navigation comment',
)
replace_once(
    shell,
    "  _AreaSpec(_Area.properties, 'Properties', Icons.holiday_village_rounded),\n  _AreaSpec(_Area.opportunities, 'Opportunities', Icons.bolt_rounded),\n  _AreaSpec(_Area.work, 'Work', Icons.workspaces_outline),",
    "  _AreaSpec(_Area.properties, 'Properties', Icons.holiday_village_rounded),\n  _AreaSpec(_Area.work, 'Work', Icons.workspaces_outline),",
    'remove opportunities from permanent navigation',
)
replace_once(
    shell,
    "const _customerDeep = <_AreaSpec>[\n  _AreaSpec(_Area.saved, 'Saved & Alerts', Icons.bookmark_added_outlined,",
    "const _customerDeep = <_AreaSpec>[\n  _AreaSpec(_Area.opportunities, 'Opportunities', Icons.bolt_rounded,\n      detail: 'Prioritized properties and explainable reasons to act'),\n  _AreaSpec(_Area.saved, 'Saved & Alerts', Icons.bookmark_added_outlined,",
    'add opportunities to contextual navigation',
)
replace_once(
    shell,
    "    const cards = <_AreaSpec>[\n      _AreaSpec(_Area.saved, 'Saved & Alerts', Icons.bookmark_added_outlined,",
    "    const cards = <_AreaSpec>[\n      _AreaSpec(_Area.opportunities, 'Opportunities', Icons.bolt_rounded,\n          detail: 'Prioritized properties, why they matter, and the next action.'),\n      _AreaSpec(_Area.saved, 'Saved & Alerts', Icons.bookmark_added_outlined,",
    'add opportunities to work hub',
)
replace_once(
    shell,
    "          'Saved properties, alerts, follow-ups, claims and portfolio work live here instead of becoming separate permanent tabs.',",
    "          'Opportunities, saved properties, alerts, follow-ups, claims and portfolio work live here instead of becoming separate permanent tabs.',",
    'work hub copy',
)

replace_once(
    dossier,
    '  _TwinView _view = _TwinView.site3d;',
    '  _TwinView _view = _TwinView.front;',
    'image-first default',
)
replace_once(
    dossier,
    '      _view = _TwinView.site3d;',
    '      _view = _TwinView.front;',
    'image-first property change',
)
replace_once(
    dossier,
    "                _viewChip(_TwinView.site3d, '3D', Icons.view_in_ar_rounded),\n                _viewChip(_TwinView.front, 'Front', Icons.home_rounded),\n                _viewChip(_TwinView.aerial, 'Aerial', Icons.satellite_alt_rounded),\n                _viewChip(_TwinView.history, 'History', Icons.history_rounded),",
    "                _viewChip(_TwinView.front, 'Front', Icons.home_rounded),\n                _viewChip(_TwinView.aerial, 'Aerial', Icons.satellite_alt_rounded),\n                _viewChip(_TwinView.site3d, 'Structure 3D', Icons.view_in_ar_rounded),\n                _viewChip(_TwinView.history, 'History', Icons.history_rounded),",
    'visual control order and truthful 3d label',
)
replace_once(
    dossier,
    "                      'LIVE PROPERTY TWIN',",
    "                      'PROPERTY VISUAL + INTELLIGENCE',",
    'property header truth label',
)
replace_once(
    dossier,
    "            const Text(\n              'Property Twin',",
    "            const Text(\n              'Property',",
    'property appbar title',
)
replace_once(
    dossier,
    "            title: '3D site is live; structure detail is upgrading',\n            body:\n                'The property location remains usable while national footprint lanes attach a source-backed structure automatically.',",
    "            title: 'Structure 3D is still upgrading',\n            body:\n                'This is source-backed geometry, not a photograph of the house. Front and aerial imagery remain separate and are shown when a real approved image is available.',",
    'truthful empty 3d message',
)

# Guardrails: keep property capability contextual and truthful.
shell_text = shell.read_text(encoding='utf-8')
dossier_text = dossier.read_text(encoding='utf-8')
assert "_AreaSpec(_Area.opportunities, 'Opportunities'" not in shell_text.split('const _primary = <_AreaSpec>[',1)[1].split('];',1)[0]
assert "_AreaSpec(_Area.work, 'Work'" in shell_text
assert "'Structure 3D'" in dossier_text
assert 'PROPERTY VISUAL + INTELLIGENCE' in dossier_text
assert '_TwinView _view = _TwinView.front;' in dossier_text
assert "BridgePoint will not manufacture a house photo" in dossier_text
print('Recovery V937 unified-property/navigation patch applied.')
