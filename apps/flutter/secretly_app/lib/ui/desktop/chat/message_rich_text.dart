// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'desktop_link_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/e2e_payload_v1.dart';
import '../../chat_message_mentions.dart';
import '../design/tokens.dart';
import 'noto_emoji_lottie.dart';

/// Текст сообщения так же, как его рисует телефон: разметка, упоминания,
/// ссылки.
///
/// 🔴 ДЕСКТОП ПОКАЗЫВАЛ РАЗМЕТКУ СЫРЬЁМ.
///
/// Телефон разбирает `**жирный**`, `__курсив__`, `~~зачёркнутый~~`,
/// `` `код` ``, `||спойлер||` и рисует упоминания фишками
/// (`buildChatMessageTextSpans` в `lib/ui/chat_message_mentions.dart`). Десктоп
/// же выводил `LinkifiedText` — только ссылки. Сообщение, набранное на телефоне
/// жирным, на компьютере читалось «\*\*жирный\*\*»: звёздочки на экране,
/// которых человек не писал. Спойлер и вовсе раскрывался сам — ||секрет||
/// показывался открытым текстом рядом с палками.
///
/// Разбор берём ОБЩИЙ, а не пишем свой: свой разошёлся бы с телефоном на
/// первой же правке, и одно сообщение выглядело бы на двух устройствах
/// по-разному.
///
/// Цвета общий разборщик берёт из `Theme.of(context).colorScheme`, а десктоп
/// живёт на своей палитре. Поэтому вокруг него ставится ЛОКАЛЬНАЯ тема с
/// нужными `primary` и `onSurface` — так мы не трогаем ни общий код, ни тему
/// всего окна.
class MessageRichText extends StatelessWidget {
  const MessageRichText({
    super.key,
    required this.text,
    required this.mentions,
    required this.style,
    required this.isSelf,
    required this.selfProfileId,
    this.canReceiveAdminMentions = false,
    this.onProfileMentionTap,
    this.trailingSpan,
  });

  /// 🔴 МЕСТО ПОД ВРЕМЯ В КОНЦЕ ПОСЛЕДНЕЙ СТРОКИ.
  ///
  /// В телеграме у короткого сообщения время стоит В ТОЙ ЖЕ строке («го
  /// 21:07 ✓✓»), а у длинного переезжает вниз. Никакого условия «если текст
  /// короче N» там нет: в конец текста просто вставлен НЕВИДИМЫЙ пролёт
  /// шириной с подпись времени, и дальше решает обычный перенос строк. Влез —
  /// время рядом, не влез — абзац перенёс пролёт на новую строку вместе с
  /// собой.
  ///
  /// Само время рисуется поверх, поэтому здесь нужен именно пустой пролёт той
  /// же ширины — см. `_textBubble`.
  final InlineSpan? trailingSpan;

  final String text;
  final List<MsgMentionV1> mentions;
  final TextStyle style;
  final bool isSelf;
  final String selfProfileId;
  final bool canReceiveAdminMentions;
  final ValueChanged<String>? onProfileMentionTap;

  static Future<void> _open(Uri uri) async {
    try {
      // Приглашение в комнату и другие свои ссылки открываем внутри окна.
      if (DesktopLinkRouter.handle(uri)) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Браузер не открылся — молча: ссылка остаётся в тексте, её можно
      // скопировать.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          // Фишка упоминания и ссылка на чужом пузыре — служебным синим ленты,
          // тем же, которым набраны имя автора и галочки доставки.
          primary: c.deliveryIndicator,
          // Точки спойлера на чужом пузыре — цветом текста, а не темы окна.
          onSurface: c.textPrimary,
        ),
      ),
      child: Builder(
        builder: (ctx) => Text.rich(
          TextSpan(
            children: [
              ...animateEmojiInSpans(
                buildChatMessageTextSpans(
                context: ctx,
                text: text,
                mentions: mentions,
                baseStyle: style,
                isOutgoing: isSelf,
                selfProfileId: selfProfileId,
                currentUserCanReceiveAdminMentions: canReceiveAdminMentions,
                onProfileMentionTap: onProfileMentionTap,
                  onLinkTap: _open,
                ),
                style.fontSize ?? 16.0,
              ),
              if (trailingSpan != null) trailingSpan!,
            ],
          ),
          style: style,
        ),
      ),
    );
  }
}

/// 🔴 ЭМОДЗИ ВНУТРИ СООБЩЕНИЯ ОЖИВАЮТ — КАК НА ТЕЛЕФОНЕ (16.09.2026).
///
/// Указание владельца: «сделай чтобы все эмодзи гифки и т д работали правильно
/// в пк версии! В мобильной все идеально работает!»
///
/// На телефоне каждое анимируемое эмодзи в тексте рисуется проигрывателем Noto
/// (`_animateEmojiInSpans` в `chat_screen.dart`), здесь же оставался статичный
/// шрифтовой знак. Одно и то же сообщение выглядело на двух устройствах
/// по-разному — и то, ради чего человек эмодзи и ставил, на компьютере
/// пропадало.
///
/// 🔴 ЦИКЛ БЕЗОПАСЕН ТОЛЬКО СО СТОРОЖЕМ ВИДИМОСТИ. Зацикленная анимация
/// заказывает кадр каждый вsync: без сторожа сотня смайликов в уехавших за
/// край сообщениях держала бы окно в вечной перерисовке. Сторож живёт в
/// [NotoEmojiLottie] — там же, где на телефоне.
///
/// Разбираются только ПРОСТЫЕ куски текста: у фишки упоминания, ссылки и
/// спойлера свои обработчики нажатия и своя раскраска, и подменять их
/// картинкой нельзя.
List<InlineSpan> animateEmojiInSpans(
  List<InlineSpan> spans,
  double fontSize,
) {
  final out = <InlineSpan>[];
  for (final span in spans) {
    if (span is TextSpan &&
        span.text != null &&
        span.text!.isNotEmpty &&
        (span.children == null || span.children!.isEmpty) &&
        span.recognizer == null) {
      out.addAll(_splitEmojiSpans(span.text!, span.style, fontSize));
    } else {
      out.add(span);
    }
  }
  return out;
}

List<InlineSpan> _splitEmojiSpans(
  String text,
  TextStyle? style,
  double fontSize,
) {
  // Быстрый путь: оживлять нечего — обходимся одним куском, как раньше.
  var hasEmoji = false;
  for (final ch in text.characters) {
    if (isAnimatableNotoEmoji(ch)) {
      hasEmoji = true;
      break;
    }
  }
  if (!hasEmoji) return <InlineSpan>[TextSpan(text: text, style: style)];

  final out = <InlineSpan>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      out.add(TextSpan(text: buf.toString(), style: style));
      buf.clear();
    }
  }

  for (final ch in text.characters) {
    if (isAnimatableNotoEmoji(ch)) {
      flush();
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SelectableAnimatedEmoji(
            emoji: ch,
            // 1,35 от роста строки — то же число, что на телефоне: знак должен
            // читаться крупнее буквы, но не распирать строку.
            size: fontSize * 1.35,
            style: style,
          ),
        ),
      );
    } else {
      buf.write(ch);
    }
  }
  flush();
  return out;
}

/// Живое эмодзи, которое выделяется и копируется как обычный знак.
///
/// Анимация — не текст: без подложки выделение перескакивало бы через неё, а
/// в скопированном тексте эмодзи пропадало бы. Под анимацией лежит тот же знак
/// прозрачным текстом: он и подсвечивается, и попадает в копию. Размер задаёт
/// анимация — строка не меняется ни на точку.
class SelectableAnimatedEmoji extends StatelessWidget {
  const SelectableAnimatedEmoji({
    super.key,
    required this.emoji,
    required this.size,
    required this.style,
  });

  final String emoji;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Center(
            child: Text(
              emoji,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: (style ?? const TextStyle()).copyWith(
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        // Пока анимация не загрузилась (или без сети), на её месте рисуется
        // обычный знак — он тоже текст. Из выделения его исключаем, иначе
        // эмодзи попадало бы в копию дважды.
        SelectionContainer.disabled(
          child: NotoEmojiLottie(
            emoji: emoji,
            size: size,
            mode: NotoLottieMode.looping,
          ),
        ),
      ],
    );
  }
}
