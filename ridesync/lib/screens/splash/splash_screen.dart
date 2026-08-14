import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown while Firebase restores the session. The router holds here until auth
/// resolves, so this doubles as the cold-start loading state.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.void_,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 64,
              color: AppColors.signal,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('RideSync', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Travel together. Stay safe.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}