// ignore_for_file: avoid_print, depend_on_referenced_packages, unused_local_variable
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final logoFile = File('assets/Hissab Logo.png');
  if (!logoFile.existsSync()) {
    print('Error: assets/Hissab Logo.png not found');
    exit(1);
  }

  final bytes = logoFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Failed to decode logo image');
    exit(1);
  }

  print('Decoded original logo: ${image.width}x${image.height}');

  // Helper to resize while preserving aspect ratio, centered in a square canvas if needed
  img.Image makeSquareIcon(int size, {bool maskable = false}) {
    // If maskable, scale so it fits inside safe zone (approx 80%)
    final scaleFactor = maskable ? 0.8 : 1.0;
    final targetContentSize = (size * scaleFactor).round();

    final resized = img.copyResize(
      image,
      width: targetContentSize,
      height: targetContentSize,
      interpolation: img.Interpolation.cubic,
    );

    if (maskable) {
      // Create transparent square canvas and composite centered
      final canvas = img.Image(width: size, height: size, numChannels: 4);
      final xOffset = (size - targetContentSize) ~/ 2;
      final yOffset = (size - targetContentSize) ~/ 2;
      img.compositeImage(canvas, resized, dstX: xOffset, dstY: yOffset);
      return canvas;
    }
    return resized;
  }

  // 1. Web Favicon (64x64 PNG)
  final favicon = img.copyResize(image, width: 64, height: 64, interpolation: img.Interpolation.cubic);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
  print('Generated web/favicon.png');

  // 2. Web Icons & PWA
  final icon192 = makeSquareIcon(192);
  File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));

  final icon512 = makeSquareIcon(512);
  File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon512));

  final maskable192 = makeSquareIcon(192, maskable: true);
  File('web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(maskable192));

  final maskable512 = makeSquareIcon(512, maskable: true);
  File('web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(maskable512));
  print('Generated web/icons/* (192, 512, maskable)');

  // 3. Android mipmaps
  final androidSizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in androidSizes.entries) {
    final resized = makeSquareIcon(entry.value);
    final targetFile = File(entry.key);
    targetFile.parent.createSync(recursive: true);
    targetFile.writeAsBytesSync(img.encodePng(resized));
    print('Generated ${entry.key} (${entry.value}x${entry.value})');
  }

  print('All icons successfully generated from official Hissab Logo!');
}
