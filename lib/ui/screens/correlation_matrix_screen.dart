import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/analytics_service.dart';
import '../../services/metric_service.dart';
import '../../data/models/metric_definition.dart';
import '../../data/models/enums.dart';
import 'package:covary/data/database/app_database.dart';

class CorrelationMatrixScreen extends StatefulWidget {
  const CorrelationMatrixScreen({super.key});

  @override
  State<CorrelationMatrixScreen> createState() => _CorrelationMatrixScreenState();
}

class _CorrelationMatrixScreenState extends State<CorrelationMatrixScreen> {
  int _lagDays = 0;
  bool _isLoading = true;
  List<MetricDefinition> _rowMetrics = [];
  List<MetricDefinition> _colMetrics = [];
  Map<String, Map<String, double?>> _matrix = {};

  // "Virtual" metrics for passive sensing data that don't have definitions in MetricService
  static const List<MetricDefinition> _passiveMetrics = [
    MetricDefinition(
      id: 'passive_social_usage',
      label: 'category_time:social',
      category: EventCategory.appUsage,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'social_usage',
    ),
    MetricDefinition(
      id: 'passive_total_usage',
      label: 'total_screen_time',
      category: EventCategory.appUsage,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'total_usage',
    ),
    MetricDefinition(
      id: 'passive_entertainment_usage',
      label: 'category_time:entertainment',
      category: EventCategory.appUsage,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'entertainment_usage',
    ),
    MetricDefinition(
      id: 'passive_sleep',
      label: 'sleep_duration_hours',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'bedtime',
    ),
    MetricDefinition(
      id: 'passive_steps',
      label: 'step_count',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'run',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoselectMetrics();
    });
  }

  void _autoselectMetrics() {
    final allSubjective = context.read<MetricService>().allMetrics.where((m) => m.isEnabled).toList();
    final allAvailable = [...allSubjective, ..._passiveMetrics];
    
    setState(() {
      // Symmetrical by default for better research overview
      _rowMetrics = allAvailable.where((m) => 
        m.category == EventCategory.mood || 
        m.category == EventCategory.behavior ||
        m.category == EventCategory.productivity
      ).toList();

      _colMetrics = List.from(_rowMetrics);
      
      // If we have passive data, add it to columns
      final passive = allAvailable.where((m) => 
        m.category == EventCategory.appUsage || 
        m.category == EventCategory.health
      ).toList();
      _colMetrics.addAll(passive);

      // Fallback
      if (_rowMetrics.isEmpty) _rowMetrics = allAvailable.take(5).toList();
      if (_colMetrics.isEmpty) _colMetrics = allAvailable.take(5).toList();
    });

    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    if (_rowMetrics.isEmpty || _colMetrics.isEmpty) return;

    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();
    final analyticsService = context.read<AnalyticsService>();
    final newMatrix = <String, Map<String, double?>>{};

    for (final row in _rowMetrics) {
      newMatrix[row.id] = {};
      for (final col in _colMetrics) {
        // Only show 1.0 on diagonal if the user has actually logged data for it
        if (row.id == col.id && _lagDays == 0) {
          final events = await db.getEventsByLabel(row.label);
          if (events.isNotEmpty) {
            newMatrix[row.id]![col.id] = 1.0;
          } else {
            newMatrix[row.id]![col.id] = null;
          }
          continue;
        }

        final correlation = await analyticsService.calculateSpearmanCorrelation(
          metricA: row.label,
          metricB: col.label,
          lagDays: _lagDays,
        );
        newMatrix[row.id]![col.id] = correlation;
      }
    }

    if (mounted) {
      setState(() {
        _matrix = newMatrix;
        _isLoading = false;
      });
    }
  }

  void _showMetricSelection() {
    final allSubjective = context.read<MetricService>().allMetrics.where((m) => m.isEnabled).toList();
    final allAvailable = [...allSubjective, ..._passiveMetrics];
    
    showDialog(
      context: context,
      builder: (context) => _MetricSelectionDialog(
        allMetrics: allAvailable,
        initialRows: _rowMetrics,
        initialCols: _colMetrics,
        onApply: (newRows, newCols) {
          setState(() {
            _rowMetrics = newRows;
            _colMetrics = newCols;
          });
          _loadMatrix();
        },
        onAutoselect: () {
          Navigator.pop(context);
          _autoselectMetrics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correlation Matrix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Select Metrics',
            onPressed: _showMetricSelection,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMatrix,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLagSelector(colorScheme, textTheme),
          const Divider(height: 1),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _matrix.isEmpty 
                ? _buildEmptyState(textTheme)
                : ListView(
                    children: [
                      const SizedBox(height: 40), // Extra space for slanted headers
                      _buildMatrixGrid(colorScheme, textTheme),
                      _buildDataReliabilityInfo(colorScheme, textTheme),
                    ],
                  ),
          ),
          _buildLegend(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildLagSelector(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Time Lag: $_lagDays ${_lagDays == 1 ? 'Day' : 'Days'}',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_lagDays > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Predictive',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Slider(
            value: _lagDays.toDouble(),
            min: 0,
            max: 7,
            divisions: 7,
            label: '$_lagDays',
            onChanged: (val) {
              setState(() => _lagDays = val.toInt());
            },
            onChangeEnd: (_) => _loadMatrix(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _lagDays == 0 
                ? 'Correlating behaviors on the same day.'
                : 'Correlating today\'s metrics with your state $_lagDays ${_lagDays == 1 ? 'day' : 'days'} later.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixGrid(ColorScheme colorScheme, TextTheme textTheme) {
    const double cellSize = 52.0;
    const double headerWidth = 120.0;
    const double headerHeight = 80.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row (Slanted Columns)
              Row(
                children: [
                  const SizedBox(width: headerWidth), 
                  ..._colMetrics.map((m) => _buildSlantedHeader(m, cellSize, headerHeight, textTheme)),
                ],
              ),
              const SizedBox(height: 4),
              // Data Rows
              ..._rowMetrics.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      _buildRowHeader(row, headerWidth, cellSize, textTheme),
                      ..._colMetrics.asMap().entries.map((colEntry) {
                        final colIndex = colEntry.key;
                        final col = colEntry.value;
                        return _buildCell(
                          _matrix[row.id]?[col.id], 
                          cellSize, 
                          colorScheme,
                          delayIndex: rowIndex + colIndex,
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlantedHeader(MetricDefinition m, double width, double height, TextTheme textTheme) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.bottomLeft,
      child: Transform.translate(
        offset: const Offset(12, -2),
        child: Transform.rotate(
          angle: -0.5, // Slightly less slanted for better readability
          child: Container(
            width: 90,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmoji(m.emoji, 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _displayLabel(m),
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white.withAlpha(200),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowHeader(MetricDefinition m, double width, double height, TextTheme textTheme) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.only(right: 12),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              _displayLabel(m),
              textAlign: TextAlign.right,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10, 
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(180),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: _buildEmoji(m.emoji, 14),
          ),
        ],
      ),
    );
  }

  String _displayLabel(MetricDefinition m) {
    if (m.id.startsWith('passive_')) {
      // Clean up internal labels for display: "category_time:social" -> "SOCIAL"
      String label = m.label;
      if (label.contains(':')) {
        label = label.split(':').last;
      }
      return label.replaceAll('_', ' ').toUpperCase();
    }
    return m.label;
  }

  Widget _buildCell(double? correlation, double size, ColorScheme colorScheme, {int delayIndex = 0}) {
    Color cellColor = Colors.white.withAlpha(8);
    String text = '';
    
    bool hasData = correlation != null;
    if (hasData) {
      text = correlation.abs() > 0.05 ? correlation.toStringAsFixed(2) : '0';
      if (correlation > 0.05) {
        cellColor = Color.lerp(
          colorScheme.surfaceContainerHighest.withAlpha(100), 
          Colors.cyanAccent, 
          correlation.clamp(0, 1)
        )!.withAlpha((correlation * 240).toInt().clamp(60, 240));
      } else if (correlation < -0.05) {
        cellColor = Color.lerp(
          colorScheme.surfaceContainerHighest.withAlpha(100), 
          Colors.orangeAccent, 
          correlation.abs().clamp(0, 1)
        )!.withAlpha((correlation.abs() * 240).toInt().clamp(60, 240));
      } else {
        cellColor = Colors.white.withAlpha(15);
        text = '·';
      }
    } else {
      text = '·';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (delayIndex * 30)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        width: size - 6,
        height: size - 6,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasData && correlation.abs() > 0.6 
                ? Colors.white.withAlpha(80) 
                : Colors.white.withAlpha(10),
            width: 0.5,
          ),
          boxShadow: hasData && correlation.abs() > 0.8 ? [
            BoxShadow(
              color: cellColor.withAlpha(100),
              blurRadius: 8,
              spreadRadius: -2,
            )
          ] : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: text == '·' ? 14 : 10,
              fontWeight: FontWeight.w900,
              color: hasData && correlation.abs() > 0.4 
                ? Colors.white 
                : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmoji(String? emoji, double size) {
    if (emoji == null) return Icon(Icons.circle, size: size, color: Colors.grey);
    return Text(
      _mapEmoji(emoji),
      style: TextStyle(fontSize: size),
    );
  }

  String _mapEmoji(String key) {
    const map = {
      'mood': '😊', 'bolt': '⚡', 'stress': '😫', 'sleep': '😴', 
      'star': '⭐', 'bedtime': '🛌', 'run': '🏃', 'edit': '📝',
      'favorite': '❤️', 'meat': '🥩', 'lightbulb': '💡',
      'psychology': '🧠', 'water': '💧', 'meditation': '🧘',
      'book': '📚', 'coffee': '☕',
      'social_usage': '📱', 'total_usage': '⌛', 'entertainment_usage': '🎬',
    };
    return map[key] ?? '📊';
  }

  Widget _buildDataReliabilityInfo(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHighest.withAlpha(150),
              colorScheme.surfaceContainerHighest.withAlpha(80),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.primary.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.insights_rounded, size: 18, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  'Research Integrity',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'To ensure statistical validity, correlations are only calculated once 3 days of overlapping data are present. The intensity of color represents the strength of the relationship.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withAlpha(50))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendItem(label: 'Positive', color: Colors.cyanAccent),
          _LegendItem(label: 'Neutral', color: Colors.white24),
          _LegendItem(label: 'Negative', color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Not enough data yet.',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try logging more behaviors daily. Metrics will automatically appear here once 3 days of data are recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricSelectionDialog extends StatefulWidget {
  final List<MetricDefinition> allMetrics;
  final List<MetricDefinition> initialRows;
  final List<MetricDefinition> initialCols;
  final Function(List<MetricDefinition>, List<MetricDefinition>) onApply;
  final VoidCallback onAutoselect;

  const _MetricSelectionDialog({
    required this.allMetrics,
    required this.initialRows,
    required this.initialCols,
    required this.onApply,
    required this.onAutoselect,
  });

  @override
  State<_MetricSelectionDialog> createState() => _MetricSelectionDialogState();
}

class _MetricSelectionDialogState extends State<_MetricSelectionDialog> {
  late List<String> _selectedRows;
  late List<String> _selectedCols;

  @override
  void initState() {
    super.initState();
    _selectedRows = widget.initialRows.map((m) => m.id).toList();
    _selectedCols = widget.initialCols.map((m) => m.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: Row(
          children: [
            const Text('Select Metrics'),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onAutoselect,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Autoselect', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Rows'),
                  Tab(text: 'Columns'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMetricList(_selectedRows, (id) {
                      setState(() {
                        if (_selectedRows.contains(id)) {
                          _selectedRows.remove(id);
                        } else {
                          _selectedRows.add(id);
                        }
                      });
                    }),
                    _buildMetricList(_selectedCols, (id) {
                      setState(() {
                        if (_selectedCols.contains(id)) {
                          _selectedCols.remove(id);
                        } else {
                          _selectedCols.add(id);
                        }
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newRows = widget.allMetrics.where((m) => _selectedRows.contains(m.id)).toList();
              final newCols = widget.allMetrics.where((m) => _selectedCols.contains(m.id)).toList();
              widget.onApply(newRows, newCols);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricList(List<String> selection, Function(String) onToggle) {
    return ListView.builder(
      itemCount: widget.allMetrics.length,
      itemBuilder: (context, index) {
        final metric = widget.allMetrics[index];
        final isSelected = selection.contains(metric.id);
        return CheckboxListTile(
          title: Text(_displayLabel(metric)),
          subtitle: Text(metric.category.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
          secondary: Text(_mapEmoji(metric.emoji ?? '')),
          value: isSelected,
          onChanged: (_) => onToggle(metric.id),
        );
      },
    );
  }

  String _displayLabel(MetricDefinition m) {
    if (m.id.startsWith('passive_')) {
      // Clean up internal labels for display: "category_time:social" -> "SOCIAL"
      String label = m.label;
      if (label.contains(':')) {
        label = label.split(':').last;
      }
      return label.replaceAll('_', ' ').toUpperCase();
    }
    return m.label;
  }

  String _mapEmoji(String key) {
    const map = {
      'mood': '😊', 'bolt': '⚡', 'stress': '😫', 'sleep': '😴', 
      'star': '⭐', 'bedtime': '🛌', 'run': '🏃', 'edit': '📝',
      'favorite': '❤️', 'meat': '🥩', 'lightbulb': '💡',
      'psychology': '🧠', 'water': '💧', 'meditation': '🧘',
      'book': '📚', 'coffee': '☕',
      'social_usage': '📱', 'total_usage': '⌛', 'entertainment_usage': '🎬',
    };
    return map[key] ?? '📊';
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
