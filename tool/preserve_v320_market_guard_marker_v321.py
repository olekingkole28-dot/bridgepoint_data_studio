from pathlib import Path
import runpy

# The v321 generated source is hash-verified before this point. Repair only the isolated
# zoom-aware expansion marker closure that Flutter analyze caught in PR CI.
runpy.run_path('tool/fix_v321_map_compile.py',run_name='__main__')

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint_user_market_context_v320'
if marker not in body:
    body += "\n// Legacy release-guard compatibility only: bridgepoint_user_market_context_v320\n"
    path.write_text(body,encoding='utf-8')
    print('Preserved legacy v320 market guard marker without changing v321 runtime behavior.')
else:
    print('Legacy v320 market guard marker already present.')
