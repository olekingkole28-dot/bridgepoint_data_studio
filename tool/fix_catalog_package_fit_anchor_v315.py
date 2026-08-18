from pathlib import Path

path=Path('tool/apply_catalog_package_fit_v315.py')
body=path.read_text(encoding='utf-8')
if "founder_old=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))\"" in body:
    print('v315 founder preview insertion already layout-agnostic.')
    raise SystemExit(0)

old="""founder_old=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))])\"
founder_new=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer')),OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit'))])\"
"""
new="""founder_old=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))\"
founder_new=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer')),OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit'))\"
"""
if body.count(old)!=1:
    raise SystemExit(f'v315 generator founder block count {body.count(old)}')
body=body.replace(old,new,1)
path.write_text(body,encoding='utf-8')
print('Repaired v315 founder package-fit preview insertion to be layout-agnostic.')
