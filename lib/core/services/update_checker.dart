import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class UpdateChecker {
  static const String currentVersion = '1.2.0';
  static const String githubRepo = 'khan-masud/me-plus-plus';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final String latestTag = data['tag_name'] ?? '';
      final String htmlUrl = data['html_url'] ?? '';
      final String changelog = data['body'] ?? 'No release notes provided.';

      if (latestTag.isEmpty) return;

      // Clean prefix 'v' if present (e.g. 'v1.0.1' -> '1.0.1')
      final latestVer = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

      if (_isVersionNewer(currentVersion, latestVer)) {
        if (!context.mounted) return;
        _showUpdateDialog(context, latestTag, changelog, htmlUrl);
      }
    } catch (_) {
      // Fail silently to avoid breaking offline usage
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true; // latest has more subversions
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String changelog,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Text('Update Available!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version ($version) of Me++ is available. Update your app for the latest features and bug fixes. Please make sure to backup your data first!',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 14),
              const Text(
                'Changelog:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    changelog,
                    style: AppTypography.bodySmall,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }
}
