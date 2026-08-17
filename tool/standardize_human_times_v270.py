from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v270-human-readable-times'
if marker in body:
    print('Human-readable timestamps v270 already applied.')
    raise SystemExit(0)

old_bp="""String _bpDateTime(Object? value){
  final dt=DateTime.tryParse('$value')?.toLocal();
  if(dt==null)return '${value??'—'}';
  final h=dt.hour%12==0?12:dt.hour%12;
  final m=dt.minute.toString().padLeft(2,'0');
  final ap=dt.hour>=12?'PM':'AM';
  return '${dt.month}/${dt.day}/${dt.year} • $h:$m $ap';
}
"""
new_bp="""String _bpClockV270(DateTime dt){
  final h=dt.hour%12==0?12:dt.hour%12;
  final m=dt.minute.toString().padLeft(2,'0');
  final ap=dt.hour>=12?'PM':'AM';
  return '$h:$m $ap';
}

String _bpDateLabelV270(DateTime dt){
  const months=<String>['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final now=DateTime.now();
  final today=DateTime(now.year,now.month,now.day);
  final day=DateTime(dt.year,dt.month,dt.day);
  final delta=today.difference(day).inDays;
  if(delta==0)return 'Today';
  if(delta==1)return 'Yesterday';
  if(dt.year==now.year)return '${months[dt.month-1]} ${dt.day}';
  return '${months[dt.month-1]} ${dt.day}, ${dt.year}';
}

String _bpDateTime(Object? value){
  final raw='${value??''}'.trim();
  final dt=DateTime.tryParse(raw)?.toLocal();
  if(dt==null)return raw.isEmpty?'Time unavailable':raw;
  return '${_bpDateLabelV270(dt)} at ${_bpClockV270(dt)}';
}

String _bpUpdatedTimeV270(Object? value){
  final raw='${value??''}'.trim();
  final dt=DateTime.tryParse(raw)?.toLocal();
  if(dt==null)return raw.isEmpty?'Update time unavailable':raw;
  final now=DateTime.now();
  final sameDay=dt.year==now.year&&dt.month==now.month&&dt.day==now.day;
  return sameDay?'Updated ${_bpClockV270(dt)}':'Updated ${_bpDateLabelV270(dt)} at ${_bpClockV270(dt)}';
}

String _bpExactTimeV270(Object? value){
  final raw='${value??''}'.trim();
  final dt=DateTime.tryParse(raw)?.toLocal();
  if(dt==null)return raw;
  const months=<String>['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month-1]} ${dt.day}, ${dt.year} at ${_bpClockV270(dt)}';
}
"""
if body.count(old_bp)!=1:
    raise SystemExit(f'v270 _bpDateTime anchor count {body.count(old_bp)}')
body=body.replace(old_bp,new_bp,1)

old_ai="""String _bridgePointAiDateV263(dynamic value){
  final d=DateTime.tryParse('${value??''}')?.toLocal();
  if(d==null)return '';
  const months=<String>['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month-1]} ${d.day}, ${d.year}';
}
"""
new_ai="""String _bridgePointAiDateV263(dynamic value){
  final raw='${value??''}'.trim();
  if(raw.isEmpty)return '';
  return _bpDateTime(value);
}
"""
if body.count(old_ai)!=1:
    raise SystemExit(f'v270 AI date anchor count {body.count(old_ai)}')
body=body.replace(old_ai,new_ai,1)

old_when="""  String whenText(Object? value){
    final dt=DateTime.tryParse('$value')?.toLocal();if(dt==null)return '$value';
    final h=dt.hour%12==0?12:dt.hour%12;final m=dt.minute.toString().padLeft(2,'0');final ap=dt.hour>=12?'PM':'AM';
    return '${dt.month}/${dt.day} • $h:$m $ap';
  }
"""
new_when="""  String whenText(Object? value)=>_bpDateTime(value);
"""
if body.count(old_when)!=1:
    raise SystemExit(f'v270 growth whenText anchor count {body.count(old_when)}')
body=body.replace(old_when,new_when,1)

old_notification="""      final created=DateTime.tryParse('${n['created_at']??''}')?.toLocal();
      final createdLabel=created==null?'Time unavailable':'${created.month}/${created.day}/${created.year} • ${(created.hour%12)==0?12:created.hour%12}:${created.minute.toString().padLeft(2,'0')} ${created.hour>=12?'PM':'AM'}';
"""
new_notification="""      final createdLabel=_bpDateTime(n['created_at']);
"""
if body.count(old_notification)!=1:
    raise SystemExit(f'v270 notification timestamp anchor count {body.count(old_notification)}')
body=body.replace(old_notification,new_notification,1)

old_seen="""            final seen=DateTime.tryParse('${person['last_seen_at']??person['last_sign_in_at']??person['account_created_at']??''}')?.toLocal();
            final seenLabel=seen==null?'No activity timestamp':('${seen.month}/${seen.day} • ${(seen.hour%12)==0?12:seen.hour%12}:${seen.minute.toString().padLeft(2,'0')} ${seen.hour>=12?'PM':'AM'}');
"""
new_seen="""            final seenRaw=person['last_seen_at']??person['last_sign_in_at']??person['account_created_at'];
            final seenLabel=seenRaw==null?'No activity timestamp':_bpDateTime(seenRaw);
"""
if body.count(old_seen)!=1:
    raise SystemExit(f'v270 recent people timestamp anchor count {body.count(old_seen)}')
body=body.replace(old_seen,new_seen,1)

replacements={
"item['next_action_at']==null?'No next action':'Next ${item['next_action_at'].toString().substring(0,10)}'":"item['next_action_at']==null?'No next action':'Next ${_bpDateTime(item['next_action_at'])}'",
"item['follow_up_at']==null?'UNSCHEDULED':item['follow_up_at'].toString().substring(0,10)":"item['follow_up_at']==null?'Unscheduled':_bpDateTime(item['follow_up_at'])",
"'Detected: ${signal['detected_at'] ?? '—'}\\n'":"'Detected: ${signal['detected_at']==null?'—':_bpDateTime(signal['detected_at'])}\\n'",
"'Effective: ${signal['effective_at'] ?? '—'}\\n'":"'Effective: ${signal['effective_at']==null?'—':_bpDateTime(signal['effective_at'])}\\n'",
"'Expires: ${signal['expires_at'] ?? '—'}'":"'Expires: ${signal['expires_at']==null?'—':_bpDateTime(signal['expires_at'])}'",
}
for old,new in replacements.items():
    if body.count(old)!=1:
        raise SystemExit(f'v270 timestamp replacement anchor count {body.count(old)} for {old[:48]}')
    body=body.replace(old,new,1)

# Make the common generated/update label explicitly read like a human update status.
generated_old="""    final generated=_bpDateTime(data['generated_at']);
"""
generated_new="""    final generated=_bpUpdatedTimeV270(data['generated_at']);
"""
if body.count(generated_old)==1:
    body=body.replace(generated_old,generated_new,1)

body += "\nconst String _bridgePointHumanReadableTimesV270='bridgepoint-v270-human-readable-times | Today at 9:03 PM | Updated 9:03 PM | exact local audit time';\n"
path.write_text(body,encoding='utf-8')
print('Standardized BridgePoint timestamps to human-readable local time v270.')
