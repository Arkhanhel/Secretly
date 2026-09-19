// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Сверка с макетом владельца: цвета счётчиков, рамка на своей кнопке, свой
// профиль в правой панели и плавающее поле ввода.
//
// 🔴 Четыре расхождения, которые владелец назвал 13.09.2026, глядя на макет
// рядом с работающим окном:
//
//   1) счётчики непрочитанного были СИНИМИ — в макете красные. Синим они
//      совпадали и с акцентом кнопок, и с выделением строки: в списке из
//      тридцати чатов непрочитанное переставало отличаться от «выбранного»;
//   2) на собственной кнопке внизу рейки не было премиальной РАМКИ — её
//      видели все собеседники, кроме владельца, который за неё платит;
//   3) свой профиль открывался отдельной страницей поверх окна — так, как не
//      открывается больше ни один профиль в приложении;
//   4) вокруг поля ввода стояла сплошная панель с чертой сверху: лента
//      упиралась в неё, как в пол, вместо того чтобы уходить под поле.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/radii.dart';
import 'package:secretly_app/ui/desktop/design/shadows.dart';
import 'package:secretly_app/ui/desktop/design/typography.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('счётчики непрочитанного', () {
    test('🔴 цвет называет ТИП разговора', () {
      // «Двенадцать непрочитанных» в личной переписке и в шумной комнате —
      // разные новости, и в списке из тридцати строк это видно боковым
      // зрением.
      //
      // 15.09.2026, указание владельца: личная переписка ГОЛУБАЯ (как в
      // макете, где все строки списка #4C8DF6), комната ФИОЛЕТОВАЯ. До этого
      // личная была красной, а комната голубой — и красный тем самым значил
      // сразу две разные вещи: «личная переписка» и «тебя ждут» в фильтрах.
      expect(kDColorsDark.unreadDot, const Color(0xFF4C8DF6));
      expect(kDColorsDark.unreadRoom, const Color(0xFF7C5CE0));
      expect(kDColorsDark.unreadChannel, const Color(0xFFA78BFA));
      expect(kDColorsLight.unreadDot, const Color(0xFF2563EB));
      expect(
        kDColorsDark.unreadRoom,
        isNot(kDColorsDark.unreadDot),
        reason: 'иначе тип снова перестаёт читаться',
      );
      // И ни один из них больше не красный: красный остался сигналу.
      expect(kDColorsDark.unreadDot, isNot(kDColorsDark.unreadRail));
      expect(kDColorsDark.unreadRoom, isNot(kDColorsDark.unreadRail));
    });

    test('🔴 цвет считает ОДНА функция на всё окно', () {
      // Иначе у рейки, списка и ленты заведётся три разных мнения.
      final panel = read('lib/ui/desktop/chat/chat_list_panel.dart');
      expect(panel.contains('Color unreadColorFor(ChatKind kind'), isTrue);
      for (final path in const <String>[
        'lib/ui/desktop/shell/sidebar.dart',
        'lib/ui/desktop/chat/chat_thread_panel.dart',
      ]) {
        expect(
          read(path).contains('unreadColorFor('),
          isTrue,
          reason: '$path красит счётчик мимо общей функции',
        );
      }
    });

    test('🔴 не идут за темой оформления', () {
      // Тема меняет настроение окна, а «тут не прочитано» — это сигнал.
      final bridge = read('lib/ui/desktop/design/theme_bridge.dart');
      expect(
        bridge.contains('unreadDot: base.unreadDot'),
        isTrue,
        reason: 'пресет перекрашивал счётчик в цвет обоев и тем самым гасил его',
      );
    });

    test('полоса фильтров считает все чаты разом — там красный', () {
      // У фильтра «Непрочит.» нет одного типа: он считает и личные, и
      // комнаты, — красить его по типу нечем. В макете он красный.
      final bar = read('lib/ui/desktop/chat/chat_category_bar.dart');
      expect(bar.contains('color: colors.unreadRail'), isTrue);
      expect(bar.contains('colors.unreadDot'), isFalse);
      expect(kDColorsDark.unreadRail, const Color(0xFFF43F5E));
    });

    // 🔴 ФИЛЬТР И РЕЙКА СЧИТАЮТ РАЗГОВОРЫ, А НЕ СООБЩЕНИЯ (15.09.2026).
    //
    // Складывалась сумма непрочитанных сообщений: «Непрочит. 19» читалось как
    // девятнадцать сообщений, а означать должно «девятнадцать разговоров ждут
    // ответа» — ровно то число, ради которого на фильтр и нажимают. Сумма
    // вдобавок врала на порядок: один шумный чат на сто сообщений давал «100»
    // там, где ждёт один разговор.
    test('🔴 фильтр считает РАЗГОВОРЫ', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(section.contains('if (c.unreadCount <= 0) continue;'), isTrue);
      expect(section.contains('archiveUnread += 1;'), isTrue);
      expect(section.contains('personalUnread += 1;'), isTrue);
      expect(section.contains('unread += 1;'), isTrue);
      expect(section.contains('if (c.unreadCount > 0) groupUnread += 1;'), isTrue);
      // Сумм сообщений не осталось.
      expect(section.contains('+= c.unreadCount'), isFalse);
    });

    test('🔴 плитка раздела на рейке считает РАЗГОВОРЫ', () {
      final app = read('lib/ui/desktop/app/desktop_production_app.dart');
      expect(app.contains('roomUnread += 1;'), isTrue);
      expect(app.contains('directUnread += 1;'), isTrue);
      expect(app.contains('roomUnread += c.unreadCount;'), isFalse);
      expect(app.contains('directUnread += c.unreadCount;'), isFalse);
    });

    test('🔴 а ЗАКРЕПЛЁННАЯ переписка на рейке считает СООБЩЕНИЯ', () {
      // Там плитка И ЕСТЬ разговор: «сколько разговоров ждёт» дало бы вечную
      // единицу.
      final app = read('lib/ui/desktop/app/desktop_production_app.dart');
      expect(app.contains('unread: c.unreadCount,'), isTrue);
    });

    test('вся рейка говорит ОДНИМ цветом — красным', () {
      // Голубое и фиолетовое живут в списке, где рядом стоит имя и видно,
      // чей это разговор. На рейке рядом ничего нет, и три цвета там
      // читались бы как три вида тревоги. В макете все её бейджи красные.
      final rail = read('lib/ui/desktop/shell/sidebar.dart');
      expect(rail.contains('rail ? c.unreadRail : unreadColorFor(kind, c)'), isTrue);
      expect(
        'rail: true,'.allMatches(rail).length,
        3,
        reason: 'плитка раздела, закреплённая переписка и ответ поддержки '
            'на кнопке «Настройки» — все три одного цвета',
      );
    });

    test('🔴 черта «новые сообщения» — красная, как сигнал', () {
      // Она говорит ровно «отсюда тебя ждут», то есть то же, что фильтр и
      // плитка раздела. Пока личная переписка была красной, черта брала её
      // цвет; теперь та голубая, и черта берёт сам сигнал — иначе покраснение
      // ушло бы вместе с ним.
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      final idx = panel.indexOf('class _UnreadSeparator');
      expect(idx, greaterThan(0));
      final body = panel.substring(idx, (idx + 2000).clamp(0, panel.length));
      expect(body.contains('final line = c.unreadRail;'), isTrue);
    });
  });

  test('🔴 на кнопке своего профиля есть рамка', () {
    final sidebar = read('lib/ui/desktop/shell/sidebar.dart');
    expect(sidebar.contains('selfFrameId'), isTrue);
    expect(
      sidebar.contains('frameId: frameId'),
      isTrue,
      reason: 'рамка должна доехать до самого портрета, а не осесть в снимке',
    );
    // Подпись снимка обязана включать рамку, иначе смена рамки на телефоне не
    // перерисует рейку.
    final sigIdx = sidebar.indexOf('String get signature');
    expect(sigIdx, greaterThan(0));
    expect(
      sidebar.substring(sigIdx, sigIdx + 600).contains('selfFrameId'),
      isTrue,
    );
  });

  group('свой профиль — в правой панели', () {
    test('🔴 отдельной страницы больше нет', () {
      expect(
        File('lib/ui/desktop/workspace/profile_workspace.dart').existsSync(),
        isFalse,
        reason: 'два профиля в двух местах разъедутся на первой же правке',
      );
      final root = read('lib/ui/desktop/app/desktop_production_app.dart');
      expect(root.contains('ProfileWorkspace'), isFalse);
    });

    test('панель знает, кого показывать', () {
      final drawer = read('lib/ui/desktop/chat/details/details_drawer.dart');
      expect(drawer.contains('showSelfProfile'), isTrue);
      expect(drawer.contains('SelfProfileView'), isTrue);
    });

    test('🔴 открытие переписки возвращает панель к ней', () {
      // Иначе свой профиль висел бы поверх чужих чатов, пока его не закроют.
      final root = read('lib/ui/desktop/app/desktop_production_app.dart');
      expect(root.contains('_dropSelfProfileOnSelection'), isTrue);
    });

    test('настройки открываются мини-окнами посередине', () {
      final view = read('lib/ui/desktop/chat/details/self_profile_view.dart');
      // 19.09.2026: подписи уехали в переводы — проверяем ключи.
      for (final title in const <String>[
        'title: l10n.desktopProfileEmojiStatus',
        'l10n.desktopProfileAvatarFrame',
        'l10n.desktopProfileCover',
      ]) {
        expect(view.contains(title), isTrue, reason: 'нет окна: $title');
      }
      expect(view.contains('DesktopDialog.show'), isTrue);
    });
  });

  group('поле ввода плавает над лентой', () {
    test('🔴 вокруг поля нет панели', () {
      final composer = read('lib/ui/desktop/chat/composer.dart');
      expect(
        composer.contains('decoration: const BoxDecoration()'),
        isTrue,
        reason: 'сплошная плашка отрезала низ окна ровной чертой',
      );
      expect(
        composer.contains('border: Border(top: BorderSide(color: c.borderSubtle))'),
        isFalse,
      );
    });

    test('🔴 лента резервирует высоту поля и та измеряется живьём', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      expect(panel.contains('_composerHeight'), isTrue);
      expect(
        panel.contains('_MeasuredComposer'),
        isTrue,
        reason:
            'высота поля меняется карточкой ответа и многострочным текстом — '
            'захардкоженный отступ прятал бы последнее сообщение',
      );
    });

    test('затенение лежит НАД сообщениями и ПОД полем', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      final fadeIdx = panel.indexOf('ЗАТЕНЕНИЕ К НИЖНЕЙ ГРАНИЦЕ');
      final composerIdx = panel.indexOf('_MeasuredComposer(');
      expect(fadeIdx, greaterThan(0));
      expect(composerIdx, greaterThan(fadeIdx), reason: 'поле должно рисоваться позже');
      expect(
        panel.substring(fadeIdx, composerIdx).contains('IgnorePointer'),
        isTrue,
        reason: 'иначе затенение съедало бы нажатия по последнему пузырю',
      );
    });
  });

  group('список чатов по макету', () {
    test('🔴 разделы по дням вместо одного «ВСЕ ЧАТЫ»', () {
      final panel = read('lib/ui/desktop/chat/chat_list_panel.dart');
      expect(panel.contains('_dateHeaderFor'), isTrue);
      // 19.09.2026: подписи разделов уехали в переводы, а в списке осталась
      // МЕТКА раздела. Проверяем метки — они и есть разбиение; сам текст
      // теперь дело языковых файлов.
      for (final label in const <String>[
        '_kTodayHeader',
        '_kYesterdayHeader',
        '_kThisWeekHeader',
        '_kEarlierHeader',
      ]) {
        expect(panel.contains(label), isTrue, reason: 'нет раздела $label');
      }
      expect(
        panel.contains('l10n.desktopListToday'),
        isTrue,
        reason: 'подпись раздела берётся из переводов',
      );
      expect(
        panel.contains("_kAllChatsHeader"),
        isFalse,
        reason: 'подпись «все чаты» над всем списком ничего не сообщает',
      );
    });

    test('раздел считается по СЫРОМУ времени, а не по готовой подписи', () {
      // `time` уже отформатировано, и по нему «вчера» от «позавчера» не
      // отличить.
      final panel = read('lib/ui/desktop/chat/chat_list_panel.dart');
      expect(panel.contains('final int timestampMs'), isTrue);
    });

    test('🔴 идущий созвон виден В СТРОКЕ списка', () {
      final panel = read('lib/ui/desktop/chat/chat_list_panel.dart');
      expect(panel.contains('RoomCallHint'), isTrue);
      expect(panel.contains('desktopListDiscussion'), isTrue);
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(
        section.contains('listCachedActiveRoomCalls'),
        isTrue,
        reason: 'о созвоне узнавал только тот, кто и так зашёл в комнату',
      );
      expect(
        section.contains('item.roomCall?.participants'),
        isTrue,
        reason: 'без этого в подписи список не перерисуется на начало созвона',
      );
    });

    test('🔴 в плашке обсуждения видно, КТО внутри', () {
      final banner = read('lib/ui/desktop/chat/room_call_banner.dart');
      expect(banner.contains('RoomCallFace'), isTrue);
      expect(banner.contains('_FaceStack'), isTrue);
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(section.contains('_callFaces('), isTrue);
      expect(
        section.contains('if (!p.isJoined) continue;'),
        isTrue,
        reason: 'лицо того, кто ещё не вошёл, обещало бы разговор, которого нет',
      );
    });
  });

  group('правая панель: вкладки по макету', () {
    test('🔴 появилась вкладка «Ссылки»', () {
      final gallery = read(
        'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
      );
      expect(gallery.contains('_GalleryTab(l10n.desktopGalleryLinks)'), isTrue);
      expect(gallery.contains('_DesktopLinksList'), isTrue);
    });

    test('фото и видео слились в «Медиа» — вкладок всё ещё четыре', () {
      // В панели шириной 260–330 точек больше четырёх не помещается: пятая
      // вкладка порвала бы раскладку, которую сторожит gallery_tabs_test.
      final gallery = read(
        'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
      );
      expect(gallery.contains('_GalleryTab(l10n.desktopGalleryMedia)'), isTrue);
      expect(gallery.contains("_GalleryTab('Фото')"), isFalse);
      expect(gallery.contains("_GalleryTab('Видео')"), isFalse);
      expect(gallery.contains('length: 4'), isTrue);
    });

    test('🔴 вид плитки считается по вложению, а не по вкладке', () {
      // Иначе в объединённой ленте все видео нарисовались бы картинками.
      final gallery = read(
        'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
      );
      expect(gallery.contains('bool get _isVideo'), isTrue);
      expect(gallery.contains('_GridKind'), isFalse);
    });

    test('🔴 ссылки считаются ЗА ТОТ ЖЕ проход по событиям', () {
      // Отдельный проход означал бы второе чтение пяти тысяч событий и второй
      // разбор каждого payload.
      final loader = read('lib/ui/widgets/conversation_media_gallery.dart');
      expect(loader.contains('ConversationLinkItem'), isTrue);
      expect(loader.contains('extractChatMessageLinks'), isTrue);
      expect(
        loader.contains("text.startsWith('__secretly')"),
        isTrue,
        reason: 'в управляющих сообщениях лежит base64 — там не ссылки',
      );
      expect(
        loader.contains('seenUrls.add'),
        isTrue,
        reason: 'пять пересылок одной ссылки — это одна ссылка',
      );
    });
  });

  group('левая панель: второй проход по макету', () {
    test('🔴 выбранная строка — СПЛОШНАЯ заливка без полоски (телеграм)', () {
      // 14.09 здесь по макету стояли тихая подсветка И полоска у края.
      // 16.09 владелец прислал скриншот телеграма: открытый чат залит цветом
      // окна целиком, текст на нём белый, полоски нет. Так «где я» видно
      // боковым зрением через всю панель.
      final panel = read('lib/ui/desktop/chat/chat_list_panel.dart');
      expect(
        panel.contains('if (selected)\n                Positioned('),
        isFalse,
        reason: 'полоска вернулась',
      );
      expect(panel.contains('? selectedChatRowFill(c.accentPrimary)'), isTrue);
    });

    test('заливка выбранной — ровная, а не градиентная', () {
      // Градиент по горизонтали тянул взгляд вправо, к времени, вместо имени.
      final panel = read('lib/ui/desktop/chat/chat_list_panel.dart');
      final idx = panel.indexOf('class _ChatRow');
      expect(idx, greaterThan(0));
      final body = panel.substring(idx, idx + 3000);
      // 16.09: цвет окна, притемнённый до читаемого белого текста.
      expect(
        body.contains(
          'color: selected\n                ? selectedChatRowFill(c.accentPrimary)',
        ),
        isTrue,
      );
      expect(
        body.contains('gradient: selected'),
        isFalse,
        reason: 'градиентная плитка строки — это прошлая редакция',
      );
    });

    test('🔴 выбранный фильтр — нейтральная плашка, а не синяя', () {
      final bar = read('lib/ui/desktop/chat/chat_category_bar.dart');
      expect(bar.contains('? c.elevated'), isTrue);
      expect(
        bar.contains('c.accentPrimary.withValues(alpha: 0.18)'),
        isFalse,
        reason: 'синим в этом окне говорят уже три разные вещи',
      );
    });

    test('🔴 ползунок ленты не уезжает под поле ввода', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      expect(panel.contains('RawScrollbar'), isTrue);
      expect(
        panel.contains('bottom: _composerHeight + DSpace.s'),
        isTrue,
        reason: 'нижнюю треть ползунка нельзя было взять мышью',
      );
      expect(
        panel.contains('copyWith(scrollbars: false)'),
        isTrue,
        reason: 'без этого полос стало бы две — своя и по умолчанию',
      );
      expect(
        panel.contains('interactive: true'),
        isTrue,
        reason: 'ползунок ТАЩАТ мышью, иначе это полоска-украшение',
      );
    });

    // · КНОПКА «ПОЗВОНИТЬ» — ЗЕЛЁНАЯ ПЛЁНКА В 14 %, А НЕ СПЛОШНАЯ ЗАЛИВКА.
    //
    // 14.09 её залили сплошным зелёным с белой подписью — «главное действие
    // шапки, видно боковым зрением». Сверка с исходником макета показала
    // плёнку .14 с зелёными значком и подписью, и 15.09 владелец подтвердил
    // макет: плёнка ставит кнопку в один ряд с остальными значками шапки —
    // звонок начинают осознанно, а не задев глазом.
    test('главная кнопка шапки — плёнка по макету, а не сплошная заливка', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      final idx = panel.indexOf('class _CallButton');
      expect(idx, greaterThan(0));
      final body = panel.substring(idx, idx + 2200);
      expect(body.contains('c.success.withValues('), isTrue);
      expect(body.contains('alpha: pressed ? 0.30 : (hovered ? 0.22 : 0.14)'), isTrue);
      // Подпись светлее самой плёнки: `success` на своей же заливке в 14 %
      // почти сливается с ней.
      expect(body.contains('color: c.mintSoft,'), isTrue);
      expect(
        body.contains('color: Colors.white,'),
        isFalse,
        reason: 'белая подпись осталась от сплошной заливки',
      );
      expect(body.contains('height: 32,'), isTrue);
    });
  });

  test('служебные значки приглушены одинаково по всему окну', () {
    final btn = read('lib/ui/desktop/primitives/desktop_button.dart');
    expect(
      btn.contains('(hovered || pressed) ? c.textPrimary : c.textSecondary'),
      isTrue,
      reason:
          'значки шапки и поля ввода горели ярче тех же по смыслу значков '
          'рейки — ряд одинаково ярких кружков, в котором не за что зацепиться',
    );
  });

  // ── Третий проход по макету: тона, шрифт служебных подписей, холст ──────
  //
  // 🔴 «Мне кажется ты вообще игнорируешь дизайн который я делал» — владелец,
  // 14.09.2026. Разбор ИСХОДНИКА макета (а не снимков) показал три приёма,
  // которых в окне не было совсем, и их отсутствие как раз и читается как
  // «похоже, но не то».
  group('третий проход по макету', () {
    test('🔴 тонов текста ПЯТЬ, и они идут по убыванию яркости', () {
      // В макете цвета текста и значков: #E9EFF7 · #93A1B3 · #7E8DA0 ·
      // #6B7A8D · #4B5A6E. Трёх токенов не хватало, и всё, что тусклее
      // второго тона, сваливалось в «выключено»: время в строке списка
      // выглядело так же, как недоступный пункт меню.
      expect(kDColorsDark.textPrimary, const Color(0xFFE9EFF7));
      expect(kDColorsDark.textSecondary, const Color(0xFF93A1B3));
      expect(kDColorsDark.textTertiary, const Color(0xFF7E8DA0));
      expect(kDColorsDark.textDisabled, const Color(0xFF6B7A8D));
      expect(kDColorsDark.textFaint, const Color(0xFF4B5A6E));

      for (final set in <DColorSet>[kDColorsDark, kDColorsLight]) {
        final tones = <Color>[
          set.textPrimary,
          set.textSecondary,
          set.textTertiary,
          set.textDisabled,
          set.textFaint,
        ];
        for (var i = 1; i < tones.length; i++) {
          final prev = tones[i - 1].computeLuminance();
          final cur = tones[i].computeLuminance();
          // Тёмная тема гаснет, светлая светлеет — в обеих шаг идёт в одну
          // сторону, иначе «тусклее» перестаёт означать «тусклее».
          expect(
            set.isDark ? cur < prev : cur > prev,
            isTrue,
            reason: 'тон $i не продолжает ряд — шкала перестала быть шкалой',
          );
        }
      }
    });

    test('🔴 холст переписки — радиальный градиент, а не заливка', () {
      final panel = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      expect(panel.contains('RadialGradient('), isTrue);
      expect(panel.contains('c.threadGlow'), isTrue);
      expect(panel.contains('c.threadEdge'), isTrue);
      expect(
        panel.contains('color: c.thread,\n          child: Column('),
        isFalse,
        reason: 'плоская заливка вернулась — макет требует отблеска сверху',
      );
      // Затенение внизу обязано гаснуть В ЦВЕТ ДАЛЬНЕГО УГЛА: холст там уже
      // темнее среднего тона, и заливка средним оставляла светлую полосу у
      // самого края окна.
      expect(panel.contains('c.threadEdge.withValues(alpha: 0)'), isTrue);
      expect(
        kDColorsDark.threadGlow.computeLuminance() >
            kDColorsDark.thread.computeLuminance(),
        isTrue,
      );
      expect(
        kDColorsDark.threadEdge.computeLuminance() <
            kDColorsDark.thread.computeLuminance(),
        isTrue,
      );
    });

    test('🔴 служебные подписи набраны моноширинным, как в макете', () {
      final list = read('lib/ui/desktop/chat/chat_list_panel.dart');
      final idx = list.indexOf('class _SectionHeader');
      expect(idx, greaterThan(0));
      expect(
        list.substring(idx, (idx + 1400).clamp(0, list.length))
            .contains('DType.meta'),
        isTrue,
        reason:
            '«ЗАКРЕПЛЁННЫЕ» и «СЕГОДНЯ» стоят в одной колонке с именами, и '
            'одним шрифтом читаются как ещё одна строка чата',
      );
      final type = read('lib/ui/desktop/design/typography.dart');
      expect(type.contains('monoFamily'), isTrue);
      expect(
        type.contains("'JetBrains Mono'"),
        isTrue,
        reason: 'имя из макета обязано остаться первым в списке запасных',
      );
    });

    test('🔴 буквы заглушки растут не пропорционально размеру', () {
      // Ряд из макета: 22→8,5 · 32→11 · 42→13,5 · 48→15. Одна постоянная
      // доля ошибается на мелких портретах на пятую часть кегля.
      final av = read('lib/ui/desktop/primitives/avatar.dart');
      expect(av.contains('_inkRatio('), isTrue);
      expect(
        av.contains('final fontSize = size * 0.32;'),
        isFalse,
        reason: 'постоянная доля вернулась — мелкие инициалы снова крошка',
      );
      // Вес по размеру уточнён 15.09: в макете 800 стоит и у МЕЛКИХ (22–26),
      // и у КРУПНЫХ (44+), а рабочий 42-й набран 700. Прежнее «крупные 700,
      // мелкие 800» верно описывало только левую половину ряда.
      expect(
        av.contains('(size <= 30 || size >= 44)'),
        isTrue,
        reason: 'в макете 800 у мелких и крупных, 700 у средних',
      );
      // · Трекинга в макете нет ни одного на инициалах.
      expect(av.contains('letterSpacing: -0.2'), isFalse);
    });

    test('🔴 подсказка под полем ввода читает настройку, а не повторяет её',
        () {
      final composer = read('lib/ui/desktop/chat/composer.dart');
      expect(
        composer.contains('valueListenable: DesktopUiPrefs.enterToSend'),
        isTrue,
        reason:
            'поле слушалось настройки, а подпись под ним утверждала обратное '
            '— подпись, которая врёт про клавишу прямо над клавишей',
      );
      // 19.09.2026: обе подписи уехали в переводы — смотрим на ключ в коде
      // и на сам текст в ARB, а не на литерал, которого больше нет.
      expect(composer.contains('l10n.desktopComposerEnterNewline'), isTrue);
      expect(
        File('lib/l10n/app_ru.arb')
            .readAsStringSync()
            .contains('Enter — перенос · Shift+Enter — отправить'),
        isTrue,
      );
    });
  });

  group('строка списка: знаки и кегли по макету', () {
    test('🔴 у своего последнего сообщения есть знак доставки', () {
      final list = read('lib/ui/desktop/chat/chat_list_panel.dart');
      expect(list.contains('enum ChatDelivery'), isTrue);
      // Знак рисует ОБЩАЯ функция пузырей, а не своя копия: две копии галочек
      // в этом проекте уже расходились.
      expect(list.contains('deliveryTickGlyph('), isTrue);
      // 🔴 16.09.2026 знак доставки ПЕРЕЕХАЛ на строку имени, к времени —
      // по скриншоту телеграма от владельца. Раньше он стоял справа от превью
      // и показывался ТОЛЬКО когда непрочитанного нет, то есть о судьбе своего
      // последнего сообщения строка сообщала через раз. В телеграме это две
      // разные сведения в двух разных местах, и друг друга они не вытесняют.
      expect(
        list.contains('if (item.delivery != ChatDelivery.none) ...['),
        isTrue,
        reason: 'галочки снова уехали в строку превью',
      );
      expect(
        list.contains('if (item.unread > 0) ...[\n                                const SizedBox(width: 6),\n                                _unreadBadge(c),'),
        isTrue,
        reason: 'счётчик — на строке превью и один',
      );
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(
        section.contains('DeliveryStatus deliveryStatusFor('),
        isTrue,
        reason:
            'таблица соответствий local_state → знак обязана быть одна на '
            'весь десктоп, иначе список и переписка разойдутся',
      );
      final ctl = read('lib/app/app_controller.dart');
      expect(
        ctl.contains('final String? senderLocalState;'),
        isTrue,
        reason: 'состояние берётся ТЕМ ЖЕ проходом, что и превью',
      );
    });

    test('🔴 счётчик у невыбранного фильтра НЕ приглушён', () {
      final bar = read('lib/ui/desktop/chat/chat_category_bar.dart');
      expect(
        bar.contains('muted'),
        isFalse,
        reason:
            'счётчик зовёт туда, где человека сейчас нет, — то есть именно '
            'на невыбранный чип; приглушённый он звал шёпотом',
      );
      expect(bar.contains('borderRadius: BorderRadius.circular(9)'), isTrue);
      expect(
        bar.contains('DRadii.pill'),
        isFalse,
        reason: 'таблетка превращала фильтры в ряд кнопок',
      );
    });

    test('🔴 имя комнаты набрано жирнее имени человека', () {
      final list = read('lib/ui/desktop/chat/chat_list_panel.dart');
      // Без привязки к отступам: 16.09 строка имени ушла на уровень глубже.
      expect(
        RegExp(
          r'item\.kind == ChatKind\.direct\s+\? FontWeight\.w600\s+'
          r': FontWeight\.w700',
        ).hasMatch(list),
        isTrue,
      );
    });

    test('🔴 вырез вокруг точки присутствия — цвета фона под ней', () {
      final av = read('lib/ui/desktop/primitives/avatar.dart');
      expect(av.contains('final Color? ringColor;'), isTrue);
      expect(
        av.contains('border: Border.all(color: c.chatList, width: 2)'),
        isFalse,
        reason:
            'цвет списка чатов был зашит, и на рейке, в шапке и в правой '
            'панели вокруг точки светилось кольцо чужого цвета',
      );
      final thread = read('lib/ui/desktop/chat/chat_thread_panel.dart');
      expect(thread.contains('ringColor: c.threadGlow'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Акцент и всё, что от него считается.
  //
  // 🔴 В докстринге палитры каноном была записана пара `#3E8BF5 → #7C4DE0` —
  // на шаг темнее настоящей из макета (`#4C8DF6 → #7C5CE0`). Записанная
  // неверно, она расползлась по производным: выделение строки, плашка
  // упоминания, знак доставки и пузыри светлой темы считались от неё. По
  // отдельности разница в один шаг тона незаметна, вместе она и давала
  // «почти тот, но не тот» интерфейс.
  group('акцент сверен с исходником макета', () {
    final colors = File(
      'lib/ui/desktop/design/colors.dart',
    ).readAsStringSync();

    test('канон пары — из макета', () {
      expect(kDColorsDark.accentPrimary, const Color(0xFF4C8DF6));
      expect(kDColorsDark.accentPrimaryAlt, const Color(0xFF7C5CE0));
      expect(kDColorsDark.bubbleSelfStart, const Color(0xFF4C8DF6));
      expect(kDColorsDark.bubbleSelfEnd, const Color(0xFF7C5CE0));
    });

    test('производные считаются ОТ акцента, а не рядом с ним', () {
      // rgba(76,141,246,.15) и #6FA8F7 — прямо из исходника макета.
      expect(kDColorsDark.selected, const Color(0x264C8DF6));
      expect(kDColorsDark.deliveryIndicator, const Color(0xFF6FA8F7));
      expect(kDColorsDark.mentionBg, const Color(0x2D7C5CE0));
    });

    test('светлая тема выведена от СВОЕГО акцента', () {
      expect(kDColorsLight.selected, const Color(0x1F2563EB));
      expect(kDColorsLight.bubbleSelfStart, kDColorsLight.accentPrimary);
      expect(kDColorsLight.bubbleSelfEnd, kDColorsLight.accentPrimaryAlt);
    });

    test('старой пары в палитре не осталось нигде, кроме объяснения', () {
      // Единственное упоминание — в докстринге, где записано, что это была
      // ошибка. Значением она быть не должна.
      expect(colors.contains('Color(0xFF3E8BF5)'), isFalse);
      expect(colors.contains('Color(0xFF7C4DE0)'), isFalse);
      expect(colors.contains('0x2B3E8BF5'), isFalse);
      expect(colors.contains('0x1F3E8BF5'), isFalse);
      expect(colors.contains('0x2D7C4DE0'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Веса и трекинг шкалы.
  //
  // 🔴 В ИСХОДНИКЕ МАКЕТА ВЕСА 500 НЕТ НИ ОДНОГО РАЗА: 400 — три раза, 600 —
  // тридцать четыре, 700 — девяносто два, 800 — пятьдесят восемь. В шкале же
  // на 500 стояли `label` и `tiny`, и от этого подписи выглядели бледнее
  // макета всюду разом, а разметка добирала вес руками — по всему
  // `lib/ui/desktop` набралось больше полусотни самодельных `TextStyle`.
  //
  // Трекинг Flutter принимает в ТОЧКАХ, а не в em: значения ниже — размер × em.
  group('шкала набрана весами макета', () {
    test('🔴 веса 500 в десктопной разметке не осталось', () {
      final dir = Directory('lib/ui/desktop');
      final offenders = <String>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.readAsStringSync().contains('FontWeight.w500')) {
          offenders.add(f.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'в макете такого веса нет ни у одной надписи',
      );
    });

    test('заголовки — 800 с отрицательным трекингом', () {
      // font-size:22px;font-weight:800;letter-spacing:-0.02em
      expect(DType.display.fontWeight, FontWeight.w800);
      expect(DType.display.letterSpacing, -0.44);
      // Шестнадцатый кегль в макете встречается только с весом 800.
      expect(DType.title.fontWeight, FontWeight.w800);
      expect(DType.title.letterSpacing, -0.24);
    });

    test('подписи — 600, а не 500', () {
      expect(DType.label.fontWeight, FontWeight.w600);
      expect(DType.tiny.fontWeight, FontWeight.w600);
    });
  });

  // ---------------------------------------------------------------------------
  // Зелёных в макете ДВА, и они значат разное.
  //
  // 🔴 `#22C55E` легенда макета называет прямо: «голос». Им отмечено СОСТОЯНИЕ
  // ЧЕЛОВЕКА — точка «в сети», признак «говорит», кнопка «Принять» (20
  // вхождений в исходнике). Мятный `#34D399` — оформление СОЗВОНА и галочки:
  // значок демонстрации экрана, рамка сцены, чипы (37 вхождений).
  //
  // У нас был один зелёный на оба смысла: точка присутствия получала тот же
  // цвет, что значок демонстрации экрана.
  group('два зелёных, а не один', () {
    test('оба цвета — из исходника макета', () {
      expect(kDColorsDark.voice, const Color(0xFF22C55E));
      expect(kDColorsDark.success, const Color(0xFF34D399));
      expect(kDColorsDark.voice, isNot(kDColorsDark.success));
    });

    test('присутствие и приём звонка красятся «голосом»', () {
      final avatar = File(
        'lib/ui/desktop/primitives/avatar.dart',
      ).readAsStringSync();
      expect(avatar.contains('statusColor ?? c.voice'), isTrue);

      final toast = File(
        'lib/ui/desktop/calls/incoming_call_toast.dart',
      ).readAsStringSync();
      expect(toast.contains('bg: c.voice'), isTrue);

      final headline = File(
        'lib/ui/desktop/chat/details/details_headline.dart',
      ).readAsStringSync();
      expect(headline.contains('presenceIsOnline ? c.voice'), isTrue);
    });

    test('речь в созвоне — тоже «голос», а оформление сцены — мята', () {
      final call = File(
        'lib/ui/desktop/calls/room_call_window.dart',
      ).readAsStringSync();
      expect(call.contains('speaking ? c.voice'), isTrue);
      // Рамка сцены и значок демонстрации остаются мятными.
      expect(call.contains('c.success.withValues(alpha: 0.45)'), isTrue);
    });

    test('🔴 у шапки окна свой тон, а не тон всплывающих карточек', () {
      // Шапка идёт вдоль всего верха окна, и на этой длине «почти тот» тон
      // читается как чужая полоса, приклеенная сверху. В макете #121A24.
      expect(kDColorsDark.titleBar, const Color(0xFF121A24));
      expect(kDColorsDark.titleBar, isNot(kDColorsDark.elevated));
      final chrome = File(
        'lib/ui/desktop/shell/window_chrome.dart',
      ).readAsStringSync();
      expect(chrome.contains('color: c.titleBar,'), isTrue);
    });

    test('светлая тема разводит их так же', () {
      expect(kDColorsLight.voice, isNot(kDColorsLight.success));
    });
  });

  // ---------------------------------------------------------------------------
  // Скругления, тени и кольцо выделения.
  //
  // 🔴 Восемнадцати точек скругления в макете НЕТ НИ ОДНОГО РАЗА — а именно
  // ими был обрезан пузырь сообщения, самая заметная форма в окне. Тени были
  // вдвое-вчетверо тише: 32 точки размыва против 130 у окна макета. Цветных
  // свечений — целого класса теней макета — в токенах не было вовсе.
  group('формы и тени по исходнику', () {
    final radii = File(
      'lib/ui/desktop/design/radii.dart',
    ).readAsStringSync();

    test('🔴 ступени, которой нет в макете, не осталось', () {
      expect(
        radii.contains('static const double xl = 18'),
        isFalse,
        reason: 'восемнадцать в исходнике не встречается ни разу',
      );
      expect(DRadii.r16, 16);
      expect(DRadii.r15, 15);
      expect(DRadii.r12, 12);
      expect(DRadii.r9, 9);
    });

    test('пузырь обрезан максимумом макета', () {
      final bubble = File(
        'lib/ui/desktop/chat/message_bubble.dart',
      ).readAsStringSync();
      expect(bubble.contains('Radius.circular(DRadii.r16)'), isTrue);
      expect(bubble.contains('DRadii.xl'), isFalse);
      // Сторона со срезом стояла верно и осталась как была. `const` у радиуса
      // появился, когда верхний угол стал зависеть от `continuation`, — сам
      // срез от этого не изменился.
      expect(
        bubble.contains('bottomRight: const Radius.circular(DRadii.sm)'),
        isTrue,
      );
    });

    test('тени взяты из макета, а не приглушены', () {
      expect(DShadows.window.first.blurRadius, 130);
      expect(DShadows.window.first.offset, const Offset(0, 50));
      expect(DShadows.menu.first.blurRadius, 76);
      expect(DShadows.popover.first.blurRadius, 64);
      expect(DShadows.toast.first.blurRadius, 32);
    });

    test('🔴 цветные свечения дошли до тех двух мест, где их не было', () {
      final bubble = File(
        'lib/ui/desktop/chat/message_bubble.dart',
      ).readAsStringSync();
      expect(bubble.contains('DShadows.glowSelfBubble(c)'), isTrue);
      final rail = File(
        'lib/ui/desktop/shell/sidebar.dart',
      ).readAsStringSync();
      expect(rail.contains('DShadows.glowRailActive(c)'), isTrue);
    });

    test('🔴 выделение портрета — кольцо СНАРУЖИ, двухступенчатое', () {
      // `Border.all` уводил кольцо внутрь портрета: две точки лица съедались,
      // а на тёмном фоне край акцента сливался с содержимым.
      final avatar = File(
        'lib/ui/desktop/primitives/avatar.dart',
      ).readAsStringSync();
      expect(avatar.contains('DShadows.focusRing(c)'), isTrue);
      expect(
        avatar.contains('Border.all(color: c.accentPrimary, width: 2)'),
        isFalse,
      );
      final ring = DShadows.focusRing(kDColorsDark);
      expect(ring.length, 2);
      expect(ring[0].color, kDColorsDark.bg);
      expect(ring[0].spreadRadius, 2);
      expect(ring[1].color, kDColorsDark.accentPrimary);
      expect(ring[1].spreadRadius, 4);
    });
  });
}
