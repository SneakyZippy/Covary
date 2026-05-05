import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/profile_service.dart';
import '../../services/metric_service.dart';
import '../widgets/edit_window_dialog.dart';
import '../widgets/metric_icon.dart';
import 'profile_setup_screen.dart';
import 'package:covary/ui/screens/app_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _completeOnboarding() async {
    final profileService = context.read<ProfileService>();
    final latency = DateTime.now().difference(_startTime).inMilliseconds;
    
    await profileService.completeOnboarding(latencyMs: latency);
    
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
    
    final List<Widget> pages = [
      // 1. Mission
      const OnboardingStaticSlide(
        title: 'Welcome to Covary',
        description: 'A versatile research tool designed to uncover the patterns between your habits, environment, and daily experiences.',
        icon: Icons.science_rounded,
        color: Colors.blue,
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
        description: 'Your data never leaves your phone. Everything is stored locally and is only shared when you choose to manually export it.',
        icon: Icons.lock_person_rounded,
        color: Colors.teal,
      ),
      // 4. Contribution
      const OnboardingStaticSlide(
        title: 'Support Science',
        description: 'By participating, you are contributing directly to a Bachelor\'s Thesis research project exploring the intersection of human behavior and technology.',
        icon: Icons.school_rounded,
        color: Colors.purple,
      ),
      // 5. Window Configuration
      _WindowSetupSlide(service: metricService),
      // 6. Metric Selection
      _MetricSetupSlide(service: metricService),
    ];

    final pageColors = [
      colorScheme.primary,
      Colors.orange,
      Colors.teal,
      colorScheme.secondary,
      Colors.indigo,
      Colors.cyan,
    ];

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

  const OnboardingStaticSlide({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
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
