// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Общесистемное «показать Secretly» — ⌥⌘S.
///
/// 🔴 ВЫКЛЮЧЕНО ПО УМОЛЧАНИЮ, И ЭТО НЕ ОСТОРОЖНОСТЬ РАДИ ОСТОРОЖНОСТИ.
/// Сочетание общесистемное: включив его молча, мы отняли бы комбинацию у
/// программы, которой человек пользуется, и он не понял бы, кто её забрал.
///
/// 🔴 НЕ ТРЕБУЕТ «УНИВЕРСАЛЬНОГО ДОСТУПА». Нативная часть регистрирует ОДНО
/// сочетание у системы (`RegisterEventHotKey`), а не следит за всеми нажатиями.
/// Мессенджер, просящий право читать любой набранный текст, противоречил бы сам
/// себе — см. шапку `macos/Runner/GlobalHotKeyBridge.swift`.
class DesktopGlobalHotKeyService {
  DesktopGlobalHotKeyService({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting bool? onMacOS,
  }) : _channel = channel ?? const MethodChannel('secretly/global_hotkey'),
       _onMacOS = onMacOS;

  /// 🔴 ОДИН НА ПРИЛОЖЕНИЕ (01.10.2026). Раньше единственный экземпляр
  /// создавал раздел «Горячие клавиши», и `load()` звучал только там: включённое
  /// ⌥⌘S после перезапуска молчало, пока человек не откроет этот раздел, — то
  /// есть переключатель показывал «вкл», а сочетание не работало. Теперь
  /// экземпляр общий: `main_desktop.dart` загружает его при запуске, раздел
  /// берёт тот же самый и не освобождает его, уходя.
  static final DesktopGlobalHotKeyService instance =
      DesktopGlobalHotKeyService();

  /// 🔴 Площадка подменяема ТОЛЬКО ради проверок — см. значок в Dock рядом.
  final bool? _onMacOS;

  static const String _prefsKey = 'desktop_global_hotkey_v1';

  final MethodChannel _channel;

  /// Включено ли сейчас. Отдельно от «получилось ли включить»: сочетание мог
  /// занять кто-то другой, и тогда переключатель обязан вернуться обратно, а не
  /// делать вид, что всё хорошо.
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  /// Не удалось занять сочетание — его держит другая программа.
  final ValueNotifier<bool> taken = ValueNotifier<bool>(false);

  bool get supported => _onMacOS ?? (!kIsWeb && Platform.isMacOS);

  Future<void>? _loading;

  /// Прочитать сохранённый выбор и, если сочетание было включено, занять его
  /// снова. Повторный вызов отдаёт ту же загрузку: запуск и раздел настроек
  /// вызывают его оба, а регистрировать сочетание дважды незачем.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (!supported) return;
    var want = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      want = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      // Настройки могли не открыться — значит выключено, как по умолчанию.
    }
    if (want) await setEnabled(true, persist: false);
  }

  Future<bool> setEnabled(bool value, {bool persist = true}) async {
    if (!supported) return false;
    var ok = false;
    try {
      ok = await _channel.invokeMethod<bool>(
            'setEnabled',
            <String, dynamic>{'enabled': value},
          ) ??
          false;
    } catch (_) {
      ok = false;
    }
    // Выключение считается удавшимся всегда: нечего держать — значит и снимать
    // нечего, и запирать переключатель во включённом состоянии было бы ложью.
    final applied = value ? ok : true;
    enabled.value = value && applied;
    taken.value = value && !applied;
    if (persist && applied) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKey, enabled.value);
      } catch (_) {
        // В памяти уже применено; просто не переживёт перезапуск.
      }
    }
    return applied;
  }

  void dispose() {
    enabled.dispose();
    taken.dispose();
  }
}
