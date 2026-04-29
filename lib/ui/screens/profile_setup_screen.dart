import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/profile_service.dart';
import 'app_shell.dart';

/// Profile setup screen where the user enters or updates their nickname.
///
/// Displayed on first launch and accessible from settings. Shows the
/// auto-generated UUID (read-only) for transparency, and a text field
/// for the nickname. Every save records a [EventCategory.meta] event
/// with latency tracking per HCI requirements.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Timestamp when the screen was opened — used to calculate [latencyMs].
  late final DateTime _screenOpenedAt;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _screenOpenedAt = DateTime.now();

    // Pre-fill with existing nickname if editing.
    final profileService = context.read<ProfileService>();
    _nicknameController.text = profileService.nickname;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// Calculates the latency in milliseconds since the screen was opened.
  int _calculateLatencyMs() {
    return DateTime.now().difference(_screenOpenedAt).inMilliseconds;
  }

  /// Validates and saves the nickname, logging latency as an HCI metric.
  ///
  /// On first launch, navigates to [AppShell] (replacing the stack).
  /// When editing from Settings, simply pops back.
  Future<void> _saveNickname() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final wasFirstLaunch = context.read<ProfileService>().isFirstLaunch;

    try {
      final profileService = context.read<ProfileService>();
      await profileService.setNickname(
        _nicknameController.text,
        latencyMs: _calculateLatencyMs(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${profileService.nickname}! 🎉'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (wasFirstLaunch) {
          // First launch → navigate to the main app shell.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppShell()),
            (_) => false,
          );
        } else if (Navigator.of(context).canPop()) {
          // Editing from Settings → go back.
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving nickname: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileService = context.watch<ProfileService>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- App Icon ---
                  Icon(
                    Icons.insights_rounded,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),

                  // --- Title ---
                  Text(
                    'Covary',
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // --- Subtitle ---
                  Text(
                    profileService.isFirstLaunch
                        ? 'Welcome! Set up your profile to get started.'
                        : 'Update your profile below.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // --- UUID Display (read-only) ---
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.fingerprint_rounded,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Your Research ID',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            profileService.uuid,
                            style: textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This ID is generated once and ties all your data '
                            'together for analysis. It cannot be changed.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withAlpha(
                                179,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Nickname Input ---
                  TextFormField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      labelText: 'Nickname',
                      hintText: 'Enter a display name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveNickname(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a nickname';
                      }
                      if (value.trim().length > 30) {
                        return 'Nickname must be 30 characters or less';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- Save Button ---
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveNickname,
                    icon: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      profileService.isFirstLaunch
                          ? 'Get Started'
                          : 'Save Changes',
                    ),
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

                  // --- Privacy note ---
                  Text(
                    '🔒 All data stays on your device. '
                    'Nothing is sent to any server.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withAlpha(153),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
