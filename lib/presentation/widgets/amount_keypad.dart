import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';

class AmountKeypad extends StatelessWidget {
  final String currentAmountText;
  final CurrencyConfig currency;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback? onDone;

  const AmountKeypad({
    super.key,
    required this.currentAmountText,
    required this.currency,
    required this.onAmountChanged,
    this.onDone,
  });

  void _onKeyPress(String key) {
    String text = currentAmountText;

    if (key == 'C') {
      text = '';
    } else if (key == '⌫') {
      if (text.isNotEmpty) {
        text = text.substring(0, text.length - 1);
      }
    } else if (key == '.') {
      if (currency.decimalPlaces > 0 && !text.contains('.')) {
        text = text.isEmpty ? '0.' : '$text.';
      }
    } else {
      // Digit 0-9
      if (text == '0' && key == '0') return;
      if (text == '0' && key != '0') {
        text = key;
      } else {
        // Check if decimal places exceeded
        if (text.contains('.')) {
          final parts = text.split('.');
          if (parts.length > 1 && parts[1].length >= currency.decimalPlaces) {
            return; // Don't exceed allowed decimal places
          }
        }
        // Check reasonable length to avoid overflow
        if (text.length < 12) {
          text += key;
        }
      }
    }

    onAmountChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3'], isDark),
          const SizedBox(height: 8),
          _buildRow(['4', '5', '6'], isDark),
          const SizedBox(height: 8),
          _buildRow(['7', '8', '9'], isDark),
          const SizedBox(height: 8),
          _buildRow([currency.decimalPlaces > 0 ? '.' : 'C', '0', '⌫'], isDark),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys, bool isDark) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onKeyPress(key),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: key == '⌫' ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
