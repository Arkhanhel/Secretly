// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Server-advertised "a newer app version exists" hint, carried in the
/// `/v1/config` payload (fields `latest_build` + optional `update_url`).
///
/// SECURITY note: these two fields are NOT part of the signed config message
/// (`configSigningMessage`), so they are advisory only. We use them solely to
/// show a DISMISSIBLE "update available" nudge — never to block/lock the app.
/// A forced (blocking) update would require a signed field and is intentionally
/// out of scope here.
class AppUpdateInfo {
  const AppUpdateInfo({this.latestBuild = 0, this.updateUrl});

  /// The newest published build number the server knows about. 0 = unknown
  /// (no nudge).
  final int latestBuild;

  /// Optional store/landing URL the "Update" button opens. When null the UI
  /// falls back to a platform default.
  final String? updateUrl;

  static const AppUpdateInfo none = AppUpdateInfo();

  /// Читает ПОДПИСАННЫЙ блок `update` ответа `/v1/config`.
  ///
  /// 🔴 [verified] обязан быть результатом `verifyUpdateSignature`. Раньше эти
  /// поля брались из основного `payload`, чей подписываемый вид заморожен —
  /// то есть они были бы ВНЕ подписи, а неподписанный адрес обновления это
  /// фишинг. Не проверилось — напоминания нет; худшее, что может случиться,
  /// это отсутствие напоминания, а не поход по чужой ссылке.
  static AppUpdateInfo fromSignedConfig(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return none;
    final payload = configResponse['update'];
    if (payload is! Map) return none;
    return AppUpdateInfo.fromConfigPayload(payload);
  }

  factory AppUpdateInfo.fromConfigPayload(Map<dynamic, dynamic> payload) {
    final lb = payload['latest_build'];
    final url = payload['update_url'];
    final latest = lb is num
        ? lb.toInt()
        : int.tryParse('${lb ?? ''}'.trim()) ?? 0;
    final cleanUrl = (url is String && url.trim().isNotEmpty)
        ? url.trim()
        : null;
    return AppUpdateInfo(latestBuild: latest, updateUrl: cleanUrl);
  }
}
