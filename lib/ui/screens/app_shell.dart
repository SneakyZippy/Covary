import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../../services/update_service.dart';
import '../../services/theme_service.dart' show ThemeService, AppBackgroundStyle;
import '../theme/design_system.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'data_screen.dart';
import 'analytics_screen.dart';

/// The main app scaffold with a floating, glassmorphic bottom navigation bar.
///
/// Contains primary destinations: Home, Data, Analytics, and Settings.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkPendingFatigueDialog();
      // Check for updates on app launch
      UpdateService.checkAndPrompt(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        context.read<SyncService>().syncNow();
        NotificationService.processWebPushQueue();
      } catch (e) {
        debugPrint('[AppShell] Failed to trigger auto-sync/pwa-queue on resume: $e');
      }
    }
  }

  static const List<Widget> _screens = [
    HomeScreen(),
    DataScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final themeService = context.watch<ThemeService>();
    final bgStyle = themeService.backgroundStyle;

    final Color barBgColor;
    if (isDark) {
      switch (bgStyle) {
        case AppBackgroundStyle.pureBlack:
          barBgColor = Colors.black.withAlpha(180);
          break;
        case AppBackgroundStyle.deepCharcoal:
          barBgColor = const Color(0xFF16161A).withAlpha(180);
          break;
        case AppBackgroundStyle.midnightNavy:
          barBgColor = const Color(0xFF0B121F).withAlpha(180);
          break;
        case AppBackgroundStyle.auroraGradient:
          barBgColor = const Color(0xFF0B121F).withAlpha(130);
          break;
      }
    } else {
      barBgColor = colorScheme.surface.withAlpha(220);
    }

    final Color borderColor = isDark
        ? CovaryDesignSystem.innerBorderColor
        : colorScheme.onSurface.withAlpha(20);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double bottomMargin = bottomInset > 0 ? 12.0 : 20.0;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottomMargin),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: barBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 40 : 15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.dataset_outlined,
                      activeIcon: Icons.dataset_rounded,
                      label: 'Insights',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.analytics_outlined,
                      activeIcon: Icons.analytics_rounded,
                      label: 'Analytics',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: 'Settings',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withAlpha(160),
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withAlpha(160),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 10,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 4 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

