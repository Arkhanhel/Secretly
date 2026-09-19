// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// НАБОР СТИКЕРОВ: ПОСМОТРЕТЬ, ПОСТАВИТЬ СЕБЕ, ОТПРАВИТЬ ИЗ НЕГО.
///
/// 🔴 ЗАЧЕМ. Присланный стикер на компьютере был просто картинкой: нажатие не
/// делало ничего, и ПОСТАВИТЬ СЕБЕ чужой набор было нельзя вовсе — только с
/// телефона. На телефоне это главный способ набора вообще расходиться: увидел
/// у собеседника, нажал, добавил.
///
/// 🔴 ПОЧЕМУ ОКНО НИЧЕГО НЕ ЗНАЕТ ПРО КОНТРОЛЛЕР. Оно получает готовый снимок
/// состояния и два действия. Так окно проверяется тестом без приложения
/// целиком, а связь с контроллером остаётся в одном месте — там, где она уже
/// есть. Живость даёт [changed]: установка идёт кусками, и число «принято из
/// стольких-то» должно расти на глазах, иначе окно выглядит замершим.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../stickers/sticker_catalog.dart'
    show SecretlyStickerDescriptor;
import '../../widgets/secretly_sticker_widgets.dart'
    show SecretlyStickerAssetView;
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/hover_listener.dart';

/// Почему набор нельзя поставить — или можно.
enum DesktopStickerPackAvailability {
  /// Чужой набор, ещё не наш: кнопка работает.
  canInstall,

  /// Уже стоит.
  installed,

  /// Наш собственный — ставить нечего.
  own,

  /// Автор неизвестен (стикер пришёл в группу без отметки об авторе): просить
  /// набор не у кого, и кнопка бы обманывала.
  noAuthor,
}

@immutable
class DesktopStickerPackView {
  const DesktopStickerPackView({
    required this.title,
    required this.total,
    required this.stickers,
    required this.availability,
    this.inFlight = false,
    this.received = 0,
    this.expected = 0,
  });

  final String title;

  /// Сколько стикеров в наборе ПО ЗАМЫСЛУ автора — может быть больше, чем
  /// пришло: до установки у нас есть только нажатый.
  final int total;
  final List<SecretlyStickerDescriptor> stickers;
  final DesktopStickerPackAvailability availability;
  final bool inFlight;
  final int received;
  final int expected;

  /// Сколько плиток дорисовать пустыми, чтобы размер набора был виден ДО
  /// установки. Ограничено, иначе окно растянет набор на тысячу.
  int get missing => availability == DesktopStickerPackAvailability.installed
      ? 0
      : (total - stickers.length).clamp(0, 16);
}

class DesktopStickerPackDialog extends StatelessWidget {
  const DesktopStickerPackDialog({
    super.key,
    required this.changed,
    required this.snapshot,
    required this.onInstall,
    required this.onSend,
  });

  /// Тик контроллера: на нём окно пересчитывает снимок.
  final Stream<void> changed;
  final DesktopStickerPackView Function() snapshot;
  final Future<void> Function() onInstall;
  final Future<void> Function(SecretlyStickerDescriptor) onSend;

  static Future<void> show({
    required BuildContext context,
    required Stream<void> changed,
    required DesktopStickerPackView Function() snapshot,
    required Future<void> Function() onInstall,
    required Future<void> Function(SecretlyStickerDescriptor) onSend,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'sticker-pack',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: DMotion.medium,
      pageBuilder: (ctx, a, b) => Center(
        child: DesktopStickerPackDialog(
          changed: changed,
          snapshot: snapshot,
          onInstall: onInstall,
          onSend: onSend,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: changed,
      builder: (ctx, _) => _card(ctx, snapshot()),
    );
  }

  Widget _card(BuildContext context, DesktopStickerPackView v) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: c.detailsPanel,
          borderRadius: BorderRadius.circular(DRadii.lg),
          border: Border.all(color: c.borderSubtle),
        ),
        padding: const EdgeInsets.all(DSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(c, l10n, v),
            const SizedBox(height: DSpace.m),
            Flexible(child: _grid(context, c, v)),
            const SizedBox(height: DSpace.m),
            _action(context, c, l10n, v),
          ],
        ),
      ),
    );
  }

  Widget _header(DColorSet c, AppLocalizations l10n, DesktopStickerPackView v) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.title.isEmpty ? l10n.desktopStickerPackTitle : v.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.bodyStrong.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.desktopStickerPackCount(v.total),
                style: DType.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    DColorSet c,
    DesktopStickerPackView v,
  ) {
    final tiles = v.stickers.length + v.missing;
    if (tiles == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DSpace.l),
        child: Text(
          AppLocalizations.of(context)!.desktopStickerPackTitle,
          textAlign: TextAlign.center,
          style: DType.label.copyWith(color: c.textSecondary),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: DSpace.s,
        crossAxisSpacing: DSpace.s,
      ),
      itemCount: tiles,
      itemBuilder: (ctx, i) {
        if (i >= v.stickers.length) return _placeholder(c);
        final s = v.stickers[i];
        return HoverListener(
          onTap: () {
            Navigator.of(ctx).maybePop();
            unawaited(onSend(s));
          },
          builder: (hctx, hovered, pressed) => AnimatedContainer(
            duration: DMotion.fast,
            decoration: BoxDecoration(
              color: hovered ? c.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(DRadii.sm),
            ),
            padding: const EdgeInsets.all(4),
            child: SecretlyStickerAssetView(sticker: s, size: 72),
          ),
        );
      },
    );
  }

  /// Пустая плитка: место стикера, который приедет при установке.
  Widget _placeholder(DColorSet c) {
    return Container(
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.sm),
        border: Border.all(color: c.borderSubtle),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    DColorSet c,
    AppLocalizations l10n,
    DesktopStickerPackView v,
  ) {
    switch (v.availability) {
      case DesktopStickerPackAvailability.installed:
        return DesktopButton(
          label: l10n.desktopStickerPackInstalled,
          icon: null,
          onPressed: null,
        );
      case DesktopStickerPackAvailability.own:
        return Text(
          l10n.desktopStickerPackOwn,
          textAlign: TextAlign.center,
          style: DType.label.copyWith(color: c.textSecondary),
        );
      case DesktopStickerPackAvailability.noAuthor:
        return Text(
          l10n.desktopStickerPackNoAuthor,
          textAlign: TextAlign.center,
          style: DType.caption.copyWith(color: c.textSecondary, height: 1.35),
        );
      case DesktopStickerPackAvailability.canInstall:
        if (v.inFlight) {
          // Число «принято из стольких-то» появляется не сразу: сперва автор
          // должен ответить, сколько их. До ответа — просто «Установка…», а не
          // «0 из 0», которое читается как поломка.
          return DesktopButton(
            label: v.expected > 0
                ? l10n.desktopStickerPackInstallingProgress(
                    v.received,
                    v.expected,
                  )
                : l10n.desktopStickerPackInstalling,
            icon: null,
            onPressed: null,
          );
        }
        return DesktopButton(
          label: v.total > 0
              ? l10n.desktopStickerPackAdd(v.total)
              : l10n.desktopStickerPackAddPlain,
          icon: null,
          onPressed: () => unawaited(onInstall()),
        );
    }
  }
}
