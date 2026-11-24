// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../build_variant.dart';
import '../billing/show_paywall.dart';
import '../entitlements/feature_gate.dart';
import '../stickers/sticker_animation_service.dart';
import '../stickers/sticker_catalog.dart';
import '../stickers/sticker_share_mode.dart';
import 'motion/app_dialogs.dart';
import 'motion/press_feedback.dart';
import 'paywall_screen.dart' show PaywallTrigger;
import 'motion/motion.dart';
import 'secretly_snackbar.dart';
import 'widgets/secretly_sticker_widgets.dart';
import 'widgets/broken_media_box.dart';
import 'widgets/sticker_pack_access_picker.dart';
import 'l10n.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

/// What the user chose to do with the finished sticker on the preview screen.
/// `send` is handled by the chat; `done` means the preview already saved it to a
/// pack (nothing left for the chat to do but acknowledge).
enum StickerPreviewAction { send, done }

class StickerPreviewResult {
  const StickerPreviewResult({
    required this.action,
    required this.emoji,
    this.stickerPathOverride,
    this.format = SecretlyStickerFormat.png,
  });
  final StickerPreviewAction action;
  final String emoji;

  /// When the user «оживил» the sticker, this is the produced animated-WebP path
  /// to send/save INSTEAD of the editor's static PNG. Null = keep static.
  final String? stickerPathOverride;
  final SecretlyStickerFormat format;
}

/// Final result bubbled all the way up the sticker flow (editor → preview) back
/// to the chat, which performs the send (or just acknowledges a save).
class StickerFlowResult {
  const StickerFlowResult({
    required this.stickerPath,
    required this.action,
    required this.emoji,
    this.format = SecretlyStickerFormat.png,
  });
  final String stickerPath;
  final StickerPreviewAction action;
  final String emoji;
  final SecretlyStickerFormat format;
}

/// Preview of the finished sticker (Telegram-parity): the sticker on a dark
/// backdrop, an emoji-assignment bar, and an action menu that morphs between
///  • «Отправить стикер» / «Сделать избранным» / «Добавить в набор», and
///  • the pack chooser (← Назад / ⊕ Новый набор / existing packs).
/// Pops a [StickerPreviewResult] or null on back.
class StickerPreviewScreen extends StatefulWidget {
  const StickerPreviewScreen({
    super.key,
    required this.stickerPath,
    required this.controller,
    this.targetPackId,
  });

  final String stickerPath;
  final AppController controller;

  /// Открыт из «+» своего набора (15.11.2026): первая кнопка — «Добавить в
  /// этот набор».
  final String? targetPackId;

  @override
  State<StickerPreviewScreen> createState() => _StickerPreviewScreenState();
}

enum _MenuView { actions, chooser }

class _StickerPreviewScreenState extends State<StickerPreviewScreen> {
  static const List<String> _suggest = <String>[
    '😀',
    '😂',
    '😍',
    '😎',
    '🥳',
    '😭',
    '😡',
    '👍',
    '👎',
    '🙏',
    '👏',
    '🔥',
    '💯',
    '❤️',
    '⭐',
    '✨',
    '🎉',
    '💀',
    '👀',
    '💪',
    '🚀',
    '😉',
    '🤔',
    '🥰',
  ];
  final Set<String> _picked = <String>{};
  _MenuView _view = _MenuView.actions;
  bool _busy = false;
  bool _animating = false;
  List<SecretlyStickerPack> _packs = const <SecretlyStickerPack>[];

  /// Set once the user «оживил» the sticker — the produced animated WebP that
  /// replaces the static PNG for display, send and save.
  String? _animatedPath;
  SecretlyStickerFormat _format = SecretlyStickerFormat.png;

  String get _emoji => _picked.join();
  String get _currentPath => _animatedPath ?? widget.stickerPath;
  bool get _isAnimated => _format == SecretlyStickerFormat.webp;

  @override
  void initState() {
    super.initState();
    _packs = widget.controller.listUserStickerPacks();
  }

  void _send() => Navigator.of(context).pop(
    StickerPreviewResult(
      action: StickerPreviewAction.send,
      emoji: _emoji,
      stickerPathOverride: _animatedPath,
      format: _format,
    ),
  );

  Future<void> _addTo({
    required String packId,
    required String title,
    String? successText,
    StickerShareMode? shareMode,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.addStickerToUserPack(
        stickerFile: File(_currentPath),
        packId: packId,
        packTitle: title,
        emoji: _emoji,
        format: _format,
        animated: _isAnimated,
      );
      // Режим ставится сразу после создания набора, до первой отправки: иначе
      // первый же стикер успел бы уйти из «открытого» набора.
      if (shareMode != null) {
        await widget.controller.setUserStickerPackShareMode(
          packId: packId,
          mode: shareMode,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(
          content: Text(successText ?? context.l10n.stickerAddedToPack),
        ));
      Navigator.of(context).pop(
        StickerPreviewResult(action: StickerPreviewAction.done, emoji: _emoji),
      );
    } on StickerPackFullException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(context.l10n.stickerPackFull(e.max))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(context.l10n.stickerSaveFailed('$e'))),
      );
    }
  }

  Future<void> _favorite() async {
    final pid = widget.controller.profileId;
    if (pid.isEmpty || pid == 'unknown') return;
    await _addTo(
      packId: 'user:$pid:favorites',
      title: context.l10n.stickerFavoritesPackTitle,
      successText: context.l10n.stickerAddedToFavorites,
    );
  }

  /// «Оживить» — Premium "live sticker": pick a motion effect and encode an
  /// animated WebP from the static cutout. Fails open (paywall when locked) and
  /// degrades gracefully (keeps the static sticker if the encode is unavailable).
  Future<void> _animate() async {
    if (_animating || _busy) return;
    if (!kVideoToolsAvailable) return;
    final unlocked = FeatureGate.isUnlocked(
      widget.controller.entitlementStateNow,
      GatedFeature.premiumStickers,
    );
    if (!unlocked) {
      await showPaywall(context, PaywallTrigger.general);
      return;
    }
    final picked = await _pickEffect();
    if (picked == null || !mounted) return;
    final (effect, speed) = picked;
    setState(() => _animating = true);
    final webp = await StickerAnimationService.instance.animate(
      cutoutPng: File(widget.stickerPath),
      effect: effect,
      speed: speed,
    );
    if (!mounted) return;
    setState(() {
      _animating = false;
      if (webp != null) {
        _animatedPath = webp.path;
        _format = SecretlyStickerFormat.webp;
      }
    });
    if (webp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(context.l10n.stickerAnimationUnavailable),
        ),
      );
    }
  }

  Future<(StickerMotionEffect, double)?> _pickEffect() {
    return showModalBottomSheet<(StickerMotionEffect, double)>(
      context: context,
      backgroundColor: const Color(0xFF1B1E25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        var speed = 1.0;
        return StatefulBuilder(
          builder: (context, setSheet) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.stickerMotionPickTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final s in <(String, double)>[
                        (context.l10n.stickerMotionSlow, 0.6),
                        (context.l10n.stickerMotionNormal, 1.0),
                        (context.l10n.stickerMotionFast, 1.6),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(s.$1),
                            selected: speed == s.$2,
                            showCheckmark: false,
                            onSelected: (_) => setSheet(() => speed = s.$2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final e in StickerMotionEffect.values)
                        PressFeedback(child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetCtx).pop((e, speed)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(_motionLabel(context, e)),
                        )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _newPack() async {
    final result = await showAppDialog<_NewPackResult>(
      context: context,
      builder: (_) => _NewPackDialog(
        // Выбор режима — по доле из `/v1/config`; вне доли набор создаётся
        // открытым, как и раньше.
        showAccess: widget.controller.stickerPackAccessUiEnabled,
      ),
    );
    if (result == null || result.name.trim().isEmpty || !mounted) return;
    final pid = widget.controller.profileId;
    if (pid.isEmpty || pid == 'unknown') return;
    final slug = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    await _addTo(
      packId: 'user:$pid:$slug',
      title: result.name.trim(),
      shareMode: result.mode == StickerShareMode.fallback ? null : result.mode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.l10n.stickerReadyTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                context.l10n.stickerPickEmojiHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final e in _suggest)
                    GestureDetector(
                      onTap: () => setState(
                        () => _picked.contains(e)
                            ? _picked.remove(e)
                            : _picked.add(e),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _picked.contains(e)
                              ? Colors.white.withValues(alpha: 0.22)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 220,
                      maxHeight: 220,
                    ),
                    // _currentPath is the animated WebP once «оживлён» — Image
                    // plays it inline; the key forces a swap from the static PNG.
                    child: Image.file(
                      File(_currentPath),
                      key: ValueKey(_currentPath),
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40),
                    ),
                  ),
                ),
              ),
            ),
            // Morphing action menu.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Motion.standard,
                child: Material(
                  color: const Color(0xFF1F2733).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SizeTransition(sizeFactor: anim, child: child),
                    ),
                    child: _view == _MenuView.actions
                        ? _actionsMenu()
                        : _chooserMenu(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsMenu() {
    final target = widget.targetPackId == null
        ? null
        : _packs.where((p) => p.id == widget.targetPackId).firstOrNull;
    return Column(
      key: const ValueKey('actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (target != null) ...[
          _row(
            AdaptiveIcons.add_circle_rounded,
            context.l10n.stickerAddToThisPack(target.title),
            _busy ? null : () => _addTo(packId: target.id, title: target.title),
            primary: true,
          ),
          _divider(),
        ],
        _row(
          AdaptiveIcons.send_rounded,
          context.l10n.stickerSend,
          _busy ? null : _send,
          primary: target == null,
        ),
        // Облегчённая сборка: анимированный стикер печёт FFmpeg — «Оживить»
        // не показываем, стикер остаётся статичным.
        if (kVideoToolsAvailable) _divider(),
        if (kVideoToolsAvailable)
          _row(
            _isAnimated
                ? AdaptiveIcons.auto_awesome_rounded
                : AdaptiveIcons.auto_awesome_outlined,
            _animating
                ? context.l10n.stickerAnimating
                : (_isAnimated
                      ? context.l10n.stickerChangeMotion
                      : context.l10n.stickerAnimatePremium),
            (_busy || _animating) ? null : _animate,
          ),
        _divider(),
        _row(
          AdaptiveIcons.star_outline_rounded,
          context.l10n.stickerMakeFavorite,
          _busy ? null : _favorite,
        ),
        _divider(),
        _row(
          AdaptiveIcons.add_reaction_outlined,
          context.l10n.stickerAddToPack,
          _busy ? null : () => setState(() => _view = _MenuView.chooser),
        ),
      ],
    );
  }

  Widget _chooserMenu() {
    return Column(
      key: const ValueKey('chooser'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          appleBackIcon(AdaptiveIcons.arrow_back_rounded),
          context.l10n.stickerBack,
          _busy ? null : () => setState(() => _view = _MenuView.actions),
        ),
        _divider(),
        _row(
          AdaptiveIcons.add_circle_outline_rounded,
          context.l10n.stickerNewPack,
          _busy ? null : _newPack,
        ),
        for (final pack in _packs) ...[_divider(), _packRow(pack)],
      ],
    );
  }

  Widget _packRow(SecretlyStickerPack pack) {
    final icon = pack.stickers.isNotEmpty ? pack.stickers.first : null;
    return InkWell(
      onTap: _busy ? null : () => _addTo(packId: pack.id, title: pack.title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: (icon != null && icon.isRenderable)
                  ? SecretlyStickerAssetView(sticker: icon, size: 34)
                  : const Icon(
                      AdaptiveIcons.folder_rounded,
                      color: Colors.white70,
                      size: 26,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                pack.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.08));

  Widget _row(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool primary = false,
  }) {
    final color = primary ? const Color(0xFF4DA3FF) : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _NewPackResult = ({String name, StickerShareMode mode});

/// Подпись эффекта движения на языке интерфейса.
String _motionLabel(BuildContext context, StickerMotionEffect e) =>
    switch (e) {
      StickerMotionEffect.pulse => context.l10n.stickerMotionPulse,
      StickerMotionEffect.bounce => context.l10n.stickerMotionBounce,
      StickerMotionEffect.wobble => context.l10n.stickerMotionWobble,
      StickerMotionEffect.tada => context.l10n.stickerMotionTada,
    };

/// «Новый набор» — a name dialog (max 50 chars), Telegram-style, plus the
/// open/closed choice when [showAccess] (ТЗ 14.11.2026).
class _NewPackDialog extends StatefulWidget {
  const _NewPackDialog({this.showAccess = false});
  final bool showAccess;
  @override
  State<_NewPackDialog> createState() => _NewPackDialogState();
}

class _NewPackDialogState extends State<_NewPackDialog> {
  final TextEditingController _c = TextEditingController();

  /// По умолчанию — открытый: ровно нынешнее поведение (В-2 в ТЗ).
  StickerShareMode _mode = StickerShareMode.sentOnly;

  void _submit() => Navigator.of(
    context,
  ).pop<_NewPackResult>((name: _c.text.trim(), mode: _mode));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecretlyAlertDialog(
      backgroundColor: const Color(0xFF1F2733),
      title: Text(
        context.l10n.stickerNewPack,
        style: const TextStyle(color: Colors.white),
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.stickerNewPackHint,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _c,
            autofocus: true,
            maxLength: 50,
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFF4DA3FF),
            decoration: const InputDecoration(
              counterStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4DA3FF)),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.showAccess) ...[
            const SizedBox(height: 8),
            StickerPackAccessPicker(
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        PressFeedback(child: FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.stickerCreate),
        )),
      ],
    );
  }
}
