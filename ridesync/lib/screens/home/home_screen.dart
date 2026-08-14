import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RideSync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signed in as',
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              user?.displayName ?? 'Rider',
              style: textTheme.headlineSmall,
            ),
            Text(
              user?.email ?? '',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.construction_outlined,
                        size: 18,
                        color: AppColors.ash,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Phase 1 complete', style: textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Authentication, routing, and theming are working. '
                    'Trips and the live map come next.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Verifies the emergency style renders correctly. Wired up properly
            // in Phase 5 — for now it does nothing.
            ElevatedButton.icon(
              style: AppTheme.emergencyButtonStyle(context),
              onPressed: null,
              icon: const Icon(Icons.sos_outlined),
              label: const Text('SOS'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Not active until Phase 5',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}