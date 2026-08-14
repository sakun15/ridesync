import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/trip_provider.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trip = await ref.read(tripServiceProvider).createTrip(
            name: _nameController.text,
            description: _descriptionController.text,
            ownerId: user.uid,
            ownerDisplayName: user.displayName ?? 'Rider',
            ownerPhotoUrl: user.photoURL,
          );

      if (mounted) {
        context.go('${AppRoutes.trip}/${trip.tripId}');
      }
    } on TripException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not create the trip. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New trip')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everyone who joins can see your live location while the '
                  'trip is active.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Trip name',
                    hintText: 'Sunday ride to Nandi Hills',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Give your trip a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Meeting at the petrol pump at 6am',
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.signalDeep,
                          ),
                        )
                      : const Text('Create trip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}