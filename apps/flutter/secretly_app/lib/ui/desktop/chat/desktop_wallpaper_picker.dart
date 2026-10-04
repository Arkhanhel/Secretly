// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ОБОИ НА ПК: ТОТ ЖЕ НАБОР, ЧТО НА ТЕЛЕФОНЕ, И ОБОИ ДЛЯ ОТДЕЛЬНОГО ЧАТА.
///
/// 🔴 ЗАЧЕМ (28.09.2026, владелец: «нет обоев всех, которые есть в мобильной
/// версии» и «внутри чата нельзя поменять обои сугубо для этого чата»).
///
/// Раньше список на ПК был собран вручную: не было «Классики», стандартных
/// `chat_default`, фото из профиля и серверных обоев, а пять светлых не
/// открывались вовсе — путь строился без `improved_light/`. Обоев чата не было:
/// ключ `chat_wallpaper_v1_<чат>`, который телефон пишет давно, ПК не читал.
///
/// Здесь — список (чистая функция, по тем же правилам, что у телефона: обои
/// текущей темы, избранные первыми), сетка с настоящими превью, окно выбора
/// обоев чата и хранилище выбора по чатам с тем же ключом, что у телефона.
/// Контроллер сюда не приходит: данные передаёт вызывающий.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat_wallpapers.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_dialog.dart';
import 'desktop_wallpaper.dart';
import 'desktop_wallpaper_tiling.dart';

/// Один вариант обоев.
@immutable
class DesktopWallpaperChoice {
  const DesktopWallpaperChoice({
    required this.id,
    required this.title,
    this.premium = false,
  });

  final String id;
  final String title;

  /// Платный вариант: живые и серверные обои.
  final bool premium;
}

/// Подпись картинки из набора приложения.
String desktopWallpaperAssetTitle(String basename, AppLocalizations l10n) {
  switch (basename) {
    case 'wallpaper_dark_navy.jpg':
      return l10n.desktopWallpaperNavy;
    case 'wallpaper_dark_graphite.jpg':
      return l10n.desktopWallpaperGraphite;
    case 'wallpaper_dark_teal.jpg':
      return l10n.desktopWallpaperTeal;
    case 'wallpaper_dark_plum.jpg':
      return l10n.desktopWallpaperPlum;
    case 'wallpaper_dark_wine.jpg':
      return l10n.desktopWallpaperWine;
    case 'wallpaper_light_mint.jpg':
      return l10n.desktopWallpaperMint;
    case 'wallpaper_light_lavender.jpg':
      return l10n.desktopWallpaperLavender;
    case 'wallpaper_light_sunset.jpg':
      return l10n.desktopWallpaperSunset;
    case 'wallpaper_light_peach.jpg':
      return l10n.desktopWallpaperPeach;
    case 'wallpaper_light_sky.jpg':
      return l10n.desktopWallpaperSky;
    case 'chat_default.jpg':
      return l10n.desktopWallpaperStandard;
    default:
      return p.basenameWithoutExtension(basename);
  }
}

/// Список вариантов — по правилам телефона (`buildChatWallpaperOptions`):
/// «Как в настройках» (для чата), «Классика», «Ночной», живые, картинки
/// ТЕКУЩЕЙ темы (избранные первыми), фото из профиля, серверные.
List<DesktopWallpaperChoice> buildDesktopWallpaperChoices({
  required AppLocalizations l10n,
  required bool dark,
  required List<String> bundledAssets,
  List<String> profileFiles = const <String>[],
  List<({String id, String title})> server =
      const <({String id, String title})>[],
  bool includeGlobal = false,
}) {
  final out = <DesktopWallpaperChoice>[
    if (includeGlobal)
      DesktopWallpaperChoice(
        id: kGlobalChatWallpaperSelectionId,
        title: l10n.desktopWallpaperUseDefault,
      ),
    DesktopWallpaperChoice(id: 'default', title: l10n.desktopWallpaperClassic),
    DesktopWallpaperChoice(
      id: 'midnight',
      title: l10n.desktopWallpaperMidnight,
    ),
    for (final style in WallpaperStyles.all)
      DesktopWallpaperChoice(
        id: encodeAnimatedChatWallpaperId(style.key),
        title: style.name,
        premium: true,
      ),
  ];

  bool featured(String path) =>
      kFeaturedChatWallpaperBasenames.any((b) => path.endsWith('/$b'));
  final ordered = <String>[
    for (final b in kFeaturedChatWallpaperBasenames)
      ...bundledAssets.where((path) => path.endsWith('/$b')),
    ...bundledAssets.where((path) => !featured(path)),
  ];
  final seen = <String>{};
  for (final path in ordered) {
    final clean = path.trim();
    if (clean.isEmpty || !seen.add(clean)) continue;
    final forTheme = dark
        ? isDarkThemeChatWallpaperAssetPath(clean)
        : isLightThemeChatWallpaperAssetPath(clean);
    if (!forTheme) continue;
    out.add(
      DesktopWallpaperChoice(
        id: encodeAssetChatWallpaperId(clean),
        title: desktopWallpaperAssetTitle(p.basename(clean), l10n),
      ),
    );
  }

  var n = 0;
  for (final file in profileFiles) {
    final clean = file.trim();
    if (clean.isEmpty || !File(clean).existsSync()) continue;
    n++;
    out.add(
      DesktopWallpaperChoice(
        id: encodeFileChatWallpaperId(clean),
        title: l10n.desktopWallpaperProfilePhoto(n),
      ),
    );
  }

  for (final item in server) {
    final id = item.id.trim();
    if (id.isEmpty) continue;
    out.add(
      DesktopWallpaperChoice(
        id: encodeServerChatWallpaperId(id),
        title: item.title.trim().isEmpty ? 'Premium' : item.title.trim(),
        premium: true,
      ),
    );
  }
  return out;
}

/// Сетка с настоящими превью.
class DesktopWallpaperGrid extends StatelessWidget {
  const DesktopWallpaperGrid({
    super.key,
    required this.choices,
    required this.selectedId,
    required this.onPick,
    this.isLocked,
    this.globalPreviewId,
    this.shrinkWrap = true,
  });

  final List<DesktopWallpaperChoice> choices;
  final String selectedId;
  final ValueChanged<String> onPick;

  /// Платный вариант без подписки — с замком; нажатие всё равно приходит в
  /// [onPick], решает вызывающий (сказать «доступно с Premium»).
  final bool Function(String id)? isLocked;

  /// Что показывать на плитке «Как в настройках».
  final String? globalPreviewId;

  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    // Плитки 3:4 — как в «Внешнем виде» и как на телефоне: обои рисуются на
    // вытянутом вверх окне переписки, и узор на плитке той же пропорции
    // выглядит так, как будет выглядеть в чате.
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: choices.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 124,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (ctx, i) {
        final choice = choices[i];
        return DesktopWallpaperTile(
          choice: choice,
          selected: choice.id == selectedId,
          locked: isLocked?.call(choice.id) ?? false,
          previewId: choice.id == kGlobalChatWallpaperSelectionId
              ? (globalPreviewId ?? 'default')
              : choice.id,
          onTap: () => onPick(choice.id),
        );
      },
    );
  }
}

/// Плитка обоев: САМИ обои, метка «LIVE», галочка или замок, имя.
///
/// 🔴 ПРЕВЬЮ — НАСТОЯЩИЕ ОБОИ, А НЕ ИХ ЦВЕТА (30.09.2026, владелец: «превью
/// фонов не те, что у нас на самом деле»). Живые обои рисовались переходом
/// двух цветов стиля — ярким пятном, на которое настоящие тёмные обои с узором
/// не похожи вовсе. Теперь плитка рисуется тем же [buildDesktopChatWallpaper],
/// что и лента, только неподвижным кадром (`preview: true`), — ровно так
/// делает и телефон (`wallpaper_picker_sheet.dart`). Картинки узора у всех
/// плиток общие и декодируются один раз, анимации на плитках нет.
class DesktopWallpaperTile extends StatelessWidget {
  const DesktopWallpaperTile({
    super.key,
    required this.choice,
    required this.selected,
    required this.locked,
    required this.onTap,
    String? previewId,
  }) : previewId = previewId ?? '';

  final DesktopWallpaperChoice choice;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  /// Что рисовать; пусто — сам [choice].
  final String previewId;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final id = previewId.isEmpty ? choice.id : previewId;
    final live = decodeAnimatedChatWallpaperStyle(id) != null;
    return Semantics(
      button: true,
      selected: selected,
      label: choice.title,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: _HoverBrighten(
            child: AnimatedContainer(
              duration: DMotion.fast,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: selected ? c.accentPrimary : c.borderSubtle,
                    spreadRadius: selected ? 2 : 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: DesktopWallpaperPreview(wallpaperId: id),
                    ),
                    if (live)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.desktopAppearanceLiveBadge,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: DType.family,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: c.accentPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            FluentIcons.checkmark_12_filled,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else if (locked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            FluentIcons.lock_closed_12_filled,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x8C000000)],
                          ),
                        ),
                        child: Text(
                          choice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: DType.family,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Неподвижный кадр обоев — теми же средствами, что и лента переписки.
///
/// Палитра — окна (`DColors`), а не страницы вокруг: внутри настроек стоит
/// подменённая серая палитра, и «Ночной» (однотонный фон окна) иначе
/// нарисовался бы цветом страницы настроек.
/// Во сколько раз крупнее показывать живые обои в плитке выбора.
const double kDesktopLiveWallpaperPreviewZoom = 1.0;

class DesktopWallpaperPreview extends StatelessWidget {
  const DesktopWallpaperPreview({
    super.key,
    required this.wallpaperId,
    this.palette,
  });

  final String wallpaperId;

  /// Палитра окна; `null` — окружающая.
  final DColorSet? palette;

  @override
  Widget build(BuildContext context) {
    final c = palette ?? DesktopWallpaperPalette.of(context);
    final wallpaper = buildDesktopChatWallpaper(
      context,
      wallpaperId: wallpaperId,
      palette: c,
      preview: true,
    );
    // 🔴 О1 (30.09.2026): узор на ПК идёт по ВЫСОТЕ области. Вытянутая вверх
    // плитка (3:4) и есть уменьшенное окно переписки — ей ничего не нужно. А
    // плоская карточка набора во «Внешнем виде» (64 px в высоту) по своей
    // высоте дала бы колонки по 36 px и рябь вместо дудлов. Поэтому плоская
    // плитка показывает среднюю полосу окна не площе 4:3 — масштаб как в чате.
    // 🔴 Живые обои — крупным планом (30.09.2026). Их узор — тонкие цветные
    // линии на чёрном; уменьшенный до плитки весь чат превращал их в сплошную
    // черноту, и пять живых обоев было не отличить. Плитка показывает
    // середину чата втрое выше себя — той же отрисовкой, что в чате, только
    // кусок, а не всё окно: цвет линий и узор видны, как в переписке.
    //
    // 01.10.2026: узор живых обоев на ПК теперь постоянного размера (см.
    // `kDesktopWallpaperTileHeight`), поэтому плитка сама показывает кусок
    // чата в настоящем масштабе — увеличение больше не нужно, иначе дудлы
    // вышли бы втрое крупнее, чем в переписке.
    final zoom = decodeAnimatedChatWallpaperStyle(wallpaperId) != null
        ? kDesktopLiveWallpaperPreviewZoom
        : 1.0;
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth || !box.hasBoundedHeight) return wallpaper;
        final height = desktopWallpaperPreviewHeight(box.biggest) * zoom;
        final width = box.maxWidth * zoom;
        if (height <= box.maxHeight && width <= box.maxWidth) return wallpaper;
        return ClipRect(
          child: OverflowBox(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: wallpaper,
          ),
        );
      },
    );
  }
}

/// Палитра, которой рисовать превью обоев: окна, если её передали выше
/// (настройки передают палитру окна поверх своей серой), иначе окружающая.
class DesktopWallpaperPalette extends InheritedWidget {
  const DesktopWallpaperPalette({
    super.key,
    required this.colors,
    required super.child,
  });

  final DColorSet colors;

  static DColorSet of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DesktopWallpaperPalette>()
          ?.colors ??
      DColors.of(context);

  @override
  bool updateShouldNotify(DesktopWallpaperPalette oldWidget) =>
      oldWidget.colors != colors;
}

/// Лёгкая подсветка плитки под мышью.
class _HoverBrighten extends StatefulWidget {
  const _HoverBrighten({required this.child});

  final Widget child;

  @override
  State<_HoverBrighten> createState() => _HoverBrightenState();
}

class _HoverBrightenState extends State<_HoverBrighten> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: DMotion.fast,
                opacity: _hover ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Окно «Обои чата»: первым — «Как в настройках». Возвращает выбранный id
/// ([kGlobalChatWallpaperSelectionId] — вернуть общие) или `null`.
Future<String?> showDesktopChatWallpaperDialog(
  BuildContext context, {
  required List<DesktopWallpaperChoice> choices,
  required String selectedId,
  required String globalPreviewId,
  bool Function(String id)? isLocked,
}) {
  final l10n = AppLocalizations.of(context)!;
  return DesktopDialog.show<String>(
    context,
    title: l10n.desktopChatWallpaperTitle,
    size: DDialogSize.large,
    body: SizedBox(
      height: 440,
      child: DesktopWallpaperGrid(
        choices: choices,
        selectedId: selectedId,
        globalPreviewId: globalPreviewId,
        isLocked: isLocked,
        shrinkWrap: false,
        onPick: (id) => Navigator.of(context).maybePop(id),
      ),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// Обои отдельных чатов — тот же ключ, что у телефона
/// (`chat_screen.dart`, `_wallpaperPrefKey`): `chat_wallpaper_v1_<чат>`.
/// Нет ключа — «как в настройках». Выбор остаётся на этом устройстве, как и у
/// телефона; резервная копия его уже несёт.
abstract final class DesktopChatWallpapers {
  static const String prefix = 'chat_wallpaper_v1_';

  static final Map<String, String> _byChat = <String, String>{};

  /// Меняется при каждом выборе — переписка перерисовывается сразу.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(prefix)) continue;
        final value = prefs.getString(key)?.trim() ?? '';
        if (value.isNotEmpty && isValidChatWallpaperId(value)) {
          _byChat[key.substring(prefix.length)] = value;
        }
      }
      _loaded = true;
      revision.value++;
    } catch (_) {
      // Без настроек — общие обои везде, как было.
    }
  }

  /// Выбор этого чата или [kGlobalChatWallpaperSelectionId].
  static String selectionFor(String convoId) =>
      _byChat[convoId.trim()] ?? kGlobalChatWallpaperSelectionId;

  static Future<void> set(String convoId, String id) async {
    final key = convoId.trim();
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (id == kGlobalChatWallpaperSelectionId) {
      _byChat.remove(key);
      await prefs.remove('$prefix$key');
    } else {
      _byChat[key] = id;
      await prefs.setString('$prefix$key', id);
    }
    revision.value++;
  }

  @visibleForTesting
  static void resetForTest() {
    _byChat.clear();
    _loaded = false;
  }
}

/// Какие обои рисовать в чате: выбор чата, иначе общие; платный вариант без
/// подписки — общие (выбор чата сохраняется и вернётся с продлением).
String desktopEffectiveChatWallpaperId({
  required String chatSelection,
  required String globalId,
  required bool Function(String id) usable,
}) {
  final resolved = resolveEffectiveChatWallpaperId(
    selectionId: chatSelection,
    defaultId: globalId,
  );
  return usable(resolved) ? resolved : globalId;
}
