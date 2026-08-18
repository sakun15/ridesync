import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../state/recorder_provider.dart';

/// DEVELOPMENT ONLY — remove before release.
///
/// Records raw sensor data during a ride so thresholds can be tuned against
/// replayed data rather than repeated test rides.
///
/// The marker buttons matter as much as the recording itself: raw sensor data
/// with no labels tells you a spike happened, not what caused it.
class RecorderPanel extends ConsumerStatefulWidget {
  const RecorderPanel({super.key});

  @override
  ConsumerState<RecorderPanel> createState() => _RecorderPanelState();
}

class _RecorderPanelState extends ConsumerState<RecorderPanel> {
  Timer? _ticker;
  String? _lastMark;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Rebuild once a second so the elapsed time and sample count update.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggle() async {
    final recorder = ref.read(sensorRecorderProvider);

    if (recorder.isRecording) {
      final path = await recorder.stop();
      _ticker?.cancel();
      if (mounted) setState(() => _lastMark = null);

      if (path != null && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Recording saved'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(path)]),
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } else {
      await recorder.start();
      _startTicker();
      if (mounted) setState(() {});
    }
  }

  void _mark(String note) {
    ref.read(sensorRecorderProvider).mark(note);
    setState(() => _lastMark = note);
    // Clear the confirmation after a moment so it doesn't look stuck.
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lastMark = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recorder = ref.watch(sensorRecorderProvider);
    final isRecording = recorder.isRecording;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Amber, not red — this is a dev tool, not an emergency control.
        border: Border.all(
          color: isRecording ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRecording ? Icons.fiber_manual_record : Icons.science_outlined,
                size: 16,
                color: isRecording ? AppColors.warning : AppColors.ash,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isRecording ? 'Recording sensors' : 'Sensor recorder',
                  style: textTheme.titleSmall,
                ),
              ),
              if (isRecording)
                Text(
                  '${_formatDuration(recorder.elapsed)}  ·  ${recorder.sampleCount}',
                  style: textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          SizedBox(
            width: double.infinity,
            child: isRecording
                ? OutlinedButton.icon(
                    onPressed: _toggle,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop and save'),
                  )
                : ElevatedButton.icon(
                    onPressed: _toggle,
                    icon: const Icon(Icons.fiber_manual_record, size: 18),
                    label: const Text('Start recording'),
                  ),
          ),

          if (isRecording) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _lastMark == null ? 'Tap what just happened' : 'Marked: $_lastMark',
              style: textTheme.bodySmall?.copyWith(
                color: _lastMark == null ? AppColors.ash : AppColors.signal,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MarkChip(label: 'Pothole', onTap: () => _mark('pothole')),
                _MarkChip(label: 'Speed bump', onTap: () => _mark('speed_bump')),
                _MarkChip(label: 'Hard brake', onTap: () => _mark('hard_brake')),
                _MarkChip(label: 'Sharp turn', onTap: () => _mark('sharp_turn')),
                _MarkChip(label: 'Stopped', onTap: () => _mark('stopped')),
                _MarkChip(label: 'Rough road', onTap: () => _mark('rough_road')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkChip extends StatelessWidget {
  const _MarkChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.graphite,
      side: BorderSide.none,
    );
  }
}