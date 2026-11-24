// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Переводчик: «на каком языке сообщение» — чистые правила без ML Kit
// (22.11.2026, Т-1).
//
// 🔴 ЖАЛОБА: «русский переводится на русский» — под русским сообщением
// появлялся пересказ того же текста. Причина: при уверенности распознавания
// русского ниже 0,6 выбирался «следующий кандидат» (обычно украинский или
// болгарский), и ML Kit честно переводил «украинский» → русский через
// английский. Авторежим шёл тем же путём, а при выбранном вручную языке
// «с какого» определение не запускалось вовсе.
//
// Теперь решение принимается по нескольким признакам: письменность текста,
// буквы, которые бывают только в одном восточнославянском языке, транслит
// («privet» = русский латиницей), языки-соседи (их распознаватель путает
// между собой) и разные пороги для авторежима и для нажатия человека.
// Выключатель — [kTranslationStrictSameLanguage].

/// Выключатель новых правил. false — прежний выбор (`pickSource`) и прежнее
/// поведение при выбранном языке оригинала.
const bool kTranslationStrictSameLanguage = true;

/// Письменность текста. Нужна только та точность, что помогает решить
/// «тот же язык или нет».
enum TextScript {
  none,
  latin,
  cyrillic,
  greek,
  arabic,
  hebrew,
  han,
  kana,
  hangul,
  devanagari,
  bengali,
  gujarati,
  kannada,
  tamil,
  telugu,
  thai,
  georgian,
  other,
}

/// Чем закончилось решение о языке оригинала.
enum SourceVerdict {
  /// Переводить с [SourceDecision.source].
  translate,

  /// Сообщение уже на языке перевода.
  sameLanguage,

  /// Язык не распознан (или авторежим не уверен — молча пропустить).
  undetected,
}

class SourceDecision {
  const SourceDecision._(this.verdict, this.source, this.reason);

  const SourceDecision.translate(String source, String reason)
    : this._(SourceVerdict.translate, source, reason);
  const SourceDecision.same(String reason)
    : this._(SourceVerdict.sameLanguage, null, reason);
  const SourceDecision.undetected(String reason)
    : this._(SourceVerdict.undetected, null, reason);

  final SourceVerdict verdict;
  final String? source;

  /// Короткое имя правила — только для журнала (без текста сообщения).
  final String reason;

  @override
  String toString() => 'SourceDecision($verdict, $source, $reason)';
}

abstract final class TranslationRules {
  /// Порог «уверенно на другом языке» для авторежима.
  static const double autoMinConfidence = 0.5;

  /// Язык перевода среди кандидатов с такой уверенностью — авторежим не
  /// переводит никогда, нажатие не берёт соседа.
  static const double targetPresentConfidence = 0.25;

  /// Запас уверенности над соседом языка перевода в авторежиме.
  static const double neighbourMargin = 0.2;

  /// Нажатие: «точно язык перевода».
  static const double userSureSame = 0.6;

  /// Нажатие: минимальная уверенность запасного кандидата.
  static const double userMinOther = 0.12;

  /// Совпадение набора слов, при котором перевод считается «тем же текстом».
  static const double unchangedOverlap = 0.8;

  /// Языки, которые распознаватель путает между собой.
  static const List<Set<String>> neighbourGroups = <Set<String>>[
    <String>{'ru', 'uk', 'be', 'bg', 'mk', 'sr'},
    <String>{'es', 'pt', 'gl', 'ca'},
    <String>{'cs', 'sk'},
    <String>{'da', 'no', 'sv'},
    <String>{'hr', 'sl'},
    <String>{'ms', 'id'},
  ];

  static String _base(String code) =>
      code.trim().toLowerCase().split(RegExp('[-_]')).first;

  static bool areNeighbours(String a, String b) {
    final x = _base(a);
    final y = _base(b);
    if (x == y) return false;
    for (final g in neighbourGroups) {
      if (g.contains(x) && g.contains(y)) return true;
    }
    return false;
  }

  /// Письменность, которой пишут язык [code] (для языков ML Kit).
  static TextScript scriptOfLanguage(String code) {
    switch (_base(code)) {
      case 'ru':
      case 'uk':
      case 'be':
      case 'bg':
      case 'mk':
      case 'sr':
        return TextScript.cyrillic;
      case 'el':
        return TextScript.greek;
      case 'ar':
      case 'fa':
      case 'ur':
        return TextScript.arabic;
      case 'he':
        return TextScript.hebrew;
      case 'zh':
        return TextScript.han;
      case 'ja':
        return TextScript.kana;
      case 'ko':
        return TextScript.hangul;
      case 'hi':
      case 'mr':
        return TextScript.devanagari;
      case 'bn':
        return TextScript.bengali;
      case 'gu':
        return TextScript.gujarati;
      case 'kn':
        return TextScript.kannada;
      case 'ta':
        return TextScript.tamil;
      case 'te':
        return TextScript.telugu;
      case 'th':
        return TextScript.thai;
      case 'ka':
        return TextScript.georgian;
      case '':
        return TextScript.none;
      default:
        return TextScript.latin;
    }
  }

  /// Письменность, которой пишет ровно один язык ML Kit, — этот язык.
  static String? uniqueLanguageOfScript(TextScript s) => switch (s) {
    TextScript.greek => 'el',
    TextScript.hebrew => 'he',
    TextScript.kana => 'ja',
    TextScript.hangul => 'ko',
    TextScript.bengali => 'bn',
    TextScript.gujarati => 'gu',
    TextScript.kannada => 'kn',
    TextScript.tamil => 'ta',
    TextScript.telugu => 'te',
    TextScript.thai => 'th',
    TextScript.georgian => 'ka',
    _ => null,
  };

  static TextScript _scriptOfRune(int r) {
    if ((r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0xC0 && r <= 0x24F && r != 0xD7 && r != 0xF7) ||
        (r >= 0x1E00 && r <= 0x1EFF)) {
      return TextScript.latin;
    }
    if ((r >= 0x400 && r <= 0x52F) || (r >= 0x1C80 && r <= 0x1C8F)) {
      return TextScript.cyrillic;
    }
    if (r >= 0x370 && r <= 0x3FF) return TextScript.greek;
    if ((r >= 0x600 && r <= 0x6FF) ||
        (r >= 0x750 && r <= 0x77F) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF)) {
      return TextScript.arabic;
    }
    if (r >= 0x590 && r <= 0x5FF) return TextScript.hebrew;
    if ((r >= 0x3040 && r <= 0x30FF) || (r >= 0x31F0 && r <= 0x31FF)) {
      return TextScript.kana;
    }
    if ((r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF)) {
      return TextScript.han;
    }
    if ((r >= 0xAC00 && r <= 0xD7AF) || (r >= 0x1100 && r <= 0x11FF)) {
      return TextScript.hangul;
    }
    if (r >= 0x900 && r <= 0x97F) return TextScript.devanagari;
    if (r >= 0x980 && r <= 0x9FF) return TextScript.bengali;
    if (r >= 0xA80 && r <= 0xAFF) return TextScript.gujarati;
    if (r >= 0xC80 && r <= 0xCFF) return TextScript.kannada;
    if (r >= 0xB80 && r <= 0xBFF) return TextScript.tamil;
    if (r >= 0xC00 && r <= 0xC7F) return TextScript.telugu;
    if (r >= 0xE00 && r <= 0xE7F) return TextScript.thai;
    if (r >= 0x10A0 && r <= 0x10FF) return TextScript.georgian;
    return TextScript.other;
  }

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// Письменность большинства букв текста. Японский: хоть одна кана среди
  /// иероглифов — это японский, а не китайский.
  static TextScript dominantScript(String text) {
    final counts = <TextScript, int>{};
    var letters = 0;
    for (final r in text.runes.take(2000)) {
      final ch = String.fromCharCode(r);
      if (!_letter.hasMatch(ch)) continue;
      letters++;
      final s = _scriptOfRune(r);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    if (letters == 0) return TextScript.none;
    if ((counts[TextScript.kana] ?? 0) > 0 &&
        (counts[TextScript.kana]! + (counts[TextScript.han] ?? 0)) * 2 >=
            letters) {
      return TextScript.kana;
    }
    TextScript best = TextScript.other;
    var bestCount = 0;
    counts.forEach((s, c) {
      if (c > bestCount) {
        best = s;
        bestCount = c;
      }
    });
    // Меньше половины букв — смесь, письменность не решает ничего.
    return bestCount * 2 > letters ? best : TextScript.other;
  }

  /// Язык по буквам, которые бывают только в одном восточнославянском языке:
  /// ў → белорусский; ї є ґ → украинский; і вместе с ы/э/ё → белорусский;
  /// і → украинский; ы э ё → русский. Противоречие (ї и ы сразу) — null.
  ///
  /// 🔴 «ъ» намеренно НЕ признак русского: в болгарском он встречается в
  /// каждой второй фразе («къде», «това е хубаво»), и болгарский текст
  /// записывался бы в «уже на русском».
  static String? eastSlavicHint(String text) {
    final t = text.toLowerCase();
    final be = t.contains('ў');
    final ukOnly = RegExp('[їєґ]').hasMatch(t);
    final iDot = t.contains('і');
    final ruLetters = RegExp('[ыэё]').hasMatch(t);
    if (be) return ukOnly ? null : 'be';
    if (ukOnly) return ruLetters ? null : 'uk';
    if (iDot) return ruLetters ? 'be' : 'uk';
    if (ruLetters) return 'ru';
    return null;
  }

  /// Выбор языка оригинала.
  ///
  /// [candidates] — всё, что вернул распознаватель, по убыванию уверенности,
  /// включая записи вида `ru-Latn` (транслит). [cleanedText] — текст без
  /// ссылок, эмодзи и упоминаний. [userInitiated] — человек нажал
  /// «перевести»; иначе это авторежим, и он переводит только то, в чём
  /// уверен. [pinnedSource] — язык «с какого», выбранный человеком.
  /// [supported] — умеет ли переводчик язык (по умолчанию — любой).
  static SourceDecision decideSource({
    required List<(String, double)> candidates,
    required String target,
    required String cleanedText,
    required bool userInitiated,
    String? pinnedSource,
    bool Function(String code)? supported,
  }) {
    final tgt = _base(target);
    final pinned = (pinnedSource ?? '').trim().isEmpty
        ? null
        : _base(pinnedSource!);
    bool isSupported(String c) => supported == null || supported(c);

    if (pinned != null && pinned == tgt) {
      return const SourceDecision.same('pinned_is_target');
    }

    // 1. Письменность.
    final script = dominantScript(cleanedText);
    final tgtScript = scriptOfLanguage(tgt);
    final uniq = uniqueLanguageOfScript(script);
    if (uniq != null && uniq == tgt) {
      return const SourceDecision.same('script_unique_target');
    }
    if (script == TextScript.han && tgt == 'zh') {
      return const SourceDecision.same('script_han_target');
    }

    // 2. Буквы восточнославянских языков.
    if (script == TextScript.cyrillic) {
      final hint = eastSlavicHint(cleanedText);
      if (hint != null) {
        if (hint == tgt) return const SourceDecision.same('letters_target');
        if (pinned == null || pinned == hint || userInitiated) {
          final src = (pinned != null && userInitiated) ? pinned : hint;
          if (isSupported(src)) {
            return SourceDecision.translate(src, 'letters');
          }
        }
        if (!userInitiated) {
          return const SourceDecision.undetected('letters_not_pinned');
        }
      }
    }

    // 3. Транслит и разбор кандидатов.
    final native = <(String, double)>[];
    var targetLatn = 0.0;
    String? topLatn;
    for (final c in candidates) {
      final tag = c.$1.trim();
      if (tag.isEmpty || tag == 'und') continue;
      if (tag.contains('-')) {
        final base = _base(tag);
        if (tag.toLowerCase().endsWith('-latn')) {
          if (base == tgt && c.$2 > targetLatn) targetLatn = c.$2;
          if (native.isEmpty && topLatn == null) topLatn = base;
        }
        continue;
      }
      if (!isSupported(_base(tag))) continue;
      native.add((_base(tag), c.$2));
    }
    native.sort((a, b) => b.$2.compareTo(a.$2));
    if (topLatn != null && topLatn == tgt) {
      return const SourceDecision.same('translit_target');
    }
    if (targetLatn >= targetPresentConfidence) {
      return const SourceDecision.same('translit_target_present');
    }
    if (topLatn != null && script == TextScript.latin) {
      // Транслит чужого языка (ja-Latn, hi-Latn) модель перевода не понимает.
      return const SourceDecision.undetected('translit_foreign');
    }

    double confOf(String code) {
      for (final c in native) {
        if (c.$1 == code) return c.$2;
      }
      return 0;
    }

    final targetConf = confOf(tgt);
    final top = native.isEmpty ? null : native.first;

    // Письменность противоречит языку перевода и однозначно даёт язык.
    String? scriptFallback() =>
        (uniq != null && isSupported(uniq)) ? uniq : null;

    if (!userInitiated) {
      // ── Авторежим: переводит только то, в чём уверен.
      if (top == null) {
        final fb = scriptFallback();
        if (fb != null && (pinned == null || pinned == fb)) {
          return SourceDecision.translate(fb, 'auto_script');
        }
        return const SourceDecision.undetected('auto_no_candidates');
      }
      if (top.$1 == tgt) return const SourceDecision.same('auto_top_target');
      if (targetConf >= targetPresentConfidence) {
        return const SourceDecision.same('auto_target_present');
      }
      if (top.$2 < autoMinConfidence) {
        return const SourceDecision.undetected('auto_unsure');
      }
      if (areNeighbours(top.$1, tgt) &&
          top.$2 - targetConf < neighbourMargin) {
        return const SourceDecision.same('auto_neighbour_close');
      }
      if (pinned != null && top.$1 != pinned) {
        return const SourceDecision.undetected('auto_not_pinned');
      }
      final srcScript = scriptOfLanguage(top.$1);
      if (script != TextScript.none &&
          script != TextScript.other &&
          srcScript != script &&
          !(srcScript == TextScript.kana && script == TextScript.han)) {
        return const SourceDecision.undetected('auto_script_mismatch');
      }
      return SourceDecision.translate(top.$1, 'auto_top');
    }

    // ── Нажатие человека.
    if (top != null && top.$1 == tgt && top.$2 >= userSureSame) {
      return const SourceDecision.same('user_top_target_sure');
    }
    if (pinned != null) {
      // Выбранный язык оригинала: определение всё равно идёт — русский текст
      // при «с украинского» не пересказывается по-русски.
      if (top != null && top.$1 == tgt && targetConf >= targetPresentConfidence) {
        return const SourceDecision.same('user_pinned_but_target');
      }
      if (tgtScript != TextScript.latin &&
          tgtScript == script &&
          scriptOfLanguage(pinned) != script) {
        return const SourceDecision.same('user_pinned_script_target');
      }
      return SourceDecision.translate(pinned, 'user_pinned');
    }
    if (top == null) {
      final fb = scriptFallback();
      if (fb != null) return SourceDecision.translate(fb, 'user_script');
      return const SourceDecision.undetected('user_no_candidates');
    }
    if (top.$1 != tgt) {
      if (areNeighbours(top.$1, tgt) && targetConf >= targetPresentConfidence) {
        return const SourceDecision.same('user_neighbour_target_present');
      }
      return SourceDecision.translate(top.$1, 'user_top');
    }
    // Впереди язык перевода, но неуверенно: запасной кандидат — не сосед.
    final allowNeighbour = targetConf < targetPresentConfidence;
    for (final c in native.skip(1)) {
      if (c.$1 == tgt || c.$2 < userMinOther) continue;
      if (!allowNeighbour && areNeighbours(c.$1, tgt)) continue;
      return SourceDecision.translate(c.$1, 'user_fallback');
    }
    return const SourceDecision.same('user_no_fallback');
  }

  static final RegExp _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static Set<String> _words(String s) => _word
      .allMatches(s.toLowerCase().replaceAll('ё', 'е'))
      .map((m) => m[0]!)
      .where((w) => RegExp(r'\p{L}', unicode: true).hasMatch(w))
      .toSet();

  /// Перевод почти совпадает с оригиналом (≥ 80 % общих слов) — значит,
  /// сообщение уже было на языке перевода. Такой «перевод» не показывается
  /// и не запоминается.
  static bool looksUnchanged(String original, String translated) {
    final a = _words(original);
    final b = _words(translated);
    if (a.isEmpty || b.isEmpty) return false;
    final common = a.intersection(b).length;
    final denom = a.length > b.length ? a.length : b.length;
    return common / denom >= unchangedOverlap;
  }
}
