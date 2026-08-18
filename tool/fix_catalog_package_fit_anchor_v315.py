from pathlib import Path

path=Path('tool/apply_catalog_package_fit_v315.py')
body=path.read_text(encoding='utf-8')
if "owner_anchor=\"IconButton(onPressed:refresh,tooltip:'Refresh Investor Room'" in body:
    print('v315 package-fit preview already anchored to verified Investor Room toolbar.')
    raise SystemExit(0)

old="""founder_old=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))])\"
founder_new=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer')),OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit'))])\"
if body.count(founder_old)!=1:
    raise SystemExit(f'v315 founder package-fit preview anchor {body.count(founder_old)}')
body=body.replace(founder_old,founder_new,1)
"""
new="""owner_anchor=\"IconButton(onPressed:refresh,tooltip:'Refresh Investor Room',icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))\"
owner_replace=\"OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit')),\"+owner_anchor
if body.count(owner_anchor)!=1:
    raise SystemExit(f'v315 Investor Room package-fit preview anchor {body.count(owner_anchor)}')
body=body.replace(owner_anchor,owner_replace,1)
"""
if body.count(old)!=1:
    raise SystemExit(f'v315 generator legacy founder block count {body.count(old)}')
body=body.replace(old,new,1)
path.write_text(body,encoding='utf-8')
print('Repaired v315 package-fit preview insertion to the verified Investor Room toolbar.')
