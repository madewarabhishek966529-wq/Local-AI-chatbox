import 'package:flutter/material.dart';
import '../../core/widgets/local_signal.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LocalSignalDot(size: 14),
            SizedBox(height: 16),
            Text(
              'LOCAL',
              style: TextStyle(
                color: AppColors.textSecondary,
                letterSpacing: 4,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
