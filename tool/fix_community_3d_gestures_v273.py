from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v273-community-3d-gesture-capture'
if marker in body:
    print('Community 3D gesture capture v273 already applied.')
    raise SystemExit(0)

if "import 'package:flutter/gestures.dart';" not in body:
    anchor="import 'package:flutter/material.dart';\n"
    if body.count(anchor)!=1:
        raise SystemExit(f'v273 material import anchor {body.count(anchor)}')
    body=body.replace(anchor,anchor+"import 'package:flutter/gestures.dart';\n",1)

map_anchor="""        SizedBox(height:compact?390:510,child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          styleString:_style,
"""
map_replace="""        SizedBox(height:compact?390:510,child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          styleString:_style,
          gestureRecognizers:<Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(()=>EagerGestureRecognizer()),
          },
"""
if body.count(map_anchor)!=1:
    raise SystemExit(f'v273 Community 3D map anchor {body.count(map_anchor)}')
body=body.replace(map_anchor,map_replace,1)

old_help="""        Positioned(left:10,bottom:10,right:10,child:IgnorePointer(child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xD907111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white12)),child:Row(children:[const Icon(Icons.touch_app_rounded,color:AppTheme.cyan,size:15),const SizedBox(width:6),Expanded(child:Text(compact?'Drag • pinch • rotate • two-finger tilt':'Drag to move • scroll/pinch to zoom • rotate • tilt the camera • live layers refresh when you stop moving',style:const TextStyle(color:Colors.white70,fontSize:8,fontWeight:FontWeight.w700)))])))),
"""
new_help="""        Positioned(left:10,bottom:10,right:10,child:IgnorePointer(child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xD907111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white12)),child:Row(children:[const Icon(Icons.touch_app_rounded,color:AppTheme.cyan,size:15),const SizedBox(width:6),Expanded(child:Text(compact?'Map captures your drag • pinch • rotate • two-finger tilt':'Drag/rotate/tilt stays inside the 3D map • scroll the page only outside the map',style:const TextStyle(color:Colors.white70,fontSize:8,fontWeight:FontWeight.w700)))])))),
"""
if body.count(old_help)!=1:
    raise SystemExit(f'v273 Community 3D help anchor {body.count(old_help)}')
body=body.replace(old_help,new_help,1)

body += "\nconst String _bridgePointCommunity3DGestureCaptureV273='bridgepoint-v273-community-3d-gesture-capture | EagerGestureRecognizer | map drag does not scroll page';\n"
path.write_text(body,encoding='utf-8')
print('Applied Community 3D gesture capture v273.')
