import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/confetti_animation.dart';
import '../theme/design_system.dart';


class InteractiveTutorialScreen extends StatefulWidget {
  const InteractiveTutorialScreen({super.key});

  @override
  State<InteractiveTutorialScreen> createState() => _InteractiveTutorialScreenState();
}

class _InteractiveTutorialScreenState extends State<InteractiveTutorialScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;
  bool _step1Completed = false;
  bool _step2Completed = false;
  bool _step3Completed = false;
  bool _step4Completed = false;
  bool _step5Completed = false;

  // Step 1 State
  int _coffeeCount = 0;
  int _step1TimerMs = 0;
  Timer? _step1Timer;
  bool _step1TimerRunning = true;

  // Step 2 State
  int _waterCount = 0;
  int _step2DefaultValue = 250;

  // Step 3 State
  bool _logSubjectiveAnyway = false;
  double _stressValue = 5.0;
  final int _mockStepCount = 4200;
  bool _step3Dismissed = false;

  // Step 4 State
  bool _nodeExpanded = false;

  // Step 5 State
  int _analyticsTab = 0;
  String? _selectedCell = 'Sleep-Mood';

  @override
  void initState() {
    super.initState();
    _startStep1Timer();
  }

  @override
  void dispose() {
    _step1Timer?.cancel();
    super.dispose();
  }

  void _startStep1Timer() {
    _step1Timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_step1TimerRunning && mounted) {
        setState(() {
          _step1TimerMs += 100;
        });
      }
    });
  }

  void _handleStep1Tap(BuildContext context, TapDownDetails details) {
    if (_step1Completed) return;
    
    // Stop latency timer
    _step1TimerRunning = false;
    _step1Timer?.cancel();

    setState(() {
      _coffeeCount++;
      _step1Completed = true;
    });

    // Confetti burst
    ConfettiOverlay.of(context)?.burst(details.globalPosition);
  }

  void _showMockSliderSheet(BuildContext context) {
    double tempVal = _step2DefaultValue.toDouble();
    bool saveAsDefault = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final colorScheme = Theme.of(ctx).colorScheme;
            final textTheme = Theme.of(ctx).textTheme;
            
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '💧 Log Water Intake',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${tempVal.toInt()} ml',
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Slide to select custom amount or configure logging times.',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: tempVal,
                    min: 100,
                    max: 1000,
                    divisions: 18,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.surfaceContainerHighest,
                    onChanged: (val) {
                      setModalState(() {
                        tempVal = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: saveAsDefault,
                    onChanged: (val) {
                      setModalState(() {
                        saveAsDefault = val ?? false;
                      });
                    },
                    title: const Text('Save as default single-tap value'),
                    subtitle: Text('Taps will log ${tempVal.toInt()} ml next time'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: colorScheme.primary,
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _waterCount = tempVal.toInt();
                        if (saveAsDefault) {
                          _step2DefaultValue = tempVal.toInt();
                        }
                        _step2Completed = true;
                      });
                      
                      // Trigger confetti near center
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final pos = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                        ConfettiOverlay.of(context)?.burst(pos);
                      }
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Log ${tempVal.toInt()} ml'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ConfettiOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Interactive Sandbox Tour'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentStep < _totalSteps ? 'Step ${_currentStep + 1} of $_totalSteps' : 'Playground Finished! 🎉',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentStep < _totalSteps ? '${(_currentStep / _totalSteps * 100).toInt()}% Complete' : '100% Complete',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: _currentStep < _totalSteps ? (_currentStep / _totalSteps) : 1.0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: _currentStep < _totalSteps ? _buildStepWorkspace(colorScheme, textTheme) : _buildCompletionScreen(colorScheme, textTheme),
                ),
              ),

              // Bottom Control Bar
              if (_currentStep < _totalSteps)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    border: Border(top: BorderSide(color: colorScheme.outlineVariant.withAlpha(80), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _currentStep > 0
                            ? () {
                                setState(() {
                                  _currentStep--;
                                });
                              }
                            : null,
                        child: const Text('Back'),
                      ),
                      FilledButton(
                        onPressed: _isCurrentStepCompleted()
                            ? () {
                                setState(() {
                                  _currentStep++;
                                });
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currentStep == _totalSteps - 1 ? 'Finish' : 'Next Step'),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isCurrentStepCompleted() {
    switch (_currentStep) {
      case 0:
        return _step1Completed;
      case 1:
        return _step2Completed;
      case 2:
        return _step3Completed;
      case 3:
        return _step4Completed;
      case 4:
        return _step5Completed;
      default:
        return false;
    }
  }

  Widget _buildStepWorkspace(ColorScheme colorScheme, TextTheme textTheme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(colorScheme, textTheme);
      case 1:
        return _buildStep2(colorScheme, textTheme);
      case 2:
        return _buildStep3(colorScheme, textTheme);
      case 3:
        return _buildStep4(colorScheme, textTheme);
      case 4:
        return _buildStep5(colorScheme, textTheme);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 1: Quick Track Single Tap ---
  Widget _buildStep1(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInstructionCard(
          title: 'Quick Track: Single Tap',
          explanation: 'Tapping a counter metric card instantly logs 1 unit (e.g. coffee, water) with a satisfying confetti effect. Tapping UNDO on the snackbar will delete it immediately.',
          hciMetric: 'Response Latency: Millisecond counter starts as soon as a form/card is visible to capture cognitive friction.',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Digital Latency Timer Simulation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: colorScheme.primary.withAlpha(55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: colorScheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'LATENCY: $_step1TimerMs ms',
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Coffee Quick Track Card
              Container(
                width: 260,
                constraints: const BoxConstraints(minHeight: 96),
                child: Material(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTapDown: (details) => _handleStep1Tap(context, details),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.coffee_rounded, color: colorScheme.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Coffee Intake',
                                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _coffeeCount > 0 ? 'Today: $_coffeeCount cups' : 'Today: None yet',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (_coffeeCount > 0) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.undo_rounded),
                              color: colorScheme.primary,
                              tooltip: 'Undo log',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                              onPressed: () {
                                setState(() {
                                  _coffeeCount = 0;
                                  _step1Completed = false;
                                  _step1TimerRunning = true;
                                  _step1TimerMs = 0;
                                  _startStep1Timer();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_step1Completed) ...[
          const SizedBox(height: 32),
          _buildStepCompletedBanner(colorScheme, textTheme, 'Quick Track Tap successful! Notice the recorded latency: ${_step1TimerMs}ms. Click "Next Step" to continue.'),
        ],
      ],
    );
  }

  // --- Step 2: Quick Track Long Press ---
  Widget _buildStep2(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInstructionCard(
          title: 'Quick Track: Long-Press',
          explanation: 'Long-pressing a counter card opens the Value Slider Sheet. Here you can:\n1. Slide to select custom amounts.\n2. Backdate the entry to a specific time.\n3. Save as default (changing the single-tap size).',
          hciMetric: 'Custom Anchoring: Allowing users to change defaults reduces future interactive latency.',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Water Quick Track Card
              GestureDetector(
                onLongPress: () => _showMockSliderSheet(context),
                child: Container(
                  width: 260,
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Material(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () {
                        if (_step2Completed) {
                          setState(() {
                            _waterCount += _step2DefaultValue;
                          });
                          // Confetti
                          final box = context.findRenderObject() as RenderBox?;
                          if (box != null) {
                            final pos = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                            ConfettiOverlay.of(context)?.burst(pos);
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.water_drop_rounded, color: Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Water Intake',
                                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _waterCount > 0 ? 'Today: $_waterCount ml' : 'Today: None yet',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '💡 Long-press the card above to open the sheet',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (_step2Completed) ...[
          const SizedBox(height: 32),
          _buildStepCompletedBanner(colorScheme, textTheme, 'Custom logging successful! Tapping the Water card will now log $_step2DefaultValue ml. Proceed to "Next Step".'),
        ],
      ],
    );
  }

  // --- Step 3: Missed Check-in / Recall Bias ---
  Widget _buildStep3(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInstructionCard(
          title: 'Missed Sessions & Recall Bias',
          explanation: 'When a check-in window passes, a Missed Session card appears on the Home screen. Factual metrics (e.g., Step Count) are active, while subjective metrics (e.g., Stress Level) are dimmed with a "Log anyway" warning to prevent retrospective recall bias.',
          hciMetric: 'Recall Bias Prevention: Restrict retroactive subjective logging to protect data integrity.',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 32),
        
        // Mock Missed Session Card
        if (!_step3Dismissed)
          Dismissible(
            key: const ValueKey('mock_missed_dismiss_tutorial'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (_) async {
              final bool? skip = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Skip Check-in?'),
                  content: const Text('Do you really want to leave out this check-in?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              );
              return skip;
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            ),
            onDismissed: (_) {
              setState(() {
                _step3Dismissed = true;
                _step3Completed = true;
              });
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: colorScheme.errorContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.history_rounded, color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Missed Afternoon Check-in',
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _step3Completed = true;
                            });
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Complete'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    
                    // Reliable metrics
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 14, color: colorScheme.error),
                        const SizedBox(width: 4),
                        Text(
                          'Still accurate — log now',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMockMetricChip(
                          label: 'Step Count',
                          icon: Icons.directions_run_rounded,
                          dimmed: false,
                          onTap: () => _showMockRetroLogSheet(context, 'Step Count', false),
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                    
                    // Subjective metrics
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: colorScheme.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Recall may be unreliable',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!_logSubjectiveAnyway)
                          GestureDetector(
                            onTap: () => setState(() => _logSubjectiveAnyway = true),
                            child: Text(
                              'Log anyway',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMockMetricChip(
                          label: 'Stress Level',
                          icon: Icons.psychology_rounded,
                          dimmed: !_logSubjectiveAnyway,
                          onTap: () => _showMockRetroLogSheet(context, 'Stress Level', true),
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Center(
            child: Column(
              children: [
                Icon(Icons.swipe_left_rounded, color: colorScheme.onSurfaceVariant, size: 48),
                const SizedBox(height: 16),
                const Text('Card Dismissed (Skipped)!'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _step3Dismissed = false;
                      _step3Completed = false;
                    });
                  },
                  child: const Text('Restore Card'),
                ),
              ],
            ),
          ),
          
        if (_step3Completed) ...[
          const SizedBox(height: 32),
          _buildStepCompletedBanner(colorScheme, textTheme, 'Friction and compliance handling complete! Missed logs record a warning banner for subjective metrics, preventing cognitive memory bias. Click "Next Step".'),
        ],
      ],
    );
  }

  Widget _buildMockMetricChip({
    required String label,
    required IconData icon,
    required bool dimmed,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final chip = InkWell(
      onTap: dimmed ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.error.withAlpha(dimmed ? 20 : 40),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.error.withAlpha(dimmed ? 40 : 100),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.error.withAlpha(dimmed ? 100 : 255)),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onErrorContainer
                    .withAlpha(dimmed ? 120 : 220),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return dimmed ? Opacity(opacity: 0.55, child: chip) : chip;
  }

  void _showMockRetroLogSheet(BuildContext context, String metricName, bool isSubjective) {
    double tempStress = _stressValue;
    int tempSteps = _mockStepCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final colorScheme = Theme.of(ctx).colorScheme;
            final textTheme = Theme.of(ctx).textTheme;

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isSubjective)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16,
                              color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Best-effort recall — subjective data logged retroactively.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    isSubjective ? '🧠 Log Retro Stress Level' : '👟 Log Retro Step Count',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (isSubjective) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stress Level', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('${tempStress.toInt()}/10', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: tempStress,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: colorScheme.error,
                      onChanged: (val) {
                        setModalState(() {
                          tempStress = val;
                        });
                      },
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Steps Today', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('$tempSteps steps', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: tempSteps.toDouble(),
                      min: 1000,
                      max: 15000,
                      divisions: 14,
                      activeColor: colorScheme.error,
                      onChanged: (val) {
                        setModalState(() {
                          tempSteps = (val / 100).round() * 100;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (isSubjective) {
                          _stressValue = tempStress;
                        }
                        _step3Completed = true;
                      });
                      
                      // Trigger confetti near center
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final pos = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                        ConfettiOverlay.of(context)?.burst(pos);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Center(
                      child: Text(
                        isSubjective 
                          ? 'Log Stress: ${tempStress.toInt()}/10' 
                          : 'Log Steps: $tempSteps'
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Step 4: Timeline Details ---
  Widget _buildStep4(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInstructionCard(
          title: 'Timeline & Latency Details',
          explanation: 'At the bottom of the Home screen, the timeline displays all logs recorded today. Expanding any log reveals crucial data points like latency and trigger source.',
          hciMetric: 'Transparency: Users can audit exactly what HCI and passive data is logged locally.',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 32),
        
        // Mock Timeline Widget
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Timeline',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Timeline Node 1: Sleep Quality (Expandable)
              _buildTimelineNode(
                title: 'Sleep Quality',
                time: '8:30 AM',
                value: '8 / 10',
                icon: Icons.bedtime_rounded,
                color: Colors.indigoAccent,
                colorScheme: colorScheme,
                textTheme: textTheme,
                isExpandable: true,
              ),
              
              // Timeline Node 2: Water Intake (Static)
              _buildTimelineNode(
                title: 'Water Intake',
                time: '10:15 AM',
                value: '250 ml',
                icon: Icons.water_drop_rounded,
                color: Colors.blue,
                colorScheme: colorScheme,
                textTheme: textTheme,
                isExpandable: false,
              ),
            ],
          ),
        ),
        
        if (_step4Completed) ...[
          const SizedBox(height: 32),
          _buildStepCompletedBanner(colorScheme, textTheme, 'Friction transparency audited! You expanded a node, showing how long the form took. Tap "Finish" below.'),
        ],
      ],
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String time,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isExpandable,
  }) {
    final showDetails = isExpandable && _nodeExpanded;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline stem and node circle
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(100), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            Container(
              width: 2,
              height: showDetails ? 160 : 40,
              color: colorScheme.outlineVariant.withAlpha(80),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: isExpandable
                    ? () {
                        setState(() {
                          _nodeExpanded = !_nodeExpanded;
                          _step4Completed = true;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(time, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(value, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                          if (isExpandable) ...[
                            const SizedBox(width: 8),
                            Icon(
                              showDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Expanded details (slide down simulation)
              if (showDetails)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDetailRow('Category', 'Health', colorScheme),
                      const SizedBox(height: 8),
                      _buildDetailRow('Trigger Source', 'Notification Alert', colorScheme),
                      const SizedBox(height: 8),
                      _buildDetailRow('Interaction Type', 'Click to Log', colorScheme),
                      const SizedBox(height: 8),
                      _buildDetailRow('Latency (HCI)', '4,820 ms', colorScheme, highlight: true),
                      const Divider(height: 24),
                      Text(
                        '💡 Response Latency records how much friction this question caused. If latencies are consistently high, it suggests the question is hard to answer!',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String name, String value, ColorScheme colorScheme, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlight ? colorScheme.primary : colorScheme.onSurface,
            fontSize: 12,
            fontFamily: highlight ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  // --- Step 5: Behavioral Analytics Explorer ---
  Widget _buildStep5(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInstructionCard(
          title: 'Behavioral Analytics Explorer',
          explanation: 'Covary automatically runs Spearman correlation matrices and circadian rhythm analysis. In this preview, you can interact with a pre-seeded mockup of the Analytics tools to see how insights are derived, without changing your database.',
          hciMetric: 'Insight discovery: Finding correlations helps researchers and users identify behavioral loops.',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 24),
        
        // Tab / Toggle buttons
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(150),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildAnalyticsTabButton(
                  title: 'Correlation Matrix',
                  active: _analyticsTab == 0,
                  onTap: () {
                    setState(() {
                      _analyticsTab = 0;
                      _step5Completed = true;
                    });
                  },
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ),
              Expanded(
                child: _buildAnalyticsTabButton(
                  title: 'Circadian Mood',
                  active: _analyticsTab == 1,
                  onTap: () {
                    setState(() {
                      _analyticsTab = 1;
                      _step5Completed = true;
                    });
                  },
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Active Tab content
        _analyticsTab == 0
            ? _buildMockCorrelationMatrix(colorScheme, textTheme)
            : _buildMockCircadianMood(colorScheme, textTheme),
            
        if (_step5Completed) ...[
          const SizedBox(height: 32),
          _buildStepCompletedBanner(colorScheme, textTheme, 'Analytics explored successfully! Notice how check-in timing and circadian correlation patterns relate to positive user outcomes. Click "Finish" to complete the playground.'),
        ],
      ],
    );
  }

  Widget _buildAnalyticsTabButton({
    required String title,
    required bool active,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMockCorrelationMatrix(ColorScheme colorScheme, TextTheme textTheme) {
    final List<String> metrics = ['Mood', 'Sleep', 'Steps', 'Screen'];
    final Map<String, double> matrix = {
      'Mood-Mood': 1.0,
      'Mood-Sleep': 0.75,
      'Mood-Steps': 0.35,
      'Mood-Screen': -0.48,
      'Sleep-Mood': 0.75,
      'Sleep-Sleep': 1.0,
      'Sleep-Steps': 0.22,
      'Sleep-Screen': -0.30,
      'Steps-Mood': 0.35,
      'Steps-Sleep': 0.22,
      'Steps-Steps': 1.0,
      'Steps-Screen': -0.15,
      'Screen-Mood': -0.48,
      'Screen-Sleep': -0.30,
      'Screen-Steps': -0.15,
      'Screen-Screen': 1.0,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Spearman Correlation Heatmap',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Values close to +1.0 indicate strong positive correlation, while values close to -1.0 indicate strong negative correlation.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          
          // Row Header / Headers
          Row(
            children: [
              const SizedBox(width: 60), // Corner spacing
              for (var metric in metrics)
                Expanded(
                  child: Text(
                    metric,
                    style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          for (var rowMetric in metrics) ...[
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    rowMetric,
                    style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.left,
                  ),
                ),
                for (var colMetric in metrics)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final key = '$rowMetric-$colMetric';
                        final val = matrix[key] ?? 0.0;
                        final isSelected = _selectedCell == '$rowMetric-$colMetric' || _selectedCell == '$colMetric-$rowMetric';
                        
                        Color cellColor;
                        if (val == 1.0) {
                          cellColor = colorScheme.outlineVariant.withAlpha(100);
                        } else if (val > 0) {
                          cellColor = Colors.blue.withAlpha((val * 200).toInt());
                        } else {
                          cellColor = Colors.orange.withAlpha((val.abs() * 200).toInt());
                        }
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCell = key;
                              _step5Completed = true;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            height: 48,
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected 
                                    ? colorScheme.primary 
                                    : colorScheme.outlineVariant.withAlpha(40),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              val == 1.0 ? '1.0' : (val > 0 ? '+$val' : '$val'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: val == 1.0 
                                    ? colorScheme.onSurface 
                                    : (val.abs() > 0.4 ? Colors.white : colorScheme.onSurface),
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          
          _buildSpotlightDetail(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildSpotlightDetail(ColorScheme colorScheme, TextTheme textTheme) {
    if (_selectedCell == null) {
      return Text(
        '💡 Tap any grid cell to analyze the correlation behavior.',
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      );
    }

    final key = _selectedCell!;
    final parts = key.split('-');
    final metricA = parts[0];
    final metricB = parts.length > 1 ? parts[1] : '';

    if (metricA == metricB) {
      return Text(
        'Identity Correlation: Comparing $metricA with itself always yields +1.0.',
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      );
    }

    String relationshipText = '';
    String insightText = '';
    
    if ((metricA == 'Sleep' && metricB == 'Mood') || (metricA == 'Mood' && metricB == 'Sleep')) {
      relationshipText = 'Strong Positive Correlation (+0.75)';
      insightText = 'Days following high-quality sleep show significantly elevated self-reported mood ratings. This confirms a strong baseline relationship between physical rest and emotional stability.';
    } else if ((metricA == 'Screen' && metricB == 'Mood') || (metricA == 'Mood' && metricB == 'Screen')) {
      relationshipText = 'Moderate Negative Correlation (-0.48)';
      insightText = 'Higher smartphone screen time correlates with lower evening mood and emotional focus, suggesting potential cognitive fatigue or screen-related stress loops.';
    } else if ((metricA == 'Steps' && metricB == 'Mood') || (metricA == 'Mood' && metricB == 'Steps')) {
      relationshipText = 'Mild Positive Correlation (+0.35)';
      insightText = 'Active physical movement (higher daily steps) moderately matches improved daily wellbeing and focus metrics.';
    } else if ((metricA == 'Screen' && metricB == 'Sleep') || (metricA == 'Sleep' && metricB == 'Screen')) {
      relationshipText = 'Mild Negative Correlation (-0.30)';
      insightText = 'High screen usage throughout the day, particularly during late evenings, correlates with decreased sleep quality scores.';
    } else if ((metricA == 'Steps' && metricB == 'Sleep') || (metricA == 'Sleep' && metricB == 'Steps')) {
      relationshipText = 'Weak Positive Correlation (+0.22)';
      insightText = 'Increased steps show a minor positive link to better sleep quality, suggesting physical exertion aids circadian rest.';
    } else {
      relationshipText = 'Weak Negative Correlation (-0.15)';
      insightText = 'Screen time and steps display no significant relationship, meaning active days do not necessarily result in reduced phone usage.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              relationshipText.contains('Positive') ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: relationshipText.contains('Positive') ? Colors.blue : Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '$metricA vs $metricB',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          relationshipText,
          style: textTheme.bodySmall?.copyWith(
            color: relationshipText.contains('Positive') ? Colors.blue : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          insightText,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildMockCircadianMood(ColorScheme colorScheme, TextTheme textTheme) {
    // We want to mock hourly mood & energy levels
    final List<FlSpot> moodSpots = [
      const FlSpot(0, 6.0),
      const FlSpot(2, 5.5),
      const FlSpot(4, 5.0),
      const FlSpot(6, 5.8),
      const FlSpot(8, 7.2),
      const FlSpot(10, 7.8),
      const FlSpot(12, 8.0),
      const FlSpot(14, 7.1),
      const FlSpot(16, 7.5),
      const FlSpot(18, 8.4),
      const FlSpot(20, 8.2),
      const FlSpot(22, 7.0),
      const FlSpot(23, 6.5),
    ];

    final List<FlSpot> energySpots = [
      const FlSpot(0, 3.0),
      const FlSpot(2, 2.0),
      const FlSpot(4, 1.5),
      const FlSpot(6, 4.0),
      const FlSpot(8, 8.0),
      const FlSpot(10, 8.5),
      const FlSpot(12, 7.2),
      const FlSpot(14, 6.0),
      const FlSpot(16, 6.8),
      const FlSpot(18, 7.5),
      const FlSpot(20, 5.0),
      const FlSpot(22, 3.5),
      const FlSpot(23, 3.0),
    ];

    final lineColors = CovaryDesignSystem.getChartLineColors(context);
    final accentA = lineColors.$1;
    final accentB = lineColors.$2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Circadian Mood & Energy Rhythm',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Typical daily variations in self-reported mood and energy level grouped by the hour of the day.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(accentA, 'Mood (1-10)', textTheme),
              const SizedBox(width: 24),
              _legendDot(accentB, 'Energy (1-10)', textTheme),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 23,
                minY: 1,
                maxY: 10,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outlineVariant.withValues(alpha: 0.15), strokeWidth: 0.5),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 2,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (v, _) {
                        final hour = v.toInt();
                        if (hour < 0 || hour > 23) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${hour.toString().padLeft(2, '0')}:00', style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8))),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: moodSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: accentA,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [accentA.withValues(alpha: 0.2), accentA.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: energySpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: accentB,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [accentB.withValues(alpha: 0.12), accentB.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.surfaceContainer,
                    getTooltipItems: (spots) {
                      final hour = spots.first.x.toInt();
                      final timeStr = '${hour.toString().padLeft(2, '0')}:00';
                      return spots.map((s) {
                        final isMood = s.barIndex == 0;
                        final color = isMood ? accentA : accentB;
                        final label = isMood ? 'Mood' : 'Energy';
                        return LineTooltipItem(
                          '$timeStr\n$label: ${s.y.toStringAsFixed(1)}',
                          TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            '💡 Research Tip: Looking at circadian rhythms helps identify diurnal patterns (e.g. morning fatigue or post-lunch energy dips). This information can be used to optimize the timing of EMA prompt triggers.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Completion Screen ---
  Widget _buildCompletionScreen(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.primary.withAlpha(55), width: 2),
          ),
          child: Icon(Icons.offline_pin_rounded, color: colorScheme.primary, size: 72),
        ),
        const SizedBox(height: 32),
        Text(
          'Playground Complete! 🚀',
          style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'You are now fully familiar with Covary\'s interaction mechanics, latency logs, and recall-bias controls!',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Return to App'),
        ),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildInstructionCard({
    required String title,
    required String explanation,
    required String hciMetric,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.primary.withAlpha(30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hciMetric,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCompletedBanner(ColorScheme colorScheme, TextTheme textTheme, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
