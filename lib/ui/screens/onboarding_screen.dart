import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/profile_service.dart';
import '../../services/metric_service.dart';
import '../widgets/edit_window_dialog.dart';
import '../widgets/metric_icon.dart';
import '../../data/models/enums.dart';
import 'profile_setup_screen.dart';
import 'package:covary/ui/screens/app_shell.dart';
import '../../services/sync_service.dart';
import '../widgets/sync_summary_dialog.dart';
import 'interactive_tutorial_screen.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final DateTime _startTime;
  late DateTime _pageOpenedAt;
  final Map<String, int> _slideLatencies = {};

  static const List<String> _pageKeys = [
    'onboarding_slide_welcome_ms',
    'onboarding_slide_method_ms',
    'onboarding_slide_privacy_ms',
    'onboarding_slide_support_ms',
    'onboarding_slide_preset_ms',
    'onboarding_slide_schedule_ms',
    'onboarding_slide_metrics_ms',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _pageOpenedAt = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final now = DateTime.now();
    final elapsed = now.difference(_pageOpenedAt).inMilliseconds;
    if (_currentPage >= 0 && _currentPage < _pageKeys.length) {
      final key = _pageKeys[_currentPage];
      _slideLatencies[key] = (_slideLatencies[key] ?? 0) + elapsed;
    }

    setState(() {
      _currentPage = index;
      _pageOpenedAt = now;
    });
  }

  Future<void> _completeOnboarding() async {
    final profileService = context.read<ProfileService>();
    final now = DateTime.now();

    final elapsed = now.difference(_pageOpenedAt).inMilliseconds;
    if (_currentPage >= 0 && _currentPage < _pageKeys.length) {
      final key = _pageKeys[_currentPage];
      _slideLatencies[key] = (_slideLatencies[key] ?? 0) + elapsed;
    }

    final latency = now.difference(_startTime).inMilliseconds;
    
    await profileService.completeOnboarding(
      latencyMs: latency,
      slideLatencies: _slideLatencies,
    );
    
    if (mounted) {
      if (profileService.isFirstLaunch) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
        );
      } else {
        // If replaying from settings, go back to the app shell
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AppShell()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metricService = context.watch<MetricService>();
    final profileService = context.watch<ProfileService>();
    
    if (!metricService.isInitialized || !profileService.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.science_rounded,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Covary',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Initializing database...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> pages = [
      // 1. Mission
      OnboardingStaticSlide(
        title: 'Welcome to Covary',
        description: 'A versatile research tool designed to uncover the patterns between your habits, environment, and daily experiences.',
        icon: Icons.science_rounded,
        color: Colors.blue,
        actionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Restore from cloud backup'),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final summary = await showDialog<SyncSummary?>(
                  context: context,
                  builder: (context) => const _RestoreBackupDialog(),
                );
                if (summary != null) {
                  if (context.mounted) {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => SyncSummaryDialog(summary: summary),
                    );
                  }
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AppShell()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.videogame_asset_rounded),
              label: const Text('Try Interactive Playground'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InteractiveTutorialScreen()),
                );
              },
            ),
          ],
        ),
      ),
      // 2. Method
      const OnboardingStaticSlide(
        title: 'Ecological Momentary Assessment',
        description: 'We use "In-the-moment" tracking to capture how you feel throughout the day, providing more accurate data for research.',
        icon: Icons.auto_awesome_rounded,
        color: Colors.orange,
      ),
      // 3. Privacy
      const OnboardingStaticSlide(
        title: 'Privacy First',
        description: 'By default, your data is stored locally. If you choose to enable the optional Cloud Backup, your data will be synced to Supabase (meaning it is no longer local-only). On PWA (Web), scheduled notification details are stored on Supabase to deliver browser push alerts.',
        icon: Icons.lock_person_rounded,
        color: Colors.teal,
      ),
      // 4. Contribution
      OnboardingStaticSlide(
        title: 'Support Science',
        description: 'If you would like to participate in the research, you can contribute by manually exporting and sending your data to me at the end of the study period.',
        icon: Icons.school_rounded,
        color: Colors.purple,
        actionButton: TextButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: const Text('Send Research ID to researcher'),
          onPressed: () async {
            final uuid = profileService.uuid;
            if (uuid.isNotEmpty) {
              await Clipboard.setData(ClipboardData(text: uuid));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Research ID copied! Opening share sheet...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                
                final box = context.findRenderObject() as RenderBox?;
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'My Covary Research ID is: $uuid\n\n'
                          'To: felix.zoeggeler@edu.fh-joanneum.at',
                    subject: 'Covary Research ID',
                    sharePositionOrigin: box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null,
                  ),
                );
              }
            }
          },
        ),
      ),
      // 5. Research Focus (Presets)
      _PresetSelectionSlide(service: metricService),
      // 6. Window Configuration
      _WindowSetupSlide(service: metricService),
      // 7. Metric Selection
      _MetricSetupSlide(service: metricService),
    ];

    final pageColors = [
      colorScheme.primary,
      Colors.orange,
      Colors.teal,
      colorScheme.secondary,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    final isWebIos = kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;
    final padding = MediaQuery.of(context).padding;
    final hasNativePadding = padding.top > 0 || padding.bottom > 0;
    final safeAreaMin = (isWebIos && !hasNativePadding)
        ? const EdgeInsets.only(top: 50.0, bottom: 36.0)
        : EdgeInsets.zero;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  pageColors[_currentPage].withAlpha(40),
                  colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            minimum: safeAreaMin,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ),
                
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: pages,
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    children: [
                      // Page Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index 
                                  ? pageColors[_currentPage] 
                                  : colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () {
                            if (_currentPage < pages.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: pageColors[_currentPage],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage == pages.length - 1 ? 'Finish Setup' : 'Next',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingStaticSlide extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget? actionButton;

  const OnboardingStaticSlide({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 100,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      title,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      description,
                      style: textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(height: 32),
                      actionButton!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RestoreBackupDialog extends StatefulWidget {
  const _RestoreBackupDialog();

  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  final TextEditingController _uuidController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _uuidController.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    final uuid = _uuidController.text.trim();
    if (uuid.isEmpty) {
      setState(() => _error = 'Please enter a valid UUID');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final syncService = context.read<SyncService>();
      final summary = await syncService.restoreWithUuid(uuid);
      
      if (!mounted) return;

      if (summary != null) {
        Navigator.of(context).pop(summary);
      } else {
        setState(() {
          _error = 'No backup found. Double check your UUID.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(Icons.cloud_download_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Restore Backup'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your 36-character Research ID to restore your settings, metrics, and event history.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _uuidController,
              enabled: !_isLoading,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. 17b6c8aa-b586-...',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleRestore,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Restore'),
        ),
      ],
    );
  }
}

class _WindowSetupSlide extends StatelessWidget {
  final MetricService service;

  const _WindowSetupSlide({required this.service});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final windows = service.allWindows;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            'Your Schedule',
            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Set the windows when you\'d like to receive prompts. Covary adapts to your routine.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: windows.length,
              itemBuilder: (context, index) {
                final w = windows[index];
                final isEnabled = w.isEnabled;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isEnabled ? colorScheme.surface : colorScheme.surface.withAlpha(100),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isEnabled 
                          ? colorScheme.primary.withAlpha(100) 
                          : colorScheme.outlineVariant.withAlpha(150),
                      width: isEnabled ? 2 : 1,
                    ),
                    boxShadow: isEnabled ? [
                      BoxShadow(
                        color: colorScheme.shadow.withAlpha(20),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ] : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => EditWindowDialog(service: service, existing: w),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isEnabled 
                                      ? colorScheme.primary.withAlpha(40) 
                                      : colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getWindowIcon(w.label),
                                  color: isEnabled ? colorScheme.primary : colorScheme.outline,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.label,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isEnabled ? colorScheme.onSurface : colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, 
                                          size: 14, 
                                          color: isEnabled ? colorScheme.primary.withAlpha(180) : colorScheme.outline),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_formatTime(w.startHour, w.startMinute)} – ${_formatTime(w.endHour, w.endMinute)}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: isEnabled ? colorScheme.onSurfaceVariant : colorScheme.outline,
                                            fontWeight: isEnabled ? FontWeight.w500 : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (w.isNotificationEnabled && isEnabled)
                                Icon(Icons.notifications_active_rounded, 
                                  color: colorScheme.primary.withAlpha(200), size: 18),
                              const SizedBox(width: 12),
                              Checkbox(
                                value: isEnabled,
                                onChanged: (val) => service.toggleTrackingWindow(w.id),
                                activeColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  IconData _getWindowIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('morning')) return Icons.wb_sunny_rounded;
    if (l.contains('afternoon')) return Icons.wb_cloudy_rounded;
    if (l.contains('evening')) return Icons.nights_stay_rounded;
    return Icons.schedule_rounded;
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _MetricSetupSlide extends StatelessWidget {
  final MetricService service;

  const _MetricSetupSlide({required this.service});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = service.allMetrics;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            'Track Your Patterns',
            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Select the variables that interest you. You can customize these at any time.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              physics: const BouncingScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: metrics.map((m) {
                final isSelected = m.isEnabled;
                return InkWell(
                  onTap: () => service.toggleMetric(m.id),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? colorScheme.primary.withAlpha(25)
                          : colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                        width: 2,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MetricIcon(
                          iconName: m.emoji,
                          size: 40,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          m.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PresetSelectionSlide extends StatefulWidget {
  final MetricService service;

  const _PresetSelectionSlide({required this.service});

  @override
  State<_PresetSelectionSlide> createState() => _PresetSelectionSlideState();
}

class _PresetSelectionSlideState extends State<_PresetSelectionSlide> {
  ResearchPreset? _selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Research Focus',
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose a starting point for your research. You can still customize everything later.',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _PresetTile(
                      title: 'Essential Focus',
                      description: 'The core metrics: Mood, Energy, Sleep & Wellbeing.',
                      icon: Icons.auto_awesome_rounded,
                      color: Colors.amber,
                      isSelected: _selected == ResearchPreset.essential,
                      onTap: () => _handleSelect(ResearchPreset.essential),
                    ),
                    const SizedBox(height: 16),
                    _PresetTile(
                      title: 'Full Circadian Study',
                      description: 'Advanced variables: Light, Meals, Naps, and Environment.',
                      icon: Icons.biotech_rounded,
                      color: colorScheme.primary,
                      isSelected: _selected == ResearchPreset.fullCircadian,
                      onTap: () => _handleSelect(ResearchPreset.fullCircadian),
                    ),
                    const SizedBox(height: 16),
                    _PresetTile(
                      title: 'Health & Habits',
                      description: 'Focus on Physical Activity, Nutrition, and Health.',
                      icon: Icons.favorite_rounded,
                      color: Colors.teal,
                      isSelected: _selected == ResearchPreset.healthHabits,
                      onTap: () => _handleSelect(ResearchPreset.healthHabits),
                    ),
                    const SizedBox(height: 16),
                    _PresetTile(
                      title: 'Productivity Tracker',
                      description: 'Track Focus, Bachelor Work, and Screen Time.',
                      icon: Icons.lightbulb_rounded,
                      color: Colors.lightBlue,
                      isSelected: _selected == ResearchPreset.productivity,
                      onTap: () => _handleSelect(ResearchPreset.productivity),
                    ),
                    const SizedBox(height: 16),
                    _PresetTile(
                      title: 'All-Inclusive Collector',
                      description: 'Enable every single metric for maximum data depth.',
                      icon: Icons.all_inclusive_rounded,
                      color: Colors.deepPurple,
                      isSelected: _selected == ResearchPreset.allInclusive,
                      onTap: () => _handleSelect(ResearchPreset.allInclusive),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSelect(ResearchPreset p) {
    setState(() => _selected = p);
    widget.service.applyPreset(p);
  }
}

class _PresetTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha(25) : colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? color : colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
