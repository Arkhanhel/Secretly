// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Знаки разделов настроек — векторные, на сетке 24×24.
///
/// Источник — макет владельца «Secretly · 10 стилей иконок» (20.11.2026):
/// первые десять знаков и их цвета перенесены из него число в число. Остальные
/// (передача без сети, надёжность, система, приглашение и др.) нарисованы в
/// том же духе — сплошная заливка, скругления 1–2 единицы, — потому что в
/// макете показаны только десять главных разделов, а в приложении их больше.
///
/// Почему не картинки: стиль значка выбирает человек (11 вариантов), и один
/// знак должен уметь стать белым, цветным, градиентным или светящимся. Контур
/// красится как угодно и не размывается на любом размере. Контуры разбираются
/// один раз и кешируются — список настроек их не пересчитывает.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';

/// Знак раздела. Имя — смысл раздела, а не картинка: один и тот же знак может
/// стоять у раздела на телефоне и на компьютере.
enum SettingsGlyph {
  account,
  privacy,
  security,
  devices,
  notifications,
  chats,
  language,
  network,
  storage,
  support,
  offline,
  reliability,
  power,
  system,
  invite,
  donate,
  diagnostics,
  policy,
  about,
  appearance,
  hotkeys,
  calls,
  media,
  backup,
  blocked,
  delete,
  // Вкладки экрана «Оформление».
  background,
  wallpaper,
  bubbles,
  text,
  iconStyle,
  appIcon,
  behavior,
}

/// Четыре цвета знака из макета: светлый и тёмный край градиента (`c1`,
/// `c2`), основной плоский цвет (`m`) и цвет-пара для двухцветного стиля
/// «Аврора» (`p`).
class SettingsGlyphPalette {
  const SettingsGlyphPalette(this.c1, this.c2, this.m, this.p);
  final Color c1;
  final Color c2;
  final Color m;
  final Color p;
}

const SettingsGlyphPalette _blue = SettingsGlyphPalette(
  Color(0xFF64AFFF),
  Color(0xFF2563EB),
  Color(0xFF3B8BF6),
  Color(0xFF06B6D4),
);
const SettingsGlyphPalette _violet = SettingsGlyphPalette(
  Color(0xFFB794FF),
  Color(0xFF7C3AED),
  Color(0xFF9B5CF6),
  Color(0xFFDB2777),
);
const SettingsGlyphPalette _green = SettingsGlyphPalette(
  Color(0xFF5EE584),
  Color(0xFF15A34A),
  Color(0xFF30C25A),
  Color(0xFF0E9F9A),
);
const SettingsGlyphPalette _amber = SettingsGlyphPalette(
  Color(0xFFFFC93C),
  Color(0xFFEE8A00),
  Color(0xFFFFA41B),
  Color(0xFFF43F5E),
);
const SettingsGlyphPalette _red = SettingsGlyphPalette(
  Color(0xFFFF7D7D),
  Color(0xFFE11D3A),
  Color(0xFFFF4545),
  Color(0xFFF97316),
);
const SettingsGlyphPalette _cyan = SettingsGlyphPalette(
  Color(0xFF4DE1F2),
  Color(0xFF0891B2),
  Color(0xFF13B6D3),
  Color(0xFF6366F1),
);
const SettingsGlyphPalette _teal = SettingsGlyphPalette(
  Color(0xFF40DCB9),
  Color(0xFF0D9488),
  Color(0xFF14B89A),
  Color(0xFF3B82F6),
);
const SettingsGlyphPalette _indigo = SettingsGlyphPalette(
  Color(0xFF9394FF),
  Color(0xFF4F46E5),
  Color(0xFF6467F2),
  Color(0xFFC026D3),
);
const SettingsGlyphPalette _orange = SettingsGlyphPalette(
  Color(0xFFFFA862),
  Color(0xFFE8560B),
  Color(0xFFFF7A2A),
  Color(0xFFE11D48),
);
const SettingsGlyphPalette _pink = SettingsGlyphPalette(
  Color(0xFFFF8DCB),
  Color(0xFFD9246F),
  Color(0xFFF0479B),
  Color(0xFF8B5CF6),
);
// Цвета ниже в макете не было — подобраны в той же насыщенности, чтобы
// соседние строки списка не повторяли друг друга.
const SettingsGlyphPalette _sky = SettingsGlyphPalette(
  Color(0xFF7CC8FF),
  Color(0xFF1D7FD8),
  Color(0xFF3A9BF0),
  Color(0xFF22D3EE),
);
const SettingsGlyphPalette _lime = SettingsGlyphPalette(
  Color(0xFF8BE36B),
  Color(0xFF3C9D1E),
  Color(0xFF5CC23A),
  Color(0xFF14B89A),
);
const SettingsGlyphPalette _yellow = SettingsGlyphPalette(
  Color(0xFFFFD84D),
  Color(0xFFE89A00),
  Color(0xFFFFBE1A),
  Color(0xFFFB7185),
);
const SettingsGlyphPalette _slate = SettingsGlyphPalette(
  Color(0xFFAAB5C3),
  Color(0xFF586374),
  Color(0xFF8190A2),
  Color(0xFF6366F1),
);
const SettingsGlyphPalette _rose = SettingsGlyphPalette(
  Color(0xFFFF8FA3),
  Color(0xFFE0245E),
  Color(0xFFFF4D79),
  Color(0xFFF97316),
);
const SettingsGlyphPalette _jade = SettingsGlyphPalette(
  Color(0xFF4FD6A8),
  Color(0xFF0F8F6A),
  Color(0xFF22B486),
  Color(0xFF3B82F6),
);
const SettingsGlyphPalette _steel = SettingsGlyphPalette(
  Color(0xFF93A6C2),
  Color(0xFF4A5D7A),
  Color(0xFF6B7F9C),
  Color(0xFF8B5CF6),
);

extension SettingsGlyphColors on SettingsGlyph {
  SettingsGlyphPalette get palette => switch (this) {
    SettingsGlyph.account => _blue,
    SettingsGlyph.privacy => _violet,
    SettingsGlyph.security => _green,
    SettingsGlyph.devices => _amber,
    SettingsGlyph.notifications => _red,
    SettingsGlyph.chats => _cyan,
    SettingsGlyph.language => _teal,
    SettingsGlyph.network => _indigo,
    SettingsGlyph.storage => _orange,
    SettingsGlyph.support => _pink,
    SettingsGlyph.offline => _sky,
    SettingsGlyph.reliability => _lime,
    SettingsGlyph.power => _yellow,
    SettingsGlyph.system => _slate,
    SettingsGlyph.invite => _sky,
    SettingsGlyph.donate => _rose,
    SettingsGlyph.diagnostics => _indigo,
    SettingsGlyph.policy => _jade,
    SettingsGlyph.about => _steel,
    // Вкладки «Оформления» — цвета из второго макета (Chat Appearance v2).
    SettingsGlyph.appearance => _blue,
    SettingsGlyph.background => _violet,
    SettingsGlyph.wallpaper => _cyan,
    SettingsGlyph.bubbles => _green,
    SettingsGlyph.text => _orange,
    SettingsGlyph.iconStyle => _pink,
    SettingsGlyph.appIcon => _amber,
    SettingsGlyph.behavior => _red,
    SettingsGlyph.hotkeys => _violet,
    SettingsGlyph.calls => _green,
    SettingsGlyph.media => _orange,
    SettingsGlyph.backup => _cyan,
    SettingsGlyph.blocked => _red,
    SettingsGlyph.delete => _red,
  };
}

/// Одна часть знака: залитый или обведённый контур с прозрачностью.
class GlyphPart {
  const GlyphPart(
    this.path, {
    this.stroke = false,
    this.strokeWidth = 0,
    this.opacity = 1,
    this.roundCap = false,
  });

  final Path path;
  final bool stroke;
  final double strokeWidth;
  final double opacity;
  final bool roundCap;
}

/// Особая часть: надпись «Aa» у вкладки «Текст». Хранится отдельно, потому
/// что текст рисует `TextPainter`, а не контур.
const String kGlyphTextLabel = 'Aa';

final Map<SettingsGlyph, List<GlyphPart>> _cache =
    <SettingsGlyph, List<GlyphPart>>{};

/// Части знака в координатах 24×24. Разбираются при первом обращении.
List<GlyphPart> glyphParts(SettingsGlyph glyph) =>
    _cache.putIfAbsent(glyph, () => _build(glyph));

class _PathSink extends PathProxy {
  _PathSink(this.path);
  final Path path;
  @override
  void close() => path.close();
  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

Path _d(String data, {bool evenOdd = false}) {
  final path = Path();
  if (evenOdd) path.fillType = PathFillType.evenOdd;
  writeSvgPathDataToPath(data, _PathSink(path));
  return path;
}

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

Path _rrect(double x, double y, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
  );

GlyphPart _fill(Path p, {double opacity = 1}) => GlyphPart(p, opacity: opacity);

GlyphPart _line(
  Path p,
  double width, {
  double opacity = 1,
  bool round = true,
}) => GlyphPart(
  p,
  stroke: true,
  strokeWidth: width,
  opacity: opacity,
  roundCap: round,
);

/// Шестерёнка: восемь зубцов и отверстие — контур строится, а не рисуется
/// руками, чтобы зубцы были ровными.
Path _gear() {
  final path = Path()..fillType = PathFillType.evenOdd;
  const center = Offset(12, 12);
  const teeth = 8;
  const rOuter = 10.4;
  const rInner = 7.8;
  Offset at(double angle, double r) =>
      center + Offset(r * math.cos(angle), r * math.sin(angle));
  for (var k = 0; k < teeth; k++) {
    final theta = k * 2 * math.pi / teeth - math.pi / 2;
    // Бока зубца скошены: у основания он шире, чем у вершины.
    final points = <Offset>[
      at(theta - 0.31, rInner),
      at(theta - 0.17, rOuter),
      at(theta + 0.17, rOuter),
      at(theta + 0.31, rInner),
    ];
    if (k == 0) {
      path.moveTo(points.first.dx, points.first.dy);
    } else {
      path.lineTo(points.first.dx, points.first.dy);
    }
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  path.addOval(Rect.fromCircle(center: center, radius: 3.3));
  return path;
}

/// Обод спасательного круга: четыре дуги через одну (в макете — пунктир
/// окружности, повёрнутый на 22,5°).
Path _lifebuoyDashes() {
  final path = Path();
  final rect = Rect.fromCircle(center: const Offset(12, 12), radius: 6.6);
  for (var k = 0; k < 4; k++) {
    final start = (22.5 + k * 90) * math.pi / 180;
    path.addArc(rect, start, math.pi / 4);
  }
  return path;
}

List<GlyphPart> _build(SettingsGlyph glyph) {
  const lock = <String>[
    'M7.6 10.2V7.6a4.4 4.4 0 018.8 0v2.6',
    'M7.3 9.6h9.4a3 3 0 013 3v5.4a3 3 0 01-3 3H7.3a3 3 0 01-3-3v-5.4a3 3 0 013-3z'
        'M12 13.1a1.7 1.7 0 00-.95 3.1v1.6a.95.95 0 001.9 0v-1.6A1.7 1.7 0 0012 13.1z',
  ];
  List<GlyphPart> lockParts() => <GlyphPart>[
    GlyphPart(_d(lock[0]), stroke: true, strokeWidth: 2.6, roundCap: true),
    _fill(_d(lock[1], evenOdd: true)),
  ];
  const bubble =
      'M12 3.3c-5.1 0-9.2 3.5-9.2 7.8 0 2.4 1.3 4.6 3.4 6-.2 1.4-.9 2.7-2 3.6 '
      '2.1.1 3.9-.6 5.3-1.7.8.2 1.6.3 2.5.3 5.1 0 9.2-3.5 9.2-7.8S17.1 3.3 12 3.3z';
  switch (glyph) {
    case SettingsGlyph.account:
      return <GlyphPart>[
        _fill(_circle(12, 7.8, 4.3)),
        _fill(
          _d(
            'M3.8 20c0-4 3.7-6.6 8.2-6.6s8.2 2.6 8.2 6.6c0 .8-.6 1.3-1.3 1.3'
            'H5.1c-.7 0-1.3-.5-1.3-1.3z',
          ),
        ),
      ];
    case SettingsGlyph.privacy:
      return <GlyphPart>[
        _fill(
          _d(
            'M12 4.8C6.6 4.8 2.9 9.2 1.8 12c1.1 2.8 4.8 7.2 10.2 7.2s9.1-4.4 '
            '10.2-7.2C21.1 9.2 17.4 4.8 12 4.8zM12 8.3a3.7 3.7 0 110 7.4 3.7 '
            '3.7 0 010-7.4z',
            evenOdd: true,
          ),
        ),
        _fill(_circle(12, 12, 1.8)),
      ];
    case SettingsGlyph.security:
    case SettingsGlyph.behavior:
      return lockParts();
    case SettingsGlyph.devices:
      return <GlyphPart>[
        _fill(_d('M3.8 5h9.4a2 2 0 012 2v7.2H1.8V7a2 2 0 012-2z')),
        _fill(_d('M.8 15.6h15.4v.4a2 2 0 01-2 2H2.8a2 2 0 01-2-2z')),
        _fill(_rrect(16.8, 8, 6.4, 11.8, 1.9)),
      ];
    case SettingsGlyph.notifications:
      return <GlyphPart>[
        _fill(
          _d(
            'M12 2.4c.75 0 1.35.6 1.35 1.35v.55A6.1 6.1 0 0118.1 10.3v3.5l1.65 '
            '2.5a1 1 0 01-.83 1.55H5.08a1 1 0 01-.83-1.55L5.9 13.8v-3.5a6.1 6.1 '
            '0 014.75-6v-.55c0-.75.6-1.35 1.35-1.35z',
          ),
        ),
        _fill(_d('M9.3 19h5.4a2.7 2.7 0 01-5.4 0z')),
      ];
    case SettingsGlyph.chats:
    case SettingsGlyph.bubbles:
      return <GlyphPart>[_fill(_d(bubble))];
    case SettingsGlyph.language:
      return <GlyphPart>[
        _line(_circle(12, 12, 8.7), 2.2),
        _line(
          Path()..addOval(
            Rect.fromCenter(
              center: const Offset(12, 12),
              width: 7.6,
              height: 17.4,
            ),
          ),
          2.0,
        ),
        _line(_d('M3.4 12h17.2M5 7.6h14M5 16.4h14'), 1.8, round: false),
      ];
    case SettingsGlyph.network:
      return <GlyphPart>[
        _fill(_rrect(2.6, 15, 3.6, 5.6, 1.3)),
        _fill(_rrect(7.8, 11.4, 3.6, 9.2, 1.3)),
        _fill(_rrect(13, 7.6, 3.6, 13, 1.3)),
        _fill(_rrect(18.2, 3.6, 3.6, 17, 1.3)),
      ];
    case SettingsGlyph.storage:
      return <GlyphPart>[
        _fill(_d('M10.9 3.3A8.9 8.9 0 1020.7 13.1h-9.8z')),
        _fill(_d('M13.1 1.6v9.3h9.3a9.3 9.3 0 00-9.3-9.3z'), opacity: 0.75),
      ];
    case SettingsGlyph.support:
      return <GlyphPart>[
        _line(_circle(12, 12, 6.6), 5, opacity: 0.5, round: false),
        _line(_lifebuoyDashes(), 5, round: false),
      ];
    case SettingsGlyph.offline:
      return <GlyphPart>[
        _line(_d('M8 19.2V5.4M4.4 9L8 5.4 11.6 9'), 2.5),
        _line(_d('M16 4.8v13.8M12.4 15L16 18.6l3.6-3.6'), 2.5),
      ];
    case SettingsGlyph.reliability:
      return <GlyphPart>[
        _line(_d('M2.4 12.6h4.1l2.3-5.6 4.3 11 2.6-6.6h5.9'), 2.5),
      ];
    case SettingsGlyph.power:
      return <GlyphPart>[
        _fill(
          _d(
            'M13.6 1.9c.5-.6 1.4-.1 1.2.6l-1.6 6.6h5.1c.7 0 1.1.8.6 1.4L10.4 '
            '22.1c-.5.6-1.4.1-1.2-.6l1.6-6.6H5.7c-.7 0-1.1-.8-.6-1.4z',
          ),
        ),
      ];
    case SettingsGlyph.system:
      return <GlyphPart>[_fill(_gear())];
    case SettingsGlyph.invite:
      return <GlyphPart>[
        _fill(_circle(9.2, 7.9, 3.9)),
        _fill(
          _d(
            'M2.3 19.6c0-3.7 3.1-6.1 6.9-6.1s6.9 2.4 6.9 6.1c0 .7-.6 1.3-1.3 '
            '1.3H3.6c-.7 0-1.3-.6-1.3-1.3z',
          ),
        ),
        _line(_d('M19.4 6.6v6.4M16.2 9.8h6.4'), 2.4),
      ];
    case SettingsGlyph.donate:
      return <GlyphPart>[
        _fill(
          _d(
            'M12 20.8c-.3 0-.6-.1-.8-.2C8.9 19.3 2.6 15.3 2.6 9.6A5.1 5.1 0 '
            '0112 6.9a5.1 5.1 0 019.4 2.7c0 5.7-6.3 9.7-8.6 11-.2.1-.5.2-.8.2z',
          ),
        ),
      ];
    case SettingsGlyph.diagnostics:
      return <GlyphPart>[
        _line(_circle(10.4, 10.4, 6.3), 2.6),
        _line(_d('M15.2 15.2l5.4 5.4'), 3.0),
      ];
    case SettingsGlyph.policy:
      return <GlyphPart>[
        _fill(
          _d(
            'M6.6 2.6h7.3l5.1 5.1v12a1.7 1.7 0 01-1.7 1.7H6.6a1.7 1.7 0 '
            '01-1.7-1.7V4.3a1.7 1.7 0 011.7-1.7z'
            'M8.2 11.2h7.6v1.8H8.2zM8.2 14.9h7.6v1.8H8.2zM8.2 7.5h3.9v1.8H8.2z',
            evenOdd: true,
          ),
        ),
      ];
    case SettingsGlyph.about:
      return <GlyphPart>[
        _fill(
          _d(
            'M12 2.6a9.4 9.4 0 110 18.8 9.4 9.4 0 010-18.8z'
            'M10.75 10.3h2.5v7.1h-2.5zM12 5.7a1.5 1.5 0 110 3 1.5 1.5 0 010-3z',
            evenOdd: true,
          ),
        ),
      ];
    case SettingsGlyph.appearance:
      return <GlyphPart>[
        _line(_circle(12, 12, 8.4), 2.4),
        _fill(_d('M12 3.6a8.4 8.4 0 010 16.8z')),
      ];
    case SettingsGlyph.background:
      return <GlyphPart>[
        _fill(_rrect(2.5, 8, 14.5, 13, 3.2), opacity: 0.55),
        _fill(_rrect(7, 3, 14.5, 13, 3.2)),
      ];
    case SettingsGlyph.wallpaper:
      return <GlyphPart>[
        _fill(_rrect(2.5, 3.5, 19, 17, 3.2), opacity: 0.5),
        _fill(
          _d(
            'M2.5 16.6l5.6-5.8 4 4.1 3-2.9 6.4 6v.6a1.9 1.9 0 01-1.9 1.9H4.4'
            'a1.9 1.9 0 01-1.9-1.9z',
          ),
        ),
        _fill(_circle(16.4, 8.1, 2)),
      ];
    case SettingsGlyph.text:
      // Рисуется надписью — см. [kGlyphTextLabel].
      return const <GlyphPart>[];
    case SettingsGlyph.iconStyle:
      return <GlyphPart>[
        _fill(_rrect(3, 3, 8, 8, 2.4)),
        _fill(_rrect(13, 3, 8, 8, 2.4), opacity: 0.7),
        _fill(_rrect(3, 13, 8, 8, 2.4), opacity: 0.7),
        _fill(_rrect(13, 13, 8, 8, 2.4)),
      ];
    case SettingsGlyph.appIcon:
      return <GlyphPart>[
        _fill(
          _d(
            'M12 2.8l2.75 5.6 6.15.85-4.45 4.3 1.05 6.1L12 16.75l-5.5 2.9 '
            '1.05-6.1L3.1 9.25l6.15-.85z',
          ),
        ),
      ];
    case SettingsGlyph.hotkeys:
      return <GlyphPart>[
        _fill(
          _d(
            'M4.2 5.6h15.6a2.4 2.4 0 012.4 2.4v8a2.4 2.4 0 01-2.4 2.4H4.2A2.4 '
            '2.4 0 011.8 16V8a2.4 2.4 0 012.4-2.4z'
            'M5 8.6h2.3v2.2H5zM8.6 8.6h2.3v2.2H8.6zM12.2 8.6h2.3v2.2h-2.3z'
            'M15.8 8.6H19v2.2h-3.2zM7.4 13.4h9.2v2.1H7.4z',
            evenOdd: true,
          ),
        ),
      ];
    case SettingsGlyph.calls:
      return <GlyphPart>[
        _fill(
          _d(
            'M6.6 2.9l2.3-.4c.6-.1 1.2.2 1.4.8l1.1 3c.2.5 0 1.1-.4 1.4L9.4 9'
            'c.9 2.3 2.8 4.3 5.1 5.3l1.4-1.6c.4-.4 1-.6 1.5-.4l3 1.1c.6.2.9.8.8 '
            '1.4l-.4 2.3c-.2 1-1 1.6-2 1.6C10.5 18.7 5.3 13.5 5 4.9c0-1 .6-1.8 '
            '1.6-2z',
          ),
        ),
      ];
    case SettingsGlyph.media:
      return <GlyphPart>[
        _fill(_rrect(8.6, 2.4, 6.8, 11.6, 3.4)),
        _line(_d('M5.6 11.2a6.4 6.4 0 0012.8 0'), 2.2),
        _line(_d('M12 17.8v3.4'), 2.2),
      ];
    case SettingsGlyph.backup:
      return <GlyphPart>[
        _fill(
          _d(
            'M7.2 19.6a4.6 4.6 0 01-.7-9.15A6 6 0 0118.1 9.4a4.6 4.6 0 01-.6 '
            '10.2z'
            'M12 9.9l3.6 3.6h-2.4v3.5h-2.4v-3.5H8.4z',
            evenOdd: true,
          ),
        ),
      ];
    case SettingsGlyph.blocked:
      return <GlyphPart>[
        _line(_circle(12, 12, 8.4), 2.6),
        _line(_d('M6.1 6.1l11.8 11.8'), 2.6),
      ];
    case SettingsGlyph.delete:
      return <GlyphPart>[
        _fill(_d('M9.2 2.8h5.6l.8 1.7h4.2v2.3H4.2V4.5h4.2z')),
        _fill(
          _d(
            'M5.6 8.4h12.8l-.9 11.3a1.8 1.8 0 01-1.8 1.6H8.3a1.8 1.8 0 '
            '01-1.8-1.6z',
          ),
        ),
      ];
  }
}
