import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart'
    as platform;

Future<void> saveAdminReport({
  required List<int> bytes,
  required String filename,
  required String contentType,
}) => platform.saveAdminReport(
  bytes: bytes,
  filename: filename,
  contentType: contentType,
);
