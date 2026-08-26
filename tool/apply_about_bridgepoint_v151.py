from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

# v805: Weather/Home/Community now follow Studio + Integrations in the modern
# route table. Add About after Community without rewinding any existing route.
replace_once(
"""    _NavigationItem('Weather Center', Icons.cloud_outlined),
    _NavigationItem('My Home', Icons.home_rounded),
    _NavigationItem('Community', Icons.groups_2_outlined),
  ];
""",
"""    _NavigationItem('Weather Center', Icons.cloud_outlined),
    _NavigationItem('My Home', Icons.home_rounded),
    _NavigationItem('Community', Icons.groups_2_outlined),
    _NavigationItem('About BridgePoint', Icons.hub_outlined),
  ];
""",
'about-navigation')

replace_once(
"""      case 17:
        return const _CommunityPage();
      case 18:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
""",
"""      case 17:
        return const _CommunityPage();
      case 18:
        return const _AboutBridgePointPage();
      case 19:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
""",
'about-switch')

# Insert before Field Mode, a stable canonical boundary that remains after the
# modern Weather/Home/Community adapter and does not depend on retired owner UI.
marker='class _FieldModePage extends StatefulWidget {'
if text.count(marker)!=1:
    raise SystemExit(f'About BridgePoint insertion marker expected 1 match, found {text.count(marker)}')

page=r'''
class _AboutBridgePointPage extends StatelessWidget{
  const _AboutBridgePointPage();

  Widget _principle(IconData icon,String title,String body,{Color color=AppTheme.cyan})=>
    Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:AppTheme.panelSoft.withOpacity(.72),
        borderRadius:BorderRadius.circular(13),
        border:Border.all(color:color.withOpacity(.14)),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,color:color,size:22),
        const SizedBox(height:9),
        Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),
        const SizedBox(height:5),
        Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5)),
      ]),
    );

  Widget _stage(String number,String title,String body)=>Expanded(
    child:Container(
      constraints:const BoxConstraints(minWidth:150),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
        color:AppTheme.cyan.withOpacity(.045),
        borderRadius:BorderRadius.circular(12),
        border:Border.all(color:AppTheme.cyan.withOpacity(.12)),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(number,style:TextStyle(color:AppTheme.cyan.withOpacity(.75),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
        const SizedBox(height:6),
        Text(title,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.all(18),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(
        width:double.infinity,
        padding:const EdgeInsets.all(24),
        decoration:BoxDecoration(
          gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.12),AppTheme.blue.withOpacity(.08),AppTheme.panel.withOpacity(.82)]),
          borderRadius:BorderRadius.circular(18),
          border:Border.all(color:AppTheme.cyan.withOpacity(.18)),
        ),
        child:LayoutBuilder(builder:(context,constraints){
          final wide=constraints.maxWidth>820;
          final intro=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('ABOUT BRIDGEPOINT INTELLIGENCE',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.2)),
            const SizedBox(height:9),
            const Text('Turn fragmented property data into explainable action.',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,height:1.08)),
            const SizedBox(height:11),
            const Text(
              'BridgePoint Intelligence is the decision layer between scattered property information and the real-world decision of what deserves attention next. It connects evidence across properties, weather, events, permits, physical change, ownership, field observations and other trusted sources; resolves that evidence to the correct property; ranks what matters; explains why; helps people act; records the outcome; and learns from what happened.',
              style:TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.65),
            ),
            const SizedBox(height:13),
            Wrap(spacing:7,runSpacing:7,children:const [
              _OpportunityChip(label:'DETECT',color:AppTheme.cyan),
              _OpportunityChip(label:'CONNECT',color:AppTheme.blue),
              _OpportunityChip(label:'SCORE',color:AppTheme.green),
              _OpportunityChip(label:'EXPLAIN',color:AppTheme.cyan),
              _OpportunityChip(label:'ACT',color:AppTheme.amber),
              _OpportunityChip(label:'LEARN',color:AppTheme.green),
            ]),
          ]);
          final mission=Container(
            padding:const EdgeInsets.all(17),
            decoration:BoxDecoration(color:Colors.black.withOpacity(.18),borderRadius:BorderRadius.circular(14)),
            child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Icon(Icons.flag_outlined,color:AppTheme.green,size:26),
              SizedBox(height:10),
              Text('OUR MISSION',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
              SizedBox(height:7),
              Text('Give people a clearer information advantage before an important property decision is made.',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,height:1.3)),
              SizedBox(height:8),
              Text('BridgePoint is built so contractors, field teams, homeowners, investors, adjusters and other property decision-makers can understand what changed, what the evidence says, how confident that evidence is, and what action is worth considering—without hiding the reasoning behind a mystery score.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5)),
            ]),
          );
          return wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:3,child:intro),const SizedBox(width:18),Expanded(flex:2,child:mission)]):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[intro,const SizedBox(height:16),mission]);
        }),
      ),
      const SizedBox(height:18),
      const _PanelHeader(title:'The BridgePoint intelligence loop',subtitle:'The product is designed around the full decision cycle—not a static list of leads',action:'Evidence → outcome → learning'),
      const SizedBox(height:10),
      LayoutBuilder(builder:(context,constraints){
        if(constraints.maxWidth<780){
          return Column(children:[
            Row(children:[_stage('01','Detect','Find a new event, change, record or observation.'),const SizedBox(width:7),_stage('02','Resolve','Match it to the correct canonical property/entity.')]),
            const SizedBox(height:7),
            Row(children:[_stage('03','Connect','Combine supporting and counter-evidence across sources.'),const SizedBox(width:7),_stage('04','Prioritize','Score opportunity, confidence, urgency and freshness separately.')]),
            const SizedBox(height:7),
            Row(children:[_stage('05','Explain','Show Why This Property, Why Now and what changed.'),const SizedBox(width:7),_stage('06','Act + Learn','Route the work, track the outcome and improve future ranking.')]),
          ]);
        }
        return Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _stage('01','Detect','Find a new event, change, record or observation.'),const SizedBox(width:7),
          _stage('02','Resolve','Match it to the correct canonical property/entity.'),const SizedBox(width:7),
          _stage('03','Connect','Combine supporting and counter-evidence across sources.'),const SizedBox(width:7),
          _stage('04','Prioritize','Score opportunity, confidence, urgency and freshness separately.'),const SizedBox(width:7),
          _stage('05','Explain','Show Why This Property, Why Now and what changed.'),const SizedBox(width:7),
          _stage('06','Act + Learn','Route the work, track the outcome and improve future ranking.'),
        ]);
      }),
      const SizedBox(height:18),
      const _PanelHeader(title:'What BridgePoint is becoming',subtitle:'One intelligence foundation with different products and delivery layers',action:'App → Platform → APIs → Infrastructure'),
      const SizedBox(height:10),
      LayoutBuilder(builder:(context,constraints){
        final cols=constraints.maxWidth>=1000?4:constraints.maxWidth>=650?2:1;
        const gap=9.0;
        final width=(constraints.maxWidth-gap*(cols-1))/cols;
        final cards=[
          _principle(Icons.phone_iphone_rounded,'BridgePoint App','The working product: maps, weather, Property DNA, opportunities, routes, field workflow, CRM handoff, homeowner tools, community observations and owner controls.'),
          _principle(Icons.hub_outlined,'Intelligence Platform','The shared intelligence engine underneath every use case: property matching, evidence, patterns, scoring, opportunity lifecycle, provenance, outcomes and learning.',color:AppTheme.blue),
          _principle(Icons.api_rounded,'BridgePoint APIs','A way for larger customers and technology partners to consume BridgePoint property intelligence, evidence, models and workflows inside their own systems.',color:AppTheme.green),
          _principle(Icons.account_tree_outlined,'Technology Infrastructure','Reusable infrastructure for discovering, normalizing, matching, validating and continuously refreshing fragmented government/property data—plus the state-expansion machinery built on top of it.',color:AppTheme.amber),
        ];
        return Wrap(spacing:gap,runSpacing:gap,children:cards.map((c)=>SizedBox(width:width,child:c)).toList());
      }),
      const SizedBox(height:18),
      LayoutBuilder(builder:(context,constraints){
        final width=constraints.maxWidth>=900?(constraints.maxWidth-10)/2:constraints.maxWidth;
        return Wrap(spacing:10,runSpacing:10,children:[
          SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[Icon(Icons.business_center_outlined,color:AppTheme.cyan),SizedBox(width:8),Text('FOR PROPERTY PROFESSIONALS',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900))]),
            const SizedBox(height:10),
            const Text('BridgePoint sits upstream of a traditional CRM. The CRM manages a lead or customer you already know. BridgePoint helps answer the earlier question: “Which property should we be looking at, why, and how confident are we?”',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5)),
            const SizedBox(height:10),
            Wrap(spacing:6,runSpacing:6,children:const [
              _OpportunityChip(label:'Ranked opportunities',color:AppTheme.cyan),_OpportunityChip(label:'Why Now',color:AppTheme.green),_OpportunityChip(label:'Weather',color:AppTheme.blue),_OpportunityChip(label:'Routes',color:AppTheme.amber),_OpportunityChip(label:'Field evidence',color:AppTheme.cyan),_OpportunityChip(label:'CRM handoff',color:AppTheme.green),
            ]),
          ])))),
          SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[Icon(Icons.home_rounded,color:AppTheme.green),SizedBox(width:8),Text('FOR HOMEOWNERS',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900))]),
            const SizedBox(height:10),
            const Text('BridgePoint Home is built to shift the information advantage back toward the person who owns the house. The Home Passport combines public property facts with the homeowner’s private system history, warranties, maintenance, improvements, inventory, documents, weather/storm context, neighborhood intelligence and an action plan.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.5)),
            const SizedBox(height:10),
            Wrap(spacing:6,runSpacing:6,children:const [
              _OpportunityChip(label:'Home Passport',color:AppTheme.green),_OpportunityChip(label:'Property timeline',color:AppTheme.cyan),_OpportunityChip(label:'Home systems',color:AppTheme.blue),_OpportunityChip(label:'Maintenance',color:AppTheme.amber),_OpportunityChip(label:'Documents',color:AppTheme.cyan),_OpportunityChip(label:'Neighborhood intelligence',color:AppTheme.green),
            ]),
          ])))),
        ]);
      }),
      const SizedBox(height:18),
      const _PanelHeader(title:'Why BridgePoint is different',subtitle:'The advantage is not any single data source—it is the connected architecture and feedback loop',action:'Built for compounding intelligence'),
      const SizedBox(height:10),
      LayoutBuilder(builder:(context,constraints){
        final cols=constraints.maxWidth>=900?3:constraints.maxWidth>=600?2:1;
        const gap=9.0;final width=(constraints.maxWidth-gap*(cols-1))/cols;
        final items=[
          _principle(Icons.merge_type_rounded,'Many signals, one property record','BridgePoint resolves fragmented events and records back to a canonical property instead of leaving information trapped in separate datasets.'),
          _principle(Icons.fact_check_outlined,'Explainable by design','Opportunity score, confidence, urgency, evidence dates, provenance, counter-signals and score changes are meant to be inspectable—not hidden behind a single number.',color:AppTheme.green),
          _principle(Icons.history_toggle_off_rounded,'Remember what was known at the time','Historical evidence, score and model context can be preserved so later outcomes can be compared with what BridgePoint actually knew before the result.',color:AppTheme.blue),
          _principle(Icons.route_outlined,'Intelligence that reaches the field','Routes, assignments, status, notes, offline workflow and CRM handoff are designed to turn intelligence into an action instead of another dashboard.',color:AppTheme.amber),
          _principle(Icons.people_alt_outlined,'A proprietary evidence flywheel','Legitimate field observations, community observations and customer outcomes can become new proprietary evidence after trust, moderation and isolation rules are satisfied.'),
          _principle(Icons.public_rounded,'Expansion as technology','The long-term state expansion engine is designed to discover and adapt to different state datasets instead of assuming every state looks like Connecticut.',color:AppTheme.green),
        ];
        return Wrap(spacing:gap,runSpacing:gap,children:items.map((c)=>SizedBox(width:width,child:c)).toList());
      }),
      const SizedBox(height:18),
      Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.verified_user_outlined,color:AppTheme.cyan),SizedBox(width:8),Text('TRUST IS PART OF THE PRODUCT',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900))]),
        const SizedBox(height:10),
        const Text('BridgePoint should never become more confident than its evidence. Public-source facts, customer/private facts, community observations and BridgePoint-derived intelligence are kept conceptually separate. Missing evidence should be shown as missing. Predictions should be labeled as predictions. A weather exposure is not proof of damage. A community observation is not an official fact. A score is not proof of insurance coverage, legal status, safety, market value or a guaranteed outcome.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.6)),
        const SizedBox(height:10),
        Wrap(spacing:6,runSpacing:6,children:const [
          _OpportunityChip(label:'Provenance',color:AppTheme.cyan),_OpportunityChip(label:'Confidence',color:AppTheme.green),_OpportunityChip(label:'Evidence dates',color:AppTheme.blue),_OpportunityChip(label:'Counter-signals',color:AppTheme.amber),_OpportunityChip(label:'Tenant isolation',color:AppTheme.cyan),_OpportunityChip(label:'Human verification',color:AppTheme.green),
        ]),
      ]))),
      const SizedBox(height:18),
      Container(
        width:double.infinity,
        padding:const EdgeInsets.all(19),
        decoration:BoxDecoration(
          color:AppTheme.green.withOpacity(.055),
          borderRadius:BorderRadius.circular(15),
          border:Border.all(color:AppTheme.green.withOpacity(.15)),
        ),
        child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('THE DIRECTION',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
          SizedBox(height:7),
          Text('A living intelligence layer for properties.',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          SizedBox(height:7),
          Text('BridgePoint’s long-term goal is to make property intelligence continuously understandable and actionable: what a property is, what has happened to it, what is changing around it, what evidence exists, what is still unknown, what deserves attention, what action happened next, and whether that action produced a real outcome. As geographic coverage and outcome history grow, every legitimate new source, observation and result should make the system more useful—not just larger.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.6)),
        ]),
      ),
    ]),
  );
}

'''
text=text.replace(marker,page+marker,1)

for required in ["_NavigationItem('About BridgePoint'",'class _AboutBridgePointPage','case 19:','BridgePointOwnerCommandCenter']:
    if required not in text:
        raise SystemExit(f'About BridgePoint v805 marker missing: {required}')

if text==original:
    raise SystemExit('No About BridgePoint changes applied')
path.write_text(text,encoding='utf-8')
print('Applied About BridgePoint / Mission page v151/v805')
