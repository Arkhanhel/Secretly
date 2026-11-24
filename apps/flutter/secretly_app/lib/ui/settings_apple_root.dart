// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Главный экран настроек на iPhone — по макету владельца «iPhone · Liquid
/// Glass» (20.11.2026).
///
/// Крупный заголовок «Настройки», который при прокрутке уходит в узкую
/// шапку; поле поиска; карточка профиля; группы строк на полупрозрачных
/// стеклянных панелях. В строке — значок, название, значение и «›», без
/// пояснений: так устроены настройки самой iOS.
///
/// 🔴 ПРОИЗВОДИТЕЛЬНОСТЬ. Панели полупрозрачные, но БЕЗ `BackdropFilter`:
/// под ними плавный градиентный фон приложения, и размытие плавного градиента
/// даёт тот же градиент. Восемь размытий на экране, пересчитываемых при каждом
/// кадре прокрутки, грели бы телефон ради невидимой разницы. Размытие есть
/// только у узкой шапки, где под ней проезжают строки.
///
/// Выключатель — [kAppleSettingsLayout] (`apple_style.dart`): `false`
/// возвращает прежний экран.
library;

import 'whats_new/pen_mark.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'apple_glass.dart';
import 'haptics.dart';
import 'icons/app_icons.dart';
import 'motion/motion.dart';
import 'settings_icons/settings_glyph_tile.dart';
import 'settings_root_model.dart';
import 'widgets/frosted_header_island.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

/// Полупрозрачное поле поиска iOS: капсула, значок лупы, «×» для очистки
/// и «Отменить» справа, пока поле в фокусе.
class AppleSearchField extends StatefulWidget {
  const AppleSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  State<AppleSearchField> createState() => _AppleSearchFieldState();
}

class _AppleSearchFieldState extends State<AppleSearchField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  void _cancel() {
    _clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final secondary = appleSecondaryLabel(dark);
    final hasText = widget.controller.text.isNotEmpty;
    final field = Container(
      height: 38,
      decoration: BoxDecoration(
        color: appleGlassFieldFill(dark),
        borderRadius: BorderRadius.circular(19),
      ),
      foregroundDecoration: ShapeDecoration(
        shape: AppleGlassBorder(radius: 19, dark: dark),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(AppIcons.search, size: 19, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              cursorColor: theme.colorScheme.primary,
              style: TextStyle(
                fontSize: 17,
                letterSpacing: -0.4,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontSize: 17,
                  letterSpacing: -0.4,
                  color: secondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (hasText)
            Semantics(
              button: true,
              label: MaterialLocalizations.of(context).deleteButtonTooltip,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(AdaptiveIcons.cancel, size: 18, color: secondary),
                ),
              ),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
    return Row(
      children: [
        Expanded(child: field),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Motion.standard,
          child: _focused
              ? TextButton(
                  onPressed: _cancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(left: 12, right: 2),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: -0.4,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Цвет вторичного текста iOS (`secondaryLabel`).
Color appleSecondaryLabel(bool dark) => AppleGlass.secondaryLabel(dark);

/// Заливка полупрозрачного поля iOS (`tertiarySystemFill` поверх стекла).
Color appleGlassFieldFill(bool dark) =>
    dark ? const Color(0x3D767680) : const Color(0x8CFFFFFF);

class AppleSettingsRoot extends StatefulWidget {
  const AppleSettingsRoot({
    super.key,
    required this.title,
    required this.groups,
    required this.profileName,
    required this.avatarPath,
    required this.onOpenProfile,
    required this.onOpenQr,
    required this.footer,
    this.premiumCard,
  });

  final String title;
  final List<SettingsRootGroup> groups;
  final String profileName;
  final String? avatarPath;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenQr;
  final Widget footer;
  final Widget? premiumCard;

  @override
  State<AppleSettingsRoot> createState() => _AppleSettingsRootState();
}

class _AppleSettingsRootState extends State<AppleSettingsRoot> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Узкая шапка видна, когда крупный заголовок уехал под неё. Меняется
  /// только на пороге, а не на каждом кадре прокрутки.
  final ValueNotifier<bool> _compactTitle = ValueNotifier<bool>(false);

  static const double _largeTitleExtent = 52;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final compact = _scroll.hasClients && _scroll.offset > _largeTitleExtent;
      if (compact != _compactTitle.value) _compactTitle.value = compact;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _compactTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final query = _query.text;
    final searching = normalizeSettingsQuery(query).isNotEmpty;

    final content = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
        child: Semantics(
          header: true,
          child: Text(
            widget.title,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.37,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
      AppleSearchField(
        controller: _query,
        focusNode: _searchFocus,
        hint: l10n.search,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      if (searching)
        ..._results(context, query)
      else ...[
        _ProfileCard(
          name: widget.profileName,
          avatarPath: widget.avatarPath,
          subtitle: l10n.settingsProfileCardSub,
          qrLabel: l10n.settingsProfileQr,
          onTap: widget.onOpenProfile,
          onQr: widget.onOpenQr,
        ),
        if (widget.premiumCard != null) ...[
          const SizedBox(height: 16),
          widget.premiumCard!,
        ],
        for (final group in widget.groups)
          if (group.rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GroupPanel(group: group),
          ],
        widget.footer,
      ],
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                topInset + 6,
                16,
                32 + media.padding.bottom,
              ),
              children: content,
            ),
          ),
          // Узкая шапка с названием экрана — появляется, когда крупный
          // заголовок уехал вверх.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _compactTitle,
              builder: (context, compact, _) => IgnorePointer(
                ignoring: !compact,
                child: AnimatedOpacity(
                  opacity: compact ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: SizedBox(
                    height: topInset + 44,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: SystemTopFadeLayer(
                            height: topInset + 44,
                            blurSigma: 20,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 44,
                          child: Center(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                                color: theme.colorScheme.onSurface,
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
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, String query) {
    final l10n = AppLocalizations.of(context)!;
    final matches = <({SettingsRootRow row, String group})>[
      for (final g in widget.groups)
        for (final r in g.rows)
          if (r.matches(query)) (row: r, group: g.title),
    ];
    if (matches.isEmpty) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return <Widget>[
        const SizedBox(height: 48),
        Text(
          l10n.settingsSearchNoResults(query.trim()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            letterSpacing: -0.4,
            color: appleSecondaryLabel(dark),
          ),
        ),
      ];
    }
    return <Widget>[
      _GroupPanel(
        group: SettingsRootGroup(
          title: '',
          rows: <SettingsRootRow>[for (final m in matches) m.row],
        ),
        captions: <String>[for (final m in matches) m.group],
      ),
    ];
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.avatarPath,
    required this.subtitle,
    required this.qrLabel,
    required this.onTap,
    required this.onQr,
  });

  final String name;
  final String? avatarPath;
  final String subtitle;
  final String qrLabel;
  final VoidCallback onTap;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = appleSecondaryLabel(dark);
    final path = avatarPath;
    Widget initials() => DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7DB4FF), Color(0xFF5B5BF0)],
        ),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '' : name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return AppleGlassPanel(
      child: _Pressable(
        onTap: onTap,
        merge: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 56,
                  child: path == null
                      ? initials()
                      : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          cacheWidth: 168,
                          errorBuilder: (_, __, ___) => initials(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.45,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: -0.08,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: qrLabel,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Haptics.tap();
                    onQr();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appleGlassFieldFill(dark),
                    ),
                    child: Icon(
                      AppIcons.qrCode,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(AdaptiveIcons.chevron_right_rounded, color: secondary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupPanel extends StatelessWidget {
  const _GroupPanel({required this.group, this.captions});

  final SettingsRootGroup group;

  /// Подпись под названием строки — в выдаче поиска это имя группы, чтобы
  /// было видно, где строка живёт.
  final List<String>? captions;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rows = group.rows;
    return Semantics(
      container: true,
      label: group.title.isEmpty ? null : group.title,
      child: AppleGlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Padding(
                  // Разделитель iOS начинается от текста, а не от края.
                  padding: const EdgeInsetsDirectional.only(start: 56),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: dark
                        ? const Color(0x1FFFFFFF)
                        : const Color(0x1F3C3C43),
                  ),
                ),
              _Row(row: rows[i], caption: captions?[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, this.caption});

  final SettingsRootRow row;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = appleSecondaryLabel(dark);
    final value = row.value;
    // Без своей подписи: экранный диктор слышит название, значение И значки
    // справа («требует внимания», непрочитанный ответ поддержки).
    return _Pressable(
      onTap: row.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 10, 7),
          child: Row(
            children: [
              // «Что нового 1.9»: перо вокруг значка «Стиль».
              if (row.id == 'chats')
                PenMark(
                  hint: PenHint.style,
                  round: true,
                  child: SettingsSectionIcon(row.glyph, size: 30),
                )
              else
                SettingsSectionIcon(row.glyph, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        letterSpacing: -0.4,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (caption != null && caption!.isNotEmpty)
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: secondary),
                      ),
                  ],
                ),
              ),
              if (row.trailing != null) ...[
                const SizedBox(width: 6),
                row.trailing!,
              ],
              if (value != null) ...[
                const SizedBox(width: 8),
                // Значение не делит место с названием поровну: оно своей
                // ширины и прижато к «›», но не длиннее трети строки.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width / 3,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: -0.4,
                      color: secondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(AdaptiveIcons.chevron_right_rounded, color: secondary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Нажатие как в iOS: строка подсвечивается, пока палец на ней, без «волны».
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.child,
    this.merge = true,
  });

  final VoidCallback onTap;
  final Widget child;

  /// Слить подписи детей в одну строку для экранного диктора. Карточка
  /// профиля не сливает: внутри неё своя кнопка QR, и диктор должен её найти.
  final bool merge;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Widget pressable = Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          Haptics.tap();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 0 : 220),
          color: _down
              ? (dark ? const Color(0x1FFFFFFF) : const Color(0x14000000))
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
    return widget.merge ? MergeSemantics(child: pressable) : pressable;
  }
}
