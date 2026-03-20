import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final String screenshotsDir = Platform.environment['SCREENSHOTS_DIR'] ?? 'screenshots';
  try {
    await integrationDriver(
      onScreenshot: (String name, List<int> imageBytes, [Map<String, dynamic>? args]) async {
        final File image = await File('$screenshotsDir/$name.png').create(recursive: true);
        await image.writeAsBytes(imageBytes);
        print('Screenshot saved: $screenshotsDir/$name.png');
        return true;
      },
    );
  } catch (e) {
    print('Error occurred while taking screenshot: $e');
  }
}
