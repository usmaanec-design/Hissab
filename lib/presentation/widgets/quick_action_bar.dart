import 'package:flutter/material.dart';
import 'package:hissab/core/theme/app_colors.dart';

class QuickActionBar extends StatelessWidget {
  final VoidCallback onMoneyIn;
  final VoidCallback onMoneyOut;

  const QuickActionBar({
    super.key,
    required this.onMoneyIn,
    required this.onMoneyOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Money In Button
            Expanded(
              child: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moneyIn,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ).buildButton(
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Money In (+)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                onPressed: onMoneyIn,
              ),
            ),
            const SizedBox(width: 12),

            // Money Out Button
            Expanded(
              child: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moneyOut,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ).buildButton(
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Money Out (-)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                onPressed: onMoneyOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on ButtonStyle {
  Widget buildButton({required Widget child, required VoidCallback onPressed}) {
    return ElevatedButton(
      style: this,
      onPressed: onPressed,
      child: child,
    );
  }
}
