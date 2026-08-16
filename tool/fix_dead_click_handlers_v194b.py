from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

# A disabled refresh should actually be disabled, not accept a click that does nothing.
text=text.replace(
"""        _IconButton(
          icon: Icons.refresh_rounded,
          onTap: loading ? () {} : onRefresh,
        ),
""",
"""        _IconButton(
          icon: Icons.refresh_rounded,
          onTap: loading ? null : onRefresh,
        ),
""",1)

text=text.replace(
"""  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;
""",
"""  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;
""",1)

# Disabled visual state for controls that cannot currently act.
old="""        child: Icon(icon, color: AppTheme.textMuted, size: 20),
"""
new="""        child: Icon(icon, color: onTap==null?Colors.white24:AppTheme.textMuted, size: 20),
"""
if old in text:text=text.replace(old,new,1)

# Remove any other exact empty anonymous handlers that slipped into generated release code.
text=text.replace('onPressed: () {},','onPressed: null,')
text=text.replace('onPressed:(){},','onPressed:null,')
text=text.replace('onTap: () {},','onTap: null,')
text=text.replace('onTap:(){},','onTap:null,')

if 'onTap: loading ? () {} : onRefresh' in text: raise SystemExit('loading refresh still uses a no-op handler')
if 'final VoidCallback? onTap;' not in text: raise SystemExit('nullable _IconButton handler not installed')
if text==original: raise SystemExit('No dead click handler changes applied')
p.write_text(text,encoding='utf-8')
print('Replaced no-op click handlers with true disabled controls v194b')
