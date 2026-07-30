import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  testWidgets('Test PDF', (tester) async {
    try {
      final doc = await PdfDocument.openFile('apk/demo_epub/Alices Adventures in Wonderland.pdf');
      print('Pages: ${doc.pages.length}');
      final page = doc.pages[0];
      final image = await page.render();
      print('Image width: ${image?.width}, height: ${image?.height}, pixels length: ${image?.pixels.length}');
    } catch (e) {
      print('Error: $e');
    }
  });
}
