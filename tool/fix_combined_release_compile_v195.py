from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

# Dart ternary syntax in the premium top bar.
text=text.replace('desktop?.07:.18','desktop ? .07 : .18')
text=text.replace('desktop?.16:.34','desktop ? .16 : .34')

# Merge the pre-existing map cleanup with the new weather animation timer cleanup.
old_dispose="""  @override
  void dispose(){
    _radarRefreshTimer?.cancel();
    _viewportRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void dispose(){_radarAnimationTimer?.cancel();super.dispose();}
"""
new_dispose="""  @override
  void dispose(){
    _radarRefreshTimer?.cancel();
    _viewportRefreshTimer?.cancel();
    _radarAnimationTimer?.cancel();
    super.dispose();
  }
"""
if old_dispose in text:
    text=text.replace(old_dispose,new_dispose,1)
else:
    # Fallback if formatting differs: remove only the short duplicate and inject cancellation into the existing cleanup.
    text=text.replace('  @override\n  void dispose(){_radarAnimationTimer?.cancel();super.dispose();}\n\n','',1)
    if '_radarAnimationTimer?.cancel();' not in text[text.find('class _IntelligenceMapPageState'):text.find('class _MapLegendDot')]:
        text=text.replace('    _viewportRefreshTimer?.cancel();\n    super.dispose();','    _viewportRefreshTimer?.cancel();\n    _radarAnimationTimer?.cancel();\n    super.dispose();',1)

# Only the shared header icon control needs to become nullable for disabled loading state.
icon_class_start=text.find('class _IconButton extends StatelessWidget')
if icon_class_start<0: raise SystemExit('_IconButton class missing')
icon_class_end=text.find('\n}',icon_class_start)
if icon_class_end<0: raise SystemExit('_IconButton class end missing')
icon_block=text[icon_class_start:icon_class_end]
icon_block=icon_block.replace('final VoidCallback onTap;','final VoidCallback? onTap;')
text=text[:icon_class_start]+icon_block+text[icon_class_end:]

# Hard guards for the compiler breakpoints just repaired.
for bad in ['desktop?.07:.18','desktop?.16:.34','void dispose(){_radarAnimationTimer?.cancel();super.dispose();}']:
    if bad in text: raise SystemExit(f'compile repair still contains: {bad}')
icon_check=text[text.find('class _IconButton extends StatelessWidget'):text.find('class _InlineError',text.find('class _IconButton extends StatelessWidget')) if text.find('class _InlineError',text.find('class _IconButton extends StatelessWidget'))>0 else len(text)]
if 'final VoidCallback? onTap;' not in icon_check: raise SystemExit('_IconButton callback is still non-nullable')
if text==original: raise SystemExit('No combined release compile changes applied')
p.write_text(text,encoding='utf-8')
print('Repaired combined release Dart compile breakpoints v195')
