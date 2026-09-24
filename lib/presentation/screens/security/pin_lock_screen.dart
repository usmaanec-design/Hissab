import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String? _errorMessage;

  void _onKeyPress(String digit) async {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });

      if (_pin.length == 4) {
        final appController = context.read<AppController>();
        final valid = await appController.unlockWithPin(_pin);
        if (valid) {
          widget.onUnlocked();
        } else {
          setState(() {
            _pin = '';
            _errorMessage = 'Incorrect PIN. Please try again.';
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.lock_rounded, size: 48, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            const Text(
              'Hissab Protected',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your 4-digit PIN to access your cashbook',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pin.length > i ? AppColors.primaryLight : Colors.grey.withAlpha(50),
                    border: Border.all(
                      color: _pin.length > i ? AppColors.primaryLight : Colors.grey,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.moneyOut, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],

            const Spacer(),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3'], isDark),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['4', '5', '6'], isDark),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['7', '8', '9'], isDark),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 64, height: 64),
                      _buildKeyButton('0', isDark),
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: IconButton(
                          icon: const Icon(Icons.backspace_outlined),
                          onPressed: _onBackspace,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeyButton(d, isDark)).toList(),
    );
  }

  Widget _buildKeyButton(String digit, bool isDark) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkCard : Colors.grey.withAlpha(30),
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
