from pathlib import Path
import re

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

# Convert loading-state no-op callbacks into true disabled callbacks.
text=re.sub(r"loading\s*\?\s*\(\)\s*\{\s*\}\s*:\s*onRefresh","loading ? null : onRefresh",text)
text=re.sub(r"loading\s*\?\s*\(\)\s*\{\s*\}\s*:\s*([A-Za-z_]\w*)",r"loading ? null : \1",text)

# _IconButton must accept null so a disabled refresh really disables InkWell.
text=re.sub(r"final\s+VoidCallback\s+onTap\s*;","final VoidCallback? onTap;",text,count=1)
# Preserve required argument at construction; the value itself may be null.
text=text.replace('child: Icon(icon, color: AppTheme.textMuted, size: 20),','child: Icon(icon, color: onTap==null?Colors.white24:AppTheme.textMuted, size: 20),',1)

# Replace exact empty callbacks that are inherently misleading.
text=re.sub(r"onPressed\s*:\s*\(\)\s*\{\s*\}\s*,","onPressed:null,",text)
text=re.sub(r"onTap\s*:\s*\(\)\s*\{\s*\}\s*,","onTap:null,",text)

# Verify there are no remaining exact empty handlers.
if re.search(r"on(?:Pressed|Tap)\s*:\s*\(\)\s*\{\s*\}",text):
    raise SystemExit('an empty click handler remains after cleanup')
if 'final VoidCallback? onTap;' not in text:
    raise SystemExit('nullable _IconButton handler not installed')
if text==original:
    raise SystemExit('No dead click handler changes applied')
p.write_text(text,encoding='utf-8')
print('Replaced generated no-op click handlers with true disabled controls v194b')
