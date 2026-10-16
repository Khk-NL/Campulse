import 'dart:typed_data';

import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/browser_endpoints.dart';
import 'package:campus_mobile/features/study/local_pdf_storage_browser.dart'
    as browser_pdf;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configured backend remains unchanged for native builds', () {
    expect(
      browserEndpoint('/ai', 'https://example.com/ai'),
      'https://example.com/ai',
    );
    expect(AppConfig.defaults().requestTimeout, const Duration(seconds: 5));
  });

  test(
    'browser local PDF actions direct the user to authenticated cloud storage',
    () async {
      await expectLater(
        browser_pdf.writePdf('card', Uint8List(4)),
        throwsUnsupportedError,
      );
      await expectLater(browser_pdf.readPdf('file'), throwsUnsupportedError);
      await expectLater(browser_pdf.deletePdf('file'), throwsUnsupportedError);
    },
  );
}
