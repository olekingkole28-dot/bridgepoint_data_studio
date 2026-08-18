from pathlib import Path

path=Path('tool/apply_catalog_package_fit_v315.py')
body=path.read_text(encoding='utf-8')
changed=False

# Anchor the owner package-fit preview to the verified v314 Investor Room toolbar.
legacy_block="""founder_old=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))])\"
founder_new=\"OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer')),OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit'))])\"
if body.count(founder_old)!=1:
    raise SystemExit(f'v315 founder package-fit preview anchor {body.count(founder_old)}')
body=body.replace(founder_old,founder_new,1)
"""
verified_block="""owner_anchor=\"IconButton(onPressed:refresh,tooltip:'Refresh Investor Room',icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))\"
owner_replace=\"OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit')),\"+owner_anchor
if body.count(owner_anchor)!=1:
    raise SystemExit(f'v315 Investor Room package-fit preview anchor {body.count(owner_anchor)}')
body=body.replace(owner_anchor,owner_replace,1)
"""
if legacy_block in body:
    body=body.replace(legacy_block,verified_block,1)
    changed=True
elif verified_block not in body:
    raise SystemExit('v315 package-fit preview insertion block is neither legacy nor verified')

# Repair two generated Dart ternaries. `primary?.10:.05` is parsed as a null-aware
# access on a bool, not as the intended conditional expression.
for old,new in [
    ('color.withOpacity(primary?.10:.05)','color.withOpacity(primary ? .10 : .05)'),
    ('color.withOpacity(primary?.34:.16)','color.withOpacity(primary ? .34 : .16)'),
]:
    if old in body:
        body=body.replace(old,new,1)
        changed=True
    elif new not in body:
        raise SystemExit(f'v315 compile repair target missing: {old}')

if changed:
    path.write_text(body,encoding='utf-8')
    print('Repaired v315 package-fit preview insertion and generated Dart ternaries.')
else:
    print('v315 package-fit generator repairs already applied.')
