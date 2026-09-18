// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// "A newer version is available — please update" nudge.
//
// Driven by the advisory `latest_build` / `update_url` fields the server puts in
// the /v1/config payload (see AppUpdateInfo). Strictly a DISMISSIBLE reminder —
// it never blocks the app (those fields are not part of the signed config
// message, so a forced/blocking update is intentionally out of scope). Shown at
// most once per `_kCooldown` while the running build is behind the latest, so
// the user is reminded without being nagged on every launch.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../version/app_package_info.dart';

const String _kUpdateNudgeLastShownMs = 'app_update_nudge_last_shown_ms';

/// Quiet period between update reminders (don't pop on every launch).
const Duration _kCooldown = Duration(hours: 24);

/// Platform store fallback used when the server didn't provide `update_url`.
const String _kPlayUrl =
    'https://play.google.com/store/apps/details?id=com.secretly.secretly_app';
const String _kSiteUrl = 'https://www.secretlyapp.com';

String _t(BuildContext context, {required String ru, required String en}) =>
    Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

/// Auto entry point — safe to call on every app open. Shows the nudge only when
/// the server advertises a newer build than the one running, and not more often
/// than the cooldown. Never throws into the caller.
Future<void> maybeShowUpdateNudge(
  BuildContext context,
  AppController controller,
) async {
  try {
    final info = controller.appUpdateInfo;
    if (info.latestBuild <= 0) return; // server didn't advertise anything

    final pkg = await AppPackageInfo.load();
    final running = int.tryParse(pkg.buildNumber.trim()) ?? 0;
    if (running <= 0 || running >= info.latestBuild) return; // up to date

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastShown = prefs.getInt(_kUpdateNudgeLastShownMs) ?? 0;
    if (nowMs - lastShown < _kCooldown.inMilliseconds) return;
    await prefs.setInt(_kUpdateNudgeLastShownMs, nowMs);

    if (!context.mounted) return;
    await _showUpdateSheet(context, running: running, latest: info.latestBuild,
        url: info.updateUrl);
  } catch (_) {
    // best-effort — an update reminder must never crash the app start.
  }
}

Future<void> _openStore(String? configuredUrl) async {
  final url = (configuredUrl != null && configuredUrl.isNotEmpty)
      ? configuredUrl
      : (Platform.isAndroid ? _kPlayUrl : _kSiteUrl);
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {/* best-effort */}
}

Future<void> _showUpdateSheet(
  BuildContext context, {
  required int running,
  required int latest,
  required String? url,
}) {
  final cs = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.system_update_rounded,
                    color: cs.primary, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                _t(ctx,
                    ru: 'Доступна новая версия',
                    en: 'A new version is available'),
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(ctx,
                    ru: 'Обновите Secretly, чтобы получить последние улучшения '
                        'и исправления. Это займёт меньше минуты.',
                    en: 'Update Secretly to get the latest improvements and '
                        'fixes. It takes less than a minute.'),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openStore(url);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_t(ctx, ru: 'Обновить', en: 'Update')),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  _t(ctx, ru: 'Позже', en: 'Later'),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
