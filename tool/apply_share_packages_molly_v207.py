from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

# Restore the persistent bottom-right Share control. Expansion already has a
# dedicated owner surface and must never steal this customer action slot.
share_anchor='''                                const _BridgePointLegalFooter(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                    ],
                  ),
'''
share_replacement='''                                const _BridgePointLegalFooter(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                    Positioned(
                      right: desktop ? 22 : 14,
                      bottom: desktop ? 22 : 14,
                      child: SafeArea(
                        child: Tooltip(
                          message:'Share BridgePoint',
                          child:FloatingActionButton.small(
                            heroTag:'bridgepoint-share-fab-v207',
                            onPressed:()=>_showShareBridgePointDialog(context),
                            backgroundColor:AppTheme.cyan,
                            foregroundColor:const Color(0xFF06111F),
                            elevation:7,
                            child:const Icon(Icons.ios_share_rounded,size:21),
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
'''
if share_anchor not in text:
    raise SystemExit('top-level workspace share anchor missing')
text=text.replace(share_anchor,share_replacement,1)

# Molly: slightly funnier rotating tips + an animated dog-bone orbit loader.
start=text.find('class _MollyCompanionTip extends StatelessWidget{')
end=text.find('class _FieldNoteCard extends StatelessWidget{',start)
if start<0 or end<0:
    raise SystemExit('Molly companion block missing')

molly=r'''class _MollyCompanionTip extends StatelessWidget{
  const _MollyCompanionTip();
  @override Widget build(BuildContext context){
    final now=DateTime.now();
    const tips=<String>[
      'Strongest evidence first. Coffee is optional. Receipts are not.',
      'Sniff out the evidence before you chase the lead. Squirrels are distracting enough.',
      'Save the good opportunity before somebody else throws the tennis ball.',
      'A clean note today prevents a mystery smell tomorrow.',
      'If three signals agree, Molly calls that more than a hunch. She also has excellent hunches.',
      'Check the date, check the source, then pounce. Very professional pouncing.',
      'The map is for intelligence, not wandering in circles. Molly already handles that department.',
      'High score plus fresh evidence beats a shiny pin with no story behind it.',
    ];
    final message=tips[(now.weekday*3+now.hour) % tips.length];
    return Container(
      width:double.infinity,
      padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),
      decoration:BoxDecoration(
        color:const Color(0xFFD6A06A).withOpacity(.075),
        borderRadius:BorderRadius.circular(12),
        border:Border.all(color:const Color(0xFFD6A06A).withOpacity(.22)),
      ),
      child:Row(children:[
        Container(
          width:38,height:38,
          decoration:BoxDecoration(color:const Color(0xFFD6A06A).withOpacity(.18),shape:BoxShape.circle,border:Border.all(color:const Color(0xFFD6A06A).withOpacity(.30))),
          child:const Icon(Icons.pets_rounded,color:Color(0xFFE8B77F),size:21),
        ),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(mainAxisSize:MainAxisSize.min,children:[
            Text("MOLLY'S TIP",style:TextStyle(color:Color(0xFFE8B77F),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.7)),
            SizedBox(width:7),
            _MollyBoneSpinner(size:23),
          ]),
          const SizedBox(height:3),Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4,fontStyle:FontStyle.italic)),
        ])),
      ]),
    );
  }
}

class _MollyBoneSpinner extends StatefulWidget{
  const _MollyBoneSpinner({this.size=23});
  final double size;
  @override State<_MollyBoneSpinner> createState()=>_MollyBoneSpinnerState();
}

class _MollyBoneSpinnerState extends State<_MollyBoneSpinner> with SingleTickerProviderStateMixin{
  late final AnimationController _controller;
  @override void initState(){super.initState();_controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1500))..repeat();}
  @override void dispose(){_controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Semantics(
    label:'Molly dog bone activity animation',
    child:SizedBox(width:widget.size,height:widget.size,child:Stack(alignment:Alignment.center,children:[
      Container(decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0xFFE8B77F).withOpacity(.24),width:1.2))),
      AnimatedBuilder(animation:_controller,builder:(context,child)=>Transform.rotate(
        angle:_controller.value*6.283185307179586,
        child:Align(alignment:Alignment.topCenter,child:child),
      ),child:CustomPaint(size:Size(widget.size*.34,widget.size*.18),painter:const _MollyBonePainter())),
    ])),
  );
}

class _MollyBonePainter extends CustomPainter{
  const _MollyBonePainter();
  @override void paint(Canvas canvas,Size size){
    final paint=Paint()..color=const Color(0xFFE8B77F)..style=PaintingStyle.fill;
    final h=size.height;final w=size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.18,h*.30,w*.64,h*.40),Radius.circular(h*.20)),paint);
    final r=h*.25;
    canvas.drawCircle(Offset(w*.16,h*.28),r,paint);canvas.drawCircle(Offset(w*.16,h*.72),r,paint);
    canvas.drawCircle(Offset(w*.84,h*.28),r,paint);canvas.drawCircle(Offset(w*.84,h*.72),r,paint);
  }
  @override bool shouldRepaint(covariant _MollyBonePainter oldDelegate)=>false;
}

'''
text=text[:start]+molly+text[end:]

# Make Molly's live walkthrough asides a touch more playful without changing
# the factual training instructions underneath.
walk_anchor="""    final target='${step['nav_label']??step['title']??'this page'}';
    return Container(
"""
walk_replace="""    final target='${step['nav_label']??step['title']??'this page'}';
    final mollyAside=switch(index%4){
      0=>'Quick sniff test:',1=>'Molly checked under the couch and found this:',
      2=>'Tiny tail-wag tip:',_=>'Before we chase the next screen:',
    };
    return Container(
"""
if walk_anchor not in text:
    raise SystemExit('Molly walkthrough target anchor missing')
text=text.replace(walk_anchor,walk_replace,1)
old_walk="""          const SizedBox(height:7),Text(tip.isNotEmpty?'Molly: $tip':why,style:const TextStyle(color:Color(0xFFE8B77F),fontSize:8.5,fontStyle:FontStyle.italic,height:1.4)),
"""
new_walk="""          const SizedBox(height:7),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const _MollyBoneSpinner(size:20),const SizedBox(width:6),Expanded(child:Text(tip.isNotEmpty?'Molly: $mollyAside $tip':'Molly: $mollyAside $why',style:const TextStyle(color:Color(0xFFE8B77F),fontSize:8.5,fontStyle:FontStyle.italic,height:1.4)))]),
"""
if old_walk not in text:
    raise SystemExit('Molly walkthrough tip anchor missing')
text=text.replace(old_walk,new_walk,1)

# Standard package delivery truth in the UI. BUILDING packages stay visible
# for preview, but the buttons clearly stop billing until verified output is
# present. Technology readiness comes from its delivery contract metadata.
card_anchor="""    final technology=key.startsWith('technology_')||type.toLowerCase().contains('technology');
    final accent=_bridgePointPackageAccent(key,type);
"""
card_replace="""    final technology=key.startsWith('technology_')||type.toLowerCase().contains('technology');
    final configuration=package['configuration'] is Map?Map<String,dynamic>.from(package['configuration'] as Map):<String,dynamic>{};
    final deliveryStatus='${configuration['delivery_status']??(technology?'MANAGED_PILOT':'READY')}'.toUpperCase();
    final checkoutReady=technology?false:configuration['checkout_ready']==true;
    final deliveryNote='${configuration['delivery_note']??configuration['delivery_summary']??''}'.trim();
    final accent=_bridgePointPackageAccent(key,type);
"""
if card_anchor not in text:
    raise SystemExit('package card configuration anchor missing')
text=text.replace(card_anchor,card_replace,1)

chip_anchor="""                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:Color(0xFFFFC857)),
                  _OpportunityChip(
                    label: package['active'] == true ? 'ACTIVE' : 'INACTIVE',
"""
chip_replace="""                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:Color(0xFFFFC857)),
                  _OpportunityChip(
                    label:deliveryStatus.replaceAll('_',' '),
                    color:deliveryStatus=='READY'?AppTheme.green:deliveryStatus=='BUILDING'||deliveryStatus=='ROADMAP'?AppTheme.amber:AppTheme.cyan,
                  ),
                  _OpportunityChip(
                    label: package['active'] == true ? 'ACTIVE' : 'INACTIVE',
"""
if chip_anchor not in text:
    raise SystemExit('package card chip anchor missing')
text=text.replace(chip_anchor,chip_replace,1)

price_anchor="""                      monthly == null && yearly == null
                          ? 'Pricing not configured'
                          : monthly != null
                              ? '${technology?'Starting at ':''}\$${monthly.toStringAsFixed(0)} / month'
                              : '\$${yearly!.toStringAsFixed(0)} / year',
"""
price_replace="""                      !technology&&!checkoutReady
                          ? 'BUILDING VERIFIED DELIVERY • NOT BILLING YET'
                          : monthly == null && yearly == null
                              ? 'Pricing not configured'
                              : monthly != null
                                  ? '${technology?'Starting at ':''}\$${monthly.toStringAsFixed(0)} / month'
                                  : '\$${yearly!.toStringAsFixed(0)} / year',
"""
if price_anchor not in text:
    raise SystemExit('package card price anchor missing')
text=text.replace(price_anchor,price_replace,1)

models_tail="""              if (models.length > 4)
                Text(
                  '+ ${models.length - 4} more models',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 16),
"""
models_tail_repl="""              if (models.length > 4)
                Text(
                  '+ ${models.length - 4} more models',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if(!technology&&!checkoutReady&&deliveryNote.isNotEmpty)...[
                const SizedBox(height:10),
                Text(deliveryNote,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.amber,fontSize:8.5,height:1.4,fontWeight:FontWeight.w700)),
              ],
              const SizedBox(height: 16),
"""
if models_tail not in text:
    raise SystemExit('package model tail anchor missing')
text=text.replace(models_tail,models_tail_repl,1)

detail_vars="""  final maturity='${configuration['maturity']??''}'.trim();
  final deliveryModes=(configuration['delivery_modes'] is List?(configuration['delivery_modes'] as List):const []).map((e)=>'$e'.replaceAll('_',' ')).toList();
"""
detail_vars_repl="""  final maturity='${configuration['maturity']??''}'.trim();
  final deliveryStatus='${configuration['delivery_status']??(technology?'MANAGED_PILOT':'READY')}'.toUpperCase();
  final checkoutReady=technology?false:configuration['checkout_ready']==true;
  final deliveryNote='${configuration['delivery_note']??configuration['delivery_summary']??''}'.trim();
  final deliveryModes=(configuration['delivery_modes'] is List?(configuration['delivery_modes'] as List):const []).map((e)=>'$e'.replaceAll('_',' ')).toList();
"""
if detail_vars not in text:
    raise SystemExit('package detail vars anchor missing')
text=text.replace(detail_vars,detail_vars_repl,1)

status_stat="""                    _MiniStat(
                      label: 'STATUS',
                      value: package['active'] == true ? 'Active' : 'Inactive',
                    ),
"""
status_stat_repl=status_stat+"""                    _MiniStat(
                      label:'DELIVERY',
                      value:deliveryStatus.replaceAll('_',' '),
                    ),
"""
if status_stat not in text:
    raise SystemExit('package detail status stat anchor missing')
text=text.replace(status_stat,status_stat_repl,1)

info_old="""                    technology
                      ? 'Technology pricing is shown as a starting point. BridgePoint scopes data volume, deployment mode, geography, API usage and support before billing. Core scoring weights and proprietary learning logic stay protected.'
                      : 'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',
"""
info_new="""                    technology
                      ? 'Technology pricing is shown as a starting point. BridgePoint scopes data volume, deployment mode, geography, API usage and support before billing. Core scoring weights and proprietary learning logic stay protected.'
                      : checkoutReady
                        ? 'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.'
                        : (deliveryNote.isEmpty?'BridgePoint is still building the verified delivery for this package. Self-checkout is paused and no customer will be billed until the package-specific output is live.':deliveryNote),
"""
if info_old not in text:
    raise SystemExit('package detail billing info anchor missing')
text=text.replace(info_old,info_new,1)

buttons_old="""                )) else Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:const Icon(Icons.bolt_rounded),
                    label:Text(package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
"""
buttons_new="""                )) else Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:!checkoutReady||package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:Icon(checkoutReady?Icons.bolt_rounded:Icons.construction_rounded),
                    label:Text(!checkoutReady?'Building verified feed':package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:!checkoutReady||package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(!checkoutReady?'Not billing yet':package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
"""
if buttons_old not in text:
    raise SystemExit('package detail checkout buttons anchor missing')
text=text.replace(buttons_old,buttons_new,1)

for marker in [
  'bridgepoint-share-fab-v207','Molly dog bone activity animation','Strongest evidence first. Coffee is optional. Receipts are not.',
  'BUILDING VERIFIED DELIVERY • NOT BILLING YET','Building verified feed','deliveryStatus.replaceAll'
]:
  if marker not in text: raise SystemExit(f'missing v207 marker: {marker}')

if text==original: raise SystemExit('No v207 Share/package/Molly changes applied')
p.write_text(text,encoding='utf-8')
print('Applied Share restoration, package delivery truth, and Molly animation/personality v207')
