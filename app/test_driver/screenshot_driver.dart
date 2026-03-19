import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  try {
    await integrationDriver(
      onScreenshot: (String name, List<int> imageBytes, [Map<String, dynamic>? args]) async {
        final File image = await File('screenshots/$name.png').create(recursive: true);
        await image.writeAsBytes(imageBytes);
        print('Screenshot saved: screenshots/$name.png');
        return true;
      },
    );
  } catch (e) {
    print('Error occurred while taking screenshot: $e');
  }
}
