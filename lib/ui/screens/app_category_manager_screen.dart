import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_usage_service.dart';
import '../widgets/help_button.dart';


class AppCategoryManagerScreen extends StatefulWidget {
  const AppCategoryManagerScreen({super.key});

  @override
  State<AppCategoryManagerScreen> createState() => _AppCategoryManagerScreenState();
}

class _AppCategoryManagerScreenState extends State<AppCategoryManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final appUsage = context.watch<AppUsageService>();
    final categories = appUsage.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            onPressed: _showAddCategoryDialog,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Category',
          ),
          const AppBarHelpButton(screenKey: 'app_category_manager'),
        ],
      ),
      body: categories.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final name = categories.keys.elementAt(index);
                final apps = categories[name]!;
                return _buildCategoryCard(name, apps);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No categories created yet.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAddCategoryDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create First Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, Set<String> apps) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          name.toUpperCase(),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        subtitle: Text('${apps.length} apps assigned'),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(Icons.apps, color: colorScheme.onPrimaryContainer, size: 20),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showRenameDialog(name),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _confirmDelete(name),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (apps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No apps in this category.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: apps.map((pkg) => Chip(
                      label: Text(AppUsageService.readableName(pkg), style: const TextStyle(fontSize: 11)),
                      onDeleted: () => context.read<AppUsageService>().toggleAppInCategory(pkg, name, false),
                      deleteIconColor: colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAppPicker(name),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Apps to Category'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Productivity, Gaming'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<AppUsageService>().addCategory(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New category name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                context.read<AppUsageService>().renameCategory(oldName, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "$name"? Apps will not be deleted, just unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<AppUsageService>().deleteCategory(name);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showAppPicker(String categoryName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AppPicker(categoryName: categoryName),
    );
  }
}

class _AppPicker extends StatefulWidget {
  final String categoryName;
  const _AppPicker({required this.categoryName});

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  Set<String>? _installed;
  String _search = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await context.read<AppUsageService>().fetchInstalledPackages();
      if (mounted) {
        setState(() {
          _installed = apps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _installed = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUsage = context.watch<AppUsageService>();
    final currentApps = appUsage.categories[widget.categoryName] ?? {};

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Assign Apps to ${widget.categoryName.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SearchBar(
              hintText: 'Search apps...',
              onChanged: (val) => setState(() => _search = val.toLowerCase()),
              leading: const Icon(Icons.search),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainer),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _installed == null || _installed!.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'App category selection is only supported on Android.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        children: _installed!
                            .where((pkg) => AppUsageService.readableName(pkg).toLowerCase().contains(_search))
                            .map((pkg) {
                          final isActive = currentApps.contains(pkg);
                          return CheckboxListTile(
                            title: Text(AppUsageService.readableName(pkg)),
                            subtitle: Text(pkg, style: const TextStyle(fontSize: 10)),
                            value: isActive,
                            onChanged: (val) => appUsage.toggleAppInCategory(pkg, widget.categoryName, val ?? false),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
