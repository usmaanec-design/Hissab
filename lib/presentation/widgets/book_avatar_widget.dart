import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hissab/core/constants/bank_catalog.dart';
import 'package:hissab/core/services/book_appearance_service.dart';

/// Reusable Book Avatar supporting:
/// 1. Bundled Bank Logos ('bank:alrajhi' or 'assets/banks/alrajhi.png')
/// 2. Uploaded Custom Logo (Base64 data URI or raw Base64)
/// 3. File Path Logo ('file:/path/to/image.png' or '/path/to/image.png')
/// 4. Generated Initial Avatar (First letter of book name + book color)
class BookAvatarWidget extends StatelessWidget {
  final String bookName;
  final int bookColor;
  final String? logo;
  final double size;
  final double borderRadius;
  final TextStyle? textStyle;
  final bool showBorder;

  const BookAvatarWidget({
    super.key,
    required this.bookName,
    required this.bookColor,
    this.logo,
    this.size = 40,
    this.borderRadius = 10,
    this.textStyle,
    this.showBorder = false,
  });

  Uint8List? _tryDecodeBase64(String source) {
    try {
      var clean = source;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(bookColor);
    final contrastTextColor = BookAppearanceService.getContrastTextColor(bgColor);
    final initial = BookAppearanceService.getInitial(bookName);

    Widget? imageWidget;

    if (logo != null && logo!.trim().isNotEmpty) {
      final logoStr = logo!.trim();

      // Case 1: Bundled Bank Logo
      if (logoStr.startsWith('bank:') || logoStr.startsWith('assets/banks/') || BankCatalog.findById(logoStr) != null) {
        String assetPath = logoStr;
        if (logoStr.startsWith('bank:')) {
          final bankId = logoStr.substring(5);
          final bank = BankCatalog.findById(bankId);
          assetPath = bank?.assetPath ?? 'assets/banks/$bankId.png';
        } else if (!logoStr.startsWith('assets/')) {
          final bank = BankCatalog.findById(logoStr);
          assetPath = bank?.assetPath ?? 'assets/banks/$logoStr.png';
        }

        imageWidget = Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackInitial(contrastTextColor, initial),
        );
      }
      // Case 2: File path (non-web)
      else if (!kIsWeb && (logoStr.startsWith('file:') || logoStr.startsWith('/') || logoStr.contains(r':\'))) {
        try {
          final filePath = logoStr.startsWith('file:') ? logoStr.substring(5) : logoStr;
          final file = File(filePath);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackInitial(contrastTextColor, initial),
            );
          }
        } catch (_) {
          imageWidget = null;
        }
      }
      // Case 3: Base64 image
      else if (logoStr.startsWith('data:image/') || logoStr.length > 100) {
        final bytes = _tryDecodeBase64(logoStr);
        if (bytes != null && bytes.isNotEmpty) {
          imageWidget = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitial(contrastTextColor, initial),
          );
        }
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: Colors.white.withAlpha(80), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: bgColor.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget ?? _buildFallbackInitial(contrastTextColor, initial),
    );
  }

  Widget _buildFallbackInitial(Color textColor, String initial) {
    return Center(
      child: Text(
        initial,
        style: textStyle ??
            TextStyle(
              fontSize: size * 0.48,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
      ),
    );
  }
}
