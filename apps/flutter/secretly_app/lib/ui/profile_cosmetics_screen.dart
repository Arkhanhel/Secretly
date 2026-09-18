// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_controller.dart';
import '../billing/show_paywall.dart';
import '../entitlements/cosmetic_catalog.dart';
import 'cover_crop_screen.dart';
import 'paywall_screen.dart' show PaywallTrigger;
import 'premium/cosmetic_animation_scope.dart';
import 'premium/cosmetics_catalog.dart';
import 'wave1_l10n.dart';
import 'widgets/framed_avatar.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/premium_glass.dart';

/// Premium picker for the animated avatar frame + animated profile cover.
///
/// Frames/covers are cosmetic ids stored in profile_meta and rendered
/// client-side from [kAvatarFrames]/[kProfileCovers], so every interlocutor
/// sees the same animation. All ids are premium: free users tapping an item get
/// the paywall; if they purchase, the tapped item is applied automatically.
class ProfileCosmeticsScreen extends StatefulWidget {
  const ProfileCosmeticsScreen({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });

  final AppController controller;

  /// 0 = Рамки (frames), 1 = Обложки (covers).
  final int initialTab;

  @override
  State<ProfileCosmeticsScreen> createState() => _ProfileCosmeticsScreenState();
}

class _ProfileCosmeticsScreenState extends State<ProfileCosmeticsScreen> {
  late int _tab = widget.initialTab.clamp(0, 1); // 0 = frames, 1 = covers

  AppController get _c => widget.controller;

  // All catalog ids are premium (no free ids), so the unlock decision is the
  // same for every id — probe with any id.
  bool get _premiumUnlocked =>
      isCosmeticAllowed(_c.entitlementStateNow, CosmeticKind.avatarFrame, 'x');

  Future<void> _selectFrame(String? id) async {
    if (id != null && !_premiumUnlocked) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted) return;
      setState(() {});
      if (!_premiumUnlocked) return; // user didn't purchase
    }
    await _c.setMyFrame(id);
    if (mounted) setState(() {});
  }

  Future<void> _selectCover(String? id) async {
    if (id != null && !_premiumUnlocked) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted) return;
      setState(() {});
      if (!_premiumUnlocked) return;
    }
    await _c.setMyCover(id);
    if (mounted) setState(() {});
  }

  Future<void> _addCustomCover() async {
    if (!_premiumUnlocked) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted) return;
      setState(() {});
      if (!_premiumUnlocked) return;
    }
    // One entry point — пользователь выбирает фото или видео.
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF15171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.photo_rounded, color: Colors.white),
              title: Text(
                wave1Text(
                  context,
                  ru: 'Фото',
                  en: 'Photo',
                  uk: 'Фото',
                  es: 'Foto',
                  pt: 'Foto',
                  ptBr: 'Foto',
                  fr: 'Photo',
                  de: 'Foto',
                ),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.movie_creation_rounded, color: Colors.white),
              title: Text(
                wave1Text(
                  context,
                  ru: 'Видео',
                  en: 'Video',
                  uk: 'Відео',
                  es: 'Vídeo',
                  pt: 'Vídeo',
                  ptBr: 'Vídeo',
                  fr: 'Vidéo',
                  de: 'Video',
                ),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                wave1Text(
                  context,
                  ru: 'играет у вас · собеседникам уходит кадр',
                  en: 'plays for you · contacts get a still frame',
                  uk: 'програється у вас · співрозмовникам надсилається кадр',
                  es: 'se reproduce para ti · los contactos reciben una imagen fija',
                  pt: 'reproduz para si · os contactos recebem uma imagem fixa',
                  ptBr: 'reproduz para você · os contatos recebem um quadro estático',
                  fr: 'lue chez vous · vos contacts reçoivent une image fixe',
                  de: 'wird bei dir abgespielt · Kontakte erhalten ein Standbild',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'video') {
      await _addVideoCover();
      return;
    }
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2200,
      );
    } catch (_) {
      picked = null;
    }
    final src = picked?.path;
    if (src == null || !mounted) return;
    final cropped = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CoverCropScreen(imagePath: src)),
    );
    if (cropped == null || cropped.isEmpty || !mounted) return;
    await _c.setMyCoverImage(cropped);
    if (mounted) setState(() {});
  }

  bool _busyVideo = false;

  Future<void> _addVideoCover() async {
    if (_busyVideo) return;
    if (!_premiumUnlocked) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted) return;
      setState(() {});
      if (!_premiumUnlocked) return;
    }
    XFile? picked;
    try {
      picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } catch (_) {
      picked = null;
    }
    final src = picked?.path;
    if (src == null || !mounted) return;
    setState(() => _busyVideo = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final videoOut = '${dir.path}/cover_video_$stamp.mp4';
      final stillOut = '${dir.path}/cover_video_still_$stamp.png';
      // Trim to a short, downscaled, silent loop so the cover stays light.
      final enc =
          "-y -i '$src' -t 8 -an -vf scale=720:-2 -c:v libx264 -pix_fmt yuv420p "
          "-crf 28 -preset veryfast '$videoOut'";
      final encRc = await (await FFmpegKit.execute(enc)).getReturnCode();
      String playPath;
      if (ReturnCode.isSuccess(encRc) && File(videoOut).existsSync()) {
        playPath = videoOut;
      } else {
        // Re-encode failed — keep a persistent copy of the original instead.
        try {
          await File(src).copy(videoOut);
          playPath = videoOut;
        } catch (_) {
          playPath = src;
        }
      }
      // Grab the first frame as the synced still image (what others will see).
      // Downscaled so its base64 stays well under the 4 MB profile-meta guard.
      final stillCmd =
          "-y -i '$playPath' -frames:v 1 -vf scale=480:-2 '$stillOut'";
      final stillRc = await (await FFmpegKit.execute(stillCmd)).getReturnCode();
      final stillPath =
          (ReturnCode.isSuccess(stillRc) && File(stillOut).existsSync())
          ? stillOut
          : '';
      await _c.setMyCoverVideo(playPath, stillPath);
    } catch (_) {
      // best-effort; leave the existing cover untouched on failure
    } finally {
      if (mounted) setState(() => _busyVideo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force a dark surface so the cosmic animations read well and the screen
    // keeps the premium aesthetic regardless of the app theme.
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A6BFF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0C0D11),
    );

    return Theme(
      data: dark,
      child: StreamBuilder<void>(
        stream: _c.changed,
        builder: (context, _) => _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final unlocked = _premiumUnlocked;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: ShimmerGoldText(
          wave1Text(
            context,
            ru: 'Рамки и обложки',
            en: 'Frames and covers',
            uk: 'Рамки та обкладинки',
            es: 'Marcos y portadas',
            pt: 'Molduras e capas',
            ptBr: 'Molduras e capas',
            fr: 'Cadres et couvertures',
            de: 'Rahmen und Titelbilder',
          ),
          colors: premiumShimmerColors(context),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF0C0D11))),
          const Positioned.fill(child: CosmicDustField(count: 90)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _LivePreview(
                  controller: _c,
                  frameId: _c.myFrameId,
                  coverId: _c.myCoverId,
                  coverImagePath: _c.myCoverImagePath,
                  coverVideoPath: _c.myCoverVideoPath,
                ),
                const SizedBox(height: 12),
                if (!unlocked) _lockedBanner(context),
                _Segmented(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _tab == 0
                      ? _framesGrid(unlocked)
                      : _coversList(unlocked),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: PremiumGlassCard(
        highlighted: true,
        onTap: () async {
          await showPaywall(context, PaywallTrigger.cosmetic);
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: kPremiumGold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  wave1Text(
                    context,
                    ru: 'Рамки и обложки — премиум-функция. Откройте, чтобы выбрать.',
                    en: 'Frames and covers are a premium feature. Unlock to choose one.',
                    uk: 'Рамки та обкладинки — преміум-функція. Розблокуйте, щоб обрати.',
                    es: 'Los marcos y portadas son una función premium. Desbloquéala para elegir.',
                    pt: 'Molduras e capas são uma funcionalidade premium. Desbloqueie para escolher.',
                    ptBr: 'Molduras e capas são um recurso premium. Desbloqueie para escolher.',
                    fr: 'Les cadres et couvertures sont une fonction premium. Débloquez-les pour en choisir.',
                    de: 'Rahmen und Titelbilder sind eine Premium-Funktion. Schalte sie frei, um eine auszuwählen.',
                  ),
                  style: const TextStyle(fontSize: 13.5, height: 1.25),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _framesGrid(bool unlocked) {
    final current = _c.myFrameId;
    // Frames in the GRID render STATIC (no per-tile animation) — animating a
    // whole grid of premium frames at once is heavy and distracting. Only the
    // big top preview animates (it lives outside this scope), so tapping a frame
    // shows its motion there.
    return CosmeticAnimationScope(
      enabled: false,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemCount: kAvatarFrames.length + 1,
        itemBuilder: (context, i) {
        if (i == 0) {
          return _FrameTile(
            controller: _c,
            frameId: null,
            label: wave1Text(
              context,
              ru: 'Без рамки',
              en: 'No frame',
              uk: 'Без рамки',
              es: 'Sin marco',
              pt: 'Sem moldura',
              ptBr: 'Sem moldura',
              fr: 'Aucun cadre',
              de: 'Kein Rahmen',
            ),
            selected: current == null,
            locked: false,
            onTap: () => _selectFrame(null),
          );
        }
        final f = kAvatarFrames[i - 1];
        return _FrameTile(
          controller: _c,
          frameId: f.id,
          label: f.nameLocalized(context),
          selected: current == f.id,
          locked: !unlocked,
          onTap: () => _selectFrame(f.id),
        );
      },
      ),
    );
  }

  Widget _coversList(bool unlocked) {
    final current = _c.myCoverId;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: kProfileCovers.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _CoverTile(
            coverId: null,
            label: wave1Text(
              context,
              ru: 'Без обложки',
              en: 'No cover',
              uk: 'Без обкладинки',
              es: 'Sin portada',
              pt: 'Sem capa',
              ptBr: 'Sem capa',
              fr: 'Aucune couverture',
              de: 'Kein Titelbild',
            ),
            selected: current == null,
            locked: false,
            onTap: () => _selectCover(null),
          );
        }
        if (i == 1) {
          // Single «Своя обложка» entry — photo OR video (chosen in a sheet).
          return _CustomCoverTile(
            imagePath: _c.myCoverImagePath,
            hasVideo: _c.myCoverVideoPath != null,
            busy: _busyVideo,
            selected: current == 'custom',
            locked: !unlocked,
            onTap: _addCustomCover,
          );
        }
        final cover = kProfileCovers[i - 2];
        return _CoverTile(
          coverId: cover.id,
          label: cover.nameLocalized(context),
          selected: current == cover.id,
          locked: !unlocked,
          onTap: () => _selectCover(cover.id),
        );
      },
    );
  }
}

/// Big "how others see you" preview: cover banner + framed avatar + name.
class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.controller,
    required this.frameId,
    required this.coverId,
    this.coverImagePath,
    this.coverVideoPath,
  });

  final AppController controller;
  final String? frameId;
  final String? coverId;
  final String? coverImagePath;
  final String? coverVideoPath;

  @override
  Widget build(BuildContext context) {
    final cover = coverWidgetFor(
      coverId,
      customImagePath: coverImagePath,
      customVideoPath: coverVideoPath,
    );
    final name = controller.myNickname.trim().isNotEmpty
        ? controller.myNickname.trim()
        : 'Secretly';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                cover
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF15171E), Color(0xFF0C0D11)],
                    ),
                  ),
                ),
              // Bottom scrim for name legibility over any cover.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FramedAvatar(
                      size: 104,
                      frameId: frameId,
                      avatarPath: controller.myAvatarPath,
                      fallbackSeed: controller.profileId,
                      fallbackName: name,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            _seg(
              wave1Text(
                context,
                ru: 'Рамки',
                en: 'Frames',
                uk: 'Рамки',
                es: 'Marcos',
                pt: 'Molduras',
                ptBr: 'Molduras',
                fr: 'Cadres',
                de: 'Rahmen',
              ),
              0,
            ),
            _seg(
              wave1Text(
                context,
                ru: 'Обложки',
                en: 'Covers',
                uk: 'Обкладинки',
                es: 'Portadas',
                pt: 'Capas',
                ptBr: 'Capas',
                fr: 'Couvertures',
                de: 'Titelbilder',
              ),
              1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, int i) {
    final selected = index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.controller,
    required this.frameId,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final AppController controller;
  final String? frameId;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? kPremiumGold.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                FramedAvatar(
                  size: 72,
                  frameId: frameId,
                  avatarPath: controller.myAvatarPath,
                  fallbackSeed: controller.profileId,
                  fallbackName: controller.myNickname.trim().isNotEmpty
                      ? controller.myNickname.trim()
                      : 'Secretly',
                ),
                if (frameId == null)
                  const Positioned(
                    right: 6,
                    bottom: 6,
                    child: Icon(
                      Icons.block_rounded,
                      size: 18,
                      color: Colors.white38,
                    ),
                  ),
                if (locked) const _LockBadge(),
                if (selected) const _CheckBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile for adding/editing a user-supplied custom cover image.
class _CustomCoverTile extends StatelessWidget {
  const _CustomCoverTile({
    required this.imagePath,
    required this.hasVideo,
    required this.busy,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String? imagePath;
  final bool hasVideo;
  final bool busy;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? kPremiumGold.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.16),
              width: selected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const _AddCoverPlaceholder(),
                )
              else
                const _AddCoverPlaceholder(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasVideo
                          ? Icons.movie_creation_rounded
                          : (hasImage
                                ? Icons.edit_rounded
                                : Icons.add_photo_alternate_rounded),
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasVideo
                          ? wave1Text(
                              context,
                              ru: 'Видео-обложка',
                              en: 'Video cover',
                              uk: 'Відео-обкладинка',
                              es: 'Portada de vídeo',
                              pt: 'Capa em vídeo',
                              ptBr: 'Capa em vídeo',
                              fr: 'Couverture vidéo',
                              de: 'Video-Titelbild',
                            )
                          : (hasImage
                              ? wave1Text(
                                  context,
                                  ru: 'Своя обложка',
                                  en: 'Custom cover',
                                  uk: 'Власна обкладинка',
                                  es: 'Portada personalizada',
                                  pt: 'Capa personalizada',
                                  ptBr: 'Capa personalizada',
                                  fr: 'Couverture personnalisée',
                                  de: 'Eigenes Titelbild',
                                )
                              : wave1Text(
                                  context,
                                  ru: 'Добавить свою обложку',
                                  en: 'Add your own cover',
                                  uk: 'Додати власну обкладинку',
                                  es: 'Añadir tu propia portada',
                                  pt: 'Adicionar a sua capa',
                                  ptBr: 'Adicionar sua própria capa',
                                  fr: 'Ajouter votre couverture',
                                  de: 'Eigenes Titelbild hinzufügen',
                                )),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasVideo && !busy)
                const Positioned(
                  right: 12,
                  top: 10,
                  child: Icon(Icons.play_circle_fill_rounded,
                      size: 22, color: Colors.white),
                ),
              if (busy)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (locked) const _LockBadge(),
              if (selected) const _CheckBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCoverPlaceholder extends StatelessWidget {
  const _AddCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B1E27), Color(0xFF101218)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: Colors.white.withValues(alpha: 0.5),
          size: 30,
        ),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.coverId,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String? coverId;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = coverById(coverId);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? kPremiumGold.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                // Only the SELECTED tile animates: a screenful of live covers
                // ran seventeen blur-heavy painters at once (measured: galaxy
                // 43ms a frame, fog 42ms). The rest are one-paint stills of the
                // same picture.
                (selected ? cover.builder() : coverStill(cover.id))
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF15171E), Color(0xFF0C0D11)],
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (coverId == null)
                const Positioned(
                  left: 14,
                  top: 12,
                  child: Icon(
                    Icons.block_rounded,
                    size: 18,
                    color: Colors.white38,
                  ),
                ),
              if (locked) const _LockBadge(),
              if (selected) const _CheckBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, size: 14, color: kPremiumGold),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: kPremiumGold,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.black),
      ),
    );
  }
}
