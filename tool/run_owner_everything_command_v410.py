from pathlib import Path
import re
import runpy

script_path=Path('tool/apply_owner_everything_command_v410.py')
source=script_path.read_text(encoding='utf-8')
pattern=r'''heading = "_PageHeading\(title:'Owner Center'.*?text = text\.replace\(heading, replacement, 1\)\n'''
new=r"""if 'bridgepoint-v341-national-customer-surfaces' not in text:
    raise SystemExit('V410 must run after the final national customer release')
heading_needle="_PageHeading(title:'Owner Center'"
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
insertion=f"\n{indent}const SizedBox(height:14),\n{indent}const _OwnerEverythingCommandV410(),"
text=text[:line_end]+insertion+text[line_end:]
"""
source,replaced=re.subn(pattern,lambda _m:new,source,count=1,flags=re.S)
if replaced!=1:
    raise SystemExit(f'V410 wrapper structural source rewrite count {replaced}')
exec(compile(source,str(script_path),'exec'),{'__name__':'__main__','__file__':str(script_path)})

runpy.run_path('tool/apply_owner_everything_live_metrics_v411.py',run_name='__main__')
runpy.run_path('tool/apply_owner_attention_v416.py',run_name='__main__')
runpy.run_path('tool/apply_owner_release_truth_v417.py',run_name='__main__')
runpy.run_path('tool/apply_owner_truth_gaps_v418.py',run_name='__main__')
runpy.run_path('tool/apply_owner_human_details_v419.py',run_name='__main__')
runpy.run_path('tool/apply_owner_cross_filters_v420.py',run_name='__main__')
runpy.run_path('tool/apply_owner_funnel_truth_v422.py',run_name='__main__')
runpy.run_path('tool/apply_owner_essentials_v431.py',run_name='__main__')

# V439 intentionally does not touch avatar/profile identity. It only strengthens install,
# unauthenticated entry, and BridgePoint A.I. discoverability.
runpy.run_path('tool/apply_install_entry_v439.py',run_name='__main__')

# V440 repairs the public conversion path and funnel truth. Trial links open directly in
# account-creation mode, signup is reduced to email/password + legal assent, and open-app
# navigation is no longer misreported as account-creation intent.
runpy.run_path('tool/apply_signup_conversion_v440.py',run_name='__main__')

# V441 repairs the reported mobile gold CTA failure. The native HTML control is a guaranteed
# touch target and always offers a direct app-open fallback when install APIs are unavailable.
runpy.run_path('tool/apply_mobile_install_fallback_v441.py',run_name='__main__')

# V442 fixes the real-touch narrow-screen overflow found by the V441 hard verifier: the
# install-guide action row and direct fallback are clamped inside the mobile viewport.
runpy.run_path('tool/apply_install_guide_mobile_width_v442.py',run_name='__main__')
