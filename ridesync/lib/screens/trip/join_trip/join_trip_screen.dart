import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/trip_provider.dart';

class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trip = await ref.read(tripServiceProvider).joinTrip(
            code: _codeController.text,
            uid: user.uid,
            displayName: user.displayName ?? 'Rider',
            photoUrl: user.photoURL,
          );

      if (mounted) {
        context.go('${AppRoutes.trip}/${trip.tripId}');
      }
    } on TripException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not join the trip. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join a trip')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask whoever created the trip for the six-character code.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleJoin(),
                  maxLength: 6,
                  // Codes are always uppercase and never contain O, I, or L —
                  // forcing case here means the user can't get it wrong.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.copyWith(
                        text: newValue.text.toUpperCase(),
                      ),
                    ),
                  ],
                  style: textTheme.displayMedium?.copyWith(
                    letterSpacing: 8,
                    fontSize: 32,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'ABC123',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the invite code';
                    }
                    if (value.trim().length != 6) {
                      return 'Codes are six characters';
                    }
                    return null;
                  },
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
                  onPressed: _isLoading ? null : _handleJoin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.signalDeep,
                          ),
                        )
                      : const Text('Join trip'),
                ),

                const SizedBox(height: AppSpacing.lg),
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
                      const Icon(Icons.visibility_outlined,
                          size: 18, color: AppColors.ash),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Joining shares your live location with everyone in '
                          'the trip until you leave or the trip ends.',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ),
          ),
        ),
      ),
    );
  }
}