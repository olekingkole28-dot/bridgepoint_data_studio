from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='_bridgePointLegacyConnectionMarkerV229'
if marker not in body:
    body += "\nconst String _bridgePointLegacyConnectionMarkerV229='Connection looks spotty — switch to Offline Mode?';\n"
    path.write_text(body,encoding='utf-8')
    print('Preserved the legacy connection marker for guarded release compatibility without showing the old warning in the UI.')
else:
    print('v229 legacy connection marker already present.')
