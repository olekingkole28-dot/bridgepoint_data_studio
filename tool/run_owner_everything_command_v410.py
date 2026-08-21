from pathlib import Path
import re
import runpy

script_path=Path('tool/apply_owner_everything_command_v410.py')
source=script_path.read_text(encoding='utf-8')
pattern=r'''heading = "_PageHeading\(title:'Owner Center'.*?text = text\.replace\(heading, replacement, 1\)\n'''
new="""if 'bridgepoint-v341-national-customer-surfaces' not in text:
    raise SystemExit('V410 must run after the final national customer release')
heading_needle=\"_PageHeading(title:'Owner Center'\"
if text.count(heading_needle)!=1:
    raise SystemExit(f'V410 structural Owner Center heading count {text.count(heading_needle)}')
heading_pos=text.index(heading_needle)
line_start=text.rfind('\n',0,heading_pos)+1
line_end=text.find('\n',heading_pos)
if line_end<0: line_end=len(text)
heading_line=text[line_start:line_end]
if not heading_line.strip().endswith('),'):
    raise SystemExit('V410 Owner Center heading is not a complete one-line PageHeading call')
indent=heading_line[:len(heading_line)-len(heading_line.lstrip())]
insertion=f\"\n{indent}const SizedBox(height:14),\n{indent}const _OwnerEverythingCommandV410(),\"
text=text[:line_end]+insertion+text[line_end:]
"""
source,replaced=re.subn(pattern,new,source,count=1,flags=re.S)
if replaced!=1:
    raise SystemExit(f'V410 wrapper structural source rewrite count {replaced}')
exec(compile(source,str(script_path),'exec'),{'__name__':'__main__','__file__':str(script_path)})

# V415 keeps the V410 Everything shell but switches it to the bounded cached owner-truth contract
# and promotes reconciled intelligence, billing, source-task, OAuth and warning headlines.
runpy.run_path('tool/apply_owner_everything_live_metrics_v411.py',run_name='__main__')

# V416 adds the owner-first Today/Attention summary using only the already-loaded V415 payload.
# It adds no database polling and keeps owner actions separate from automatic recovery work.
runpy.run_path('tool/apply_owner_attention_v416.py',run_name='__main__')

# V417 shows the exact compile-time release SHA inside Owner Attention.
# This is zero-DB deployment truth: the owner sees the version embedded in the running browser/PWA artifact.
runpy.run_path('tool/apply_owner_release_truth_v417.py',run_name='__main__')

# V418 elevates unavailable, contradicted and warning owner metrics into the Today/Attention surface.
# It uses the already-loaded V417 payload and adds no database reads.
runpy.run_path('tool/apply_owner_truth_gaps_v418.py',run_name='__main__')

# V419 makes every Owner Everything Details dialog understandable without reading raw JSON.
# It summarizes already-loaded payloads, preserves truth limitations, and keeps raw audit data collapsed.
runpy.run_path('tool/apply_owner_human_details_v419.py',run_name='__main__')

# V420 adds truth-aware state/vertical/package/channel/worker filters without new database reads.
# Sections lacking a requested dimension remain visible rather than disappearing like a fake zero.
runpy.run_path('tool/apply_owner_cross_filters_v420.py',run_name='__main__')

# V422 upgrades the Acquisition Funnel to the bounded cached stage-conversion truth model.
# The owner sees Today / 7d / since-launch counts, browser-capture health and the largest observable drop-off without new page-load scans.
runpy.run_path('tool/apply_owner_funnel_truth_v422.py',run_name='__main__')
