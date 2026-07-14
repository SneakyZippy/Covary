import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../services/analytics_service.dart';
import '../../services/metric_service.dart';
import '../../services/app_usage_service.dart';
import 'dart:ui';
import '../../data/models/metric_definition.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/event_repository.dart';
import '../../ui/theme/design_system.dart';
import '../widgets/help_button.dart';
import '../widgets/metric_icon.dart';


class CorrelationMatrixScreen extends StatefulWidget {
  const CorrelationMatrixScreen({super.key});

  @override
  State<CorrelationMatrixScreen> createState() =>
      _CorrelationMatrixScreenState();
}

/// A single correlation matrix cell: the coefficient plus enough context
/// (sample size, p-value) to know whether it's worth trusting.
class _MatrixCellData {
  final double? correlation;
  final int n;
  final double? pValue;
  final bool significant;
  const _MatrixCellData({
    required this.correlation,
    required this.n,
    required this.pValue,
    required this.significant,
  });
}

class _CorrelationMatrixScreenState extends State<CorrelationMatrixScreen> {
  bool _isLoading = true;
  List<MetricDefinition> _rowMetrics = [];
  List<MetricDefinition> _colMetrics = [];
  Map<String, Map<String, _MatrixCellData?>> _matrix = {};
  MetricDefinition? _spotlightRow;
  MetricDefinition? _spotlightCol;
  double? _spotlightCorrelation;
  double? _spotlightPValue;
  int? _spotlightN;
  bool _dismissedSpotlight = false;
  
  // Interactive crosshair highlighting
  String? _highlightedRowId;
  String? _highlightedColId;

  // "Virtual" metrics for passive sensing data that don't have definitions in MetricService.
  // Per-app breakdowns are deliberately excluded here (too granular for a matrix), but
  // per-category screen time is added dynamically in _autoselectMetrics() below, since
  // categories are user-defined and can't be hardcoded.
  static const List<MetricDefinition> _passiveMetrics = [
    MetricDefinition(
      id: 'passive_total_usage',
      label: 'total_screen_time',
      category: EventCategory.appUsage,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'screen_time',
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
      id: 'passive_bedtime',
      label: 'sleep_bedtime',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'bedtime',
    ),
    MetricDefinition(
      id: 'passive_wakeup',
      label: 'sleep_wakeup',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'sunny',
    ),
    MetricDefinition(
      id: 'passive_midpoint',
      label: 'sleep_midpoint',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'midpoint',
    ),
    MetricDefinition(
      id: 'passive_steps',
      label: 'step_count',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'run',
    ),
    MetricDefinition(
      id: 'passive_weather_rain',
      label: 'core_weather_rain',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'umbrella',
    ),
    MetricDefinition(
      id: 'passive_weather_sun',
      label: 'core_weather_sun',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'sunny',
    ),
    MetricDefinition(
      id: 'passive_weather_wind',
      label: 'core_weather_wind',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'air',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoselectMetrics();
    });
  }

  /// Builds one virtual [MetricDefinition] per user-defined app usage category
  /// (Settings > App Category Manager), since categories aren't static and
  /// can't be hardcoded like the other passive metrics above.
  List<MetricDefinition> _dynamicCategoryMetrics() {
    final categories = context.read<AppUsageService>().categories.keys;
    return categories.map((catName) {
      final emoji = catName == 'social'
          ? 'social'
          : catName == 'entertainment'
              ? 'entertainment'
              : 'screen_time';
      return MetricDefinition(
        id: 'passive_category_$catName',
        label: 'category_time:$catName',
        category: EventCategory.appUsage,
        inputType: MetricInputType.counter,
        isEnabled: true,
        emoji: emoji,
      );
    }).toList();
  }

  List<MetricDefinition> _buildAllAvailableMetrics() {
    final allSubjective = context
        .read<MetricService>()
        .allMetrics
        .where((m) => m.isEnabled)
        .toList();
    return [...allSubjective, ..._passiveMetrics, ..._dynamicCategoryMetrics()];
  }

  void _autoselectMetrics() {
    final allAvailable = _buildAllAvailableMetrics();

    setState(() {
      // Symmetrical by default for better research overview
      _rowMetrics = allAvailable
          .where(
            (m) =>
                m.category == EventCategory.mood ||
                m.category == EventCategory.behavior ||
                m.category == EventCategory.productivity ||
                m.category == EventCategory.biological,
          )
          .toList();

      _colMetrics = List.from(_rowMetrics);

      // If we have passive, weather or health data, add it to columns
      final passiveAndContext = allAvailable
          .where(
            (m) =>
                m.category == EventCategory.appUsage ||
                m.category == EventCategory.health ||
                m.category == EventCategory.weather,
          )
          .toList();
      _colMetrics.addAll(passiveAndContext);

      // Fallback
      if (_rowMetrics.isEmpty) _rowMetrics = allAvailable.take(5).toList();
      if (_colMetrics.isEmpty) _colMetrics = allAvailable.take(5).toList();
    });

    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    if (_rowMetrics.isEmpty || _colMetrics.isEmpty) return;

    setState(() {
      _isLoading = true;
      _spotlightRow = null;
      _spotlightCol = null;
      _spotlightCorrelation = null;
      _spotlightPValue = null;
      _spotlightN = null;
    });
    final eventRepo = context.read<EventRepository>();
    final analyticsService = context.read<AnalyticsService>();
    final newMatrix = <String, Map<String, _MatrixCellData?>>{};

    for (final row in _rowMetrics) {
      newMatrix[row.id] = {};
      for (final col in _colMetrics) {
        // Only show 1.0 on diagonal if the user has actually logged data for it
        if (row.id == col.id) {
          final events = await eventRepo.getEventsByLabel(row.label);
          newMatrix[row.id]![col.id] = events.isNotEmpty
              ? const _MatrixCellData(correlation: 1.0, n: 0, pValue: null, significant: true)
              : null;
          continue;
        }

        final detailed = await analyticsService.calculateSpearmanCorrelationDetailed(
          metricA: row.label,
          metricB: col.label,
          lagDays: 0,
        );
        newMatrix[row.id]![col.id] = detailed == null
            ? null
            : _MatrixCellData(
                correlation: detailed.correlation,
                n: detailed.n,
                pValue: detailed.pValue,
                significant: detailed.pValue < 0.05,
              );
      }
    }

    // Scan for most significant correlation to spotlight
    MetricDefinition? bestRow;
    MetricDefinition? bestCol;
    double bestAbsCorr = -1.0;
    double? bestPValue;
    int? bestN;
    double? bestCorrVal;

    for (final row in _rowMetrics) {
      for (final col in _colMetrics) {
        if (row.id == col.id) continue;
        final cell = newMatrix[row.id]?[col.id];
        if (cell == null || !cell.significant || cell.correlation == null) continue;
        if (cell.correlation!.abs() >= 0.3 && cell.correlation!.abs() > bestAbsCorr) {
          bestAbsCorr = cell.correlation!.abs();
          bestRow = row;
          bestCol = col;
          bestPValue = cell.pValue;
          bestN = cell.n;
          bestCorrVal = cell.correlation;
        }
      }
    }

    if (mounted) {
      setState(() {
        _matrix = newMatrix;
        _spotlightRow = bestRow;
        _spotlightCol = bestCol;
        _spotlightCorrelation = bestCorrVal;
        _spotlightPValue = bestPValue;
        _spotlightN = bestN;
        _isLoading = false;
      });
    }
  }

  void _showMetricSelection() {
    final allAvailable = _buildAllAvailableMetrics();

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
          const AppBarHelpButton(screenKey: 'correlation_matrix'),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _matrix.isEmpty
                ? _buildEmptyState(textTheme)
                : ListView(
                    children: [
                      const SizedBox(height: 16),
                      _buildInsightsSpotlightCard(colorScheme, textTheme),
                      const SizedBox(height: 20),
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


  Widget _buildMatrixGrid(ColorScheme colorScheme, TextTheme textTheme) {
    const double cellSize = 56.0;
    const double headerWidth = 140.0;
    const double headerHeight = 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                    ..._colMetrics.map(
                      (m) => _buildSlantedHeader(
                        m,
                        cellSize,
                        headerHeight,
                        textTheme,
                      ),
                    ),
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
                            textTheme,
                            row,
                            col,
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
      ),
    );
  }

  Widget _buildSlantedHeader(
    MetricDefinition m,
    double width,
    double height,
    TextTheme textTheme,
  ) {
    final isHighlighted = m.id == _highlightedColId;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.bottomLeft,
      child: OverflowBox(
        maxWidth: 200,
        maxHeight: 200,
        alignment: Alignment.bottomLeft,
        child: Transform.translate(
          offset: const Offset(12, -8),
          child: Transform.rotate(
            angle: -0.65,
            alignment: Alignment.bottomLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHighlighted 
                        ? colorScheme.primary.withAlpha(45) 
                        : Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHighlighted 
                          ? colorScheme.primary.withAlpha(150) 
                          : Colors.white.withAlpha(15),
                      width: isHighlighted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEmoji(
                        m.emoji, 
                        14, 
                        color: isHighlighted 
                            ? colorScheme.primary 
                            : Colors.white.withAlpha(220),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _displayLabel(m),
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isHighlighted 
                                ? colorScheme.primary 
                                : Colors.white.withAlpha(220),
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
          ),
        ),
      ),
    );
  }

  Widget _buildRowHeader(
    MetricDefinition m,
    double width,
    double height,
    TextTheme textTheme,
  ) {
    final isHighlighted = m.id == _highlightedRowId;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.only(right: 16),
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
                color: isHighlighted 
                    ? colorScheme.primary 
                    : Colors.white.withAlpha(220),
                letterSpacing: 0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted 
                  ? colorScheme.primary.withAlpha(30)
                  : Colors.white.withAlpha(8),
              shape: BoxShape.circle,
              border: Border.all(
                color: isHighlighted 
                    ? colorScheme.primary.withAlpha(80)
                    : Colors.white.withAlpha(10),
              ),
            ),
            child: _buildEmoji(
              m.emoji, 
              14, 
              color: isHighlighted 
                  ? colorScheme.primary 
                  : Colors.white.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }

  String _displayLabel(MetricDefinition m) {
    return _formatDisplayLabel(m);
  }

  Widget _buildCell(
    _MatrixCellData? cell,
    double size,
    ColorScheme colorScheme,
    TextTheme textTheme,
    MetricDefinition rowMetric,
    MetricDefinition colMetric, {
    int delayIndex = 0,
  }) {
    final bool isHighlightedRow = rowMetric.id == _highlightedRowId;
    final bool isHighlightedCol = colMetric.id == _highlightedColId;
    final bool isHighlightedCell = isHighlightedRow && isHighlightedCol;
    final bool isInCrosshair = isHighlightedRow || isHighlightedCol;
    final bool isDiagonal = rowMetric.id == colMetric.id;

    final double? correlation = cell?.correlation;
    final bool isSignificant = cell?.significant ?? false;

    final heatmapColors = CovaryDesignSystem.getHeatmapColors(context);
    Color cellColor = Colors.white.withAlpha(5);

    bool hasData = correlation != null;
    if (isDiagonal) {
      cellColor = Colors.white.withAlpha(8);
    } else if (hasData) {
      // Non-significant cells (small sample or high p-value) are shown at
      // reduced intensity so they don't visually compete with real signal.
      final double confidence = isSignificant ? 1.0 : 0.4;
      if (correlation > 0.05) {
        cellColor = heatmapColors.$1.withValues(
          alpha: ((0.15 + (0.85 * correlation)) * confidence).clamp(0.08, 1.0),
        );
      } else if (correlation < -0.05) {
        cellColor = heatmapColors.$2.withValues(
          alpha: ((0.15 + (0.85 * correlation.abs())) * confidence).clamp(0.08, 1.0),
        );
      } else {
        cellColor = Colors.white.withValues(alpha: 0.04);
      }
    } else {
      // Empty/no data case
    }

    // Blend in crosshair overlay color
    Color finalCellColor = cellColor;
    if (isInCrosshair) {
      finalCellColor = Color.alphaBlend(
        colorScheme.primary.withAlpha(isHighlightedCell ? 45 : 20),
        cellColor,
      );
    }

    final bool isStrong = !isDiagonal && hasData && isSignificant && correlation.abs() > 0.6;
    final bool isVeryStrong = !isDiagonal && hasData && isSignificant && correlation.abs() > 0.85;

    // Premium Cell Glow
    List<BoxShadow>? shadows;
    if (isVeryStrong) {
      shadows = [
        BoxShadow(
          color: finalCellColor.withValues(alpha: 0.45),
          blurRadius: 12,
          spreadRadius: -1,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isStrong) {
      shadows = [
        BoxShadow(
          color: finalCellColor.withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ];
    }

    // Highlight border behavior
    final Border cellBorder = Border.all(
      color: isHighlightedCell
          ? Colors.white
          : isStrong
              ? Colors.white.withValues(alpha: 0.45)
              : isInCrosshair
                  ? colorScheme.primary.withAlpha(120)
                  : Colors.white.withValues(alpha: 0.05),
      width: isHighlightedCell 
          ? 2.0 
          : (isStrong || isInCrosshair) 
              ? 1.5 
              : 0.5,
    );

    // Build visual child (Arrows or Diagonal Painter)
    Widget cellChild;
    if (isDiagonal) {
      cellChild = CustomPaint(
        size: Size.infinite,
        painter: _DiagonalLinePainter(
          color: isInCrosshair 
              ? colorScheme.primary.withAlpha(150)
              : Colors.white.withAlpha(35),
        ),
      );
    } else if (!hasData || correlation.abs() <= 0.05) {
      cellChild = Center(
        child: Text(
          '·',
          style: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(100),
          ),
        ),
      );
    } else {
      final bool isPositive = correlation > 0;
      final String arrow = isPositive ? '▲' : '▼';
      final double absVal = correlation.abs();
      final String valText = absVal > 0.05 ? absVal.toStringAsFixed(2) : '0';

      cellChild = Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              arrow,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isStrong
                    ? Colors.white
                    : (isPositive ? colorScheme.primary : colorScheme.secondaryContainer),
              ),
            ),
            const SizedBox(width: 1.5),
            Text(
              valText,
              style: textTheme.labelLarge?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isStrong
                    ? (isPositive
                          ? CovaryDesignSystem.onPrimary
                          : Colors.white)
                    : Colors.white.withAlpha(200),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (delayIndex * 25)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (_highlightedRowId == rowMetric.id && _highlightedColId == colMetric.id) {
            // Already highlighted! Second tap opens sheet if it has data.
            if (correlation != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _CorrelationDetailsSheet(
                  rowMetric: rowMetric,
                  colMetric: colMetric,
                  correlation: correlation,
                ),
              );
            } else {
              // Toggle highlight off on empty cell
              setState(() {
                _highlightedRowId = null;
                _highlightedColId = null;
              });
            }
          } else {
            // Highlight the cell and trace crosshairs
            setState(() {
              _highlightedRowId = rowMetric.id;
              _highlightedColId = colMetric.id;
            });
          }
        },
        child: Container(
          width: size - 6,
          height: size - 6,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: finalCellColor,
            borderRadius: BorderRadius.circular(14),
            border: cellBorder,
            boxShadow: shadows,
          ),
          child: cellChild,
        ),
      ),
    );
  }

  Widget _buildEmoji(String? emoji, double size, {Color? color}) {
    if (emoji == null) {
      return Icon(Icons.circle, size: size, color: color ?? Colors.grey);
    }
    return MetricIcon(iconName: emoji, size: size, color: color);
  }

  Widget _buildDataReliabilityInfo(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
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
                  child: Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Research Integrity',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'To ensure statistical validity, correlations are only calculated once 7 days of overlapping data are present. Cells that are not statistically significant (p ≥ 0.05) are shown at reduced intensity, even if the coefficient looks strong.',
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
    final heatmapColors = CovaryDesignSystem.getHeatmapColors(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(10))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendItem(label: 'Positive', color: heatmapColors.$1),
          _LegendItem(label: 'Neutral', color: Colors.white24),
          _LegendItem(
            label: 'Negative',
            color: heatmapColors.$2,
          ),
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
              'Try logging more behaviors daily. Metrics will automatically appear here once 7 days of data are recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _cleanLabel(MetricDefinition m) {
    return _formatDisplayLabel(m);
  }

  Widget _buildInsightsSpotlightCard(ColorScheme colorScheme, TextTheme textTheme) {
    if (_spotlightRow == null || _spotlightCol == null || _dismissedSpotlight) {
      return const SizedBox.shrink();
    }

    final rowLabel = _cleanLabel(_spotlightRow!);
    final colLabel = _cleanLabel(_spotlightCol!);
    final r = _spotlightCorrelation!;
    final rAbs = r.abs();
    final direction = r > 0 ? 'positive' : 'negative';
    final strength = rAbs >= 0.7 ? 'strong' : (rAbs >= 0.4 ? 'moderate' : 'weak');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withAlpha(45),
              colorScheme.surfaceContainerHighest.withAlpha(25),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withAlpha(70),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Insights Spotlight',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant.withAlpha(150),
                    ),
                    onPressed: () {
                      setState(() => _dismissedSpotlight = true);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'There is a $strength $direction relationship (r = ${r.toStringAsFixed(2)}, p = ${_spotlightPValue?.toStringAsFixed(3)}) between "$rowLabel" and "$colLabel" computed over $_spotlightN days.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.arrow_forward_rounded, size: 14, color: colorScheme.primary),
                    label: Text(
                      'View Detailed Analysis',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _CorrelationDetailsSheet(
                          rowMetric: _spotlightRow!,
                          colMetric: _spotlightCol!,
                          correlation: r,
                        ),
                      );
                    },
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
              final newRows = widget.allMetrics
                  .where((m) => _selectedRows.contains(m.id))
                  .toList();
              final newCols = widget.allMetrics
                  .where((m) => _selectedCols.contains(m.id))
                  .toList();
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
          subtitle: Text(
            metric.category.name.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
          secondary: _buildDialogIcon(metric.emoji, context),
          value: isSelected,
          onChanged: (_) => onToggle(metric.id),
        );
      },
    );
  }

  Widget _buildDialogIcon(String? emoji, BuildContext context) {
    if (emoji == null) {
      return const Icon(Icons.help_outline, size: 24);
    }
    return MetricIcon(
      iconName: emoji,
      size: 24,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  String _displayLabel(MetricDefinition m) {
    return _formatDisplayLabel(m);
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
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _CorrelationDetailsSheet extends StatefulWidget {
  final MetricDefinition rowMetric;
  final MetricDefinition colMetric;
  final double correlation;
  const _CorrelationDetailsSheet({
    required this.rowMetric,
    required this.colMetric,
    required this.correlation,
  });

  @override
  State<_CorrelationDetailsSheet> createState() => _CorrelationDetailsSheetState();
}

class _CorrelationDetailsSheetState extends State<_CorrelationDetailsSheet> {
  bool _loading = true;
  List<FlSpot> _spotsRow = [];
  List<FlSpot> _spotsCol = [];
  List<String> _dateLabels = [];
  double? _pValue;
  int? _n;

  @override
  void initState() {
    super.initState();
    _fetchAndAlignData();
  }

  Future<void> _fetchAndAlignData() async {
    final analyticsService = context.read<AnalyticsService>();
    final dataRow = await analyticsService.getDailyTimeSeries(widget.rowMetric.label, normalize: true, lastNDays: 14);
    final dataCol = await analyticsService.getDailyTimeSeries(widget.colMetric.label, normalize: true, lastNDays: 14);

    final sortedDates = dataRow.keys.where((d) => dataCol.containsKey(d)).toList()
      ..sort((a, b) => a.compareTo(b));

    final List<FlSpot> spotsRow = [];
    final List<FlSpot> spotsCol = [];
    final List<String> dateLabels = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      spotsRow.add(FlSpot(i.toDouble(), dataRow[date]!));
      spotsCol.add(FlSpot(i.toDouble(), dataCol[date]!));
      dateLabels.add('${date.month}/${date.day}');
    }

    // Match the 14-day window the trend chart above actually plots, instead
    // of silently computing the stat over the user's entire history.
    final detailed = await analyticsService.calculateSpearmanCorrelationDetailed(
      metricA: widget.rowMetric.label,
      metricB: widget.colMetric.label,
      lagDays: 0,
      lastNDays: 14,
    );

    if (mounted) {
      setState(() {
        _spotsRow = spotsRow;
        _spotsCol = spotsCol;
        _dateLabels = dateLabels;
        if (detailed != null) {
          _pValue = detailed.pValue;
          _n = detailed.n;
        }
        _loading = false;
      });
    }
  }

  String _getInterpretation() {
    final r = widget.correlation;
    final rAbs = r.abs();

    String direction = r > 0 ? "positive" : "negative";
    String strength = "weak";
    if (rAbs >= 0.7) {
      strength = "strong";
    } else if (rAbs >= 0.4) {
      strength = "moderate";
    }

    if (rAbs < 0.15) {
      return "There is virtually no correlation between these two metrics in your logged history.";
    }

    String contextInfo = "";
    final catA = widget.rowMetric.category;
    final catB = widget.colMetric.category;

    if (catA == EventCategory.mood && catB == EventCategory.behavior) {
      if (r > 0) {
        contextInfo = " This positive correlation suggests that your subjective feelings of '${_cleanLabel(widget.rowMetric)}' tend to improve on days you log '${_cleanLabel(widget.colMetric)}'. Dynamic tracking shows this behavior acts as a positive feedback anchor.";
      } else {
        contextInfo = " This inverse correlation indicates that your '${_cleanLabel(widget.rowMetric)}' tends to drop on days with higher '${_cleanLabel(widget.colMetric)}'. This might point to behavioral drag or exhaustion.";
      }
    } else if (catA == EventCategory.mood && catB == EventCategory.appUsage) {
      if (r < 0) {
        contextInfo = " This negative correlation points to a digital drag effect: your mood or mental state tends to dip as screen time/usage increases. This is a common indicator of 'doom-scrolling' or attention hijacking.";
      } else {
        contextInfo = " This positive correlation shows that your digital habits align positively with your mood. You might be using screen time productively or for high-value social connection.";
      }
    } else if (catA == EventCategory.mood && catB == EventCategory.health) {
      if (r > 0) {
        contextInfo = " This highlights the mind-body connection: better physical markers (like sleep or activity) are moderately linked to a more positive emotional state.";
      }
    } else if (catA == EventCategory.productivity && catB == EventCategory.appUsage) {
      if (r < 0) {
        contextInfo = " This inverse trend suggests high screen time disrupts your concentration or bachelor work, pointing to prompt friction or distraction.";
      }
    }

    String significanceInfo = "";
    if (_pValue != null && _n != null) {
      final isSignificant = _pValue! < 0.05;
      final statusText = isSignificant 
          ? "This relationship is statistically significant (p = ${_pValue!.toStringAsFixed(3)}), meaning it is highly unlikely to be random noise." 
          : "This relationship is not statistically significant (p = ${_pValue!.toStringAsFixed(3)}), indicating that more data points are needed to confirm a reliable trend.";
      significanceInfo = "\n\n**Scientific Validity:** Computed across $_n days of overlapping data. $statusText";
    }

    return "There is a $strength $direction relationship (r = ${r.toStringAsFixed(2)}) between '${_cleanLabel(widget.rowMetric)}' and '${_cleanLabel(widget.colMetric)}'.$contextInfo$significanceInfo";
  }

  String _cleanLabel(MetricDefinition m) {
    return _formatDisplayLabel(m);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final lineColors = CovaryDesignSystem.getChartLineColors(context);
    final colorA = lineColors.$1;
    final colorB = lineColors.$2;

    final heatmapColors = CovaryDesignSystem.getHeatmapColors(context);
    final positiveColor = heatmapColors.$1;
    final negativeColor = heatmapColors.$2;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Correlation Insights',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${_cleanLabel(widget.rowMetric)}  ×  ${_cleanLabel(widget.colMetric)}",
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.correlation > 0
                            ? positiveColor.withValues(alpha: 0.2)
                            : negativeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.correlation.toStringAsFixed(2),
                        style: textTheme.labelLarge?.copyWith(
                          color: widget.correlation > 0 ? positiveColor : negativeColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_n != null && _pValue != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'N = $_n days',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pValue! < 0.05
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _pValue! < 0.05
                                ? colorScheme.primary.withValues(alpha: 0.4)
                                : colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _pValue! < 0.05 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 10,
                              color: _pValue! < 0.05 ? colorScheme.primary : colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _pValue! < 0.05
                                  ? 'Significant (p = ${_pValue!.toStringAsFixed(3)})'
                                  : 'Not Significant (p = ${_pValue!.toStringAsFixed(3)})',
                              style: textTheme.labelSmall?.copyWith(
                                color: _pValue! < 0.05 ? colorScheme.primary : colorScheme.error,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _getInterpretation(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_spotsRow.isEmpty || _spotsCol.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Not enough overlapping history to render the trend chart.',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            Text(
              '14-Day Overlaid Trend (Normalized)',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 8),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (val) => FlLine(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: max(1, _spotsRow.length / 5).toDouble(),
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < _dateLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  _dateLabels[idx],
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (_spotsRow.length - 1).toDouble(),
                    minY: -0.05,
                    maxY: 1.05,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spotsRow,
                        isCurved: true,
                        color: colorA,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorA.withValues(alpha: 0.05),
                        ),
                      ),
                      LineChartBarData(
                        spots: _spotsCol,
                        isCurved: true,
                        color: colorB,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorB.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendIndicator(_cleanLabel(widget.rowMetric), colorA, textTheme),
                const SizedBox(width: 24),
                _buildLegendIndicator(_cleanLabel(widget.colMetric), colorB, textTheme),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color, TextTheme textTheme) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  final Color color;
  _DiagonalLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatDisplayLabel(MetricDefinition m) {
  if (m.id == 'passive_weather_rain') return 'Rain (Passive)';
  if (m.id == 'passive_weather_sun') return 'Sun (Passive)';
  if (m.id == 'passive_weather_wind') return 'Wind (Passive)';
  if (m.id == 'passive_steps') return 'Steps (Passive)';
  if (m.id == 'passive_sleep') return 'Sleep Duration (Passive)';
  if (m.id == 'passive_bedtime') return 'Bedtime (Passive)';
  if (m.id == 'passive_wakeup') return 'Wake-up Time (Passive)';
  if (m.id == 'passive_midpoint') return 'Sleep Midpoint (Passive)';
  if (m.id == 'passive_social_usage') return 'Social Media (Passive)';
  if (m.id == 'passive_total_usage') return 'Screen Time (Passive)';
  if (m.id == 'passive_entertainment_usage') return 'Entertainment (Passive)';

  if (m.id.startsWith('passive_')) {
    String label = m.label;
    if (label.contains(':')) {
      label = label.split(':').last;
    }
    final clean = label.replaceAll('_', ' ');
    if (clean.isEmpty) return m.label;
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
  return m.label;
}
