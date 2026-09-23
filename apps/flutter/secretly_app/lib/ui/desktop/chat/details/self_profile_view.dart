// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../../l10n/app_localizations.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../../app/app_controller.dart';
import '../../../premium/cosmetics_catalog.dart'
    show
        coverBackWidgetFor,
        coverFrontWidgetFor,
        coverWidgetFor,
        kAllAvatarFrames,
        kProfileCovers;
import '../../design/tokens.dart';
import '../../primitives/avatar.dart';
import '../../primitives/desktop_tooltip.dart';
import '../../primitives/context_menu.dart';
import '../../primitives/desktop_button.dart';
import '../../primitives/desktop_dialog.dart';
import '../../primitives/desktop_snackbar.dart';
import '../../primitives/desktop_text_field.dart';
import '../../primitives/hover_listener.dart';
import 'avatar_preview_dialog.dart';
import 'details_action_row.dart';
import 'details_header.dart';
import 'details_headline.dart';
import 'details_info_section.dart';

/// Мой профиль — В ПРАВОЙ ПАНЕЛИ, а не отдельной страницей.
///
/// 🔴 ПОЧЕМУ ПЕРЕЕХАЛО (13.09.2026, прямое указание владельца). Свой профиль
/// открывался поверх всего окна отдельным «рабочим столом» с боковым списком
/// разделов — то есть так, как не открывается больше ни один профиль в этом
/// приложении. Чужой профиль живёт в правой панели, комната живёт в правой
/// панели, а свой почему-то закрывал собой переписку целиком.
///
/// Теперь он ровно там же и выглядит так же: обложка, портрет с рамкой, имя,
/// строка действий, разделы. Разница только в том, что здесь всё можно
/// изменить — и каждое изменение открывается ОТДЕЛЬНЫМ МАЛЕНЬКИМ ОКНОМ
/// посередине, а не уводит человека с экрана переписки.
class SelfProfileView extends StatefulWidget {
  const SelfProfileView({
    super.key,
    required this.controller,
    required this.onClose,
    this.onOpenDeviceSettings,
    this.onOpenAppearanceSettings,
  });

  final AppController controller;
  final VoidCallback onClose;

  /// Открыть настройки на разделе «Сессии и устройства».
  ///
  /// 🔴 Строка «Устройства» здесь была и НИЧЕГО не открывала: вместо действия
  /// в ней было написано «Настройки → Устройства», то есть маршрут словами.
  /// Нет обработчика — строки нет вовсе: указатель в никуда хуже отсутствия
  /// указателя.
  final VoidCallback? onOpenDeviceSettings;

  /// Открыть настройки на разделе «Внешний вид».
  ///
  /// 🔴 ССЫЛКА, А НЕ КОПИЯ ОРГАНОВ УПРАВЛЕНИЯ. В макете тема, акцент и рамка
  /// стоят на одном экране профиля. Рамка здесь и есть — она про ЭТОТ
  /// профиль и живёт только тут. А тема и акцент — настройки ОКНА, и у них
  /// уже есть своё место в настройках; поставить те же переключатели ещё и
  /// сюда значило бы завести один выбор в двух местах, ровно как было с
  /// подтемами комнаты и с выходом из аккаунта.
  final VoidCallback? onOpenAppearanceSettings;

  @override
  State<SelfProfileView> createState() => _SelfProfileViewState();
}

/// Как украшение выглядит — портретом с рамкой или полоской обложки.
class _CosmeticPreview extends StatelessWidget {
  const _CosmeticPreview({
    required this.id,
    required this.frame,
    required this.name,
    required this.avatarPath,
  });

  /// `null` — «без рамки» / «без обложки»: показываем голый портрет и пустую
  /// полоску, чтобы отказ тоже был виден глазом.
  final String? id;
  final bool frame;
  final String name;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (frame) {
      return Avatar(
        name: name,
        image: Avatar.fileImage(avatarPath),
        frameId: id,
        // В сетке рамок кадров десяток: анимировать их все разом — это та
        // самая вечная перерисовка, которой в этом окне уже платили
        // процентами процессора.
        allowAnimatedFrame: false,
        size: 54,
      );
    }
    final cover = coverWidgetFor(id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DRadii.sm),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: cover ?? ColoredBox(color: c.bg),
      ),
    );
  }
}

class _SelfProfileViewState extends State<SelfProfileView> {
  /// Подписи своего профиля.
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// Фото, которое здесь показывается. Не `controller.myAvatarPath`: на
  /// спаренном компьютере своего файла нет — лицо приезжает вместе с
  /// метаданными профиля, и показать надо именно его.
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    unawaited(_reloadAvatar());
    // 🔴 Открыли свой профиль — забираем СВЕЖЕЕ опубликованное лицо.
    //
    // Рамка, обложка, ник и эмодзи-статус живут у каждого устройства своей
    // копией и догоняют друг друга обходом раз в десять минут. Этого хватает,
    // чтобы устройства сошлись сами, но мало, когда человек СМОТРИТ на свой
    // профиль: он ждёт правды сейчас, а не через десять минут.
    unawaited(widget.controller.refreshMyProfileMetaNow());
  }

  Future<void> _reloadAvatar() async {
    final path = await widget.controller.resolvedOwnAvatarPath();
    if (!mounted) return;
    setState(() => _avatarPath = path);
  }

  AppController get _c => widget.controller;

  // ── Мини-окна ──────────────────────────────────────────────────────

  /// Правка одной строки профиля отдельным окном.
  ///
  /// Поле ввода прямо в панели шириной 330 точек читается плохо, а «О себе»
  /// там и вовсе не помещается. Окно посередине даёт тексту место и ясно
  /// отделяет правку от просмотра.
  Future<void> _editLine({
    required String title,
    required String initial,
    required int maxLength,
    required Future<void> Function(String value) save,
    bool multiline = false,
  }) async {
    final ctrl = TextEditingController(text: initial);
    try {
      final saved = await DesktopDialog.show<String>(
        context,
        title: title,
        size: DDialogSize.small,
        body: DesktopTextField(
          controller: ctrl,
          autofocus: true,
          maxLength: maxLength,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 5 : 1,
          onSubmitted: multiline
              ? null
              : (v) => Navigator.of(context).maybePop(v),
        ),
        primary: DDialogAction(
          label: l10n.saveAction,
          onPressed: () => Navigator.of(context).maybePop(ctrl.text),
        ),
        secondary: DDialogAction(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
      if (saved == null || !mounted) return;
      await save(saved.trim());
      if (mounted) setState(() {});
    } finally {
      ctrl.dispose();
    }
  }

  /// Emoji-status picker. A short curated set beats a full emoji keyboard
  /// here: a status is a mood marker, not free-form input, and the row must
  /// also offer a way to REMOVE it — otherwise a status set once could never
  /// be cleared.
  Future<void> _pickEmojiStatus() async {
    const options = <String>[
      '😀', '😎', '🥳', '🤝', '💼', '📚', '🎧', '🎮', //
      '✈️', '🏖️', '🌙', '☕', '🔥', '💡', '❤️', '🫡',
    ];
    final current = _c.myEmojiStatus ?? '';
    final picked = await DesktopDialog.show<String>(
      context,
      title: l10n.desktopProfileEmojiStatus,
      size: DDialogSize.small,
      body: Wrap(
        spacing: DSpace.s,
        runSpacing: DSpace.s,
        children: [
          for (final e in options)
            HoverListener(
              onTap: () => Navigator.of(context).maybePop(e),
              builder: (ctx, hovered, pressed) => Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e == current
                      ? DColors.of(ctx).accentPrimary.withValues(alpha: 0.20)
                      : (hovered ? DColors.of(ctx).hover : Colors.transparent),
                  borderRadius: BorderRadius.circular(DRadii.md),
                ),
                child: Text(e, style: const TextStyle(fontSize: 22)),
              ),
            ),
        ],
      ),
      primary: current.isEmpty
          ? null
          : DDialogAction(
              label: l10n.desktopProfileClearStatus,
              kind: DButtonKind.tonal,
              onPressed: () => Navigator.of(context).maybePop(''),
            ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    if (picked == null || !mounted) return;
    await _c.setMyEmojiStatus(picked.isEmpty ? null : picked);
    if (mounted) setState(() {});
  }

  /// Применить рамку из полосы в панели — тем же путём, что и выбор в сетке.
  ///

  /// Frame / cover picker. Both are premium cosmetics; the controller's
  /// getters already return null when the tier does not allow them, so a
  /// lapsed subscription simply stops rendering the choice rather than
  /// losing it.
  Future<void> _pickCosmetic({required bool frame}) async {
    final currentId = frame ? _c.myFrameId : _c.myCoverId;
    final name = _c.myNickname.trim();
    final display = name.isEmpty ? 'Secretly' : name;
    final avatarPath = (_avatarPath ?? '').trim();
    final hasAvatar = avatarPath.isNotEmpty;
    final ids = <String?>[
      null, // «Без рамки» / «Без обложки» — removal must always be reachable
      ...(frame
          ? kAllAvatarFrames.map((f) => f.id)
          : kProfileCovers.map((c) => c.id)),
    ];
    final picked = await DesktopDialog.show<String>(
      context,
      title: frame ? l10n.desktopProfileAvatarFrame : l10n.desktopProfileCover,
      size: DDialogSize.medium,
      body: SizedBox(
        height: 320,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: DSpace.s,
            crossAxisSpacing: DSpace.s,
            // Под превью нужна высота: квадратная плитка держит и рамку на
            // портрете, и полоску обложки.
            childAspectRatio: 0.95,
          ),
          itemCount: ids.length,
          itemBuilder: (ctx, i) {
            final id = ids[i];
            final selected = id == currentId;
            final label = id == null
                ? (frame ? l10n.desktopProfileNoFrame : l10n.desktopProfileNoCover)
                : (frame
                      // 🔴 Не `name(true)`: подпись плитки — это подпись
                      // окна, а окно переведено на восемь языков. Русское имя
                      // здесь оставалось единственной строкой, которая не
                      // слушалась выбора языка.
                      ? kAllAvatarFrames
                            .firstWhere((f) => f.id == id)
                            .nameLocalized(ctx)
                      : kProfileCovers
                            .firstWhere((c) => c.id == id)
                            .nameLocalized(ctx));
            return HoverListener(
              // Sentinel: DesktopDialog.show returns null when DISMISSED, so
              // "no frame" cannot also be null or the two would be identical.
              onTap: () => Navigator.of(ctx).maybePop(id ?? '__none'),
              builder: (c2, hovered, pressed) => Container(
                padding: const EdgeInsets.all(DSpace.xs),
                decoration: BoxDecoration(
                  color: selected
                      ? DColors.of(ctx).accentPrimary.withValues(alpha: 0.18)
                      : (hovered
                            ? DColors.of(ctx).hover
                            : DColors.of(ctx).elevated),
                  borderRadius: BorderRadius.circular(DRadii.md),
                  border: Border.all(
                    color: selected
                        ? DColors.of(ctx).accentPrimary
                        : DColors.of(ctx).borderSubtle,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔴 УКРАШЕНИЕ ВЫБИРАЮТ ГЛАЗАМИ, А НЕ ПО СПИСКУ ИМЁН.
                    //
                    // Здесь стоял один текст: «Аврора», «Космос», «Пульс» —
                    // и человек, который за эти рамки платит, узнавал, как
                    // они выглядят, только применив каждую по очереди. Показ
                    // ничего не стоит: и рамка, и обложка умеют рисовать себя
                    // сами (`builder`), тем же кодом, что и в профиле.
                    _CosmeticPreview(
                      id: id,
                      frame: frame,
                      name: display,
                      avatarPath: hasAvatar ? avatarPath : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.tiny.copyWith(
                        color: DColors.of(ctx).textPrimary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    if (picked == null || !mounted) return;
    final value = picked == '__none' ? null : picked;
    try {
      if (frame) {
        await _c.setMyFrame(value);
      } else {
        await _c.setMyCover(value);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopProfileApplyFailed('$e'),
        kind: DSnackKind.error,
      );
    }
  }

  /// Picks a new avatar from disk.
  ///
  /// Bytes go through the shared setter, which downscales and re-encodes on a
  /// worker, so a 12-megapixel photo does not become the profile picture
  /// verbatim.
  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        DesktopSnackbar.show(
          context,
          message: l10n.desktopProfileReadFailed,
          kind: DSnackKind.error,
        );
        return;
      }
      await _c.setMyAvatarFromImageBytes(bytes);
      if (!mounted) return;
      await _reloadAvatar();
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopProfilePhotoUpdated,
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopProfilePhotoFailed('$e'),
        kind: DSnackKind.error,
      );
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await _c.removeMyAvatar();
      if (!mounted) return;
      await _reloadAvatar();
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopProfilePhotoRemoveFailed('$e'),
        kind: DSnackKind.error,
      );
    }
  }

  // ── Разметка ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = _c.myNickname.trim();
    final display = name.isEmpty ? 'Secretly' : name;
    final bio = _c.myBio.trim();
    final id = _c.profileId;
    final hasLocalAvatar = (_c.myAvatarPath ?? '').trim().isNotEmpty;
    final colors = DColors.of(context);
    final avatarPath = (_avatarPath ?? '').trim();
    final hasAvatar = avatarPath.isNotEmpty;

    return Column(
      children: [
        DetailsHeader(
          title: l10n.desktopProfileMine,
          // Идентификатор переехал под имя (макет): здесь он был бы вторым
          // разом на одном экране, а повтор читается как две разные строки.
          subtitle: null,
          onClose: widget.onClose,
          menuSections: const <List<CtxMenuItem>>[],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DetailsHeadline(
                  name: display,
                  // ◆ ПОД ИМЕНЕМ — ИДЕНТИФИКАТОР, а не присутствие (макет).
                  //
                  // Своё присутствие и так очевидно: человек сидит перед этим
                  // окном. А свой Secretly ID — единственное, чем он делится,
                  // чтобы с ним связались, и искать его в «Информации» ниже
                  // приходилось каждый раз.
                  idLine: _c.profileId,
                  // ◆ «Редактировать» — ПЛИТКОЙ В ВЕРХНЕМ РЯДУ, слева от
                  // обложки (решение владельца 23.09.2026).
                  //
                  // Была кнопка с подписью рядом с именем. Она стояла в потоке
                  // содержимого и отодвигала портрет вниз, а читалась как часть
                  // имени, хотя относится ко всему профилю. Наверху уже лежат
                  // кнопки про панель и обложку — правка профиля из того же
                  // разряда, и там она ничего не смещает.
                  //
                  // Сама правка прежняя: это по-прежнему вход в «Имя», и строки
                  // «Имя» и «О себе» ниже никуда не делись.
                  onEdit: () => unawaited(
                    _editLine(
                      title: l10n.desktopProfileName,
                      initial: name,
                      maxLength: 40,
                      save: (v) => _c.setMyNickname(v),
                    ),
                  ),
                  // 🔴 ДВА СЛОЯ, КАК НА ТЕЛЕФОНЕ. Задний — сцена без ближнего
                  // края диска, передний — сам край, он проходит ПЕРЕД лицом, и
                  // портрет читается как находящийся внутри дыры, а не
                  // наклеенный на неё. Раньше слой был один.
                  cover: coverBackWidgetFor(_c.myCoverId),
                  coverFront: coverFrontWidgetFor(_c.myCoverId),
                  // 🔴 «Сменить обложку» — кнопка ПОВЕРХ самой обложки, как в
                  // макете. Раньше обложку меняли только из ряда действий
                  // ниже, и связи между кнопкой и картинкой не было никакой.
                  //
                  // Когда обложки нет, кнопки тоже нет: «сменить» на пустом
                  // месте нечего, там работает «Обложка» в ряду действий.
                  onChangeCover: _c.myCoverId == null
                      ? null
                      : () => unawaited(_pickCosmetic(frame: false)),
                  emojiStatus: _c.myEmojiStatus,
                  premiumBadge: _c.myPremiumBadge,
                  frameId: _c.myFrameId,
                  // 🔴 БЕЙДЖ КАМЕРЫ НА ПОРТРЕТЕ — очевидный вход в смену фото.
                  //
                  // Нажатие по портрету открывало ТОЛЬКО предпросмотр, а
                  // поменять фото можно было кнопкой «Фото» ниже и строкой
                  // «Заменить фото» ещё ниже. Во всех мессенджерах камера в
                  // углу своего портрета означает ровно одно, и человек
                  // сначала жмёт туда. Раньше он попадал в просмотр.
                  //
                  // Предпросмотр никуда не делся — он на самом портрете; в
                  // углу камера. Два действия, два места.
                  avatar: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      HoverListener(
                        onTap: () => showAvatarPreviewDialog(
                          context,
                          name: display,
                          imagePath: hasAvatar ? avatarPath : null,
                        ),
                        cursor: SystemMouseCursors.click,
                        builder: (ctx, hovered, pressed) => AnimatedScale(
                          scale: pressed ? 0.97 : 1.0,
                          duration: DMotion.fast,
                          child: Avatar(
                            name: display,
                            image: hasAvatar
                                ? Avatar.fileImage(avatarPath)
                                : null,
                            frameId: _c.myFrameId,
                            allowAnimatedFrame: true,
                            size: 88,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: DesktopTooltip(
                          message: l10n.desktopProfileChangePhoto,
                          child: HoverListener(
                            onTap: () => unawaited(_pickAvatar()),
                            cursor: SystemMouseCursors.click,
                            builder: (ctx, hovered, pressed) =>
                                AnimatedContainer(
                                  duration: DMotion.fast,
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: hovered || pressed
                                        ? colors.accentPrimary
                                        : colors.elevated,
                                    shape: BoxShape.circle,
                                    // Вырез цветом панели: без него кружок
                                    // слипается с краем портрета.
                                    border: Border.all(
                                      color: colors.chatList,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    FluentIcons.camera_24_filled,
                                    size: 13,
                                    color: hovered || pressed
                                        ? Colors.white
                                        : colors.textSecondary,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DetailsActionRow(
                  items: [
                    DetailsActionItem(
                      icon: FluentIcons.image_24_regular,
                      label: l10n.desktopChatsPhoto,
                      onPressed: () => unawaited(_pickAvatar()),
                    ),
                    DetailsActionItem(
                      icon: FluentIcons.circle_24_regular,
                      label: l10n.desktopProfileFrameShort,
                      onPressed: () => unawaited(_pickCosmetic(frame: true)),
                      active: _c.myFrameId != null,
                    ),
                    DetailsActionItem(
                      icon: FluentIcons.panel_top_gallery_24_regular,
                      label: l10n.desktopProfileCoverShort,
                      onPressed: () => unawaited(_pickCosmetic(frame: false)),
                      active: _c.myCoverId != null,
                    ),
                    DetailsActionItem(
                      icon: FluentIcons.emoji_24_regular,
                      label: l10n.desktopProfileStatus,
                      onPressed: () => unawaited(_pickEmojiStatus()),
                      active: (_c.myEmojiStatus ?? '').isNotEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: DSpace.s),
                // 🔴 ПОЛОСЫ РАМОК ЗДЕСЬ БОЛЬШЕ НЕТ (решение владельца
                // 23.09.2026). Она показывала первые несколько кружков прямо в
                // профиле, дублируя кнопку «Рамка» из ряда выше: два входа в
                // одно и то же, причём меньший показывал не все варианты.
                // Кнопка «Рамка» осталась — за ней полная сетка.
                // Заголовка у раздела нет: строка сама называет и что за ней,
                // и куда она ведёт — тем же порядком, что строка «Устройства»
                // ниже (сверху описание, снизу название раздела настроек).
                if (widget.onOpenAppearanceSettings != null)
                  DetailsInfoSection(
                    children: [
                      DetailsInfoRow(
                        icon: FluentIcons.color_24_regular,
                        label: l10n.desktopSettingsAppearanceLabel,
                        value: l10n.desktopProfileAppearanceHint,
                        onTap: widget.onOpenAppearanceSettings,
                      ),
                    ],
                  ),
                DetailsInfoSection(
                  title: l10n.desktopAccountProfile,
                  children: [
                    DetailsInfoRow(
                      icon: FluentIcons.person_24_regular,
                      label: l10n.desktopProfileName,
                      value: display,
                      onTap: () => unawaited(
                        _editLine(
                          title: l10n.desktopProfileName,
                          initial: name,
                          maxLength: 40,
                          save: (v) => _c.setMyNickname(v),
                        ),
                      ),
                    ),
                    DetailsInfoRow(
                      icon: FluentIcons.text_description_24_regular,
                      label: l10n.desktopProfileAbout,
                      value: bio.isEmpty ? l10n.desktopProfileEmpty : bio,
                      multiline: true,
                      onTap: () => unawaited(
                        _editLine(
                          title: l10n.desktopProfileAbout,
                          initial: bio,
                          maxLength: 140,
                          multiline: true,
                          save: (v) => _c.setMyBio(v),
                        ),
                      ),
                    ),
                    DetailsInfoRow(
                      icon: FluentIcons.key_24_regular,
                      label: 'Secretly ID',
                      value: id,
                      copyValue: id,
                    ),
                  ],
                ),
                const SizedBox(height: DSpace.s),
                DetailsInfoSection(
                  title: l10n.desktopProfilePhoto,
                  children: [
                    // Порядок как у соседних строк: СВЕРХУ действие, снизу
                    // пояснение. «Проверить контакт» в карточке собеседника
                    // устроен так же.
                    DetailsInfoRow(
                      icon: FluentIcons.image_24_regular,
                      value: hasAvatar ? l10n.desktopProfileReplacePhoto : l10n.desktopProfilePickPhoto,
                      // 🔴 «Убрать» убирает ФАЙЛ, выбранный здесь. Фотография,
                      // приехавшая с телефона, файлом на этом компьютере не
                      // является, и сервер удаление не принимает: пустое
                      // значение он читает как «мнения нет». Поэтому строки
                      // там нет, а вместо неё — прямой ответ, где это
                      // делается.
                      label: hasLocalAvatar
                          ? l10n.desktopProfilePickedHere
                          : (hasAvatar
                                ? l10n.desktopProfileSyncedWithPhone
                                : l10n.desktopProfileNotPicked),
                      onTap: () => unawaited(_pickAvatar()),
                    ),
                    if (hasLocalAvatar)
                      DetailsInfoRow(
                        icon: FluentIcons.delete_24_regular,
                        value: l10n.desktopProfileRemovePhoto,
                        label: l10n.desktopProfileInitialsStay,
                        onTap: () => unawaited(_removeAvatar()),
                      ),
                  ],
                ),
                const SizedBox(height: DSpace.s),
                DetailsInfoSection(
                  title: l10n.desktopProfileAccount,
                  children: [
                    DetailsInfoRow(
                      icon: FluentIcons.phone_24_regular,
                      label: l10n.desktopProfileRecovery,
                      value:
                          l10n.desktopProfileRecoveryHint,
                      multiline: true,
                    ),
                    if (widget.onOpenDeviceSettings != null)
                      DetailsInfoRow(
                        icon: FluentIcons.qr_code_24_regular,
                        label: l10n.desktopDevicesTitle,
                        value: l10n.desktopProfileDevicesHint,
                        onTap: widget.onOpenDeviceSettings,
                      ),
                  ],
                ),
                const SizedBox(height: DSpace.l),
              ],
            ),
          ),
        ),
      ],
    );
  }
}



