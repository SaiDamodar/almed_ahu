import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDir = Directory(
    Platform.environment['SCREENSHOT_DIR'] ?? '${Platform.environment['HOME']}/Documents/iphone ss',
  );
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
  }

  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final path = '${outputDir.path}/$name.png';
      await File(path).writeAsBytes(bytes);
      final resize = await Process.run('sips', ['-z', '2688', '1242', path]);
      if (resize.exitCode != 0) {
        stderr.writeln('Resize failed for $name: ${resize.stderr}');
      }
      return true;
    },
  );
}
