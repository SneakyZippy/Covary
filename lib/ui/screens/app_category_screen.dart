import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_usage_service.dart';

/// Allows users to configure which installed apps are classified as
/// "Social Media" or "Entertainment" for research categorization.
///
/// ## Thesis Note
/// Letting participants define their own social/entertainment boundaries
/// improves ecological validity. The per-app screen time display gives
/// context so users can make informed classifications.
class AppCategoryScreen extends StatefulWidget {
  const AppCategoryScreen({super.key});

  @override
  State<AppCategoryScreen> createState() => _AppCategoryScreenState();
}

class _AppCategoryScreenState extends State<AppCategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Per-app screen time (package → minutes), loaded once on init.
  Map<String, int>? _appUsageMap;

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppUsage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppUsage() async {
    final service = context.read<AppUsageService>();
    final usage = await service.fetchPerAppScreenTimeMinutes();
    if (mounted) {
      setState(() {
        _appUsageMap = usage ?? {};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'Social Media'),
            Tab(
              icon: Icon(Icons.movie_filter_rounded),
              text: 'Entertainment',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- Search bar ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search apps…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),

                // --- Tab views ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryTab(
                        isSocial: true,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      _buildCategoryTab(
                        isSocial: false,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryTab({
    required bool isSocial,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final service = context.watch<AppUsageService>();
    final selectedSet =
        isSocial ? service.socialPackages : service.entertainmentPackages;

    if (_appUsageMap == null || _appUsageMap!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.app_blocking_rounded,
                size: 64,
                color: colorScheme.onSurfaceVariant.withAlpha(120),
              ),
              const SizedBox(height: 16),
              Text(
                'No app usage data available',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure Usage Access permission is granted.\n'
                'Apps will appear here after you use your device.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Only show apps from actual usage data (guaranteed installed + used).
    // The "Suggested" badge highlights apps from the curated list, but
    // we don't inject uninstalled apps into the list.
    final allPackages = <String>{
      ..._appUsageMap!.keys,
      ...selectedSet, // Keep previously-selected apps visible
    }.toList();

    // Filter by search query
    final filtered = allPackages.where((pkg) {
      if (_searchQuery.isEmpty) return true;
      final readableName = AppUsageService.readableName(pkg).toLowerCase();
      return readableName.contains(_searchQuery) ||
          pkg.toLowerCase().contains(_searchQuery);
    }).toList();

    // Sort: selected first, then suggested, then by usage descending
    filtered.sort((a, b) {
      final aSelected = selectedSet.contains(a);
      final bSelected = selectedSet.contains(b);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;

      // Within unselected, show suggested before non-suggested
      if (!aSelected && !bSelected) {
        final aSuggested = isSocial
            ? AppUsageService.isSuggestedSocial(a)
            : AppUsageService.isSuggestedEntertainment(a);
        final bSuggested = isSocial
            ? AppUsageService.isSuggestedSocial(b)
            : AppUsageService.isSuggestedEntertainment(b);
        if (aSuggested && !bSuggested) return -1;
        if (!aSuggested && bSuggested) return 1;
      }

      // Within same group, sort by usage time descending
      return (_appUsageMap![b] ?? 0).compareTo(_appUsageMap![a] ?? 0);
    });


    final totalSelectedCount = selectedSet.length;

    return Column(
      children: [
        // Summary header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSocial
                      ? colorScheme.primaryContainer
                      : colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalSelectedCount apps selected',
                  style: textTheme.labelMedium?.copyWith(
                    color: isSocial
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${filtered.length} apps shown',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // App list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final pkg = filtered[index];
              final minutes = _appUsageMap![pkg] ?? 0;
              final isSelected = selectedSet.contains(pkg);
              final isSuggested = isSocial
                  ? AppUsageService.isSuggestedSocial(pkg)
                  : AppUsageService.isSuggestedEntertainment(pkg);
              final readableName = AppUsageService.readableName(pkg);

              return _AppCategoryTile(
                packageName: pkg,
                readableName: readableName,
                minutes: minutes,
                isSelected: isSelected,
                isSuggested: isSuggested,
                accentColor: isSocial
                    ? colorScheme.primary
                    : colorScheme.tertiary,
                onToggle: (value) {
                  if (isSocial) {
                    service.toggleSocialApp(pkg, value);
                  } else {
                    service.toggleEntertainmentApp(pkg, value);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Individual App Tile
// =============================================================================

class _AppCategoryTile extends StatelessWidget {
  final String packageName;
  final String readableName;
  final int minutes;
  final bool isSelected;
  final bool isSuggested;
  final Color accentColor;
  final ValueChanged<bool> onToggle;

  const _AppCategoryTile({
    required this.packageName,
    required this.readableName,
    required this.minutes,
    required this.isSelected,
    required this.isSuggested,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: isSelected
          ? accentColor.withAlpha(25)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? BorderSide(color: accentColor.withAlpha(80), width: 1)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isSelected
              ? accentColor.withAlpha(40)
              : colorScheme.surfaceContainerHigh,
          child: Text(
            readableName.isNotEmpty ? readableName[0].toUpperCase() : '?',
            style: textTheme.titleMedium?.copyWith(
              color: isSelected ? accentColor : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                readableName,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSuggested && !isSelected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Suggested',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          _formatUsageTime(minutes),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch.adaptive(
          value: isSelected,
          activeTrackColor: accentColor,
          onChanged: onToggle,
        ),
        onTap: () => onToggle(!isSelected),
      ),
    );
  }

  String _formatUsageTime(int minutes) {
    if (minutes < 1) return 'Less than 1 min today';
    if (minutes < 60) return '$minutes min today';
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    if (remainingMin == 0) return '${hours}h today';
    return '${hours}h ${remainingMin}m today';
  }
}
