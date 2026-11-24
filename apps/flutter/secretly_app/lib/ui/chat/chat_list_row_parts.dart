// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Строка списка чатов по макету «Список чатов · по структуре Secretly» (3b,
/// 22.11.2026). Из макета взяты только сама строка и её поведение — время,
/// счётчики, галочки, черновик, звонок, вспышка при новом сообщении. Острова
/// сверху и снизу, папки и «Личные» не тронуты (слово владельца).
///
/// Одни и те же детали у вкладок «Чаты», «Комнаты» и «Личные»: раньше у
/// каждой была своя копия времени и счётчика, и они уже разошлись.
///
///  * Время — 13, цифры одной ширины, без плашки; акцентом, если есть новое:
///    «сейчас» · «4 мин» · «11:20» · «вчера» · «ср» · «12 окт» · «18.10.25».
///    Относительное («4 мин») само обновляется раз в 30 с — только у тех
///    строк, где оно показано.
///  * Счётчик — 20: новые — градиент кнопки отправки (iPhone) / `primary`
///    (Android); без звука — тональный; пропущенные звонки — красный с
///    трубкой. Появляется пружиной.
///  * Галочки — в начале превью, только у своего последнего сообщения и только
///    когда непрочитанных нет.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../calls/call_manager.dart';
import '../../calls/call_state.dart';
import '../../l10n/app_localizations.dart';
import '../icons/adaptive_icons.dart';
import '../theme_presets.dart' show ChatVisualsThemeExtension;

/// Выключатель новой строки (время, счётчики, галочки, черновик, звонок,
/// вспышка). `false` — прежняя строка (плашка времени, прежние счётчики).
const bool kChatListRowV2 = true;

// ─── Время ──────────────────────────────────────────────────────────────────

/// Подпись времени строки: «сейчас» · «4 мин» · «11:20» · «вчера» · «ср» ·
/// «12 окт» · «18.10.25». [now] — только для тестов.
String chatListTimeLabel(int ms, AppLocalizations l10n, {DateTime? now}) {
  if (ms <= 0) return '';
  final n = now ?? DateTime.now();
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final age = n.difference(dt);
  // Часы разошлись (время из будущего) — это «сейчас», а не завтрашний день.
  if (age.inSeconds < 60) return l10n.chatListTimeNow;
  if (age.inMinutes < 60) return l10n.chatListTimeMinutes(age.inMinutes);
  // Календарные даты в UTC: у UTC нет перевода часов, поэтому «вчера» и
  // день недели не съезжают на сутки в дни перехода (23/25-часовые сутки
  // давали 0 и 1 через local difference — разбор 22.11.2026).
  final today = DateTime.utc(n.year, n.month, n.day);
  final day = DateTime.utc(dt.year, dt.month, dt.day);
  String two(int v) => v.toString().padLeft(2, '0');
  if (day == today) return '${two(dt.hour)}:${two(dt.minute)}';
  final days = today.difference(day).inDays;
  if (days == 1) return l10n.desktopTimeYesterday;
  final locale = l10n.localeName;
  if (days < 7) return _safeFormat(DateFormat.E(locale), dt, two);
  if (dt.year == n.year) {
    // «12 окт» — месяц у intl: свой список пришлось бы вести на восьми языках.
    return _safeFormat(DateFormat.MMMd(locale), dt, two)
        .replaceAll('.', '')
        .trim();
  }
  return '${two(dt.day)}.${two(dt.month)}.${dt.year.toString().substring(2)}';
}

String _safeFormat(DateFormat f, DateTime dt, String Function(int) two) {
  try {
    return f.format(dt);
  } catch (_) {
    // Данные языка не загружены (тесты без initializeDateFormatting).
    return '${two(dt.day)}.${two(dt.month)}';
  }
}

/// Общие часы списков: тикают, только пока на экране есть «сейчас»/«N мин».
abstract final class _ListClock {
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);
  static int _users = 0;
  static Timer? _timer;

  static void attach() {
    if (_users++ == 0) {
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => tick.value++,
      );
    }
  }

  static void detach() {
    if (_users == 0) return;
    if (--_users == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Одни часы «полночь» на все строки: «11:20» становится «вчера», «вчера» —
/// днём недели, когда наступают новые сутки, без перестройки списка.
abstract final class _MidnightClock {
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);
  static int _users = 0;
  static Timer? _timer;

  static void _arm() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _timer = Timer(next.difference(now), () {
      tick.value++;
      if (_users > 0) _arm();
    });
  }

  static void attach() {
    if (_users++ == 0) _arm();
  }

  static void detach() {
    if (_users == 0) return;
    if (--_users == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Время строки: 13, цифры одной ширины, без плашки; акцентом, если есть
/// новое (и чат не без звука).
class ChatListTime extends StatefulWidget {
  const ChatListTime({super.key, required this.ms, this.highlight = false});

  final int ms;
  final bool highlight;

  @override
  State<ChatListTime> createState() => _ChatListTimeState();
}

class _ChatListTimeState extends State<ChatListTime> {
  bool _attached = false;

  bool get _relative =>
      widget.ms > 0 &&
      DateTime.now().millisecondsSinceEpoch - widget.ms < 3600 * 1000;

  void _sync() {
    final want = _relative;
    if (want == _attached) return;
    _attached = want;
    want ? _ListClock.attach() : _ListClock.detach();
  }

  @override
  void initState() {
    super.initState();
    _MidnightClock.attach();
    _sync();
  }

  @override
  void didUpdateWidget(ChatListTime old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _MidnightClock.detach();
    if (_attached) _ListClock.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final c = chatListColors(context);
    // Шрифт — из темы (иначе AnimatedDefaultTextStyle заменил бы его целиком).
    final base = DefaultTextStyle.of(context).style;
    Widget text() => AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: base.merge(TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: widget.highlight ? FontWeight.w600 : FontWeight.w400,
        color: widget.highlight ? c.accent : c.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      )),
      child: Text(chatListTimeLabel(widget.ms, l10n), maxLines: 1),
    );
    if (!_attached) {
      return ValueListenableBuilder<int>(
        valueListenable: _MidnightClock.tick,
        builder: (context, _, _) => text(),
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: _ListClock.tick,
      builder: (context, _, _) {
        // Час прошёл — дальше обычное «11:20», тиканье больше не нужно.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sync();
        });
        return text();
      },
    );
  }
}

// ─── Цвета ──────────────────────────────────────────────────────────────────

/// Цвета строки (тёмная — как в макете, светлая — из темы).
@immutable
class ChatListColors {
  const ChatListColors({
    required this.name,
    required this.previewOn,
    required this.previewOff,
    required this.muted,
    required this.accent,
    required this.badgeTop,
    required this.badgeBottom,
    required this.badgeFg,
    required this.badgeMuted,
    required this.badgeMutedFg,
    required this.missed,
    required this.flash,
    required this.online,
  });

  final Color name;
  final Color previewOn;
  final Color previewOff;
  final Color muted;
  final Color accent;
  final Color badgeTop;
  final Color badgeBottom;
  final Color badgeFg;
  final Color badgeMuted;
  final Color badgeMutedFg;
  final Color missed;
  final Color flash;
  final Color online;
}

bool _isIos() => defaultTargetPlatform == TargetPlatform.iOS;

ChatListColors chatListColors(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  final v = theme.extension<ChatVisualsThemeExtension>();
  final ios = _isIos();
  // Акцент текста: в тёмной теме — светлее основного цвета, чтобы мелкое
  // время и «Пишет» читались на тёмном фоне.
  final accent = dark ? Color.lerp(cs.primary, Colors.white, .32)! : cs.primary;
  return ChatListColors(
    name: cs.onSurface,
    previewOn: dark
        ? cs.onSurface.withValues(alpha: .86)
        : cs.onSurface.withValues(alpha: .80),
    previewOff: cs.onSurfaceVariant.withValues(alpha: dark ? .86 : .92),
    muted: cs.onSurfaceVariant.withValues(alpha: dark ? .80 : .85),
    accent: accent,
    badgeTop: ios ? (v?.actionTop ?? cs.primary) : cs.primary,
    badgeBottom: ios ? (v?.actionBottom ?? cs.primary) : cs.primary,
    badgeFg: ios ? Colors.white : cs.onPrimary,
    badgeMuted: dark
        ? Colors.white.withValues(alpha: .16)
        : cs.onSurface.withValues(alpha: .14),
    badgeMutedFg: dark ? const Color(0xFFDDE4EA) : cs.onSurface.withValues(alpha: .78),
    missed: const Color(0xFFE5484D),
    flash: accent.withValues(alpha: dark ? .10 : .08),
    online: const Color(0xFF3DD68C),
  );
}

// ─── Счётчики ───────────────────────────────────────────────────────────────

/// Счётчик новых: 20, 12/700, цифры одной ширины; без звука — тональный.
class ChatListUnreadBadge extends StatelessWidget {
  const ChatListUnreadBadge({
    super.key,
    required this.count,
    this.muted = false,
  });

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = chatListColors(context);
    final label = count > 99 ? '99+' : '$count';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: muted ? c.badgeMuted : null,
        gradient: muted
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.badgeTop, c.badgeBottom],
              ),
      ),
      // Крупный шрифт: цифры растут не больше чем в 1,3 раза — иначе
      // вылезали из капсулы высотой 20 (разбор 22.11.2026).
      child: Text(
        label,
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context).clamp(
          maxScaleFactor: 1.3,
        ),
        style: TextStyle(
          color: muted ? c.badgeMutedFg : c.badgeFg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Пропущенные звонки: красный, трубка и число.
class ChatListMissedCallBadge extends StatelessWidget {
  const ChatListMissedCallBadge({super.key, required this.count});

  final int count;

  static const IconData _icon = AdaptiveIconData(
    Icons.call_missed_rounded,
    CupertinoIcons.phone_arrow_down_left,
  );

  @override
  Widget build(BuildContext context) {
    final c = chatListColors(context);
    final label = count > 99 ? '99+' : '$count';
    return Container(
      height: 20,
      padding: const EdgeInsets.fromLTRB(5, 0, 7, 0),
      decoration: BoxDecoration(
        color: c.missed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(_icon, size: 13, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Булавка закреплённого чата у времени: 14, повёрнута на 45°.
class ChatListPinGlyph extends StatelessWidget {
  const ChatListPinGlyph({super.key});

  static const IconData _icon = AdaptiveIconData(
    Icons.push_pin_rounded,
    CupertinoIcons.pin_fill,
  );

  @override
  Widget build(BuildContext context) {
    final c = chatListColors(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Transform.rotate(
        angle: _isIos() ? 0 : .785,
        child: Icon(_icon, size: 14, color: c.muted),
      ),
    );
  }
}

// ─── Галочки ────────────────────────────────────────────────────────────────

enum ChatListTick { none, sent, delivered, read }

/// Галочка в начале превью: одна — отправлено, две — доставлено (серые),
/// две акцентом — прочитано.
class ChatListTickGlyph extends StatelessWidget {
  const ChatListTickGlyph({super.key, required this.tick});

  final ChatListTick tick;

  @override
  Widget build(BuildContext context) {
    if (tick == ChatListTick.none) return const SizedBox.shrink();
    final c = chatListColors(context);
    final read = tick == ChatListTick.read;
    final color = read ? c.accent : c.muted;
    // iPhone — галочки Apple (SF): у Cupertino нет двойной, поэтому две
    // одинарные со сдвигом, как в «Сообщениях»/Telegram iOS.
    if (_isIos()) {
      const check = CupertinoIcons.checkmark_alt;
      return Padding(
        key: ValueKey<ChatListTick>(tick),
        padding: const EdgeInsets.only(right: 3),
        child: tick == ChatListTick.sent
            ? Icon(check, size: 16, color: color)
            : SizedBox(
                width: 21,
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      child: Icon(check, size: 16, color: color),
                    ),
                    Positioned(
                      left: 5,
                      child: Icon(check, size: 16, color: color),
                    ),
                  ],
                ),
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Icon(
        tick == ChatListTick.sent ? Icons.done_rounded : Icons.done_all_rounded,
        key: ValueKey<ChatListTick>(tick),
        size: 17,
        color: color,
      ),
    );
  }
}

// ─── Черновики ──────────────────────────────────────────────────────────────

/// Неотправленный текст чатов — тот же, что поле ввода сохраняет при выходе
/// из чата (`chat_draft_v1_<id>` в настройках телефона). Список читает его
/// один раз и дальше узнаёт об изменениях от экрана чата.
abstract final class ChatListDrafts {
  static const String prefix = 'chat_draft_v1_';
  static final ValueNotifier<Map<String, String>> drafts =
      ValueNotifier<Map<String, String>>(const <String, String>{});
  static bool _loading = false;

  static Future<void> ensureLoaded() async {
    if (_loading) return;
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = <String, String>{};
      for (final k in prefs.getKeys()) {
        if (!k.startsWith(prefix)) continue;
        final v = prefs.get(k);
        if (v is String && v.trim().isNotEmpty) {
          next[k.substring(prefix.length)] = v;
        }
      }
      // Пока читали, экран чата мог уже сообщить свежее — оно важнее.
      drafts.value = <String, String>{...next, ...drafts.value};
    } catch (_) {
      // Нет хранилища (тесты) — без черновиков.
    }
  }

  /// Экран чата сохранил / стёр черновик.
  static void set(String convoId, String? text) {
    final id = convoId.trim();
    if (id.isEmpty) return;
    final t = (text ?? '').trim();
    final cur = drafts.value;
    if (t.isEmpty ? !cur.containsKey(id) : cur[id] == text) return;
    final next = Map<String, String>.of(cur);
    if (t.isEmpty) {
      next.remove(id);
    } else {
      next[id] = text!;
    }
    drafts.value = next;
  }
}

/// «Черновик: …» вместо превью, пока в чате лежит неотправленный текст.
class ChatListDraftLine extends StatelessWidget {
  const ChatListDraftLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = chatListColors(context);
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: l10n.desktopListDraftPrefix,
            style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: oneLine, style: TextStyle(color: c.previewOff)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14.5),
    );
  }
}

// ─── Звонок ─────────────────────────────────────────────────────────────────

/// Идёт звонок с этим человеком: зелёная трубка, «Идёт звонок · 01:23»
/// (секунды тикают только у этой строки). `null` — звонка с ним нет.
class ChatListActiveCallLine extends StatefulWidget {
  const ChatListActiveCallLine({
    super.key,
    required this.peerProfileId,
    required this.fallback,
  });

  final String peerProfileId;
  final Widget fallback;

  @override
  State<ChatListActiveCallLine> createState() => _ChatListActiveCallLineState();
}

class _ChatListActiveCallLineState extends State<ChatListActiveCallLine> {
  Timer? _timer;

  static bool _live(CallState s, String peer) =>
      peer.isNotEmpty &&
      s.peerProfileId == peer &&
      (s.phase == CallPhase.connected ||
          s.phase == CallPhase.connecting ||
          s.phase == CallPhase.reconnecting ||
          s.phase == CallPhase.ringingOutgoing ||
          s.phase == CallPhase.ringingIncoming);

  void _syncTimer(bool on) {
    if (on && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!on && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = CallManager.instance;
    if (manager == null) return widget.fallback;
    return ValueListenableBuilder<CallState>(
      valueListenable: manager.state,
      builder: (context, s, _) {
        final live = _live(s, widget.peerProfileId.trim());
        final connected = live && s.phase == CallPhase.connected;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncTimer(connected && s.connectedAtMs != null);
        });
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          child: live
              ? KeyedSubtree(
                  key: const ValueKey('call'),
                  child: _line(context, s, connected),
                )
              : KeyedSubtree(
                  key: const ValueKey('preview'),
                  child: widget.fallback,
                ),
        );
      },
    );
  }

  Widget _line(BuildContext context, CallState s, bool connected) {
    final l10n = AppLocalizations.of(context)!;
    const green = Color(0xFF34C759);
    // Пока только звонит — «Звонок…», «Идёт звонок · 01:23» — с соединения
    // (разбор 22.11.2026).
    final ringing =
        s.phase == CallPhase.ringingOutgoing ||
        s.phase == CallPhase.ringingIncoming ||
        (s.phase == CallPhase.connecting && s.connectedAtMs == null);
    var label = ringing ? l10n.chatListCallRinging : l10n.chatListCallInProgress;
    final at = s.connectedAtMs;
    if (connected && at != null) {
      final sec = ((DateTime.now().millisecondsSinceEpoch - at) / 1000)
          .floor()
          .clamp(0, 359999);
      final mm = (sec ~/ 60).toString().padLeft(2, '0');
      final ss = (sec % 60).toString().padLeft(2, '0');
      label = '$label · $mm:$ss';
    }
    return Row(
      children: [
        Icon(
          s.isVideo
              ? const AdaptiveIconData(
                  Icons.videocam_rounded,
                  CupertinoIcons.video_camera_solid,
                )
              : const AdaptiveIconData(
                  Icons.phone_in_talk_rounded,
                  CupertinoIcons.phone_fill,
                ),
          size: 16,
          color: green,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: green,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Вспышка ────────────────────────────────────────────────────────────────

/// Пришло новое сообщение — строка коротко подсвечивается (0,9 с), пока
/// поднимается наверх. Первое появление строки — без вспышки.
class ChatListRowFlash extends StatefulWidget {
  const ChatListRowFlash({
    super.key,
    required this.stamp,
    required this.unread,
    required this.child,
  });

  /// Время последнего события строки.
  final int stamp;
  final int unread;
  final Widget child;

  @override
  State<ChatListRowFlash> createState() => _ChatListRowFlashState();
}

class _ChatListRowFlashState extends State<ChatListRowFlash>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didUpdateWidget(ChatListRowFlash old) {
    super.didUpdateWidget(old);
    if (widget.stamp > old.stamp && widget.unread > old.unread) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      final c = _c ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..addListener(() => setState(() {}));
      c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    var k = 0.0;
    if (c != null && c.isAnimating) {
      final t = c.value;
      // Быстро вспыхивает (15 %) и плавно гаснет.
      k = t < .15
          ? t / .15
          : 1 - Curves.easeOutCubic.transform((t - .15) / .85);
    }
    // Обёртка есть всегда: появись она только на время вспышки — строка
    // под ней пересоздалась бы и потеряла своё состояние.
    final color = chatListColors(context).flash;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: k <= 0 ? Colors.transparent : color.withValues(alpha: color.a * k),
      ),
      child: widget.child,
    );
  }
}

// ─── Вторая строка ──────────────────────────────────────────────────────────

/// Вторая строка чата (макет 3b), одна на все три списка: идёт звонок с
/// этим человеком → «Звонок…» / «Идёт звонок · 01:23»; есть неотправленный
/// текст → «Черновик: …»; иначе [preview]. [draftKey] — тот же ключ, что у
/// экрана чата (у 1:1 — профиль собеседника, у комнаты и запроса — id
/// беседы). [peerProfileId] — `null` у комнат и запросов (звонка нет).
class ChatListRowSubtitle extends StatelessWidget {
  const ChatListRowSubtitle({
    super.key,
    required this.draftKey,
    required this.preview,
    this.peerProfileId,
    this.showDraft = true,
  });

  final String draftKey;
  final String? peerProfileId;
  final bool showDraft;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    if (!kChatListRowV2) return preview;
    Widget line = !showDraft
        ? preview
        : ValueListenableBuilder<Map<String, String>>(
            valueListenable: ChatListDrafts.drafts,
            child: preview,
            builder: (context, drafts, preview) {
              final draft = drafts[draftKey];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: draft == null
                    ? KeyedSubtree(
                        key: const ValueKey('preview'),
                        child: preview!,
                      )
                    : ChatListDraftLine(
                        key: const ValueKey('draft'),
                        text: draft,
                      ),
              );
            },
          );
    final peer = peerProfileId?.trim() ?? '';
    if (peer.isNotEmpty) {
      line = ChatListActiveCallLine(peerProfileId: peer, fallback: line);
    }
    return line;
  }
}

