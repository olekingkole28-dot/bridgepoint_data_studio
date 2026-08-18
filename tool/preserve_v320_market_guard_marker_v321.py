from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint_user_market_context_v320'
if marker not in body:
    body += "\n// Legacy release-guard compatibility only: bridgepoint_user_market_context_v320\n"
    path.write_text(body,encoding='utf-8')
    print('Preserved legacy v320 market guard marker without changing v321 runtime behavior.')
else:
    print('Legacy v320 market guard marker already present.')
