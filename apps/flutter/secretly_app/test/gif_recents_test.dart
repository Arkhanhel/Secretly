// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/gifs/gif_recents.dart';

// Недавно выбранные гифки (09.08.2026).
//
// «Вверху сначала последние выбранные, с ограничением до 8». Проверяются
// решения, а не хранилище: порядок, дубли, потолок и поведение на испорченной
// записи.

RecentGif gif(int i) => RecentGif(
  previewUrl: 'https://media.giphy.com/p$i.gif',
  fullUrl: 'https://media.giphy.com/f$i.gif',
);

void main() {
  group('чтение из хранилища', () {
    test('🔴 испорченная запись НЕ роняет подборщик', () {
      // Недавние — украшение. Испорченная запись обязана стоить пустой полосы,
      // а не неоткрывающегося листа выбора.
      expect(decodeRecentGifs(null), isEmpty);
      expect(decodeRecentGifs(''), isEmpty);
      expect(decodeRecentGifs('не json'), isEmpty);
      expect(decodeRecentGifs('{"p":"x"}'), isEmpty);
      expect(decodeRecentGifs('[1,2,3]'), isEmpty);
      expect(decodeRecentGifs('[{"p":null,"f":null}]'), isEmpty);
    });

    test('круг через хранилище сохраняет порядок', () {
      final list = <RecentGif>[gif(1), gif(2), gif(3)];
      expect(decodeRecentGifs(encodeRecentGifs(list)), list);
    });

    test('🔴 не-https отбрасывается при чтении', () {
      // Значение пришло из хранилища, а значит могло быть записано старой
      // сборкой или испорчено. Отдать такую строку в загрузчик картинок или в
      // отправку значило бы доверять данным больше, чем коду.
      const raw =
          '[{"p":"http://a/1.gif","f":"http://a/1.gif"},'
          '{"p":"https://a/2.gif","f":"https://a/2.gif"}]';
      final decoded = decodeRecentGifs(raw);
      expect(decoded, hasLength(1));
      expect(decoded.single.fullUrl, 'https://a/2.gif');
    });

    test('чтение обрезает до потолка, даже если в хранилище больше', () {
      final many = List<RecentGif>.generate(40, gif);
      // Кодировщик уже режет, поэтому подсовываем «раздутую» запись руками.
      final raw = <String>[
        for (final g in many) '{"p":"${g.previewUrl}","f":"${g.fullUrl}"}',
      ].join(',');
      expect(decodeRecentGifs('[$raw]'), hasLength(kRecentGifLimit));
    });

    test('дубли в записи не удваивают полосу', () {
      final raw = encodeRecentGifs(<RecentGif>[gif(1), gif(1), gif(2)]);
      expect(decodeRecentGifs(raw), <RecentGif>[gif(1), gif(2)]);
    });
  });

  group('запоминание выбора', () {
    test('🔴 выбранная встаёт ПЕРВОЙ', () {
      final next = withRecentGif(<RecentGif>[gif(1), gif(2)], gif(9));
      expect(next.first, gif(9));
      expect(next, hasLength(3));
    });

    test('🔴 повтор поднимается наверх, а не заводит вторую запись', () {
      // Иначе восемь мест займут четыре любимые гифки, и полоса перестанет
      // показывать недавнее.
      final next = withRecentGif(<RecentGif>[gif(1), gif(2), gif(3)], gif(3));
      expect(next, <RecentGif>[gif(3), gif(1), gif(2)]);
    });

    test('🔴 потолок в восемь соблюдается', () {
      var list = const <RecentGif>[];
      for (var i = 0; i < 20; i++) {
        list = withRecentGif(list, gif(i));
      }
      expect(list, hasLength(kRecentGifLimit));
      // Наверху — последняя выбранная.
      expect(list.first, gif(19));
      // Самые старые вытеснены.
      expect(list.contains(gif(0)), isFalse);
    });

    test('одинаковыми считаются по ПОЛНОЙ ссылке', () {
      // GIPHY отдаёт превьюшку в разных размерах для одной и той же гифки, и по
      // превьюшке дубль прошёл бы мимо проверки.
      const same = RecentGif(
        previewUrl: 'https://media.giphy.com/other-size.gif',
        fullUrl: 'https://media.giphy.com/f1.gif',
      );
      final next = withRecentGif(<RecentGif>[gif(1), gif(2)], same);
      expect(next, hasLength(2));
      expect(next.first.previewUrl, 'https://media.giphy.com/other-size.gif');
    });

    test('🔴 негодная ссылка не портит уже накопленное', () {
      // Провал запоминания не имеет права стереть полосу.
      const bad = RecentGif(previewUrl: '', fullUrl: '');
      final current = <RecentGif>[gif(1), gif(2)];
      expect(withRecentGif(current, bad), current);
    });

    test('негодные записи вычищаются попутно', () {
      const bad = RecentGif(
        previewUrl: 'http://a/x.gif',
        fullUrl: 'http://a/x.gif',
      );
      final next = withRecentGif(<RecentGif>[bad, gif(2)], gif(9));
      expect(next, <RecentGif>[gif(9), gif(2)]);
    });
  });

  group('ключ хранилища', () {
    test('🔴 профиль входит в ключ', () {
      // База одна на все профили устройства: без профиля недавние одного
      // человека показались бы другому.
      expect(recentGifsKvKey('P1'), isNot(recentGifsKvKey('P2')));
      expect(recentGifsKvKey('P1'), contains('P1'));
    });

    test('пробелы вокруг профиля не создают второй ключ', () {
      expect(recentGifsKvKey(' P1 '), recentGifsKvKey('P1'));
    });
  });
}
