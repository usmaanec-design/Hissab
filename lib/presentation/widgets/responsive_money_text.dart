import 'package:flutter/material.dart';
import '../../core/constants/currencies.dart';
import '../../core/utils/money_display_formatter.dart';

/// Reusable, overflow-safe money text widget.
/// Guarantees that extremely large amounts (e.g. SAR 555,555,555,555.00)
/// will NEVER cause RenderFlex overflows, overlap other widgets, or clip awkwardly.
///
/// Features:
/// - Exact, compact, or smart formatting mode.
/// - FittedBox auto-scaling to prevent overflow on narrow screens.
/// - Tooltip showing full exact amount on tap or hover.
/// - Accessibility semantics with exact readable amount.
/// - Optional two-line mode for tight cards.
class ResponsiveMoneyText extends StatelessWidget {
  final int minorUnits;
  final CurrencyConfig currency;
  final TextStyle? style;
  final Color? color;
  final bool isCompact;
  final bool smart;
  final bool showExplicitPlus;
  final Alignment alignment;
  final bool twoLines;
  final double? fontSize;
  final FontWeight? fontWeight;

  const ResponsiveMoneyText({
    super.key,
    required this.minorUnits,
    required this.currency,
    this.style,
    this.color,
    this.isCompact = false,
    this.smart = false,
    this.showExplicitPlus = false,
    this.alignment = Alignment.centerLeft,
    this.twoLines = false,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );

    final exactText = MoneyDisplayFormatter.formatExact(
      minorUnits,
      currency,
      showExplicitPlus: showExplicitPlus,
    );

    String displayText;
    if (isCompact) {
      displayText = MoneyDisplayFormatter.formatCompact(
        minorUnits,
        currency,
        showExplicitPlus: showExplicitPlus,
      );
    } else if (smart) {
      displayText = MoneyDisplayFormatter.formatSmart(
        minorUnits,
        currency,
        showExplicitPlus: showExplicitPlus,
      );
    } else {
      displayText = exactText;
    }

    Widget content;
    if (twoLines) {
      final parts = MoneyDisplayFormatter.formatParts(
        minorUnits,
        currency,
        compact: isCompact,
        showExplicitPlus: showExplicitPlus,
      );
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment == Alignment.centerRight
            ? CrossAxisAlignment.end
            : (alignment == Alignment.center ? CrossAxisAlignment.center : CrossAxisAlignment.start),
        children: [
          Text(
            '${parts.sign}${parts.code}',
            style: effectiveStyle.copyWith(
              fontSize: (effectiveStyle.fontSize ?? 14) * 0.75,
              fontWeight: FontWeight.w600,
              color: effectiveStyle.color?.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(
              parts.amount,
              style: effectiveStyle,
              maxLines: 1,
            ),
          ),
        ],
      );
    } else {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          displayText,
          style: effectiveStyle,
          maxLines: 1,
          softWrap: false,
        ),
      );
    }

    return Tooltip(
      message: exactText,
      waitDuration: const Duration(milliseconds: 300),
      child: Semantics(
        label: exactText,
        child: content,
      ),
    );
  }
}
