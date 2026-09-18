// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../widgets/frosted_header_island.dart';
import '../wave1_l10n.dart';
import 'noto_emoji_catalog.dart';

/// Bottom-sheet picker for the premium emoji status. Resolves to the chosen
/// emoji, an empty string to clear the status, or null if dismissed.
Future<String?> showEmojiStatusPicker(
  BuildContext context, {
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15171E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _EmojiStatusSheet(current: current),
  );
}

/// Localized label for a Noto emoji category [slug]. The generated catalog
/// only ships Russian labels (`kNotoCategoryLabelsRu`); this resolves the
/// remaining 7 app locales through [wave1Text] so the section headers and the
/// island tabs read correctly everywhere.
String notoCategoryLabel(BuildContext context, String slug) {
  switch (slug) {
    case 'smileys_and_emotions':
      return wave1Text(
        context,
        ru: 'Смайлики и эмоции',
        en: 'Smileys & emotion',
        uk: 'Смайлики й емоції',
        es: 'Emoticonos y emociones',
        pt: 'Sorrisos e emoções',
        ptBr: 'Carinhas e emoções',
        fr: 'Émojis et émotions',
        de: 'Smileys & Emotionen',
      );
    case 'people':
      return wave1Text(
        context,
        ru: 'Люди и тело',
        en: 'People & body',
        uk: 'Люди й тіло',
        es: 'Personas y cuerpo',
        pt: 'Pessoas e corpo',
        ptBr: 'Pessoas e corpo',
        fr: 'Personnes et corps',
        de: 'Menschen & Körper',
      );
    case 'animals_and_nature':
      return wave1Text(
        context,
        ru: 'Природа',
        en: 'Animals & nature',
        uk: 'Тварини й природа',
        es: 'Animales y naturaleza',
        pt: 'Animais e natureza',
        ptBr: 'Animais e natureza',
        fr: 'Animaux et nature',
        de: 'Tiere & Natur',
      );
    case 'food_and_drink':
      return wave1Text(
        context,
        ru: 'Еда и напитки',
        en: 'Food & drink',
        uk: 'Їжа й напої',
        es: 'Comida y bebida',
        pt: 'Comida e bebida',
        ptBr: 'Comida e bebida',
        fr: 'Nourriture et boissons',
        de: 'Essen & Trinken',
      );
    case 'travel_and_places':
      return wave1Text(
        context,
        ru: 'Путешествия',
        en: 'Travel & places',
        uk: 'Подорожі й місця',
        es: 'Viajes y lugares',
        pt: 'Viagens e lugares',
        ptBr: 'Viagens e lugares',
        fr: 'Voyages et lieux',
        de: 'Reisen & Orte',
      );
    case 'activities_and_events':
      return wave1Text(
        context,
        ru: 'Активности',
        en: 'Activities',
        uk: 'Активності',
        es: 'Actividades',
        pt: 'Atividades',
        ptBr: 'Atividades',
        fr: 'Activités',
        de: 'Aktivitäten',
      );
    case 'objects':
      return wave1Text(
        context,
        ru: 'Предметы',
        en: 'Objects',
        uk: 'Предмети',
        es: 'Objetos',
        pt: 'Objetos',
        ptBr: 'Objetos',
        fr: 'Objets',
        de: 'Objekte',
      );
    case 'symbols':
      return wave1Text(
        context,
        ru: 'Символы',
        en: 'Symbols',
        uk: 'Символи',
        es: 'Símbolos',
        pt: 'Símbolos',
        ptBr: 'Símbolos',
        fr: 'Symboles',
        de: 'Symbole',
      );
    case 'flags':
      return wave1Text(
        context,
        ru: 'Флаги',
        en: 'Flags',
        uk: 'Прапори',
        es: 'Banderas',
        pt: 'Bandeiras',
        ptBr: 'Bandeiras',
        fr: 'Drapeaux',
        de: 'Flaggen',
      );
    default:
      return kNotoCategoryLabelsRu[slug] ?? slug;
  }
}

/// Slug for the «Animated» section that is pinned to the top of the picker.
/// EVERY entry in [kNotoCodepoints] is a Noto *animation* (the table is
/// generated from the Noto-emoji-animation manifest), so this section is the
/// FULL animated set — all catalog emoji except the collapsed skin-tone
/// variants — rendered as Noto Lottie previews.
const String _kAnimatedSlug = '__animated__';

/// The full animated Noto set for the «Animated» tab: every key in
/// [kNotoCodepoints] (each has a Lottie), minus the tone-modified variants that
/// are collapsed out of the grid, kept in catalog (manifest) order. Hundreds of
/// options — not a hand-picked handful.
final List<String> _kAllAnimated = <String>[
  for (final emoji in kNotoCodepoints.keys)
    if (!kNotoSkinToneHidden.contains(emoji)) emoji,
];

class _EmojiStatusSheet extends StatefulWidget {
  const _EmojiStatusSheet({this.current});

  final String? current;

  @override
  State<_EmojiStatusSheet> createState() => _EmojiStatusSheetState();
}

class _EmojiStatusSheetState extends State<_EmojiStatusSheet> {
  String _query = '';
  final ScrollController _scroll = ScrollController();
  // Section slug -> scroll offset, recomputed each layout pass so the island
  // tabs can jump to a category. Keyed lazily by the sliver list below.
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String slug) =>
      _sectionKeys[slug] ??= GlobalKey(debugLabel: 'emoji-status-$slug');

  void _jumpTo(String slug) {
    final key = _sectionKeys[slug];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    // Bucket the catalog by category (bases only — tone variants collapsed).
    final buckets = <String, List<String>>{
      for (final slug in kNotoCategoryOrder) slug: <String>[],
    };
    for (final emoji in kNotoCodepoints.keys) {
      if (kNotoSkinToneHidden.contains(emoji)) continue;
      if (_query.isNotEmpty) {
        final cp = kNotoCodepoints[emoji] ?? '';
        if (!cp.contains(_query) && emoji != _query) continue;
      }
      final slug = kNotoCategories[emoji] ?? 'symbols';
      (buckets[slug] ??= <String>[]).add(emoji);
    }
    // «Animated» bucket — the FULL animated Noto set, only when not searching
    // (searching uses the per-category buckets above, which already cover the
    // whole catalog).
    final featured = _query.isEmpty ? _kAllAnimated : const <String>[];

    // The slugs that actually have content this frame, in display order with
    // «Animated» pinned first.
    final visibleSlugs = <String>[
      if (featured.isNotEmpty) _kAnimatedSlug,
      for (final slug in kNotoCategoryOrder)
        if ((buckets[slug] ?? const <String>[]).isNotEmpty) slug,
    ];

    final hasCurrent = (widget.current ?? '').isNotEmpty;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: (h * 0.62).clamp(360.0, 720.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Эмодзи-статус',
                        en: 'Emoji status',
                        uk: 'Емодзі-статус',
                        es: 'Estado con emoji',
                        pt: 'Estado com emoji',
                        ptBr: 'Status com emoji',
                        fr: 'Statut emoji',
                        de: 'Emoji-Status',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasCurrent)
                    TextButton(
                      onPressed: () => Navigator.pop(context, ''),
                      child: Text(
                        wave1Text(
                          context,
                          ru: 'Убрать',
                          en: 'Remove',
                          uk: 'Прибрати',
                          es: 'Quitar',
                          pt: 'Remover',
                          ptBr: 'Remover',
                          fr: 'Retirer',
                          de: 'Entfernen',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(
                autofocus: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: wave1Text(
                    context,
                    ru: 'Поиск эмодзи',
                    en: 'Search emoji',
                    uk: 'Пошук емодзі',
                    es: 'Buscar emoji',
                    pt: 'Procurar emoji',
                    ptBr: 'Buscar emoji',
                    fr: 'Rechercher un emoji',
                    de: 'Emoji suchen',
                  ),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            // Island-style category switchers (hidden while searching).
            if (visibleSlugs.isNotEmpty && _query.isEmpty)
              _CategoryIslandTabs(
                slugs: visibleSlugs,
                onTap: _jumpTo,
              ),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  // «Animated» section — the full animated Noto catalog, drawn
                  // as cheap system glyphs (see _emojiGridSliver). Only the
                  // chosen status loops the Noto Lottie at its display site.
                  if (featured.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      key: _keyFor(_kAnimatedSlug),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: Color(0xFFE8A33D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              wave1Text(
                                context,
                                ru: 'Анимированные',
                                en: 'Animated',
                                uk: 'Анімовані',
                                es: 'Animados',
                                pt: 'Animados',
                                ptBr: 'Animados',
                                fr: 'Animés',
                                de: 'Animiert',
                              ),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _emojiGridSliver(featured),
                  ],
                  for (final slug in kNotoCategoryOrder)
                    if ((buckets[slug] ?? const <String>[]).isNotEmpty) ...[
                      SliverToBoxAdapter(
                        key: _keyFor(slug),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Text(
                            notoCategoryLabel(context, slug),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      _emojiGridSliver(buckets[slug]!),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A grid sliver of emoji swatches.
  ///
  /// Every swatch — including the «Animated» section, which holds the FULL
  /// animated catalog (hundreds of emoji) — is rendered as a plain (cheap)
  /// system glyph via [Text], exactly like the main emoji picker in
  /// chat_screen. This is deliberate: a screenful of `NotoStatusEmoji` Lottie
  /// previews each spins up a disk/network load (even at `animate: false`),
  /// and with 600+ tiles the lazy [SliverGrid] kicked off a load storm on
  /// every scroll frame — the flicker/lag the user reported. The real Noto
  /// art still appears at the chosen emoji's display site (profile chip /
  /// chat header / list rows / contact-details hero), which loops the Lottie.
  Widget _emojiGridSliver(List<String> emojis) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final e = emojis[i];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context, e),
                child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
              ),
            );
          },
          childCount: emojis.length,
        ),
      ),
    );
  }
}

/// Horizontal strip of frosted "glass island" category chips. Tapping a chip
/// scroll-jumps the grid to that section. Matches the app's island styling
/// (chat header / top bars) via [FrostedHeaderIsland].
class _CategoryIslandTabs extends StatelessWidget {
  const _CategoryIslandTabs({required this.slugs, required this.onTap});

  final List<String> slugs;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
        itemCount: slugs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final slug = slugs[i];
          return FrostedHeaderIsland(
            radius: 16,
            height: 32,
            blurSigma: 18,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(slug),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: _CategoryChipLabel(slug: slug),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChipLabel extends StatelessWidget {
  const _CategoryChipLabel({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    if (slug == _kAnimatedSlug) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: Color(0xFFE8A33D),
          ),
          const SizedBox(width: 5),
          Text(
            wave1Text(
              context,
              ru: 'Анимированные',
              en: 'Animated',
              uk: 'Анімовані',
              es: 'Animados',
              pt: 'Animados',
              ptBr: 'Animados',
              fr: 'Animés',
              de: 'Animiert',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Text(
      notoCategoryLabel(context, slug),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
