from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
"""    this.reducedMotion = false,
    this.simplifiedViews = false,
  });

  final bool largeText;
  final bool highContrast;
  final bool reducedMotion;
  final bool simplifiedViews;

  _DisplayPreferences copyWith({
    bool? largeText,
    bool? highContrast,
    bool? reducedMotion,
    bool? simplifiedViews,
  }) => _DisplayPreferences(
    largeText: largeText ?? this.largeText,
    highContrast: highContrast ?? this.highContrast,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    simplifiedViews: simplifiedViews ?? this.simplifiedViews,
  );
""",
"""    this.reducedMotion = false,
    this.simplifiedViews = false,
    this.mapBaseStyle = 'satellite',
  });

  final bool largeText;
  final bool highContrast;
  final bool reducedMotion;
  final bool simplifiedViews;
  final String mapBaseStyle;

  _DisplayPreferences copyWith({
    bool? largeText,
    bool? highContrast,
    bool? reducedMotion,
    bool? simplifiedViews,
    String? mapBaseStyle,
  }) => _DisplayPreferences(
    largeText: largeText ?? this.largeText,
    highContrast: highContrast ?? this.highContrast,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    simplifiedViews: simplifiedViews ?? this.simplifiedViews,
    mapBaseStyle: mapBaseStyle ?? this.mapBaseStyle,
  );
""",
'display-preferences-map-style')

replace_once(
"""    reducedMotion:value['reduced_motion']==true,
    simplifiedViews:value['simplified_views']==true,
  );
}

Map<String, String> _apiHeaders() {
""",
"""    reducedMotion:value['reduced_motion']==true,
    simplifiedViews:value['simplified_views']==true,
    mapBaseStyle:'${value['map_base_style']??'satellite'}'=='street'?'street':'satellite',
  );
}

String _bridgePointBaseMapUrl()=>_displayPreferences.value.mapBaseStyle=='street'
  ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
  : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

Map<String, String> _apiHeaders() {
""",
'apply-map-style-and-url')

# All BridgePoint maps should honor the same account preference.
count=text.count("'https://tile.openstreetmap.org/{z}/{x}/{y}.png'")
if count!=3:
    raise SystemExit(f'base-map-url: expected exactly 3 map tile URLs, found {count}')
text=text.replace("'https://tile.openstreetmap.org/{z}/{x}/{y}.png'","_bridgePointBaseMapUrl()")

replace_once(
"""  bool _mapAutoRotate = true;
  String _mapStyle = 'standard';
""",
"""  bool _mapAutoRotate = true;
  String _mapStyle = 'satellite';
""",
'settings-map-style-default')

replace_once(
"""    _refreshSeconds = widget.refreshSeconds;
    _accessibility=_displayPreferences.value;
  }
""",
"""    _refreshSeconds = widget.refreshSeconds;
    _accessibility=_displayPreferences.value;
    _mapStyle=_accessibility.mapBaseStyle;
  }
""",
'settings-map-style-init')

replace_once(
"""      final saved=await _callRpc('bridgepoint_update_display_preferences_v80',{
        'p_large_text':next.largeText,'p_high_contrast':next.highContrast,
        'p_reduced_motion':next.reducedMotion,'p_simplified_views':next.simplifiedViews,
      });
      _applyDisplayPreferences(saved);
""",
"""      final saved=await _callRpc('bridgepoint_update_display_preferences_v98',{
        'p_large_text':next.largeText,'p_high_contrast':next.highContrast,
        'p_reduced_motion':next.reducedMotion,'p_simplified_views':next.simplifiedViews,
        'p_map_base_style':next.mapBaseStyle,
      });
      _applyDisplayPreferences(saved);
      if(mounted)setState((){_accessibility=_displayPreferences.value;_mapStyle=_accessibility.mapBaseStyle;});
""",
'save-map-style-preference')

replace_once(
"""                        items: const ['standard', 'street', 'satellite']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value[0].toUpperCase() + value.substring(1)),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _mapStyle = value ?? 'standard'),
""",
"""                        items: const ['satellite', 'street']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value=='satellite'?'Satellite (default)':'Street map'),
                                ))
                            .toList(),
                        onChanged: _savingAccessibility?null:(value){
                          final style=value=='street'?'street':'satellite';
                          setState(()=>_mapStyle=style);
                          _saveAccessibility(_accessibility.copyWith(mapBaseStyle:style));
                        },
""",
'settings-map-style-persist')

replace_once(
"""                    subtitle: 'Opportunity markers now use category-specific icons.',
""",
"""                    subtitle: 'Satellite is the BridgePoint default. Switch to a street map here at any time; your choice follows your account.',
""",
'settings-map-style-copy')

if text==original:
    raise SystemExit('No satellite map changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint satellite map preference patch v98')
