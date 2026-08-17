from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v268-front-photo-compile'
if marker in body:
    print('Front photo compile repair v268 already applied.')
    raise SystemExit(0)

old="""          Positioned.fill(child:Material(color:Colors.transparent,child:InkWell(onTap:()=>_showZoomablePropertyImage(context,url,title:label,subtitle:'$source • $captured'),child:const Align(alignment:Alignment.bottomRight,child:Padding(padding:EdgeInsets.all(10),child:CircleAvatar(radius:17,backgroundColor:Colors.black54,child:Icon(Icons.zoom_in_rounded,color:Colors.white,size:19)))))),
"""
new="""          Positioned.fill(
            child:Material(
              color:Colors.transparent,
              child:InkWell(
                onTap:()=>_showZoomablePropertyImage(context,url,title:label,subtitle:'$source • $captured'),
                child:const Align(
                  alignment:Alignment.bottomRight,
                  child:Padding(
                    padding:EdgeInsets.all(10),
                    child:CircleAvatar(
                      radius:17,
                      backgroundColor:Colors.black54,
                      child:Icon(Icons.zoom_in_rounded,color:Colors.white,size:19),
                    ),
                  ),
                ),
              ),
            ),
          ),
"""
if body.count(old)!=1:
    raise SystemExit(f'v268 media overlay anchor count {body.count(old)}')
body=body.replace(old,new,1)
body += "\nconst String _bridgePointFrontPhotoCompileV268='bridgepoint-v268-front-photo-compile';\n"
path.write_text(body,encoding='utf-8')
print('Repaired front property photo media overlay compile v268.')
