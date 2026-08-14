import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trip_model.dart';
import '../../state/auth_provider.dart';
import '../../state/trip_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider).value;
    final tripsAsync = ref.watch(activeTripsProvider);

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              user?.displayName ?? 'Rider',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.createTrip),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New trip'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.joinTrip),
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Join'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            Text('Active trips', style: textTheme.labelSmall),
            const SizedBox(height: AppSpacing.sm),

            tripsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'Could not load your trips. Check your connection.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
              ),
              data: (trips) {
                if (trips.isEmpty) return const _EmptyTrips();
                return Column(
                  children: trips
                      .map((t) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _TripCard(trip: t),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.push('${AppRoutes.trip}/${trip.tripId}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.signal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.memberIds.length} '
                    '${trip.memberIds.length == 1 ? "person" : "people"}'
                    '  ·  ${trip.inviteCode}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.ash),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.route_outlined, size: 28, color: AppColors.ash),
          const SizedBox(height: AppSpacing.sm),
          Text('No active trips', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start a trip or join one with a code.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}