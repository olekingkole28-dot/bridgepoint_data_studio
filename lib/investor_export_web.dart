// ignore_for_file: deprecated_member_use
import 'dart:html' as html;

Future<bool> bridgepointDownloadInvestorHtml(String filename,String content) async {
  final blob=html.Blob([content],'text/html;charset=utf-8');
  final url=html.Url.createObjectUrlFromBlob(blob);
  final anchor=html.AnchorElement(href:url)..download=filename..style.display='none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<bool> bridgepointPrintInvestorHtml(String content) async {
  final w=html.window.open('about:blank','_blank');
  if(w==null)return false;
  w.document.open();
  w.document.write(content);
  w.document.close();
  await Future<void>.delayed(const Duration(milliseconds:350));
  w.focus();
  w.print();
  return true;
}
