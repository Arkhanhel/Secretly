// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../models/e2e_payload_v1.dart';
import '../../chat_message_mentions.dart';

/// Упоминания в комнате: из чего десктоп собирает `@имя` и как превращает
/// набранный текст в разметку протокола.
///
/// 🔴 ДЕСКТОП УМЕЛ ПОКАЗЫВАТЬ УПОМИНАНИЯ, НО НЕ УМЕЛ ИХ СТАВИТЬ.
///
/// Пузырь подсвечивает обращение, строка списка ставит сиренево-розовый
/// счётчик, уведомление приходит — всё это работает на ВХОД. А на выход
/// `sendGroupMessage` вызывался без `mentions`: набранное на компьютере
/// «@Игорь, посмотри» уходило обычным текстом. У получателя — ни подсветки, ни
/// значка, ни уведомления; человек, которого позвали с компьютера, об этом не
/// узнавал.
///
/// Разбор и сборка разметки — общие с телефоном
/// (`resolveChatMessageMentions` в `lib/ui/chat_message_mentions.dart`), то
/// есть смещения и правила границ совпадают по определению.

/// Имя-ярлык для `@`: пробелы в подчёркивания, знаки препинания прочь.
///
/// 🔴 ПРАВИЛО ПОВТОРЯЕТ `_sanitizeMentionHandle` ТЕЛЕФОНА
/// (`lib/ui/chat_screen.dart`) ЗНАК В ЗНАК, и это сознательная копия, а не
/// небрежность: тот метод приватный, а трогать выпущенный экран ради
/// извлечения четырёх строк — риск, несопоставимый с выигрышем.
///
/// Копия не должна разойтись с оригиналом: за этим следит
/// `test/desktop_mentions_test.dart` — он берёт регулярные выражения из
/// `chat_screen.dart` и сверяет их с этими.
String desktopMentionHandle(String raw) {
  final compact = raw.trim().replaceAll(RegExp(r'\s+'), '_');
  final stripped = compact.replaceAll(RegExp(r'[@.,!?;:()\[\]{}<>/]+'), '');
  final collapsed = stripped.replaceAll(RegExp(r'_+'), '_');
  return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Кого можно позвать: участник комнаты или все разом.
class DesktopMentionTarget {
  const DesktopMentionTarget.member({
    required this.token,
    required this.title,
    required this.profileId,
    this.avatarPath,
    this.subtitle,
  }) : type = MsgMentionV1.profileType;

  const DesktopMentionTarget.everyone({required this.token, this.subtitle})
    : type = MsgMentionV1.allType,
      title = 'Все участники',
      profileId = null,
      avatarPath = null;

  const DesktopMentionTarget.admins({required this.token, this.subtitle})
    : type = MsgMentionV1.adminsType,
      title = 'Администраторы',
      profileId = null,
      avatarPath = null;

  /// То, что попадёт в текст: «@Игорь», «@all».
  final String token;
  final String title;
  final String? subtitle;
  final String? profileId;
  final String? avatarPath;
  final String type;

  bool get isBroadcast => type != MsgMentionV1.profileType;

  ChatMentionCandidate get candidate =>
      ChatMentionCandidate(token: token, type: type, profileId: profileId);
}

/// Собирает список тех, кого можно позвать.
///
/// Одинаковые имена разводит суффиксом `_2`, `_3` — иначе два Игоря дали бы
/// один ярлык на двоих, и разметка встала бы не на того.
///
/// `@all` и `@admins` — впереди: ими зовут чаще всего, и в списке из тридцати
/// человек искать их прокруткой было бы странно. `@admins` даётся только
/// комнате, где администраторы вообще есть.
List<DesktopMentionTarget> desktopMentionTargets({
  required Iterable<({String profileId, String displayName, String? avatarPath, String? role})> members,
  required String selfProfileId,
  bool withAdmins = false,
}) {
  final out = <DesktopMentionTarget>[
    const DesktopMentionTarget.everyone(
      token: '@all',
      subtitle: 'Позвать всех в комнате',
    ),
    if (withAdmins)
      const DesktopMentionTarget.admins(
        token: '@admins',
        subtitle: 'Позвать владельца и администраторов',
      ),
  ];
  final used = <String>{'all', if (withAdmins) 'admins'};
  final self = selfProfileId.trim();
  for (final m in members) {
    // Себя звать незачем: уведомление придёт самому себе.
    if (self.isNotEmpty && m.profileId == self) continue;
    final base = () {
      final byName = desktopMentionHandle(m.displayName);
      if (byName.isNotEmpty) return byName;
      final byId = desktopMentionHandle(m.profileId);
      return byId.isEmpty ? 'member' : byId;
    }();
    var handle = base;
    var suffix = 2;
    while (used.contains(handle.toLowerCase())) {
      handle = '${base}_$suffix';
      suffix++;
    }
    used.add(handle.toLowerCase());
    out.add(
      DesktopMentionTarget.member(
        token: '@$handle',
        title: m.displayName.trim().isEmpty ? handle : m.displayName.trim(),
        subtitle: m.role,
        profileId: m.profileId,
        avatarPath: m.avatarPath,
      ),
    );
  }
  return out;
}

/// Набираемое сейчас `@…` под курсором.
class DesktopMentionDraft {
  const DesktopMentionDraft({
    required this.start,
    required this.end,
    required this.query,
  });

  /// Позиция самой «собачки».
  final int start;

  /// Конец набранного (он же курсор).
  final int end;

  /// Набранное ПОСЛЕ «собачки», без неё.
  final String query;
}

/// Ищет `@…` под курсором. `null` — человек сейчас пишет обычный текст.
///
/// Границы те же, что у разбора готового сообщения: «собачка» считается
/// началом упоминания, только если перед ней начало строки или разделитель, —
/// иначе адрес почты открывал бы список участников.
DesktopMentionDraft? desktopMentionDraft({
  required String text,
  required int caret,
}) {
  if (caret <= 0 || caret > text.length) return null;
  var scan = caret - 1;
  while (scan >= 0) {
    final ch = String.fromCharCode(text.codeUnitAt(scan));
    if (ch == '@') {
      if (scan > 0) {
        final before = String.fromCharCode(text.codeUnitAt(scan - 1));
        if (!isChatMentionBoundaryCharacter(before)) return null;
      }
      return DesktopMentionDraft(
        start: scan,
        end: caret,
        query: text.substring(scan + 1, caret),
      );
    }
    // Пробел обрывает поиск: `@` из прошлого слова к этому курсору отношения
    // не имеет. Внутри ярлыка пробелов не бывает — они стали подчёркиваниями.
    if (ch.trim().isEmpty) return null;
    scan--;
  }
  return null;
}

/// Отбирает подходящих под набранное. Пустой запрос — все, по порядку.
List<DesktopMentionTarget> desktopMentionMatches({
  required List<DesktopMentionTarget> targets,
  required String query,
  int limit = 8,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return targets.take(limit).toList(growable: false);
  final out = <DesktopMentionTarget>[];
  // Сперва те, у кого совпало НАЧАЛО: человек набирает первые буквы имени, и
  // «Игорь» на запрос «иг» должен стоять выше «Сергей_Игоревич».
  for (final t in targets) {
    if (t.token.substring(1).toLowerCase().startsWith(q) ||
        t.title.toLowerCase().startsWith(q)) {
      out.add(t);
    }
  }
  for (final t in targets) {
    if (out.contains(t)) continue;
    if (t.token.substring(1).toLowerCase().contains(q) ||
        t.title.toLowerCase().contains(q)) {
      out.add(t);
    }
  }
  return out.take(limit).toList(growable: false);
}

/// Готовая разметка для отправки. Пусто — звать некого или некому.
List<MsgMentionV1> desktopResolveMentions({
  required String text,
  required List<DesktopMentionTarget> targets,
}) {
  if (targets.isEmpty || !text.contains('@')) {
    return const <MsgMentionV1>[];
  }
  return resolveChatMessageMentions(
    text: text,
    candidates: targets.map((t) => t.candidate).toList(growable: false),
  );
}
