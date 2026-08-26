from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text


def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)


# v787: add a persisted base-map preference using small, formatting-stable
# anchors instead of one giant pre-dart-format class matcher.
replace_once(
    "    this.simplifiedViews = false,\n  });",
    "    this.simplifiedViews = false,\n    this.mapBaseStyle = 'satellite',\n  });",
    'display-preferences-map-style-constructor',
)
replace_once(
    "  final bool simplifiedViews;\n\n  _DisplayPreferences copyWith({",
    "  final bool simplifiedViews;\n  final String mapBaseStyle;\n\n  _DisplayPreferences copyWith({",
    'display-preferences-map-style-field',
)
replace_once(
    "    bool? simplifiedViews,\n  }) =>",
    "    bool? simplifiedViews,\n    String? mapBaseStyle,\n  }) =>",
    'display-preferences-map-style-copy-param',
)
replace_once(
    "        simplifiedViews: simplifiedViews ?? this.simplifiedViews,\n      );",
    "        simplifiedViews: simplifiedViews ?? this.simplifiedViews,\n        mapBaseStyle: mapBaseStyle ?? this.mapBaseStyle,\n      );",
    'display-preferences-map-style-copy-value',
)
replace_once(
    "    simplifiedViews: value['simplified_views'] == true,\n  );",
    "    simplifiedViews: value['simplified_views'] == true,\n    mapBaseStyle: '${value['map_base_style'] ?? 'satellite'}' == 'street'\n        ? 'street'\n        : 'satellite',\n  );",
    'apply-map-style-preference',
)

# Replace only the real map TileLayer literals BEFORE defining the helper.
# The old v98 generator replaced globally after inserting the helper, which
# could replace the helper's own street URL and make it recursively call itself.
osm = "'https://tile.openstreetmap.org/{z}/{x}/{y}.png'"
osm_count = text.count(osm)
if osm_count != 2:
    raise SystemExit(f'base-map-url: expected exactly 2 live map tile URLs, found {osm_count}')
text = text.replace(osm, '_bridgePointBaseMapUrl()')

api_marker = "Map<String, String> _apiHeaders() {"
if text.count(api_marker) != 1:
    raise SystemExit(f'base-map-helper-anchor: expected exactly 1 match, found {text.count(api_marker)}')
helper = """String _bridgePointBaseMapUrl() =>
    _displayPreferences.value.mapBaseStyle == 'street'
        ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
        : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

"""
text = text.replace(api_marker, helper + api_marker, 1)

replace_once(
    "  String _mapStyle = 'standard';",
    "  String _mapStyle = 'satellite';",
    'settings-map-style-default',
)
replace_once(
    "    _refreshSeconds = widget.refreshSeconds;\n    _accessibility = _displayPreferences.value;",
    "    _refreshSeconds = widget.refreshSeconds;\n    _accessibility = _displayPreferences.value;\n    _mapStyle = _accessibility.mapBaseStyle;",
    'settings-map-style-init',
)

replace_once(
    "await _callRpc('bridgepoint_update_display_preferences_v80', {",
    "await _callRpc('bridgepoint_update_display_preferences_v98', {",
    'save-map-style-rpc',
)
replace_once(
    "        'p_simplified_views': next.simplifiedViews,\n      });\n      _applyDisplayPreferences(saved);",
    "        'p_simplified_views': next.simplifiedViews,\n        'p_map_base_style': next.mapBaseStyle,\n      });\n      _applyDisplayPreferences(saved);\n      if (mounted) {\n        setState(() {\n          _accessibility = _displayPreferences.value;\n          _mapStyle = _accessibility.mapBaseStyle;\n        });\n      }",
    'save-map-style-preference',
)

replace_once(
"""                        items: const ['standard', 'street', 'satellite']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value[0].toUpperCase() +
                                      value.substring(1)),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _mapStyle = value ?? 'standard'),
""",
"""                        items: const ['satellite', 'street']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value == 'satellite'
                                      ? 'Satellite (default)'
                                      : 'Street map'),
                                ))
                            .toList(),
                        onChanged: _savingAccessibility
                            ? null
                            : (value) {
                                final style =
                                    value == 'street' ? 'street' : 'satellite';
                                setState(() => _mapStyle = style);
                                _saveAccessibility(_accessibility.copyWith(
                                    mapBaseStyle: style));
                              },
""",
    'settings-map-style-persist',
)
replace_once(
    "                    subtitle:\n                        'Opportunity markers now use category-specific icons.',",
    "                    subtitle:\n                        'Satellite is the BridgePoint default. Switch to a street map here at any time; your choice follows your account.',",
    'settings-map-style-copy',
)

if text == original:
    raise SystemExit('No satellite map changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint satellite map preference patch v98/v787')
