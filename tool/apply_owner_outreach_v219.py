from pathlib import Path

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v219-owner-outreach'

if marker in body:
    print('Owner outreach v219 already applied.')
    raise SystemExit(0)

old_data = """      final offer=map(data['founding_offer']),intel=map(data['intelligence']);
      final verticals=rows(data['top_opportunity_verticals']),failures=rows(data['recent_failures']);
"""
new_data = """      final offer=map(data['founding_offer']),intel=map(data['intelligence']);
      final outreach=map(data['outreach']);
      final outreachReplies=rows(outreach['recent_replies']);
      final verticals=rows(data['top_opportunity_verticals']),failures=rows(data['recent_failures']);
"""
if old_data not in body:
    raise SystemExit('Owner outreach v219 data anchor not found.')
body = body.replace(old_data, new_data, 1)

old_metric_tail = """          _MetricCard(width:w,label:'30-DAY USERS',value:_formatInteger(usage['monthly_active']??0),detail:'${usage['page_views_7d']??0} page views this week',icon:Icons.calendar_month_rounded,accent:const Color(0xFF9B7BFF)),
        ]);}),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;final w=wide?(c.maxWidth-16)/2:c.maxWidth;return Wrap(spacing:16,runSpacing:16,children:[
"""
new_metric_tail = """          _MetricCard(width:w,label:'30-DAY USERS',value:_formatInteger(usage['monthly_active']??0),detail:'${usage['page_views_7d']??0} page views this week',icon:Icons.calendar_month_rounded,accent:const Color(0xFF9B7BFF)),
          _MetricCard(width:w,label:'OUTREACH TARGET',value:'${_formatInteger(outreach['tracked_contacts']??0)} / ${_formatInteger(outreach['target_contacts']??500)}',detail:'${_formatInteger(outreach['remaining_to_target']??500)} contacts remaining',icon:Icons.campaign_rounded,accent:AppTheme.cyan),
          _MetricCard(width:w,label:'EMAILS SENT',value:_formatInteger(outreach['emails_sent']??0),detail:'${_formatInteger(outreach['emails_delivered']??0)} delivered',icon:Icons.outgoing_mail,accent:AppTheme.blue),
          _MetricCard(width:w,label:'OUTREACH REPLIES',value:_formatInteger(outreach['replies']??0),detail:'${_formatInteger(outreach['interested']??0)} interested • ${_formatInteger(outreach['not_interested']??0)} not interested',icon:Icons.mark_email_read_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'OUTREACH CONVERSIONS',value:_formatInteger(outreach['trials_started']??0),detail:'${_formatInteger(outreach['paid_customers']??0)} paid customers',icon:Icons.trending_up_rounded,accent:AppTheme.amber),
        ]);}),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;final w=wide?(c.maxWidth-16)/2:c.maxWidth;return Wrap(spacing:16,runSpacing:16,children:[
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Outreach Command Center',subtitle:'Apollo + inbox activity • statewide customer acquisition',action:'Owner only'),const SizedBox(height:14),
            _OwnerStatusRow('500-contact goal','${outreach['tracked_contacts']??0} / ${outreach['target_contacts']??500}',AppTheme.cyan),
            _OwnerStatusRow('Staged / enrolled','${outreach['staged']??0} / ${outreach['enrolled']??0}',AppTheme.blue),
            _OwnerStatusRow('Sent / delivered','${outreach['emails_sent']??0} / ${outreach['emails_delivered']??0}',AppTheme.green),
            _OwnerStatusRow('Replies / interested','${outreach['replies']??0} / ${outreach['interested']??0}',AppTheme.green),
            _OwnerStatusRow('Not interested / unsubscribed','${outreach['not_interested']??0} / ${outreach['unsubscribed']??0}',AppTheme.amber),
            _OwnerStatusRow('Bounced','${outreach['bounced']??0}',(outreach['bounced'] as num? ?? 0)>0?AppTheme.red:AppTheme.green),
            _OwnerStatusRow('Trials / paid','${outreach['trials_started']??0} / ${outreach['paid_customers']??0}',AppTheme.green),
            _OwnerStatusRow('Last send',outreach['last_sent_at']?.toString()??'Waiting for first send',AppTheme.cyan),
            _OwnerStatusRow('Last reply',outreach['last_reply_at']?.toString()??'No replies yet',AppTheme.cyan),
            if(outreachReplies.isNotEmpty)...[
              const Divider(height:24),
              const Text('Latest replies',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:8),
              ...outreachReplies.take(6).map((item)=>Container(
                margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),
                decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(10)),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[Expanded(child:Text('${item['company_name']??item['email']??'Prospect'}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10))),Text('${item['reply_disposition']??'REPLY'}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900))]),
                  const SizedBox(height:3),Text('${item['first_name']??''} ${item['last_name']??''} • ${item['replied_at']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                  if(item['reply_summary']?.toString().isNotEmpty==true)...[const SizedBox(height:4),Text(item['reply_summary'].toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.35))],
                ]),
              )),
            ] else const Padding(padding:EdgeInsets.only(top:8),child:Text('Replies will appear here automatically as outreach begins.',style:TextStyle(color:AppTheme.textMuted,fontSize:10))),
            const SizedBox(height:4),const Text('bridgepoint-v219-owner-outreach',style:TextStyle(fontSize:0,color:Colors.transparent)),
          ])))),
"""
if old_metric_tail not in body:
    raise SystemExit('Owner outreach v219 metric anchor not found.')
body = body.replace(old_metric_tail, new_metric_tail, 1)

old_heading = "_PageHeading(title:'Owner Center',subtitle:'Your private daily view of revenue • customers • automation • intelligence'"
new_heading = "_PageHeading(title:'Owner Center',subtitle:'Revenue • customers • outreach • automation • intelligence'"
if old_heading not in body:
    raise SystemExit('Owner outreach v219 heading anchor not found.')
body = body.replace(old_heading, new_heading, 1)

path.write_text(body, encoding='utf-8')
print('Applied BridgePoint owner outreach v219 UI.')
