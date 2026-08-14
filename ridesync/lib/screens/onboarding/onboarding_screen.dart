import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(
                Icons.shield_outlined,
                size: 48,
                color: AppColors.signal,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Travel together,\nstay safe',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Share your live location with friends and family, and get '
                'automatic crash detection with emergency alerts.',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.smoke),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _Feature(
                icon: Icons.location_on_outlined,
                title: 'Live group map',
                description: 'See everyone in your trip in real time.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _Feature(
                icon: Icons.sensors_outlined,
                title: 'Crash detection',
                description:
                    'Sensors watch for impacts and alert your contacts.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _Feature(
                icon: Icons.sos_outlined,
                title: 'One-tap SOS',
                description: 'Send your location to emergency contacts.',
              ),
              const Spacer(),
              // Plain, unglamorous, and non-negotiable. Overstating what
              // smartphone crash detection can do is the single most harmful
              // thing this app could claim.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.slate,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Crash detection is a best-effort feature. It can miss '
                        'real crashes and can trigger falsely. Never rely on it '
                        'as your only safety measure.',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.signup),
                child: const Text('Get started'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.ash),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(description, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}