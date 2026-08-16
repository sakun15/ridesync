import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/location_service.dart';
import '../../../../state/location_provider.dart';

/// Shows the trip content once location permission is granted, and an
/// explanation of what's missing when it isn't.
///
/// Each denial state needs a different action — "denied" can be re-asked,
/// "denied forever" can only be fixed in system settings, and "services
/// disabled" is an OS-level toggle unrelated to this app. Treating them the
/// same would leave people tapping a button that can never work.
class LocationPermissionGate extends ConsumerWidget {
  const LocationPermissionGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(locationPermissionProvider);

    return permission.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _PermissionMessage(
        icon: Icons.error_outline,
        title: 'Could not check location access',
        body: 'Something went wrong. Try again.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(locationPermissionProvider),
      ),
      data: (state) {
        switch (state) {
          case LocationPermissionState.granted:
            return child;

          case LocationPermissionState.denied:
            return _PermissionMessage(
              icon: Icons.location_off_outlined,
              title: 'Location access needed',
              body: 'RideSync needs your location to show you on the map and '
                  'to send your position if something goes wrong.',
              actionLabel: 'Allow location',
              onAction: () => ref.invalidate(locationPermissionProvider),
            );

          case LocationPermissionState.deniedForever:
            return _PermissionMessage(
              icon: Icons.location_off_outlined,
              title: 'Location access blocked',
              body: 'Location is turned off for RideSync. You can turn it back '
                  'on in your phone settings.',
              actionLabel: 'Open settings',
              onAction: () =>
                  ref.read(locationServiceProvider).openSettings(),
            );

          case LocationPermissionState.servicesDisabled:
            return _PermissionMessage(
              icon: Icons.gps_off_outlined,
              title: 'Location is turned off',
              body: 'Your phone\'s location services are off. Turn them on to '
                  'share your position with the group.',
              actionLabel: 'Open location settings',
              onAction: () =>
                  ref.read(locationServiceProvider).openLocationSettings(),
            );
        }
      },
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.warning),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}