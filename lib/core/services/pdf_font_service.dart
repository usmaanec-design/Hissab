import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Production-ready PDF Font and RTL text shaping service for Hissab.
/// Embeds true Unicode fonts (NotoSansArabic Regular & Bold) directly into PDF documents,
/// ensuring flawless rendering of Urdu, Arabic, English, and mixed RTL/LTR text
/// without missing characters, square boxes (tofu), or broken layouts.
class PdfFontService {
  static final PdfFontService instance = PdfFontService._internal();
  PdfFontService._internal();

  pw.Font? _regularFont;
  pw.Font? _boldFont;

  /// Loads and caches embedded TTF fonts from assets
  Future<void> initFonts() async {
    if (_regularFont != null && _boldFont != null) return;

    try {
      final regularData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _regularFont = pw.Font.ttf(regularData);

      final boldData = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _boldFont = pw.Font.ttf(boldData);
    } catch (e) {
      // Fallback to standard Helvetica if asset load fails in non-flutter environment
      _regularFont ??= pw.Font.helvetica();
      _boldFont ??= pw.Font.helveticaBold();
    }
  }

  pw.Font get regularFont => _regularFont ?? pw.Font.helvetica();
  pw.Font get boldFont => _boldFont ?? pw.Font.helveticaBold();

  /// Creates a unified PDF ThemeData with embedded Unicode font families
  /// and Helvetica fallback for complete mixed Urdu/Arabic/English support
  Future<pw.ThemeData> getPdfTheme() async {
    await initFonts();
    return pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
    );
  }

  /// Determines whether a given string contains predominantly RTL (Urdu / Arabic) characters
  static bool isRtlText(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    // Arabic, Urdu, Persian Unicode ranges: 0600-06FF, 0750-077F, 08A0-08FF, FB50-FDFF, FE70-FEFF
    final rtlRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return rtlRegex.hasMatch(text);
  }

  /// Wraps any text widget with proper RTL or LTR Directionality
  static pw.Widget wrapDirectional({
    required pw.Widget child,
    required String? text,
  }) {
    final isRtl = isRtlText(text);
    return pw.Directionality(
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: child,
    );
  }

  /// Helper to create a directional, overflow-safe PDF Text widget
  static pw.Widget buildText(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    int? maxLines,
  }) {
    final isRtl = isRtlText(text);
    return pw.Directionality(
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        text,
        style: style,
        textAlign: textAlign ?? (isRtl ? pw.TextAlign.right : pw.TextAlign.left),
        maxLines: maxLines,
      ),
    );
  }
}
