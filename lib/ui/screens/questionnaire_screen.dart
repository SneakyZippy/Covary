import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;

import '../../data/database/app_database.dart' show EventsCompanion;
import '../../data/models/enums.dart';
import '../../data/repositories/event_repository.dart';
import '../../services/profile_service.dart';
import 'app_shell.dart';

class QuestionnaireQuestion {
  final String label;
  final String title;
  final String description;
  final IconData icon;
  final List<String> options;

  const QuestionnaireQuestion({
    required this.label,
    required this.title,
    required this.description,
    required this.icon,
    required this.options,
  });
}

const List<QuestionnaireQuestion> _questions = [
  QuestionnaireQuestion(
    label: 'demographic_age',
    title: 'How old are you?',
    description: 'Select your age range. This helps categorize responses for research analysis.',
    icon: Icons.cake_rounded,
    options: ['Under 18', '18-24', '25-34', '35-44', '45-54', '55-64', '65 or older'],
  ),
  QuestionnaireQuestion(
    label: 'demographic_occupation',
    title: 'What is your current occupation?',
    description: 'Select your primary activity. This helps correlate focus and habits with study/work environments.',
    icon: Icons.work_rounded,
    options: [
      'Student',
      'Employed (Full-time)',
      'Employed (Part-time)',
      'Self-employed',
      'Unemployed',
      'Retired',
      'Other',
    ],
  ),
  QuestionnaireQuestion(
    label: 'demographic_gender',
    title: 'What is your gender identity?',
    description: 'Used for demographic balancing in the final thesis dataset.',
    icon: Icons.face_rounded,
    options: ['Woman', 'Man', 'Non-binary', 'Prefer not to say', 'Other'],
  ),
  QuestionnaireQuestion(
    label: 'demographic_tracking_experience',
    title: 'How experienced are you with self-tracking?',
    description: 'Do you regularly track mood, sleep, or habits in other apps?',
    icon: Icons.bar_chart_rounded,
    options: [
      'None (First time tracking)',
      'Beginner (Used tracking before, but not regularly)',
      'Intermediate (Use several tracking features/apps regularly)',
      'Advanced (Consistently track and analyze my metrics)',
    ],
  ),
  QuestionnaireQuestion(
    label: 'demographic_sleep_schedule',
    title: 'How would you describe your sleep schedule?',
    description: 'Circadian rhythms are core to daily wellbeing metrics.',
    icon: Icons.bedtime_rounded,
    options: [
      'Regular (Sleep and wake at similar times)',
      'Variable (Schedule changes frequently/irregularly)',
      'Shift work (Night shifts or rotating/unusual schedule)',
    ],
  ),
];

class QuestionnaireScreen extends StatefulWidget {
  final bool isEditMode;

  const QuestionnaireScreen({
    super.key,
    this.isEditMode = false,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  /// Stores selected options: {label: selectedOption}
  final Map<String, String> _selections = {};

  /// Tracks time spent on each question: {label: timeSpentMs}
  final Map<String, int> _latencies = {};

  /// Timestamp when the current page was shown.
  late DateTime _pageOpenedAt;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
    if (widget.isEditMode) {
      _loadPreviousAnswers();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Fetches previous answers from the database to pre-populate selections in edit mode.
  Future<void> _loadPreviousAnswers() async {
    setState(() => _isLoading = true);
    try {
      final eventRepo = Provider.of<EventRepository>(context, listen: false);
      final events = await eventRepo.getEventsByCategory(EventCategory.meta);

      for (var question in _questions) {
        final label = question.label;
        final filtered = events.where((e) => e.label == label).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (filtered.isNotEmpty) {
          _selections[label] = filtered.first.value;
        }
      }
    } catch (e) {
      debugPrint('[QuestionnaireScreen] Error loading previous answers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Calculates the time spent on the current page and adds it to latencies.
  void _saveCurrentPageLatency() {
    final now = DateTime.now();
    final elapsed = now.difference(_pageOpenedAt).inMilliseconds;
    final currentLabel = _questions[_currentPage].label;
    _latencies[currentLabel] = (_latencies[currentLabel] ?? 0) + elapsed;
    _pageOpenedAt = now;
  }

  /// Triggered when the user taps on an option.
  void _selectOption(String label, String option) {
    final profileService = Provider.of<ProfileService>(context, listen: false);
    if (profileService.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _selections[label] = option;
    });
  }

  /// Navigates to the next page, recording page latencies.
  void _nextPage() {
    if (_selections[_questions[_currentPage].label] == null) return;

    _saveCurrentPageLatency();
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _saveAnswers();
    }
  }

  /// Navigates to the previous page.
  void _prevPage() {
    if (_currentPage > 0) {
      _saveCurrentPageLatency();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Saves the answers as EventCategory.meta events and updates profile state.
  Future<void> _saveAnswers() async {
    _saveCurrentPageLatency();
    setState(() => _isLoading = true);

    try {
      final eventRepo = Provider.of<EventRepository>(context, listen: false);
      final profileService = Provider.of<ProfileService>(context, listen: false);

      // Save each response as an event
      for (var question in _questions) {
        final label = question.label;
        final value = _selections[label];
        final latency = _latencies[label] ?? 0;

        if (value != null) {
          await eventRepo.insertEvent(EventsCompanion(
            category: const Value(EventCategory.meta),
            label: Value(label),
            value: Value(value),
            latencyMs: Value(latency),
            triggerSource: const Value(TriggerSource.manual),
            interactionType: const Value(InteractionType.click),
          ));
        }
      }

      // Mark as completed
      await profileService.setCompletedQuestionnaire(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditMode
                ? 'Demographics updated successfully! 👍'
                : 'Setup complete! Let\'s go! 🚀'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (widget.isEditMode) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppShell()),
            (_) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving answers: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'Edit Questionnaire' : 'Quick Questionnaire',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: widget.isEditMode || _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _currentPage > 0 ? _prevPage : () => Navigator.of(context).pop(),
              )
            : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // --- Progress Header ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${_currentPage + 1} of ${_questions.length}',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${((_currentPage + 1) / _questions.length * 100).toInt()}% Complete',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Custom premium progress bar
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              width: MediaQuery.of(context).size.width *
                                  ((_currentPage + 1) / _questions.length) *
                                  0.88, // accounting for margins
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colorScheme.primary, colorScheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withAlpha(80),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- Questions Page View ---
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Force wizard buttons
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        final selectedOption = _selections[question.label];

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Icon & Question info
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    question.icon,
                                    size: 40,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                question.title,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                question.description,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Option Cards
                              ...question.options.map((option) {
                                final isSelected = selectedOption == option;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Card(
                                    elevation: isSelected ? 4 : 0,
                                    color: isSelected
                                        ? colorScheme.primary.withAlpha(15)
                                        : colorScheme.surfaceContainerHighest.withAlpha(120),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.outlineVariant.withAlpha(80),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _selectOption(question.label, option),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                option,
                                                style: textTheme.bodyLarge?.copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? colorScheme.primary
                                                      : colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: colorScheme.primary,
                                              )
                                            else
                                              Icon(
                                                Icons.circle_outlined,
                                                color: colorScheme.onSurfaceVariant.withAlpha(120),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // --- Navigation Footer ---
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        if (_currentPage > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _prevPage,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Back'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _selections[_questions[_currentPage].label] != null
                                ? _nextPage
                                : null,
                            icon: Icon(
                              _currentPage == _questions.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            label: Text(
                              _currentPage == _questions.length - 1
                                  ? (widget.isEditMode ? 'Save Changes' : 'Complete Setup')
                                  : 'Next Question',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
