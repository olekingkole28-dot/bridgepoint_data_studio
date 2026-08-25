from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
lines=text.splitlines()
needle='if(approvals.isNotEmpty)...['
indices=[i for i,line in enumerate(lines) if needle in line]

# v783: this script only repairs syntax inside the historical v94
# _OwnerExpansionPanel. The current Owner Command Center uses the separate
# BridgePointOwnerGlobalControl surface instead. If that newer control plane is
# wired and proves its governed expansion actions, there is intentionally no
# legacy approval block to repair.
def canonical_owner_global_present():
    owner_path=Path('lib/screens/bridgepoint_owner_global_control.dart')
    command_path=Path('lib/screens/bridgepoint_owner_command_center.dart')
    if not owner_path.exists() or not command_path.exists():
        return False
    owner=owner_path.read_text(encoding='utf-8')
    command=command_path.read_text(encoding='utf-8')
    return (
        'BridgePointOwnerGlobalControl' in command
        and 'bridgepoint_owner_global_command_v675' in owner
        and "'START_US_ALL'" in owner
        and "'START_WORLD_DISCOVERY'" in owner
        and "'START_JURISDICTION'" in owner
        and 'These actions queue discovery/build work. They never bypass validation or customer-readiness gates.' in owner
    )

if len(indices)==0 and canonical_owner_global_present():
    print('Legacy owner approval repair superseded by wired Owner Global Control v675; continuing')
elif len(indices)!=1:
    raise SystemExit(f'owner approval repair expected 1 legacy match or canonical owner global control, found {len(indices)}')
else:
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

# v785: apply_launch_v95 predates dart-format on the opportunity action row.
# Rewrite only that historical matcher to the current formatted source before
# v95 executes. The action names and handlers must still match exactly.
v95_path=Path('tool/apply_launch_v95.py')
v95=v95_path.read_text(encoding='utf-8')
compact_old='''"""                  Row(children:[
                    Expanded(child:FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity'))),
                    const SizedBox(width:10),
                    Expanded(child:OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note'))),
                  ]),
""",'''
formatted_old='''"""                  Row(children: [
                    Expanded(
                        child: FilledButton.icon(
                            onPressed: () {
                              _saveOpportunity(context, opportunity);
                            },
                            icon: const Icon(Icons.bookmark_add_rounded),
                            label: const Text('Save opportunity'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () {
                              _showAddNoteDialog(context, opportunity);
                            },
                            icon: const Icon(Icons.note_add_rounded),
                            label: const Text('Add note'))),
                  ]),
""",'''
if compact_old in v95:
    v95=v95.replace(compact_old,formatted_old,1)
    print('Modernized v95 opportunity CRM action matcher for formatted Dart v785')
elif formatted_old in v95:
    print('v95 opportunity CRM action matcher already modernized; continuing')
else:
    raise SystemExit('v95 opportunity CRM action matcher found neither compact nor formatted historical form')

# v786: dart-format also normalized the property-detail subtitle spacing.
# Both the historical input and the generated replacement use the same handler,
# so normalize both occurrences in the v95 script before it executes.
compact_property="subtitle:_opportunityWhyThisProperty(opportunity),"
formatted_property="subtitle: _opportunityWhyThisProperty(opportunity),"
property_count=v95.count(compact_property)
if property_count:
    v95=v95.replace(compact_property,formatted_property)
    print(f'Modernized {property_count} v95 property CRM subtitle matcher occurrence(s) v786')
elif v95.count(formatted_property) >= 2:
    print('v95 property CRM subtitle matcher already modernized; continuing')
else:
    raise SystemExit('v95 property CRM subtitle matcher found neither expected compact nor formatted forms')

v95_path.write_text(v95,encoding='utf-8')
