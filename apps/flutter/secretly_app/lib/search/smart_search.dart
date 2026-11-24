// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Общий поиск главного экрана (острова v3, 20.11.2026): один запрос — чаты,
/// комнаты и контакты сразу.
///
/// Всё считается на устройстве, по уже расшифрованным названиям: на сервер
/// запрос не уходит никогда.
///
/// Что умеет, кроме «название содержит строку»:
/// * начала слов в любом порядке: «орл мир» → «Мира Орлова»;
/// * инициалы: «мо» → «Мира Орлова»;
/// * забытая раскладка: «ghbdtn» → «привет», «руддщ» → «hello»;
/// * транслит в обе стороны: «ivan» → «Иван», «иван» → «Ivan»;
/// * ё/е, й/и, ї/і, є/е, ґ/г и акценты (é → e);
/// * одна опечатка в слове от 4 букв: «олек» → «Олег»;
/// * @ник и ID профиля.
///
/// Порядок: качество совпадения, затем живость — непрочитанное, закреплённое,
/// давность последнего сообщения, недавно открытое из поиска.
library;

import 'dart:math' as math;

/// Что нашлось.
enum SmartSearchKind { chat, room, contact }

/// Строка, по которой ищем.
class SmartSearchItem {
  const SmartSearchItem({
    required this.id,
    required this.kind,
    required this.title,
    this.handle,
    this.lastActivityMs = 0,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
  });

  /// convoId для чата и комнаты, profileId для контакта.
  final String id;
  final SmartSearchKind kind;
  final String title;

  /// @ник / ID профиля — ищется, но слабее названия.
  final String? handle;
  final int lastActivityMs;
  final int unread;
  final bool pinned;
  final bool muted;
}

/// Найденное: строка, оценка и где подсветить совпадение в названии.
class SmartSearchHit {
  const SmartSearchHit({
    required this.item,
    required this.score,
    this.highlightStart,
    this.highlightEnd,
  });

  final SmartSearchItem item;
  final double score;

  /// Полуинтервал в ИСХОДНОМ названии; `null` — подсвечивать нечего
  /// (совпало через раскладку, транслит или по нику).
  final int? highlightStart;
  final int? highlightEnd;
}

/// Запрос, разобранный один раз на все строки.
class SmartQuery {
  SmartQuery._(this.raw, this.direct, this.variants);

  factory SmartQuery.parse(String raw) {
    final direct = SmartSearch.normalize(raw);
    final variants = <({String text, double weight})>[];
    void add(String v, double w) {
      if (v.isEmpty || v == direct) return;
      if (variants.any((e) => e.text == v)) return;
      variants.add((text: v, weight: w));
    }

    add(SmartSearch.normalize(SmartSearch.swapLayout(raw)), 0.88);
    add(SmartSearch.translitToLatin(direct), 0.92);
    return SmartQuery._(raw, direct, variants);
  }

  final String raw;

  /// Запрос как набран, нормализованный.
  final String direct;

  /// Другие прочтения: другая раскладка, транслит.
  final List<({String text, double weight})> variants;

  bool get isEmpty => direct.isEmpty;
}

abstract final class SmartSearch {
  /// Минимальная оценка, ниже которой строка не показывается.
  static const double minScore = 30;

  /// Найти и упорядочить. [boostKind] — раздел, из которого начат поиск: его
  /// строки при равенстве идут выше. [recentIds] — открытые из поиска
  /// недавно, от свежего к старому.
  static List<SmartSearchHit> run(
    Iterable<SmartSearchItem> items,
    String rawQuery, {
    SmartSearchKind? boostKind,
    List<String> recentIds = const <String>[],
    int? nowMs,
  }) {
    final q = SmartQuery.parse(rawQuery);
    if (q.isEmpty) return const <SmartSearchHit>[];
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final hits = <SmartSearchHit>[];
    for (final item in items) {
      final hit = match(item, q);
      if (hit == null) continue;
      hits.add(
        SmartSearchHit(
          item: item,
          score: hit.score +
              _liveliness(item, now) +
              _recentBoost(item.id, recentIds) +
              (boostKind == item.kind ? 3 : 0),
          highlightStart: hit.highlightStart,
          highlightEnd: hit.highlightEnd,
        ),
      );
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.item.lastActivityMs.compareTo(a.item.lastActivityMs);
    });
    return hits;
  }

  /// Оценка совпадения одной строки (без живости); `null` — не подходит.
  static SmartSearchHit? match(SmartSearchItem item, SmartQuery q) {
    final title = normalize(item.title);
    final titleLatin = translitToLatin(title);
    final handle = normalize(item.handle ?? '');

    SmartSearchHit? best;
    void consider(double score, {int? start, int? end}) {
      if (score < minScore) return;
      if (best != null && best!.score >= score) return;
      best = SmartSearchHit(
        item: item,
        score: score,
        highlightStart: start,
        highlightEnd: end,
      );
    }

    // Как набрано — с подсветкой.
    final directScore = _scoreText(title, q.direct);
    if (directScore != null) {
      final range = _highlight(item.title, title, q.direct);
      consider(directScore, start: range?.$1, end: range?.$2);
    }
    // Латиница против латиницы: «ivan» ↔ «Иван», «иван» ↔ «Ivan».
    if (titleLatin != title) {
      final s = _scoreText(titleLatin, q.direct);
      if (s != null) consider(s * 0.92);
    }
    for (final v in q.variants) {
      final s1 = _scoreText(title, v.text);
      if (s1 != null) consider(s1 * v.weight);
      if (titleLatin != title) {
        final s2 = _scoreText(titleLatin, v.text);
        if (s2 != null) consider(s2 * v.weight * 0.95);
      }
    }
    // Ник / ID — слабее названия.
    if (handle.isNotEmpty) {
      final compact = q.direct.replaceAll(' ', '');
      if (compact.isNotEmpty) {
        if (handle == compact) {
          consider(72);
        } else if (handle.startsWith(compact)) {
          consider(64);
        } else if (compact.length >= 3 && handle.contains(compact)) {
          consider(44);
        }
      }
    }
    return best;
  }

  /// Оценка «насколько [query] похож на [text]», обе строки нормализованы.
  static double? _scoreText(String text, String query) {
    if (text.isEmpty || query.isEmpty) return null;
    if (text == query) return 100;
    if (text.startsWith(query)) return 90;

    final words = _words(text);
    final qWords = _words(query);
    if (qWords.isEmpty) return null;

    // Каждое слово запроса — начало своего слова в названии, в любом порядке.
    if (_allWordsPrefix(words, qWords)) {
      return qWords.length > 1 ? 84 : 78;
    }
    // Инициалы: «мо» → «Мира Орлова», «ак» → «Алексей Ким».
    if (qWords.length == 1 && words.length >= 2) {
      final q = qWords.first;
      if (q.length >= 2 && q.length <= words.length) {
        final initials = words.map((w) => w[0]).join();
        if (initials.startsWith(q)) return 70;
      }
    }
    // Подстрока.
    if (query.length >= 2 && text.contains(query)) return 52;
    // Одна опечатка в слове (от 4 букв): «олек» → «Олег».
    if (qWords.length == 1 && qWords.first.length >= 4) {
      final q = qWords.first;
      for (final w in words) {
        if (w.length + 1 < q.length) continue;
        final head = w.length > q.length ? w.substring(0, q.length) : w;
        if (_withinOneEdit(head, q)) return 38;
      }
    }
    return null;
  }

  static bool _allWordsPrefix(List<String> words, List<String> qWords) {
    final used = List<bool>.filled(words.length, false);
    for (final q in qWords) {
      var found = false;
      for (var i = 0; i < words.length; i++) {
        if (used[i]) continue;
        if (words[i].startsWith(q)) {
          used[i] = true;
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }

  /// Расстояние Дамерау–Левенштейна не больше 1.
  static bool _withinOneEdit(String a, String b) {
    if (a == b) return true;
    final la = a.length, lb = b.length;
    if ((la - lb).abs() > 1) return false;
    var i = 0;
    while (i < la && i < lb && a[i] == b[i]) {
      i++;
    }
    if (la == lb) {
      // Замена или перестановка соседних.
      if (a.substring(i + 1) == b.substring(i + 1)) return true;
      return i + 1 < la &&
          a[i] == b[i + 1] &&
          a[i + 1] == b[i] &&
          a.substring(i + 2) == b.substring(i + 2);
    }
    // Вставка/удаление.
    return la > lb
        ? a.substring(i + 1) == b.substring(i)
        : a.substring(i) == b.substring(i + 1);
  }

  static List<String> _words(String s) =>
      s.split(' ').where((w) => w.isNotEmpty).toList(growable: false);

  /// Где в исходном названии подсветить. Только когда нормализация не
  /// поменяла длину (иначе индексы разъедутся).
  static (int, int)? _highlight(String original, String norm, String query) {
    if (original.length != norm.length || query.isEmpty) return null;
    var at = norm.startsWith(query) ? 0 : -1;
    if (at < 0) {
      // Начало слова точнее, чем середина.
      final wordStart = norm.indexOf(' $query');
      at = wordStart >= 0 ? wordStart + 1 : norm.indexOf(query);
    }
    if (at < 0) {
      // Первое слово запроса — начало какого-то слова.
      final first = query.split(' ').first;
      if (first.isEmpty) return null;
      if (norm.startsWith(first)) {
        at = 0;
      } else {
        final w = norm.indexOf(' $first');
        if (w < 0) return null;
        at = w + 1;
      }
      return (at, at + first.length);
    }
    return (at, at + query.length);
  }

  /// Живость: непрочитанное, закреплённое, свежее. Не перебивает качество
  /// совпадения — максимум ~12 баллов против десятков между уровнями.
  static double _liveliness(SmartSearchItem item, int nowMs) {
    var s = 0.0;
    if (item.unread > 0 && !item.muted) s += 4;
    if (item.pinned) s += 3;
    if (item.lastActivityMs > 0) {
      final days = math.max(0, nowMs - item.lastActivityMs) / 86400000.0;
      s += 5 * math.exp(-days / 14);
    }
    return s;
  }

  static double _recentBoost(String id, List<String> recentIds) {
    final i = recentIds.indexOf(id);
    if (i < 0) return 0;
    return math.max(2, 8 - i).toDouble();
  }

  // ── Нормализация ─────────────────────────────────────────────────────────

  static const Map<String, String> _fold = {
    'ё': 'е', 'й': 'и', 'ї': 'і', 'є': 'е', 'ґ': 'г', 'ў': 'у', //
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'ą': 'a', 'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'è': 'e', 'é': 'e',
    'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e', 'ğ': 'g', 'ì': 'i',
    'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i', 'ł': 'l', 'ñ': 'n',
    'ń': 'n', 'ň': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ø': 'o', 'ō': 'o', 'ő': 'o', 'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's',
    'ť': 't', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u',
    'ű': 'u', 'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z', 'ß': 'ss',
    '’': '', '\'': '', 'ʼ': '', '`': '',
  };

  /// Нижний регистр, ё/е и родственники, без акцентов и знаков, одиночные
  /// пробелы, без ведущего @.
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final out = StringBuffer();
    var lastSpace = true;
    for (final rune in lower.runes) {
      var ch = String.fromCharCode(rune);
      ch = _fold[ch] ?? ch;
      if (ch.isEmpty) continue;
      final isWordChar = ch.length > 1 || _isLetterOrDigit(rune, ch);
      if (!isWordChar) {
        if (!lastSpace) {
          out.write(' ');
          lastSpace = true;
        }
        continue;
      }
      out.write(ch);
      lastSpace = false;
    }
    return out.toString().trim();
  }

  static bool _isLetterOrDigit(int rune, String ch) {
    if (rune >= 0x30 && rune <= 0x39) return true; // 0-9
    if (ch.toUpperCase() != ch.toLowerCase()) return true; // буква с регистром
    // Знаки и типографика (тире, кавычки, стрелки, «・») — разделители.
    if (rune >= 0x2000 && rune <= 0x2BFF) return false;
    if (rune >= 0x3000 && rune <= 0x303F) return false;
    // Буквы без регистра (иероглифы, арабский…) и эмодзи считаем «словом»:
    // по ним тоже ищут.
    return rune > 0x2FF;
  }

  // ── Раскладка ────────────────────────────────────────────────────────────

  static const String _latinKeys = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`";
  static const String _cyrKeys = 'йцукенгшщзхъфывапролджэячсмитьбюё';

  /// Тот же ряд клавиш в другой раскладке: «ghbdtn» ↔ «привет».
  static String swapLayout(String input) {
    final lower = input.toLowerCase();
    final latinCount = lower.runes.where((r) => r >= 0x61 && r <= 0x7A).length;
    final cyrCount = lower.runes.where((r) => r >= 0x430 && r <= 0x44F).length;
    final toCyr = latinCount >= cyrCount;
    final from = toCyr ? _latinKeys : _cyrKeys;
    final to = toCyr ? _cyrKeys : _latinKeys;
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out.toString();
  }

  // ── Транслит ─────────────────────────────────────────────────────────────

  static const Map<String, String> _translit = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'zh',
    'з': 'z', 'и': 'i', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o',
    'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'h',
    'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '',
    'э': 'e', 'ю': 'yu', 'я': 'ya', 'і': 'i',
  };

  /// Кириллица латиницей (по нормализованной строке): «иван» → «ivan».
  static String translitToLatin(String normalized) {
    if (!normalized.runes.any((r) => r >= 0x400 && r <= 0x4FF)) {
      return normalized;
    }
    final out = StringBuffer();
    for (final rune in normalized.runes) {
      final ch = String.fromCharCode(rune);
      out.write(_translit[ch] ?? ch);
    }
    return out.toString();
  }
}
