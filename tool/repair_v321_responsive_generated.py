from pathlib import Path
import re

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')

# V687: this repair still protects the functional NOAA/radar contract, but it no
# longer freezes the release to one old V321 map-control tooltip. Later releases
# legitimately evolved the control surface while preserving the radar loader and
# primary noaa-radar TileLayer.

# ---------------------------------------------------------------------------
# Conflict 1: verified-frame discovery is additive. If the frame-list helper
# fails, keep radar entitlement enabled and fall back to NOAA's newest/current
# layer rather than making the whole radar disappear.
# ---------------------------------------------------------------------------
fn_start=body.find('Future<void> _loadNoaaRadarFramesV271()')
if fn_start<0:
    raise SystemExit('v321 repair: _loadNoaaRadarFramesV271 missing')
open_brace=body.find('{',fn_start)
if open_brace<0:
    raise SystemExit('v321 repair: NOAA frame loader opening brace missing')
depth=0;quote=None;escaped=False;fn_end=None
for i in range(open_brace,len(body)):
    ch=body[i]
    if quote is not None:
        if escaped: escaped=False
        elif ch=='\\': escaped=True
        elif ch==quote: quote=None
        continue
    if ch in ("'",'\"'):
        quote=ch;continue
    if ch=='{': depth+=1
    elif ch=='}':
        depth-=1
        if depth==0:
            fn_end=i+1
            break
if fn_end is None:
    raise SystemExit('v321 repair: NOAA frame loader end missing')
segment=body[fn_start:fn_end]
desired_catch="catch(_){if(mounted)setState((){_weatherAllowedV318=true;_noaaRadarFramesV271=<DateTime>[];_radarFrameIndex=0;_radarRevision++;});}"
if desired_catch not in segment:
    catches=list(re.finditer(r'catch\s*\(_\)\s*\{',segment))
    if not catches:
        raise SystemExit('v321 repair: NOAA loader catch missing')
    match=catches[-1]
    catch_start=match.start()
    catch_open=segment.find('{',match.start())
    depth=0;quote=None;escaped=False;catch_end=None
    for i in range(catch_open,len(segment)):
        ch=segment[i]
        if quote is not None:
            if escaped: escaped=False
            elif ch=='\\': escaped=True
            elif ch==quote: quote=None
            continue
        if ch in ("'",'\"'):
            quote=ch;continue
        if ch=='{': depth+=1
        elif ch=='}':
            depth-=1
            if depth==0:
                catch_end=i+1
                break
    if catch_end is None:
        raise SystemExit('v321 repair: NOAA loader catch did not balance')
    segment=segment[:catch_start]+desired_catch+segment[catch_end:]
    body=body[:fn_start]+segment+body[fn_end:]

# ---------------------------------------------------------------------------
# Conflict 2: strengthen the primary Intelligence Map precipitation overlay.
# Find the map TileLayer by its noaa-radar ValueKey, then wrap it in opacity and
# use low-latency tile buffering. This remains compatible with later releases.
# ---------------------------------------------------------------------------
radar_key="key:ValueKey('noaa-radar-$_radarRevision-${_radarFrame.toIso8601String()}')"
key_idx=body.find(radar_key)
if key_idx<0:
    raise SystemExit('v321 repair: primary Intelligence Map radar TileLayer missing')
window_start=max(0,key_idx-180)
window_end=min(len(body),key_idx+900)
window=body[window_start:window_end]
if 'Opacity(opacity:.88,child:TileLayer(' not in window:
    tile_start=body.rfind('TileLayer(',0,key_idx)
    if tile_start<0 or key_idx-tile_start>180:
        raise SystemExit('v321 repair: primary radar TileLayer start not found')
    cond_start=body.rfind('if(_weatherAllowedV318&&_showRadar)',0,tile_start)
    if cond_start>=0 and tile_start-cond_start<90:
        start=cond_start
        prefix='if(_weatherAllowedV318&&_showRadar)'
    else:
        start=tile_start
        prefix=''

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
    j=end
    while j<len(body) and body[j] in ' \t': j+=1
    if j<len(body) and body[j]==',': j+=1
    expr=body[tile_start:end]
    if 'panBuffer:0' not in expr:
        expr=expr.replace(
            "maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio',",
            "maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:160),startOpacity:.90,reloadStartOpacity:.98),userAgentPackageName:'com.bridgepoint.data_studio',",
            1,
        )
    replacement=prefix+'Opacity(opacity:.88,child:'+expr+'),'
    body=body[:start]+replacement+body[j:]

# ---------------------------------------------------------------------------
# Conflict 3: if the legacy V321 U.S.-weather control still exists, keep its
# radar-first behavior. If a later release has replaced that specific widget,
# do not fail the whole release: Conflicts 1 and 2 above already prove the live
# NOAA loader, entitlement fallback and primary radar layer are present.
# ---------------------------------------------------------------------------
old_tooltip="tooltip:'Show United States live weather'"
new_tooltip="tooltip:'Show United States precipitation radar'"
if old_tooltip in body:
    body=body.replace(old_tooltip,new_tooltip,1)

button_idx=body.find(new_tooltip)
legacy_control_present=button_idx>=0
if legacy_control_present:
    control_start=body.rfind('_MapControlButton(',0,button_idx)
    control_end=body.find('const SizedBox(height:7)',button_idx)
    if control_start<0 or control_end<0:
        raise SystemExit('v321 repair: legacy U.S. radar control boundaries missing')
    control=body[control_start:control_end]
    control=re.sub(
        r"setState\(\(\)\{[^}]*?_showRadar=true;[^}]*?\}\);",
        "setState((){_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=4.2;});",
        control,
        count=1,
    )
    control=control.replace(
        "setState((){_showRadar=true;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;});",
        "setState((){_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=4.2;});",
    )
    desired_notice="ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration:Duration(seconds:2),content:Text('U.S. precipitation radar on • expansion badges hidden so the radar stays clear.')));"
    if 'U.S. precipitation radar on • expansion badges hidden so the radar stays clear.' not in control:
        notice_start=control.find('ScaffoldMessenger.of(context).showSnackBar')
        if notice_start>=0:
            notice_end=control.find(';',notice_start)
            if notice_end<0:
                raise SystemExit('v321 repair: U.S. radar snackbar terminator missing')
            control=control[:notice_start]+desired_notice+control[notice_end+1:]
        else:
            load_call='unawaited(_loadNoaaRadarFramesV271());'
            if load_call in control:
                control=control.replace(load_call,load_call+desired_notice,1)
            else:
                state_call="setState((){_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=4.2;});"
                if state_call not in control:
                    raise SystemExit('v321 repair: radar-first state call missing for snackbar insertion')
                control=control.replace(state_call,state_call+desired_notice,1)
    if '_showClouds=false' not in control or '_showExpansion=false' not in control:
        raise SystemExit('v321 repair: legacy U.S. radar control did not become radar-first')
    if 'U.S. precipitation radar on • expansion badges hidden so the radar stays clear.' not in control:
        raise SystemExit('v321 repair: legacy U.S. radar clarity message missing')
    body=body[:control_start]+control+body[control_end:]
else:
    evolved_required=[
        '_loadNoaaRadarFramesV271',
        '_weatherAllowedV318',
        '_showRadar',
        radar_key,
    ]
    evolved_missing=[x for x in evolved_required if x not in body]
    if evolved_missing:
        raise SystemExit(f'v687 evolved radar contract incomplete: {evolved_missing}')
    print('v687: legacy V321 U.S. radar button not present; validated evolved NOAA/radar contract instead.')

required=[
    'bridgepoint-v321-resilience-expansion-eta-radar-map',
    desired_catch,
    'Opacity(opacity:.88,child:TileLayer(',
    '_loadNoaaRadarFramesV271',
    '_weatherAllowedV318',
    '_showRadar',
]
if legacy_control_present:
    required += [
        new_tooltip,
        '_showClouds=false',
        '_showExpansion=false',
        'U.S. precipitation radar on • expansion badges hidden so the radar stays clear.',
    ]
missing=[x for x in required if x not in body]
if missing:
    raise SystemExit(f'v321 responsive repair incomplete: {missing}')

path.write_text(body,encoding='utf-8')
print('Repaired V321 radar/mobile conflicts with V687 evolved-control compatibility.')
