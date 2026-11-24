// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Фон» в «Оформлении» — мягкие размытые фоны страниц приложения для тёмной
/// и светлой темы (макет «Chat Appearance v2», 20.11.2026; числа — из него).
///
/// Фон — это база и два-три больших цветных «пятна» (эллиптические радиальные
/// градиенты, как `radial-gradient(w% h% at x% y%, цвет, transparent)` в
/// макете). «По теме» (`theme`, по умолчанию) — прежний линейный градиент
/// темы: у того, кто не выбирал фон, ничего не меняется.
///
/// Рисуется одним [CustomPainter]: никаких слоёв размытия, пятна — уже мягкие
/// градиенты. Страница кладёт фон в свой `RepaintBoundary`, поэтому при
/// прокрутке он не перерисовывается.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Пятно: размеры и центр — доли ширины и высоты экрана.
@immutable
class AppBackdropBlob {
  const AppBackdropBlob(this.w, this.h, this.x, this.y, this.dark, this.light);

  final double w;
  final double h;
  final double x;
  final double y;
  final Color dark;
  final Color light;
}

@immutable
class AppBackdropPreset {
  const AppBackdropPreset({
    required this.id,
    required this.darkBase,
    required this.lightBase,
    required this.blobs,
  });

  final String id;
  final Color darkBase;
  final Color lightBase;
  final List<AppBackdropBlob> blobs;

  Color base(bool dark) => dark ? darkBase : lightBase;

  String name(AppLocalizations l) => switch (id) {
    'dusk' => l.appBackdropDusk,
    'ocean' => l.appBackdropOcean,
    'sunset' => l.appBackdropSunset,
    'mint' => l.appBackdropMint,
    'lavender' => l.appBackdropLavender,
    'peach' => l.appBackdropPeach,
    'aurora' => l.appBackdropAurora,
    'berry' => l.appBackdropBerry,
    'amber' => l.appBackdropAmber,
    _ => id,
  };
}

/// Идентификатор «как у темы» — прежний градиент.
const String kAppBackdropTheme = 'theme';

const List<AppBackdropPreset> kAppBackdropPresets = <AppBackdropPreset>[
  AppBackdropPreset(
    id: 'dusk',
    darkBase: Color(0xFF08080E),
    lightBase: Color(0xFFEFF0F6),
    blobs: [
      AppBackdropBlob(.70, .40, .12, .18, Color(0xFF3A2A8C), Color(0xFFCBD7FF)),
      AppBackdropBlob(.55, .35, .92, .48, Color(0xFF0E5C7C), Color(0xFFCDEFEF)),
      AppBackdropBlob(.65, .38, .28, .88, Color(0xFF7C2A55), Color(0xFFFBD5E5)),
    ],
  ),
  AppBackdropPreset(
    id: 'ocean',
    darkBase: Color(0xFF050A12),
    lightBase: Color(0xFFEEF4F9),
    blobs: [
      AppBackdropBlob(1.10, .55, .40, 1.0, Color(0xFF0B3F7C), Color(0xFFBFDBFF)),
      AppBackdropBlob(.60, .35, .95, .10, Color(0xFF0E6C78), Color(0xFFC4EEF0)),
    ],
  ),
  AppBackdropPreset(
    id: 'sunset',
    darkBase: Color(0xFF0C0808),
    lightBase: Color(0xFFF8F1EE),
    blobs: [
      AppBackdropBlob(.90, .48, 0, .95, Color(0xFF8C3A1E), Color(0xFFFFD6BE)),
      AppBackdropBlob(.55, .32, 1.0, .15, Color(0xFF7C1E4E), Color(0xFFFFCCE0)),
      AppBackdropBlob(.45, .26, .60, .52, Color(0xFF3E1E6C), Color(0xFFE2D4FF)),
    ],
  ),
  AppBackdropPreset(
    id: 'mint',
    darkBase: Color(0xFF050C0A),
    lightBase: Color(0xFFEFF6F2),
    blobs: [
      AppBackdropBlob(1.20, .38, .50, 0, Color(0xFF165C46), Color(0xFFC8EEDB)),
      AppBackdropBlob(.60, .36, 1.0, .85, Color(0xFF0E5560), Color(0xFFC4E9EC)),
    ],
  ),
  AppBackdropPreset(
    id: 'lavender',
    darkBase: Color(0xFF09070F),
    lightBase: Color(0xFFF4F1FA),
    blobs: [
      AppBackdropBlob(.85, .45, .50, .48, Color(0xFF4A2A8C), Color(0xFFDCCFFF)),
      AppBackdropBlob(.55, .30, 0, .95, Color(0xFF7C2A6E), Color(0xFFFBD2EE)),
    ],
  ),
  AppBackdropPreset(
    id: 'peach',
    darkBase: Color(0xFF0D0807),
    lightBase: Color(0xFFFAF3EF),
    blobs: [
      AppBackdropBlob(.65, .38, 1.0, .05, Color(0xFF8C4A2A), Color(0xFFFFDCC8)),
      AppBackdropBlob(.70, .40, 0, .85, Color(0xFF7C2A3A), Color(0xFFFFCFD6)),
    ],
  ),
  AppBackdropPreset(
    id: 'aurora',
    darkBase: Color(0xFF04090B),
    lightBase: Color(0xFFEEF5F4),
    blobs: [
      AppBackdropBlob(1.10, .24, .20, .12, Color(0xFF0E6C50), Color(0xFFC4F0DD)),
      AppBackdropBlob(.55, .40, 1.0, .50, Color(0xFF1A4C8C), Color(0xFFCADCFF)),
      AppBackdropBlob(.60, .34, .15, .95, Color(0xFF4E2A7C), Color(0xFFE3D5FF)),
    ],
  ),
  AppBackdropPreset(
    id: 'berry',
    darkBase: Color(0xFF0A0610),
    lightBase: Color(0xFFF7F1F7),
    blobs: [
      AppBackdropBlob(.90, .36, .60, 0, Color(0xFF7C1E5E), Color(0xFFFFCDE9)),
      AppBackdropBlob(1.20, .40, .30, 1.0, Color(0xFF2A1E7C), Color(0xFFD4D3FF)),
    ],
  ),
  AppBackdropPreset(
    id: 'amber',
    darkBase: Color(0xFF0C0907),
    lightBase: Color(0xFFF9F4EC),
    blobs: [
      AppBackdropBlob(.70, .40, .10, .40, Color(0xFF7C5A1A), Color(0xFFFFE6BC)),
      AppBackdropBlob(.60, .34, .95, .92, Color(0xFF7C2E3A), Color(0xFFFFD3D3)),
    ],
  ),
];

/// Выбранный фон или `null` — «По теме» (прежний градиент).
AppBackdropPreset? resolveAppBackdrop(String? id) {
  for (final p in kAppBackdropPresets) {
    if (p.id == id) return p;
  }
  return null;
}

bool isValidAppBackdropId(String id) =>
    id == kAppBackdropTheme || resolveAppBackdrop(id) != null;

class AppBackdropPainter extends CustomPainter {
  const AppBackdropPainter({required this.preset, required this.dark});

  final AppBackdropPreset preset;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = preset.base(dark));
    final shader = RadialGradient(
      colors: const [Colors.white, Color(0x00FFFFFF)],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    for (final b in preset.blobs) {
      final color = dark ? b.dark : b.light;
      canvas.save();
      canvas.clipRect(rect);
      canvas.translate(b.x * size.width, b.y * size.height);
      canvas.scale(b.w * size.width, b.h * size.height);
      // Один белый радиальный шейдер, окрашенный через modulate: без нового
      // шейдера на каждое пятно.
      canvas.drawRect(
        const Rect.fromLTRB(-1, -1, 1, 1),
        Paint()
          ..shader = shader
          ..colorFilter = ColorFilter.mode(color, BlendMode.modulate),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(AppBackdropPainter old) =>
      old.preset.id != preset.id || old.dark != dark;
}

/// Фон за [child]: кешируется отдельным слоем, прокрутка его не трогает.
/// [preset] `null` — фона нет, но форма дерева та же: смена фона не
/// пересоздаёт [child] и не сбрасывает его состояние.
class AppBackdropLayer extends StatelessWidget {
  const AppBackdropLayer({
    super.key,
    required this.preset,
    required this.dark,
    required this.child,
  });

  final AppBackdropPreset? preset;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: preset == null
                  ? null
                  : AppBackdropPainter(preset: preset!, dark: dark),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
