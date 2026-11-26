// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Нативное окно «Оцените приложение» (24.11.2026, владелец: «для новых
/// пользователей… нативное, если есть и от Apple, и от Google»).
///
/// Само окно — системное: на iPhone `AppStore.requestReview` (звёзды прямо
/// в приложении), на Android — In-App Review Google Play. Своей плашки и
/// вопроса «нравится ли вам?» перед ним нет — правила Apple (5.6.1) и Google
/// запрещают выспрашивать мнение перед окном оценки.
///
/// Когда просим (всё сразу):
/// - только телефоны;
/// - только новые пользователи: при первом запуске этой логики на
///   устройстве не было переписки старше трёх суток ([kAppReviewExistingUsers]
///   включает и старых);
/// - прошло не меньше 3 суток с первого запуска и запусков не меньше 5;
/// - повтор — не раньше чем через 120 дней, всего не больше 3 просьб
///   (Apple сама показывает окно не чаще трёх раз в год; Google — по квоте).
///
/// - экран спокоен: приложение на переднем плане, главный экран сверху, нет
///   звонка, в этот запуск не было окна обновления.
///
/// Показать окно или нет, решает система — попытка засчитывается, только
/// если система приняла просьбу. Любая ошибка проглатывается.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Выключатель всего окна оценки.
const bool kAppReviewPrompt = true;

/// `true` — просить и тех, кто пользовался приложением до этой версии.
const bool kAppReviewExistingUsers = false;

const Duration kAppReviewMinAge = Duration(days: 3);
const int kAppReviewMinLaunches = 5;
const Duration kAppReviewRepeatAfter = Duration(days: 120);
const int kAppReviewMaxRequests = 3;

/// Переписка старше этого при первом запуске — значит, аккаунт старый.
const Duration kAppReviewExistingUserAge = Duration(days: 3);

const String _kFirstSeen = 'app_review_first_seen_ms_v1';
const String _kExisting = 'app_review_existing_user_v1';
const String _kLaunches = 'app_review_launches_v1';
const String _kRequests = 'app_review_requests_v1';
const String _kLastRequest = 'app_review_last_request_ms_v1';

/// Состояние для решения (из настроек устройства).
@immutable
class AppReviewState {
  const AppReviewState({
    required this.firstSeenMs,
    required this.existingUser,
    required this.launches,
    required this.requests,
    required this.lastRequestMs,
  });

  final int firstSeenMs;
  final bool existingUser;
  final int launches;
  final int requests;
  final int lastRequestMs;
}

/// Можно ли попросить оценку сейчас (чистая функция — для тестов).
@visibleForTesting
bool appReviewDue(AppReviewState s, int nowMs) {
  if (!kAppReviewPrompt) return false;
  if (s.existingUser && !kAppReviewExistingUsers) return false;
  if (s.firstSeenMs <= 0 || nowMs - s.firstSeenMs < kAppReviewMinAge.inMilliseconds) {
    return false;
  }
  if (s.launches < kAppReviewMinLaunches) return false;
  if (s.requests >= kAppReviewMaxRequests) return false;
  if (s.requests > 0 &&
      nowMs - s.lastRequestMs < kAppReviewRepeatAfter.inMilliseconds) {
    return false;
  }
  return true;
}

class AppReviewPrompt {
  AppReviewPrompt._();

  static const MethodChannel _channel = MethodChannel('secretly/app_review');

  static bool _launchCounted = false;

  static bool get _phone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Запуск: один раз за процесс считает запуск, при самом первом —
  /// запоминает время и старый ли это аккаунт ([oldestMessageAtMs]).
  static Future<void> noteLaunch({
    required Future<bool> Function(int cutoffMs) hasMessagesBefore,
    int? nowMs,
  }) async {
    if (!_phone || _launchCounted) return;
    // Процесс, поднятый в фоне (пуш, звонок), — не запуск человеком.
    if (!_foreground) return;
    _launchCounted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      if (prefs.getInt(_kFirstSeen) == null) {
        final existing = await hasMessagesBefore(
          now - kAppReviewExistingUserAge.inMilliseconds,
        );
        await prefs.setBool(_kExisting, existing);
        await prefs.setInt(_kFirstSeen, now);
      }
      await prefs.setInt(_kLaunches, (prefs.getInt(_kLaunches) ?? 0) + 1);
    } catch (_) {}
  }

  static bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Попросить оценку, если пора. Возвращает `true`, если система приняла
  /// просьбу. [screenCalm] — экран спокоен (главный экран сверху, нет
  /// звонка); иначе не просим и попытку не тратим.
  static Future<bool> maybeRequest({
    int? nowMs,
    bool Function()? screenCalm,
  }) async {
    if (!_phone || !_foreground) return false;
    if (screenCalm != null && !screenCalm()) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      final state = AppReviewState(
        firstSeenMs: prefs.getInt(_kFirstSeen) ?? 0,
        existingUser: prefs.getBool(_kExisting) ?? true,
        launches: prefs.getInt(_kLaunches) ?? 0,
        requests: prefs.getInt(_kRequests) ?? 0,
        lastRequestMs: prefs.getInt(_kLastRequest) ?? 0,
      );
      if (!appReviewDue(state, now)) return false;
      final asked = await _channel.invokeMethod<bool>('request') ?? false;
      // Попытка считается, только если система приняла просьбу (на iPhone
      // без активной сцены — нет): иначе пропущенный раз съедал бы одну из
      // трёх попыток и паузу 120 дней.
      if (asked) {
        await prefs.setInt(_kRequests, state.requests + 1);
        await prefs.setInt(_kLastRequest, now);
      }
      return asked;
    } catch (e) {
      if (!kReleaseMode) debugPrint('AppReviewPrompt: пропущено ($e)');
      return false;
    }
  }

  @visibleForTesting
  static void debugReset() => _launchCounted = false;
}
