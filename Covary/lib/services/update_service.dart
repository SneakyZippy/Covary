import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// A simple service to check for updates against a remote JSON file.
/// 
/// Example JSON structure:
/// {
///   "latest_version": "1.0.1",
///   "build_number": 2,
///   "download_url": "https://example.com/Covary-latest.apk",
///   "release_notes": "Improved stability and new metrics."
/// }
class UpdateService {
  static const String versionUrl = 'https://raw.githubusercontent.com/SneakyZippy/Covary/main/version.json';

  /// Checks if an update is available and shows a dialog if so.
  static Future<void> checkAndPrompt(BuildContext context, {bool silent = true}) async {
    try {
      final updateInfo = await fetchUpdateInfo();
      if (updateInfo == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final latestVersion = updateInfo['latest_version'] as String;
      final latestBuild = updateInfo['build_number'] as int;

      // Logic: Update if build number is higher OR version string is different (and not lower)
      bool hasUpdate = false;
      if (latestBuild > currentBuild) {
        hasUpdate = true;
      } else if (latestVersion != currentVersion) {
        // Basic string comparison might be enough for simple incremental versions
        // but ideally use a version parsing library if needed.
        hasUpdate = _isVersionHigher(latestVersion, currentVersion);
      }

      if (hasUpdate) {
        if (!context.mounted) return;
        _showUpdateDialog(context, updateInfo);
      } else if (!silent) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('App is up to date (Local: $currentBuild, Server: $latestBuild)')),
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check for updates: $e')),
        );
      }
    }
  }

  static Future<Map<String, dynamic>?> fetchUpdateInfo() async {
    final response = await http.get(Uri.parse(versionUrl)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('HTTP request failed with status: ${response.statusCode}');
    }
  }

  static bool _isVersionHigher(String latest, String current) {
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  static void _showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version (${updateInfo['latest_version']}+${updateInfo['build_number']}) is available.'),
            if (updateInfo['build_timestamp'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Published: ${updateInfo['build_timestamp']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            if (updateInfo['release_notes'] != null) ...[
              const SizedBox(height: 16),
              const Text('What\'s new:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(updateInfo['release_notes']),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              final url = Uri.parse(updateInfo['download_url']);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
