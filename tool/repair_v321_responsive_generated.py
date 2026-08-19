from pathlib import Path
import re

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')

# ---------------------------------------------------------------------------
# Conflict 1: verified-frame discovery is additive. If the frame-list helper
# fails, keep radar entitlement enabled and fall back to NOAA's newest/current
# layer rather than making the whole radar disappear.
# ---------------------------------------------------------------------------
fn_start=body.find('Future<void> _loadNoaaRadarFramesV271()')
if fn_start<0:
    raise SystemExit('v321 repair: _loadNoaaRadarFramesV271 missing')
fn_end=body.find('\n  }',fn_start)
if fn_end<0:
    raise SystemExit('v321 repair: NOAA frame loader end missing')
# Include enough of the function to capture compact catch forms.
segment=body[fn_start:fn_end+4]
desired_catch="}catch(_){if(mounted)setState((){_weatherAllowedV318=true;_noaaRadarFramesV271=<DateTime>[];_radarFrameIndex=0;_radarRevision++;});}"
if desired_catch not in segment:
    # Replace the catch attached to this loader only; do not alter other weather
    # catches elsewhere in the app.
    segment,n=re.subn(
        r"\}catch\(_\)\{if\(mounted\)setState\(\(\)=>_weatherAllowedV318=false\);\}",
        desired_catch,
        segment,
        count=1,
    )
    if n!=1:
        # Formatting-tolerant fallback for the same semantic branch.
        segment,n=re.subn(
            r"\}\s*catch\s*\(_\)\s*\{\s*if\s*\(mounted\)\s*setState\s*\(\s*\(\)\s*=>\s*_weatherAllowedV318\s*=\s*false\s*\)\s*;?\s*\}",
            desired_catch,
            segment,
            count=1,
        )
        if n!=1:
            raise SystemExit('v321 repair: NOAA loader failure catch shape not found')
    body=body[:fn_start]+segment+body[fn_end+4:]

# ---------------------------------------------------------------------------
# Conflict 2: strengthen the primary Intelligence Map precipitation overlay.
# Find the map TileLayer by its noaa-radar ValueKey, then wrap it in opacity and
# use low-latency tile buffering. This remains compatible with the later v325
# switch to NOAA's symbolized-current service.
# ---------------------------------------------------------------------------
radar_key="key:ValueKey('noaa-radar-$_radarRevision-${_radarFrame.toIso8601String()}')"
key_idx=body.find(radar_key)
if key_idx<0:
    raise SystemExit('v321 repair: primary Intelligence Map radar TileLayer missing')
# Skip if v321 visibility tuning is already present around this exact layer.
window_start=max(0,key_idx-180)
window_end=min(len(body),key_idx+900)
window=body[window_start:window_end]
if 'Opacity(opacity:.88,child:TileLayer(' not in window:
    tile_start=body.rfind('TileLayer(',0,key_idx)
    if tile_start<0 or key_idx-tile_start>180:
        raise SystemExit('v321 repair: primary radar TileLayer start not found')
    # Include an immediately preceding entitlement condition if present.
    cond_start=body.rfind('if(_weatherAllowedV318&&_showRadar)',0,tile_start)
    if cond_start>=0 and tile_start-cond_start<90:
        start=cond_start
        prefix='if(_weatherAllowedV318&&_showRadar)'
    else:
        start=tile_start
        prefix=''

    # Find the closing parenthesis of this TileLayer call while ignoring strings.
    open_paren=body.find('(',tile_start)
    depth=0; quote=None; escaped=False; end=None
    for i in range(open_paren,len(body)):
        ch=body[i]
        if quote is not None:
            if escaped:
                escaped=False
            elif ch=='\\':
                escaped=True
            elif ch==quote:
                quote=None
            continue
        if ch in ("'",'\"'):
            quote=ch; continue
        if ch=='(':
            depth+=1
        elif ch==')':
            depth-=1
            if depth==0:
                end=i+1
                break
    if end is None:
        raise SystemExit('v321 repair: primary radar TileLayer did not balance')
    # Preserve comma after widget expression.
    j=end
    while j<len(body) and body[j] in ' \t': j+=1
    if j<len(body) and body[j]==',': j+=1
    expr=body[tile_start:end]
    # Add v321 tile tuning if the existing evolved renderer does not have it.
    if 'panBuffer:0' not in expr:
        expr=expr.replace(
            "maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio',",
            "maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:160),startOpacity:.90,reloadStartOpacity:.98),userAgentPackageName:'com.bridgepoint.data_studio',",
            1,
        )
    replacement=prefix+'Opacity(opacity:.88,child:'+expr+'),' 
    body=body[:start]+replacement+body[j:]

# ---------------------------------------------------------------------------
# Conflict 3: the U.S.-weather control is radar-first. When used, it clears
# clouds and expansion badges so users can actually see NOAA reflectivity.
# ---------------------------------------------------------------------------
old_tooltip="tooltip:'Show United States live weather'"
new_tooltip="tooltip:'Show United States precipitation radar'"
if old_tooltip in body:
    body=body.replace(old_tooltip,new_tooltip,1)

# Locate the public map-control button by the U.S. precipitation tooltip (new or
# already-updated) and replace only its callback body.
button_idx=body.find(new_tooltip)
if button_idx<0:
    raise SystemExit('v321 repair: U.S. precipitation radar control missing')
control_start=body.rfind('_MapControlButton(',0,button_idx)
control_end=body.find('const SizedBox(height:7)',button_idx)
if control_start<0 or control_end<0:
    raise SystemExit('v321 repair: U.S. radar control boundaries missing')
control=body[control_start:control_end]
# Normalize setState callback regardless of the older live-weather wording.
control=re.sub(
    r"setState\(\(\)\{[^}]*?_showRadar=true;[^}]*?\}\);",
    "setState((){_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=4.2;});",
    control,
    count=1,
)
# If prior compact form did not match, replace the exact old callback state.
control=control.replace(
    "setState((){_showRadar=true;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;});",
    "setState((){_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=4.2;});",
)
control=control.replace(
    "United States live weather on • loading the latest NOAA precipitation radar…",
    "U.S. precipitation radar on • expansion badges hidden so the radar stays clear.",
)
if '_showClouds=false' not in control or '_showExpansion=false' not in control:
    raise SystemExit('v321 repair: U.S. radar control did not become radar-first')
if 'U.S. precipitation radar on • expansion badges hidden so the radar stays clear.' not in control:
    raise SystemExit('v321 repair: U.S. radar clarity message missing')
body=body[:control_start]+control+body[control_end:]

required=[
    'bridgepoint-v321-resilience-expansion-eta-radar-map',
    desired_catch,
    'Opacity(opacity:.88,child:TileLayer(',
    "tooltip:'Show United States precipitation radar'",
    '_showClouds=false',
    '_showExpansion=false',
    'U.S. precipitation radar on • expansion badges hidden so the radar stays clear.',
]
missing=[x for x in required if x not in body]
if missing:
    raise SystemExit(f'v321 responsive repair incomplete: {missing}')

path.write_text(body,encoding='utf-8')
print('Repaired the three v321 radar/mobile hunks structurally.')
