import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveAdminReport({
  required List<int> bytes,
  required String filename,
  required String contentType,
}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
