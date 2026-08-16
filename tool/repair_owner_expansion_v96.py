from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
lines=text.splitlines()
needle='if(approvals.isNotEmpty)...['
indices=[i for i,line in enumerate(lines) if needle in line]
if len(indices)!=1:
    raise SystemExit(f'owner approval repair expected 1 match, found {len(indices)}')
i=indices[0]
indent=lines[i][:len(lines[i])-len(lines[i].lstrip())]
replacement=f'''{indent}if(approvals.isNotEmpty)...[
{indent}  const SizedBox(height:12),
{indent}  const Text('YOUR APPROVAL REQUIRED',style:TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),
{indent}  ...approvals.map((a)=>Container(
{indent}    width:double.infinity,
{indent}    margin:const EdgeInsets.only(top:7),
{indent}    padding:const EdgeInsets.all(11),
{indent}    decoration:BoxDecoration(
{indent}      color:AppTheme.amber.withOpacity(.07),
{indent}      borderRadius:BorderRadius.circular(10),
{indent}      border:Border.all(color:AppTheme.amber.withOpacity(.17)),
{indent}    ),
{indent}    child:Column(
{indent}      crossAxisAlignment:CrossAxisAlignment.start,
{indent}      children:[
{indent}        Text('${{a['title']??a['approval_type']}}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),
{indent}        const SizedBox(height:3),
{indent}        Text('${{a['message']??''}}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
{indent}        const SizedBox(height:8),
{indent}        Wrap(
{indent}          spacing:8,runSpacing:8,
{indent}          children:[
{indent}            FilledButton(onPressed:busy?null:()=>approve('${{a['approval_id']}}','APPROVED'),child:const Text('Approve & continue')),
{indent}            OutlinedButton(onPressed:busy?null:()=>approve('${{a['approval_id']}}','REJECTED'),child:const Text('Reject')),
{indent}          ],
{indent}        ),
{indent}      ],
{indent}    ),
{indent}  )),
{indent}],'''.splitlines()
lines[i:i+1]=replacement
p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Repaired owner expansion approval UI syntax')
