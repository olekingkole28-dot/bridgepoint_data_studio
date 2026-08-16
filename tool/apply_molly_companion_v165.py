from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

# Upgrade any surviving generic walkthrough tip label.
text=text.replace("Text('TIP / TRICK'","Text(\"MOLLY'S TIP\"")

# Add a final, stable Molly companion element after all previous generated-release repairs.
marker='class _FieldNoteCard extends StatelessWidget{'
if text.count(marker)!=1:
    raise SystemExit('Field note marker missing for Molly companion')
classes=r'''
class _MollyCompanionTip extends StatelessWidget{
  const _MollyCompanionTip();
  @override Widget build(BuildContext context){
    final hour=DateTime.now().hour;
    final message=hour<10
      ? 'Molly says: start with the strongest evidence before the day gets noisy.'
      : hour<15
        ? 'Molly says: sniff out the evidence before you chase the lead.'
        : hour<20
          ? 'Molly says: save the good opportunity before it runs away.'
          : 'Molly says: tomorrow’s route is easier when today’s notes are clean.';
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
          const Text("MOLLY'S TIP",style:TextStyle(color:Color(0xFFE8B77F),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.7)),
          const SizedBox(height:3),Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4,fontStyle:FontStyle.italic)),
        ])),
      ]),
    );
  }
}

'''
text=text.replace(marker,classes+marker,1)

# Put Molly directly into the daily dashboard so she is visible even if walkthrough markup changes later.
anchor="""        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:fieldNoteRequest,builder:(context,noteSnapshot){
"""
if anchor not in text:
    raise SystemExit('Daily brief Molly placement anchor missing')
text=text.replace(anchor,"""        const SizedBox(height:10),const _MollyCompanionTip(),
        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:fieldNoteRequest,builder:(context,noteSnapshot){
""",1)

if text==original:
    raise SystemExit('No Molly companion changes applied')
path.write_text(text,encoding='utf-8')
print("Applied Molly companion final layer v165")
