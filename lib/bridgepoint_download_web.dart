// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

Future<bool> bridgePointDownloadText(String filename,String text,{String mimeType='text/plain'}) async{
  final bytes=utf8.encode(text);
  final blob=html.Blob([bytes],mimeType);
  final url=html.Url.createObjectUrlFromBlob(blob);
  try{
    final anchor=html.AnchorElement(href:url)
      ..download=filename
      ..style.display='none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return true;
  }finally{
    html.Url.revokeObjectUrl(url);
  }
}

Future<bool> bridgePointPrintPage() async{
  html.window.print();
  return true;
}
