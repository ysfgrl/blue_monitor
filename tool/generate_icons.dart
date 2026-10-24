import 'dart:io';

import 'package:image/image.dart' as image;

/// Run from the project root: dart run tool/generate_icons.dart
Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final iosProject = File('${root.path}/ios/Runner.xcodeproj/project.pbxproj');
  final iosProjectSettings = iosProject.readAsBytesSync();
  late final int result;
  try {
    final generator = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'flutter_launcher_icons'],
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
    );
    result = await generator.exitCode;
  } finally {
    // AppIcon is already selected. Preserve unrelated Xcode asset settings.
    iosProject.writeAsBytesSync(iosProjectSettings);
  }
  if (result != 0) {
    exitCode = result;
    return;
  }

  final source = image.decodePng(
    File('${root.path}/assets/iconcon.png').readAsBytesSync(),
  );
  if (source == null) throw StateError('assets/iconcon.png okunamadı.');

  image.Image resized(int size) => image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.average,
  );

  void write(String relativePath, List<int> bytes) {
    final file = File('${root.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  const appId = 'com.ysfgrl.serial_monitor.serial_monitor';
  for (final size in [16, 24, 32, 48, 64, 128, 256, 512]) {
    write(
      'linux/packaging/icons/hicolor/${size}x$size/apps/$appId.png',
      image.encodePng(resized(size)),
    );
  }
  write('linux/runner/resources/app_icon.png', image.encodePng(resized(512)));

  // Multiple ICO frames keep taskbar and Explorer icons sharp at every scale.
  write(
    'windows/runner/resources/app_icon.ico',
    image.IcoEncoder().encodeImages([
      for (final size in [16, 24, 32, 48, 64, 128, 256]) resized(size),
    ]),
  );
  write(
    'web/favicon.ico',
    image.IcoEncoder().encodeImages([
      for (final size in [16, 32, 48]) resized(size),
    ]),
  );
  write('web/icons/apple-touch-icon.png', image.encodePng(resized(180)));

  // Padding keeps the artwork visible inside circular PWA launcher masks.
  for (final size in [192, 512]) {
    final icon = image.Image(width: size, height: size, numChannels: 3);
    image.fill(icon, color: image.ColorRgb8(8, 22, 45));
    final contentSize = (size * 0.68).round();
    final offset = (size - contentSize) ~/ 2;
    image.compositeImage(
      icon,
      resized(contentSize),
      dstX: offset,
      dstY: offset,
    );
    write('web/icons/Icon-maskable-$size.png', image.encodePng(icon));
  }
  stdout.writeln('Android, iOS, web, macOS, Linux ve Windows ikonları hazır.');
}
