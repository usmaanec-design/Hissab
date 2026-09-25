// ignore_for_file: avoid_print, depend_on_referenced_packages, unused_local_variable
import 'dart:io';
import 'package:image/image.dart' as img;

class BankAssetDef {
  final String id;
  final String code;
  final int primaryColor;
  final int secondaryColor;
  final String country;

  const BankAssetDef({
    required this.id,
    required this.code,
    required this.primaryColor,
    required this.secondaryColor,
    required this.country,
  });
}

const banks = [
  // Saudi Banks
  BankAssetDef(id: 'alrajhi', code: 'RAJHI', primaryColor: 0xFF003882, secondaryColor: 0xFF001B44, country: 'sa'),
  BankAssetDef(id: 'snb', code: 'SNB', primaryColor: 0xFF006C35, secondaryColor: 0xFF004421, country: 'sa'),
  BankAssetDef(id: 'riyad', code: 'RIYAD', primaryColor: 0xFF004B87, secondaryColor: 0xFF002A4C, country: 'sa'),
  BankAssetDef(id: 'alinma', code: 'INMA', primaryColor: 0xFF8A5A2B, secondaryColor: 0xFF543414, country: 'sa'),
  BankAssetDef(id: 'albilad', code: 'BILAD', primaryColor: 0xFFBA1B23, secondaryColor: 0xFF7D1016, country: 'sa'),
  BankAssetDef(id: 'sab', code: 'SAB', primaryColor: 0xFFD41217, secondaryColor: 0xFF1E293B, country: 'sa'),
  BankAssetDef(id: 'anb', code: 'ANB', primaryColor: 0xFF0A2B4C, secondaryColor: 0xFFC29B38, country: 'sa'),
  BankAssetDef(id: 'bsf', code: 'BSF', primaryColor: 0xFF142F54, secondaryColor: 0xFF0B1A2F, country: 'sa'),
  BankAssetDef(id: 'saib', code: 'SAIB', primaryColor: 0xFF005A9C, secondaryColor: 0xFF003256, country: 'sa'),
  BankAssetDef(id: 'aljazira', code: 'JAZIRA', primaryColor: 0xFF00587C, secondaryColor: 0xFF003247, country: 'sa'),

  // Pakistan Banks
  BankAssetDef(id: 'meezan', code: 'MEEZAN', primaryColor: 0xFF003366, secondaryColor: 0xFFD4AF37, country: 'pk'),
  BankAssetDef(id: 'hbl', code: 'HBL', primaryColor: 0xFF007A5E, secondaryColor: 0xFF004D3B, country: 'pk'),
  BankAssetDef(id: 'ubl', code: 'UBL', primaryColor: 0xFF005696, secondaryColor: 0xFF003359, country: 'pk'),
  BankAssetDef(id: 'mcb', code: 'MCB', primaryColor: 0xFFDE6012, secondaryColor: 0xFF003865, country: 'pk'),
  BankAssetDef(id: 'alfalah', code: 'ALFALAH', primaryColor: 0xFFD01C24, secondaryColor: 0xFF7C0F14, country: 'pk'),
  BankAssetDef(id: 'abl', code: 'ABL', primaryColor: 0xFF002B49, secondaryColor: 0xFFF26722, country: 'pk'),
  BankAssetDef(id: 'askari', code: 'ASKARI', primaryColor: 0xFF004D25, secondaryColor: 0xFF002E16, country: 'pk'),
  BankAssetDef(id: 'faysal', code: 'FAYSAL', primaryColor: 0xFF003366, secondaryColor: 0xFF001F3F, country: 'pk'),
  BankAssetDef(id: 'alhabib', code: 'BAHL', primaryColor: 0xFF004422, secondaryColor: 0xFF002B15, country: 'pk'),
  BankAssetDef(id: 'scb', code: 'SCB', primaryColor: 0xFF008542, secondaryColor: 0xFF0054A6, country: 'pk'),
  BankAssetDef(id: 'js', code: 'JS', primaryColor: 0xFF003366, secondaryColor: 0xFFD4AF37, country: 'pk'),
  BankAssetDef(id: 'soneri', code: 'SONERI', primaryColor: 0xFF002B49, secondaryColor: 0xFF001A2C, country: 'pk'),
  BankAssetDef(id: 'habibmetro', code: 'HMB', primaryColor: 0xFFB31B2C, secondaryColor: 0xFF002855, country: 'pk'),
];

void main() {
  final outDir = Directory('assets/banks');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  const size = 180;
  for (final b in banks) {
    final image = img.Image(width: size, height: size, numChannels: 4);

    // Extract colors
    final pA = (b.primaryColor >> 24) & 0xFF;
    final pR = (b.primaryColor >> 16) & 0xFF;
    final pG = (b.primaryColor >> 8) & 0xFF;
    final pB = b.primaryColor & 0xFF;

    final sA = (b.secondaryColor >> 24) & 0xFF;
    final sR = (b.secondaryColor >> 16) & 0xFF;
    final sG = (b.secondaryColor >> 8) & 0xFF;
    final sB = b.secondaryColor & 0xFF;

    final radius = 32.0;

    // Draw rounded background with subtle diagonal gradient
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        // Rounded corner check
        bool inside = true;
        if (x < radius && y < radius) {
          final dx = radius - x;
          final dy = radius - y;
          if (dx * dx + dy * dy > radius * radius) inside = false;
        } else if (x >= size - radius && y < radius) {
          final dx = x - (size - radius - 1);
          final dy = radius - y;
          if (dx * dx + dy * dy > radius * radius) inside = false;
        } else if (x < radius && y >= size - radius) {
          final dx = radius - x;
          final dy = y - (size - radius - 1);
          if (dx * dx + dy * dy > radius * radius) inside = false;
        } else if (x >= size - radius && y >= size - radius) {
          final dx = x - (size - radius - 1);
          final dy = y - (size - radius - 1);
          if (dx * dx + dy * dy > radius * radius) inside = false;
        }

        if (inside) {
          final t = (x + y) / (2.0 * size);
          final r = (pR * (1.0 - t) + sR * t).round();
          final g = (pG * (1.0 - t) + sG * t).round();
          final bl = (pB * (1.0 - t) + sB * t).round();
          image.setPixelRgba(x, y, r, g, bl, 255);
        } else {
          image.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    // Draw inner accent circle
    final center = size ~/ 2;
    img.drawCircle(
      image,
      x: center,
      y: center,
      radius: (size * 0.38).round(),
      color: img.ColorRgba8(255, 255, 255, 30),
    );

    // Draw country dot top-right (Green for SA, White/Gold for PK)
    final dotColor = b.country == 'sa'
        ? img.ColorRgba8(0, 190, 80, 255)
        : img.ColorRgba8(255, 215, 0, 255);
    img.fillCircle(image, x: size - 26, y: 26, radius: 8, color: dotColor);

    // Draw text initials using built-in font
    img.drawString(
      image,
      b.code,
      font: img.arial24,
      x: (size - (b.code.length * 14)) ~/ 2,
      y: center - 12,
      color: img.ColorRgba8(255, 255, 255, 245),
    );

    final file = File('assets/banks/${b.id}.png');
    file.writeAsBytesSync(img.encodePng(image));
    print('Generated bank logo: ${file.path}');
  }

  print('Successfully generated ${banks.length} bank logo assets!');
}
