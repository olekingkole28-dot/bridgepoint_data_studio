from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

# Normalize the Daily Brief state/init boundary expected by v164.
expected_state="""class _DailyBriefPageState extends State<_DailyBriefPage>{
  late Future<Map<String,dynamic>> request;
  late Future<Map<String,dynamic>> fieldNoteRequest;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});}
"""
if expected_state not in text:
    state_pattern=re.compile(
        r"class _DailyBriefPageState extends State<_DailyBriefPage>\s*\{\s*"
        r"late Future<Map<String,\s*dynamic>> request;\s*"
        r"late Future<Map<String,\s*dynamic>> fieldNoteRequest;\s*"
        r"@override\s*void initState\(\)\s*\{\s*super\.initState\(\);\s*"
        r"request\s*=\s*_callRpc\(\s*'bridgepoint_daily_brief_v74'\s*,\s*const \{\}\s*\);\s*"
        r"fieldNoteRequest\s*=\s*_callRpc\(\s*'bridgepoint_field_note_of_day_v81'\s*,\s*const \{\}\s*\);\s*\}",
        re.S,
    )
    if len(state_pattern.findall(text))!=1:
        raise SystemExit(f'v813 Daily Brief state expected 1 match, found {len(state_pattern.findall(text))}')
    text=state_pattern.sub(expected_state.rstrip('\n'),text,count=1)

# Normalize the Daily Brief refresh IconButton while preserving its behavior.
expected_refresh="""            IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState((){request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});}),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
"""
if expected_refresh not in text:
    refresh_pattern=re.compile(
        r"(?P<indent>[ \t]*)IconButton\(\s*tooltip:\s*'Refresh Daily Brief'\s*,\s*"
        r"onPressed:\s*\(\)\s*=>\s*setState\(\(\)\s*\{\s*"
        r"request\s*=\s*_callRpc\(\s*'bridgepoint_daily_brief_v74'\s*,\s*const \{\}\s*\);\s*"
        r"fieldNoteRequest\s*=\s*_callRpc\(\s*'bridgepoint_field_note_of_day_v81'\s*,\s*const \{\}\s*\);\s*"
        r"\}\)\s*,\s*icon:\s*const Icon\(\s*Icons\.refresh_rounded\s*,\s*color:\s*AppTheme\.cyan\s*\)\s*\)\s*,",
        re.S,
    )
    m=refresh_pattern.search(text)
    if m is None:
        raise SystemExit('v813 Daily Brief refresh boundary not found')
    indent=m.group('indent')
    normalized=(f"{indent}IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState((){{request=_callRpc('bridgepoint_daily_brief_v74',const {{}});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {{}});}}),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),")
    text=refresh_pattern.sub(normalized,text,count=1)

# Normalize the field-note FutureBuilder prefix used as v164's widget-panel
# insertion point. Only this small prefix is collapsed; the field-note body is untouched.
expected_panel="""        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:fieldNoteRequest,builder:(context,noteSnapshot){
"""
if expected_panel not in text:
    panel_pattern=re.compile(
        r"(?P<indent>[ \t]*)const SizedBox\(height:\s*18\),\s*"
        r"FutureBuilder<Map<String,\s*dynamic>>\(\s*"
        r"future:\s*fieldNoteRequest\s*,\s*builder:\s*\(context,\s*noteSnapshot\)\s*\{",
        re.S,
    )
    m=panel_pattern.search(text)
    if m is None:
        raise SystemExit('v813 field-note widget insertion boundary not found')
    indent=m.group('indent')
    normalized=(f"{indent}const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(\n"
                f"{indent}  future:fieldNoteRequest,builder:(context,noteSnapshot){{")
    text=panel_pattern.sub(normalized,text,count=1)

# v164 inserts helper classes before the Field Note card.
if 'class _FieldNoteCard extends StatelessWidget{' not in text:
    formatted='class _FieldNoteCard extends StatelessWidget {'
    if text.count(formatted)!=1:
        raise SystemExit(f'v813 FieldNote class expected 1 formatted marker, found {text.count(formatted)}')
    text=text.replace(formatted,'class _FieldNoteCard extends StatelessWidget{',1)

for required in [
    "class _DailyBriefPageState extends State<_DailyBriefPage>{",
    "tooltip:'Refresh Daily Brief'",
    'future:fieldNoteRequest,builder:(context,noteSnapshot){',
    'class _FieldNoteCard extends StatelessWidget{',
]:
    if required not in text:
        raise SystemExit(f'v813 compatibility marker missing: {required}')

if text==original:
    print('Dashboard widgets v164 compatibility already normalized v813')
else:
    path.write_text(text,encoding='utf-8')
    print('Normalized Daily Brief boundaries for dashboard widgets v164/v813')
