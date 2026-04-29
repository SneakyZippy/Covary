import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/analytics_service.dart';
import '../../services/metric_service.dart';
import '../../data/models/metric_definition.dart';
import '../../data/models/enums.dart';

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
      label: 'social_screen_time_minutes',
      category: EventCategory.appUsage,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'social_usage',
    ),
    MetricDefinition(
      id: 'passive_total_usage',
      label: 'total_screen_time_minutes',
      category: EventCategory.appUsage,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'total_usage',
    ),
    MetricDefinition(
      id: 'passive_entertainment_usage',
      label: 'entertainment_screen_time_minutes',
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
      // Autoselect: Mood/Behavior on rows, Usage/Health on columns
      _rowMetrics = allAvailable.where((m) => 
        m.category == EventCategory.mood || 
        m.category == EventCategory.behavior ||
        m.category == EventCategory.productivity
      ).toList();

      _colMetrics = allAvailable.where((m) => 
        m.category == EventCategory.appUsage || 
        m.category == EventCategory.health ||
        m.category == EventCategory.mood
      ).toList();

      // Fallback
      if (_rowMetrics.isEmpty) _rowMetrics = allAvailable.take(5).toList();
      if (_colMetrics.isEmpty) _colMetrics = allAvailable.take(5).toList();
    });

    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    if (_rowMetrics.isEmpty || _colMetrics.isEmpty) return;

    setState(() => _isLoading = true);
    
    final analyticsService = context.read<AnalyticsService>();
    final newMatrix = <String, Map<String, double?>>{};

    for (final row in _rowMetrics) {
      newMatrix[row.id] = {};
      for (final col in _colMetrics) {
        if (row.id == col.id && _lagDays == 0) {
          newMatrix[row.id]![col.id] = 1.0;
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
                : _buildMatrixGrid(colorScheme, textTheme),
          ),
          _buildLegend(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildLagSelector(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Time Lag: $_lagDays ${_lagDays == 1 ? 'Day' : 'Days'}',
                style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_lagDays > 0)
                Text(
                  'Predicting tomorrow\'s state',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.secondary),
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
    const double cellSize = 60.0;
    const double headerWidth = 100.0;
    const double headerHeight = 100.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Columns)
            Row(
              children: [
                SizedBox(width: headerWidth, height: headerHeight), // Top-left empty space
                ..._colMetrics.map((m) => _buildColumnHeader(m, cellSize, headerHeight, textTheme)),
              ],
            ),
            // Data Rows
            ..._rowMetrics.map((row) => Row(
              children: [
                _buildRowHeader(row, headerWidth, cellSize, textTheme),
                ..._colMetrics.map((col) => _buildCell(
                  _matrix[row.id]?[col.id], 
                  cellSize, 
                  colorScheme,
                )),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader(MetricDefinition m, double width, double height, TextTheme textTheme) {
    final double maxTextHeight = height - 40; 

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildEmoji(m.emoji, 18),
          const SizedBox(height: 4),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: maxTextHeight,
              child: Text(
                _displayLabel(m),
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowHeader(MetricDefinition m, double width, double height, TextTheme textTheme) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              _displayLabel(m),
              textAlign: TextAlign.right,
              style: textTheme.labelSmall?.copyWith(fontSize: 9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          _buildEmoji(m.emoji, 16),
        ],
      ),
    );
  }

  String _displayLabel(MetricDefinition m) {
    if (m.id.startsWith('passive_')) {
      // Clean up internal labels for display
      return m.label.replaceAll('_screen_time_minutes', '').replaceAll('_', ' ').toUpperCase();
    }
    return m.label;
  }

  Widget _buildCell(double? correlation, double size, ColorScheme colorScheme) {
    Color cellColor = Colors.transparent;
    String text = '-';
    
    if (correlation != null) {
      text = correlation.abs() > 0.1 ? correlation.toStringAsFixed(2) : '0';
      if (correlation > 0) {
        cellColor = Colors.blue.withValues(alpha: correlation.clamp(0, 1));
      } else {
        cellColor = Colors.red.withValues(alpha: correlation.abs().clamp(0, 1));
      }
    }

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: correlation != null && correlation.abs() > 0.5 
              ? Colors.white 
              : Colors.black87,
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

  Widget _buildLegend(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surfaceContainerHighest.withAlpha(100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendItem(label: 'Positive', color: Colors.blue),
          _LegendItem(label: 'Neutral', color: Colors.grey.withAlpha(50)),
          _LegendItem(label: 'Negative', color: Colors.red),
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
              'Not enough data or no metrics selected.',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Select metrics to compare in the filter menu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
      return m.label.replaceAll('_screen_time_minutes', '').replaceAll('_', ' ').toUpperCase();
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
