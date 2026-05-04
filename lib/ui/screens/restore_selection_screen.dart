import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/metric_service.dart';
import '../../services/profile_service.dart';
import 'app_shell.dart';
import 'profile_setup_screen.dart';

class RestoreSelectionScreen extends StatefulWidget {
  const RestoreSelectionScreen({super.key});

  @override
  State<RestoreSelectionScreen> createState() => _RestoreSelectionScreenState();
}

class _RestoreSelectionScreenState extends State<RestoreSelectionScreen> {
  bool _isLoading = false;

  Future<void> _resumeSession() async {
    final profileService = context.read<ProfileService>();
    setState(() => _isLoading = true);
    try {
      await profileService.recoverFromDatabase();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startFresh() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Fresh?'),
        content: const Text(
          'This will permanently delete all existing data on this device and '
          'generate a new Research ID. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete & Start Fresh'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final profileService = context.read<ProfileService>();
    final metricService = context.read<MetricService>();

    setState(() => _isLoading = true);
    try {
      await profileService.startFresh();
      await metricService.debugResetMetrics();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting fresh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.restore_page_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back',
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We found existing Covary data on this device. Would you like to resume your previous study session, or wipe it and start fresh?',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Resume Option
                FilledButton.icon(
                  onPressed: _resumeSession,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume Session'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start Fresh Option
                OutlinedButton.icon(
                  onPressed: _startFresh,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Start Fresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
