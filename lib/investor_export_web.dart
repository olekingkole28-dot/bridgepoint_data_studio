// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
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
  // Let the printable document call window.print() on itself. This avoids depending
  // on WindowBase.document/focus/print APIs that current Flutter web no longer exposes.
  final printable=content.replaceFirst(
    '</body>',
    '<script>window.addEventListener("load",function(){setTimeout(function(){window.print();},250);});</script></body>',
  );
  final blob=html.Blob([printable],'text/html;charset=utf-8');
  final url=html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url,'_blank');
  await Future<void>.delayed(const Duration(seconds:2));
  html.Url.revokeObjectUrl(url);
  return true;
}
