// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../thermal_guard.dart';
import '../wave1_l10n.dart';
import '../widgets/premium_glass.dart';
import 'cosmetic_animation_scope.dart';
import 'cosmetic_motion_gate.dart';
import 'live_covers.dart';
import 'live_frames.dart';

/// Built-in catalog of premium animated avatar FRAMES and profile COVERS
/// (TZ-MONETIZE-01 — premium cosmetics). Each item is a short stable [id] stored
/// in the user's profile_meta and rendered client-side here, so every contact
/// sees the same animation with ~0 bandwidth. All items are premium-only.

class AvatarFrame {
  const AvatarFrame({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.builder,
  });

  final String id;
  final String nameRu;
  final String nameEn;

  /// Builds the animated ring overlay for a square avatar of [size].
  final Widget Function(double size) builder;

  String name(bool ru) => ru ? nameRu : nameEn;

  /// The display name in the active locale (all 8 supported locales). Falls back
  /// to [nameEn] for any locale without an explicit translation.
  String nameLocalized(BuildContext context) => _cosmeticNameForLocale(
    wave1LocaleTagFromContext(context),
    id,
    nameRu,
    nameEn,
  );
}

class ProfileCover {
  const ProfileCover({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.builder,
  });

  final String id;
  final String nameRu;
  final String nameEn;

  /// Builds the animated cover banner (fills its container).
  final Widget Function() builder;

  String name(bool ru) => ru ? nameRu : nameEn;

  /// The display name in the active locale (all 8 supported locales). Falls back
  /// to [nameEn] for any locale without an explicit translation.
  String nameLocalized(BuildContext context) => _cosmeticNameForLocale(
    wave1LocaleTagFromContext(context),
    id,
    nameRu,
    nameEn,
  );
}

/// Per-locale display name for a cosmetic catalog item. The ru/en names live on
/// the item; uk/es/pt/pt_BR/fr/de come from this table keyed by `kind:id` (the
/// stable catalog id), so frames and covers that share a motif (e.g. `bears`)
/// each resolve correctly. Unknown locales fall back to [nameEn].
String _cosmeticNameForLocale(
  String localeTag,
  String id,
  String nameRu,
  String nameEn,
) {
  if (localeTag == 'ru') return nameRu;
  if (localeTag == 'en') return nameEn;
  final row = _kCosmeticNameTranslations[id];
  if (row == null) return nameEn;
  return row[localeTag] ?? (localeTag == 'pt_BR' ? row['pt'] : null) ?? nameEn;
}

/// uk / es / pt / pt_BR / fr / de translations for every frame + cover name,
/// keyed by the catalog id. Frame and cover ids are disjoint except where the
/// motif is identical (`bears`, `rainbow`), in which case one entry serves both.
const Map<String, Map<String, String>> _kCosmeticNameTranslations = {
  // ── living covers (набор profile_fx, 23.09.2026) ──
  'snow': {
    'uk': 'Снігопад',
    'es': 'Nevada',
    'pt': 'Nevasca',
    'pt_BR': 'Nevasca',
    'fr': 'Chute de neige',
    'de': 'Schneefall',
  },
  'aurora_fx': {
    'uk': 'Сяйво',
    'es': 'Aurora',
    'pt': 'Aurora',
    'pt_BR': 'Aurora',
    'fr': 'Aurore',
    'de': 'Polarlicht',
  },
  'embers': {
    'uk': 'Вуглинки',
    'es': 'Brasas',
    'pt': 'Brasas',
    'pt_BR': 'Brasas',
    'fr': 'Braises',
    'de': 'Glut',
  },
  'mesh': {
    'uk': 'Меш',
    'es': 'Malla',
    'pt': 'Malha',
    'pt_BR': 'Malha',
    'fr': 'Maillage',
    'de': 'Mesh',
  },
  'starfall': {
    'uk': 'Зорепад',
    'es': 'Lluvia de estrellas',
    'pt': 'Chuva de estrelas',
    'pt_BR': 'Chuva de estrelas',
    'fr': 'Pluie d’étoiles',
    'de': 'Sternschnuppen',
  },
  'synthwave': {
    'uk': 'Синтвейв',
    'es': 'Synthwave',
    'pt': 'Synthwave',
    'pt_BR': 'Synthwave',
    'fr': 'Synthwave',
    'de': 'Synthwave',
  },
  'bokeh': {
    'uk': 'Боке',
    'es': 'Bokeh',
    'pt': 'Bokeh',
    'pt_BR': 'Bokeh',
    'fr': 'Bokeh',
    'de': 'Bokeh',
  },
  'ocean': {
    'uk': 'Океан',
    'es': 'Océano',
    'pt': 'Oceano',
    'pt_BR': 'Oceano',
    'fr': 'Océan',
    'de': 'Ozean',
  },
  'rain_glass': {
    'uk': 'Дощ по склу',
    'es': 'Lluvia en el cristal',
    'pt': 'Chuva no vidro',
    'pt_BR': 'Chuva no vidro',
    'fr': 'Pluie sur la vitre',
    'de': 'Regen am Glas',
  },
  'soap_bubbles': {
    'uk': 'Мильні бульбашки',
    'es': 'Pompas de jabón',
    'pt': 'Bolhas de sabão',
    'pt_BR': 'Bolhas de sabão',
    'fr': 'Bulles de savon',
    'de': 'Seifenblasen',
  },
  'topography': {
    'uk': 'Топографія',
    'es': 'Topografía',
    'pt': 'Topografia',
    'pt_BR': 'Topografia',
    'fr': 'Topographie',
    'de': 'Topografie',
  },
  'silk': {
    'uk': 'Шовк',
    'es': 'Seda',
    'pt': 'Seda',
    'pt_BR': 'Seda',
    'fr': 'Soie',
    'de': 'Seide',
  },
  'constellations': {
    'uk': 'Сузір’я',
    'es': 'Constelaciones',
    'pt': 'Constelações',
    'pt_BR': 'Constelações',
    'fr': 'Constellations',
    'de': 'Sternbilder',
  },
  'sakura': {
    'uk': 'Сакура',
    'es': 'Sakura',
    'pt': 'Sakura',
    'pt_BR': 'Sakura',
    'fr': 'Sakura',
    'de': 'Sakura',
  },
  'clouds': {
    'uk': 'Хмари',
    'es': 'Nubes',
    'pt': 'Nuvens',
    'pt_BR': 'Nuvens',
    'fr': 'Nuages',
    'de': 'Wolken',
  },
  'night_city': {
    'uk': 'Нічне місто',
    'es': 'Ciudad nocturna',
    'pt': 'Cidade à noite',
    'pt_BR': 'Cidade à noite',
    'fr': 'Ville de nuit',
    'de': 'Nachtstadt',
  },
  'flow': {
    'uk': 'Потік',
    'es': 'Flujo',
    'pt': 'Fluxo',
    'pt_BR': 'Fluxo',
    'fr': 'Flux',
    'de': 'Fluss',
  },
  'hologram': {
    'uk': 'Голограма',
    'es': 'Holograma',
    'pt': 'Holograma',
    'pt_BR': 'Holograma',
    'fr': 'Hologramme',
    'de': 'Hologramm',
  },
  'dot_ocean': {
    'uk': 'Точковий океан',
    'es': 'Océano de puntos',
    'pt': 'Oceano de pontos',
    'pt_BR': 'Oceano de pontos',
    'fr': 'Océan de points',
    'de': 'Punkte-Ozean',
  },
  'kaleidoscope': {
    'uk': 'Калейдоскоп',
    'es': 'Caleidoscopio',
    'pt': 'Caleidoscópio',
    'pt_BR': 'Caleidoscópio',
    'fr': 'Kaléidoscope',
    'de': 'Kaleidoskop',
  },
  'eclipse': {
    'uk': 'Затемнення',
    'es': 'Eclipse',
    'pt': 'Eclipse',
    'pt_BR': 'Eclipse',
    'fr': 'Éclipse',
    'de': 'Finsternis',
  },
  'moon_path': {
    'uk': 'Доріжка',
    'es': 'Sendero lunar',
    'pt': 'Trilha lunar',
    'pt_BR': 'Trilha lunar',
    'fr': 'Sentier lunaire',
    'de': 'Mondpfad',
  },
  'ripples': {
    'uk': 'Кола на воді',
    'es': 'Ondas en el agua',
    'pt': 'Ondas na água',
    'pt_BR': 'Ondas na água',
    'fr': 'Ondes sur l’eau',
    'de': 'Wellenringe',
  },
  'spotlight': {
    'uk': 'Прожектор',
    'es': 'Foco',
    'pt': 'Holofote',
    'pt_BR': 'Holofote',
    'fr': 'Projecteur',
    'de': 'Scheinwerfer',
  },
  // ── living frames (набор profile_fx, 23.09.2026) ──
  'cat': {
    'uk': 'Рудик',
    'es': 'Pelirrojo',
    'pt': 'Ruivo',
    'pt_BR': 'Ruivo',
    'fr': 'Rouquin',
    'de': 'Rotschopf',
  },
  'coder': {
    'uk': 'Кодер',
    'es': 'Programador',
    'pt': 'Programador',
    'pt_BR': 'Programador',
    'fr': 'Codeur',
    'de': 'Coder',
  },
  'music': {
    'uk': 'Меломан',
    'es': 'Melómano',
    'pt': 'Melómano',
    'pt_BR': 'Melômano',
    'fr': 'Mélomane',
    'de': 'Musikfan',
  },
  'aquarium': {
    'uk': 'Акваріум',
    'es': 'Acuario',
    'pt': 'Aquário',
    'pt_BR': 'Aquário',
    'fr': 'Aquarium',
    'de': 'Aquarium',
  },
  'slime': {
    'uk': 'Слайм',
    'es': 'Slime',
    'pt': 'Slime',
    'pt_BR': 'Slime',
    'fr': 'Slime',
    'de': 'Schleim',
  },
  'octopus': {
    'uk': 'Восьминіжка',
    'es': 'Pulpito',
    'pt': 'Polvinho',
    'pt_BR': 'Polvinho',
    'fr': 'Petite pieuvre',
    'de': 'Krakenbaby',
  },
  'bird': {
    'uk': 'Пташка',
    'es': 'Pajarito',
    'pt': 'Passarinho',
    'pt_BR': 'Passarinho',
    'fr': 'Petit oiseau',
    'de': 'Vögelchen',
  },
  'lava_lamp': {
    'uk': 'Лава-лампа',
    'es': 'Lámpara de lava',
    'pt': 'Lâmpada de lava',
    'pt_BR': 'Lâmpada de lava',
    'fr': 'Lampe à lave',
    'de': 'Lavalampe',
  },
  'ghost': {
    'uk': 'Привидко',
    'es': 'Fantasmita',
    'pt': 'Fantasminha',
    'pt_BR': 'Fantasminha',
    'fr': 'Petit fantôme',
    'de': 'Geisterchen',
  },
  'streak': {
    'uk': 'Стрік',
    'es': 'Racha',
    'pt': 'Sequência',
    'pt_BR': 'Sequência',
    'fr': 'Série',
    'de': 'Serie',
  },
  'level_up': {
    'uk': 'Level Up',
    'es': 'Level Up',
    'pt': 'Level Up',
    'pt_BR': 'Level Up',
    'fr': 'Level Up',
    'de': 'Level Up',
  },
  'live': {
    'uk': 'В ефірі',
    'es': 'En directo',
    'pt': 'Ao vivo',
    'pt_BR': 'Ao vivo',
    'fr': 'En direct',
    'de': 'Live',
  },
  'bubble_gum': {
    'uk': 'Бабл-гам',
    'es': 'Chicle',
    'pt': 'Chiclete',
    'pt_BR': 'Chiclete',
    'fr': 'Chewing-gum',
    'de': 'Kaugummi',
  },
  'stickers': {
    'uk': 'Стікерпак',
    'es': 'Pack de stickers',
    'pt': 'Pacote de stickers',
    'pt_BR': 'Pacote de figurinhas',
    'fr': 'Pack de stickers',
    'de': 'Stickerpack',
  },
  'aura': {
    'uk': 'Аура',
    'es': 'Aura',
    'pt': 'Aura',
    'pt_BR': 'Aura',
    'fr': 'Aura',
    'de': 'Aura',
  },
  'glitch': {
    'uk': 'Глітч',
    'es': 'Glitch',
    'pt': 'Glitch',
    'pt_BR': 'Glitch',
    'fr': 'Glitch',
    'de': 'Glitch',
  },
  'social_battery': {
    'uk': 'Соцбатарейка',
    'es': 'Batería social',
    'pt': 'Bateria social',
    'pt_BR': 'Bateria social',
    'fr': 'Batterie sociale',
    'de': 'Sozialakku',
  },
  'typing': {
    'uk': 'Друкує…',
    'es': 'Escribiendo…',
    'pt': 'A escrever…',
    'pt_BR': 'Digitando…',
    'fr': 'En train d’écrire…',
    'de': 'Schreibt…',
  },
  'saturn': {
    'uk': 'Сатурн',
    'es': 'Saturno',
    'pt': 'Saturno',
    'pt_BR': 'Saturno',
    'fr': 'Saturne',
    'de': 'Saturn',
  },
  'vinyl': {
    'uk': 'Вініл',
    'es': 'Vinilo',
    'pt': 'Vinil',
    'pt_BR': 'Vinil',
    'fr': 'Vinyle',
    'de': 'Vinyl',
  },
  'weather': {
    'uk': 'Хмаринка',
    'es': 'Nubecita',
    'pt': 'Nuvenzinha',
    'pt_BR': 'Nuvenzinha',
    'fr': 'Petit nuage',
    'de': 'Wölkchen',
  },
  'sleep': {
    'uk': 'Не турбувати',
    'es': 'No molestar',
    'pt': 'Não incomodar',
    'pt_BR': 'Não perturbe',
    'fr': 'Ne pas déranger',
    'de': 'Nicht stören',
  },
  'pixel': {
    'uk': '8-біт',
    'es': '8 bits',
    'pt': '8 bits',
    'pt_BR': '8 bits',
    'fr': '8 bits',
    'de': '8-Bit',
  },
  'drift': {
    'uk': 'Дрифт',
    'es': 'Drift',
    'pt': 'Drift',
    'pt_BR': 'Drift',
    'fr': 'Drift',
    'de': 'Drift',
  },
  'astronaut': {
    'uk': 'Космонавт',
    'es': 'Astronauta',
    'pt': 'Astronauta',
    'pt_BR': 'Astronauta',
    'fr': 'Astronaute',
    'de': 'Astronaut',
  },
  'chrome': {
    'uk': 'Рідкий хром',
    'es': 'Cromo líquido',
    'pt': 'Cromo líquido',
    'pt_BR': 'Cromo líquido',
    'fr': 'Chrome liquide',
    'de': 'Flüssigchrom',
  },
  // ── frames ──
  'cosmic': {
    'uk': 'Космос',
    'es': 'Cosmos',
    'pt': 'Cosmos',
    'pt_BR': 'Cosmos',
    'fr': 'Cosmos',
    'de': 'Kosmos',
  },
  'gold': {
    'uk': 'Золото',
    'es': 'Oro',
    'pt': 'Ouro',
    'pt_BR': 'Ouro',
    'fr': 'Or',
    'de': 'Gold',
  },
  'orbit': {
    'uk': 'Орбіта',
    'es': 'Órbita',
    'pt': 'Órbita',
    'pt_BR': 'Órbita',
    'fr': 'Orbite',
    'de': 'Orbit',
  },
  'neon': {
    'uk': 'Неон',
    'es': 'Neón',
    'pt': 'Néon',
    'pt_BR': 'Néon',
    'fr': 'Néon',
    'de': 'Neon',
  },
  'stars': {
    'uk': 'Зорі',
    'es': 'Estrellas',
    'pt': 'Estrelas',
    'pt_BR': 'Estrelas',
    'fr': 'Étoiles',
    'de': 'Sterne',
  },
  'aurora': {
    'uk': 'Аврора',
    'es': 'Aurora',
    'pt': 'Aurora',
    'pt_BR': 'Aurora',
    'fr': 'Aurore',
    'de': 'Polarlicht',
  },
  'pulse': {
    'uk': 'Пульс',
    'es': 'Pulso',
    'pt': 'Pulso',
    'pt_BR': 'Pulso',
    'fr': 'Pulsation',
    'de': 'Puls',
  },
  'ember': {
    'uk': 'Жар',
    'es': 'Brasas',
    'pt': 'Brasas',
    'pt_BR': 'Brasas',
    'fr': 'Braises',
    'de': 'Glut',
  },
  'nebula': {
    'uk': 'Туманність',
    'es': 'Nebulosa',
    'pt': 'Nebulosa',
    'pt_BR': 'Nebulosa',
    'fr': 'Nébuleuse',
    'de': 'Nebel',
  },
  'electric': {
    'uk': 'Електро',
    'es': 'Eléctrico',
    'pt': 'Elétrico',
    'pt_BR': 'Elétrico',
    'fr': 'Électrique',
    'de': 'Elektro',
  },
  'flame': {
    'uk': 'Полумʼя',
    'es': 'Llama',
    'pt': 'Chama',
    'pt_BR': 'Chama',
    'fr': 'Flamme',
    'de': 'Flamme',
  },
  'smoke': {
    'uk': 'Дим',
    'es': 'Humo',
    'pt': 'Fumo',
    'pt_BR': 'Fumaça',
    'fr': 'Fumée',
    'de': 'Rauch',
  },
  'bears': {
    'uk': 'Ведмедики',
    'es': 'Ositos',
    'pt': 'Ursinhos',
    'pt_BR': 'Ursinhos',
    'fr': 'Oursons',
    'de': 'Bärchen',
  },
  'rainbow': {
    'uk': 'Веселка',
    'es': 'Arcoíris',
    'pt': 'Arco-íris',
    'pt_BR': 'Arco-íris',
    'fr': 'Arc-en-ciel',
    'de': 'Regenbogen',
  },
  'butterfly': {
    'uk': 'Метелики',
    'es': 'Mariposas',
    'pt': 'Borboletas',
    'pt_BR': 'Borboletas',
    'fr': 'Papillons',
    'de': 'Schmetterlinge',
  },
  // ── covers ──
  'space': {
    'uk': 'Космос',
    'es': 'Espacio',
    'pt': 'Espaço',
    'pt_BR': 'Espaço',
    'fr': 'Espace',
    'de': 'Weltraum',
  },
  'waves': {
    'uk': 'Хвилі',
    'es': 'Olas',
    'pt': 'Ondas',
    'pt_BR': 'Ondas',
    'fr': 'Vagues',
    'de': 'Wellen',
  },
  'meteors': {
    'uk': 'Метеори',
    'es': 'Meteoros',
    'pt': 'Meteoros',
    'pt_BR': 'Meteoros',
    'fr': 'Météores',
    'de': 'Meteore',
  },
  'marks': {
    'uk': 'Іконки',
    'es': 'Iconos',
    'pt': 'Ícones',
    'pt_BR': 'Ícones',
    'fr': 'Icônes',
    'de': 'Symbole',
  },
  'goldhaze': {
    'uk': 'Золота димка',
    'es': 'Bruma dorada',
    'pt': 'Bruma dourada',
    'pt_BR': 'Névoa dourada',
    'fr': 'Brume dorée',
    'de': 'Goldener Dunst',
  },
  'logos': {
    'uk': 'Наші іконки',
    'es': 'Iconos de la app',
    'pt': 'Ícones da app',
    'pt_BR': 'Ícones do app',
    'fr': 'Icônes de l’app',
    'de': 'App-Symbole',
  },
  'fire': {
    'uk': 'Багаття',
    'es': 'Fogata',
    'pt': 'Fogueira',
    'pt_BR': 'Fogueira',
    'fr': 'Feu de camp',
    'de': 'Lagerfeuer',
  },
  'fog': {
    'uk': 'Дим',
    'es': 'Humo',
    'pt': 'Fumo',
    'pt_BR': 'Fumaça',
    'fr': 'Fumée',
    'de': 'Rauch',
  },
  'fireflies': {
    'uk': 'Світлячки',
    'es': 'Luciérnagas',
    'pt': 'Pirilampos',
    'pt_BR': 'Vaga-lumes',
    'fr': 'Lucioles',
    'de': 'Glühwürmchen',
  },
};

final List<AvatarFrame> kAvatarFrames = [
  AvatarFrame(
    id: 'cosmic',
    nameRu: 'Космос',
    nameEn: 'Cosmic',
    builder: (s) => _AnimatedFrame(size: s, kind: 'cosmic'),
  ),
  AvatarFrame(
    id: 'gold',
    nameRu: 'Золото',
    nameEn: 'Gold',
    builder: (s) => _AnimatedFrame(size: s, kind: 'gold'),
  ),
  AvatarFrame(
    id: 'orbit',
    nameRu: 'Орбита',
    nameEn: 'Orbit',
    builder: (s) => _AnimatedFrame(size: s, kind: 'orbit'),
  ),
  AvatarFrame(
    id: 'neon',
    nameRu: 'Неон',
    nameEn: 'Neon',
    builder: (s) => _AnimatedFrame(size: s, kind: 'neon'),
  ),
  AvatarFrame(
    id: 'stars',
    nameRu: 'Звёзды',
    nameEn: 'Stars',
    builder: (s) => _AnimatedFrame(size: s, kind: 'stars'),
  ),
  AvatarFrame(
    id: 'aurora',
    nameRu: 'Аврора',
    nameEn: 'Aurora',
    builder: (s) => _AnimatedFrame(size: s, kind: 'aurora'),
  ),
  AvatarFrame(
    id: 'pulse',
    nameRu: 'Пульс',
    nameEn: 'Pulse',
    builder: (s) => _AnimatedFrame(size: s, kind: 'pulse'),
  ),
  AvatarFrame(
    id: 'ember',
    nameRu: 'Угли',
    nameEn: 'Embers',
    builder: (s) => _AnimatedFrame(size: s, kind: 'ember'),
  ),
  AvatarFrame(
    id: 'nebula',
    nameRu: 'Туманность',
    nameEn: 'Nebula',
    builder: (s) => _AnimatedFrame(size: s, kind: 'nebula'),
  ),
  AvatarFrame(
    id: 'electric',
    nameRu: 'Электро',
    nameEn: 'Electric',
    builder: (s) => _AnimatedFrame(size: s, kind: 'electric'),
  ),
  AvatarFrame(
    id: 'flame',
    nameRu: 'Пламя',
    nameEn: 'Flame',
    builder: (s) => _AnimatedFrame(size: s, kind: 'flame'),
  ),
  AvatarFrame(
    id: 'smoke',
    nameRu: 'Дым',
    nameEn: 'Smoke',
    builder: (s) => _AnimatedFrame(size: s, kind: 'smoke'),
  ),
  AvatarFrame(
    id: 'bears',
    nameRu: 'Мишки',
    nameEn: 'Bears',
    builder: (s) => _AnimatedFrame(size: s, kind: 'bears'),
  ),
  AvatarFrame(
    id: 'rainbow',
    nameRu: 'Радуга',
    nameEn: 'Rainbow',
    builder: (s) => _AnimatedFrame(size: s, kind: 'rainbow'),
  ),
  AvatarFrame(
    id: 'butterfly',
    nameRu: 'Бабочки',
    nameEn: 'Butterflies',
    builder: (s) => _AnimatedFrame(size: s, kind: 'butterfly'),
  ),
  AvatarFrame(
    id: 'comet',
    nameRu: 'Комета',
    nameEn: 'Comet',
    builder: (s) => _AnimatedFrame(size: s, kind: 'comet'),
  ),
  AvatarFrame(
    id: 'sakura',
    nameRu: 'Сакура',
    nameEn: 'Sakura',
    builder: (s) => _AnimatedFrame(size: s, kind: 'sakura'),
  ),
  AvatarFrame(
    id: 'phoenix',
    nameRu: 'Феникс',
    nameEn: 'Phoenix',
    builder: (s) => _AnimatedFrame(size: s, kind: 'phoenix'),
  ),
  AvatarFrame(
    id: 'frost',
    nameRu: 'Иней',
    nameEn: 'Frost',
    builder: (s) => _AnimatedFrame(size: s, kind: 'frost'),
  ),
  AvatarFrame(
    id: 'prism',
    nameRu: 'Призма',
    nameEn: 'Prism',
    builder: (s) => _AnimatedFrame(size: s, kind: 'prism'),
  ),
];

/// 🔴 ЖИВЫЕ рамки — персонажи из макета 23.09.2026. Список ОТДЕЛЬНЫЙ, и это
/// не аккуратность ради аккуратности: всё, что окружает [kAvatarFrames] —
/// атлас испечённых кадров, упаковка трёх кадров в каналы, проверка шва
/// петли, — держится на том, что у рамки ЕСТЬ период. У этих периода нет:
/// движение считают пружины, а моменты подёргивания берутся из случайных
/// чисел. Впиши их в тот же список — и семь проверок начнут печь то, чего не
/// существует.
///
/// Выбор пользователя разрешается через [frameById], который смотрит оба
/// списка, поэтому идентификатор из профиля рисуется везде одинаково.
final List<AvatarFrame> kLivingAvatarFrames = [
  AvatarFrame(
    id: 'cat',
    nameRu: 'Рыжик',
    nameEn: 'Ginger',
    builder: (s) => LiveFrameView(size: s, id: 'cat'),
  ),
  AvatarFrame(
    id: 'coder',
    nameRu: 'Кодер',
    nameEn: 'Coder',
    builder: (s) => LiveFrameView(size: s, id: 'coder'),
  ),
  AvatarFrame(
    id: 'music',
    nameRu: 'Меломан',
    nameEn: 'Music lover',
    builder: (s) => LiveFrameView(size: s, id: 'music'),
  ),
  AvatarFrame(
    id: 'aquarium',
    nameRu: 'Аквариум',
    nameEn: 'Aquarium',
    builder: (s) => LiveFrameView(size: s, id: 'aquarium'),
  ),
  AvatarFrame(
    id: 'slime',
    nameRu: 'Слайм',
    nameEn: 'Slime',
    builder: (s) => LiveFrameView(size: s, id: 'slime'),
  ),
  AvatarFrame(
    id: 'octopus',
    nameRu: 'Осьминожка',
    nameEn: 'Octopus',
    builder: (s) => LiveFrameView(size: s, id: 'octopus'),
  ),
  AvatarFrame(
    id: 'bird',
    nameRu: 'Птичка',
    nameEn: 'Birdie',
    builder: (s) => LiveFrameView(size: s, id: 'bird'),
  ),
  AvatarFrame(
    id: 'lava_lamp',
    nameRu: 'Лава-лампа',
    nameEn: 'Lava lamp',
    builder: (s) => LiveFrameView(size: s, id: 'lava_lamp'),
  ),
  AvatarFrame(
    id: 'ghost',
    nameRu: 'Призрачок',
    nameEn: 'Ghostie',
    builder: (s) => LiveFrameView(size: s, id: 'ghost'),
  ),
  AvatarFrame(
    id: 'streak',
    nameRu: 'Стрик',
    nameEn: 'Streak',
    builder: (s) => LiveFrameView(size: s, id: 'streak'),
  ),
  AvatarFrame(
    id: 'level_up',
    nameRu: 'Level Up',
    nameEn: 'Level Up',
    builder: (s) => LiveFrameView(size: s, id: 'level_up'),
  ),
  AvatarFrame(
    id: 'live',
    nameRu: 'В эфире',
    nameEn: 'Live',
    builder: (s) => LiveFrameView(size: s, id: 'live'),
  ),
  AvatarFrame(
    id: 'bubble_gum',
    nameRu: 'Бабл-гам',
    nameEn: 'Bubble gum',
    builder: (s) => LiveFrameView(size: s, id: 'bubble_gum'),
  ),
  AvatarFrame(
    id: 'stickers',
    nameRu: 'Стикерпак',
    nameEn: 'Sticker pack',
    builder: (s) => LiveFrameView(size: s, id: 'stickers'),
  ),
  AvatarFrame(
    id: 'aura',
    nameRu: 'Аура',
    nameEn: 'Aura',
    builder: (s) => LiveFrameView(size: s, id: 'aura'),
  ),
  AvatarFrame(
    id: 'glitch',
    nameRu: 'Глитч',
    nameEn: 'Glitch',
    builder: (s) => LiveFrameView(size: s, id: 'glitch'),
  ),
  AvatarFrame(
    id: 'social_battery',
    nameRu: 'Соцбатарейка',
    nameEn: 'Social battery',
    builder: (s) => LiveFrameView(size: s, id: 'social_battery'),
  ),
  AvatarFrame(
    id: 'typing',
    nameRu: 'Печатает…',
    nameEn: 'Typing…',
    builder: (s) => LiveFrameView(size: s, id: 'typing'),
  ),
  AvatarFrame(
    id: 'saturn',
    nameRu: 'Сатурн',
    nameEn: 'Saturn',
    builder: (s) => LiveFrameView(size: s, id: 'saturn'),
  ),
  AvatarFrame(
    id: 'vinyl',
    nameRu: 'Винил',
    nameEn: 'Vinyl',
    builder: (s) => LiveFrameView(size: s, id: 'vinyl'),
  ),
  AvatarFrame(
    id: 'weather',
    nameRu: 'Тучка',
    nameEn: 'Cloudy',
    builder: (s) => LiveFrameView(size: s, id: 'weather'),
  ),
  AvatarFrame(
    id: 'sleep',
    nameRu: 'Не беспокоить',
    nameEn: 'Do not disturb',
    builder: (s) => LiveFrameView(size: s, id: 'sleep'),
  ),
  AvatarFrame(
    id: 'pixel',
    nameRu: '8-бит',
    nameEn: '8-bit',
    builder: (s) => LiveFrameView(size: s, id: 'pixel'),
  ),
  AvatarFrame(
    id: 'drift',
    nameRu: 'Дрифт',
    nameEn: 'Drift',
    builder: (s) => LiveFrameView(size: s, id: 'drift'),
  ),
  AvatarFrame(
    id: 'astronaut',
    nameRu: 'Космонавт',
    nameEn: 'Astronaut',
    builder: (s) => LiveFrameView(size: s, id: 'astronaut'),
  ),
  AvatarFrame(
    id: 'chrome',
    nameRu: 'Жидкий хром',
    nameEn: 'Liquid chrome',
    builder: (s) => LiveFrameView(size: s, id: 'chrome'),
  ),
];

/// Всё, что можно ВЫБРАТЬ. Экраны выбора ходят сюда, машинерия атласа — в
/// [kAvatarFrames].
final List<AvatarFrame> kAllAvatarFrames = [
  ...kAvatarFrames,
  ...kLivingAvatarFrames,
];

final List<ProfileCover> kProfileCovers = [
  ProfileCover(
    id: 'space',
    nameRu: 'Космос',
    nameEn: 'Space',
    builder: () => const _AnimatedCover(kind: 'space'),
  ),
  ProfileCover(
    id: 'waves',
    nameRu: 'Волны',
    nameEn: 'Waves',
    builder: () => const _AnimatedCover(kind: 'waves'),
  ),
  ProfileCover(
    id: 'meteors',
    nameRu: 'Метеоры',
    nameEn: 'Meteors',
    builder: () => const _AnimatedCover(kind: 'meteors'),
  ),
  ProfileCover(
    id: 'marks',
    nameRu: 'Иконки',
    nameEn: 'Marks',
    builder: () => const _AnimatedCover(kind: 'marks'),
  ),
  ProfileCover(
    id: 'goldhaze',
    nameRu: 'Золотая дымка',
    nameEn: 'Gold haze',
    builder: () => const _AnimatedCover(kind: 'goldhaze'),
  ),
  ProfileCover(
    id: 'logos',
    nameRu: 'Наши иконки',
    nameEn: 'App marks',
    builder: () => const _AnimatedCover(kind: 'logos'),
  ),
  ProfileCover(
    id: 'fire',
    nameRu: 'Костёр',
    nameEn: 'Fire',
    builder: () => const _AnimatedCover(kind: 'fire'),
  ),
  ProfileCover(
    id: 'fog',
    nameRu: 'Дым',
    nameEn: 'Smoke',
    builder: () => const _AnimatedCover(kind: 'fog'),
  ),
  ProfileCover(
    id: 'bears',
    nameRu: 'Мишки',
    nameEn: 'Bears',
    builder: () => const _AnimatedCover(kind: 'bears'),
  ),
  ProfileCover(
    id: 'rainbow',
    nameRu: 'Радуга',
    nameEn: 'Rainbow',
    builder: () => const _AnimatedCover(kind: 'rainbow'),
  ),
  ProfileCover(
    id: 'fireflies',
    nameRu: 'Светлячки',
    nameEn: 'Fireflies',
    builder: () => const _AnimatedCover(kind: 'fireflies'),
  ),
  ProfileCover(
    id: 'fireworks',
    nameRu: 'Салют',
    nameEn: 'Fireworks',
    builder: () => const _AnimatedCover(kind: 'fireworks'),
  ),
  ProfileCover(
    id: 'fireworks_gold',
    nameRu: 'Золотой салют',
    nameEn: 'Golden fireworks',
    builder: () => const _AnimatedCover(kind: 'fireworks_gold'),
  ),
  ProfileCover(
    id: 'reef',
    nameRu: 'Подводный мир',
    nameEn: 'Coral reef',
    builder: () => const _AnimatedCover(kind: 'reef'),
  ),
  ProfileCover(
    id: 'galaxy',
    nameRu: 'Галактика',
    nameEn: 'Galaxy',
    builder: () => const _AnimatedCover(kind: 'galaxy'),
  ),
  ProfileCover(
    id: 'aurora_sky',
    nameRu: 'Северное сияние',
    nameEn: 'Aurora',
    builder: () => const _AnimatedCover(kind: 'aurora_sky'),
  ),
  ProfileCover(
    id: 'blackhole',
    nameRu: 'Чёрная дыра',
    nameEn: 'Black hole',
    // Rendered by a real Schwarzschild-lensing fragment shader (not the
    // CustomPainter path) — see [_BlackHoleShaderCover].
    builder: () => const _BlackHoleShaderCover(),
  ),
];

/// 🔴 ЖИВЫЕ обложки — сцены набора `profile_fx`. Список отдельный от
/// [kProfileCovers] по той же причине, что и у рамок: там свои, написанные под
/// шейдер и видео, здесь — выгрузка со страницы дизайна. Выбор человека
/// разрешает [coverById], который смотрит оба списка.
final List<ProfileCover> kLivingProfileCovers = [
  ProfileCover(
    id: 'snow',
    nameRu: 'Снегопад',
    nameEn: 'Snowfall',
    builder: () => LiveCoverView(id: 'snow'),
  ),
  ProfileCover(
    id: 'aurora_fx',
    nameRu: 'Сияние',
    nameEn: 'Aurora',
    builder: () => LiveCoverView(id: 'aurora_fx'),
  ),
  ProfileCover(
    id: 'embers',
    nameRu: 'Угли',
    nameEn: 'Embers',
    builder: () => LiveCoverView(id: 'embers'),
  ),
  ProfileCover(
    id: 'mesh',
    nameRu: 'Меш',
    nameEn: 'Mesh',
    builder: () => LiveCoverView(id: 'mesh'),
  ),
  ProfileCover(
    id: 'starfall',
    nameRu: 'Звездопад',
    nameEn: 'Starfall',
    builder: () => LiveCoverView(id: 'starfall'),
  ),
  ProfileCover(
    id: 'synthwave',
    nameRu: 'Синтвейв',
    nameEn: 'Synthwave',
    builder: () => LiveCoverView(id: 'synthwave'),
  ),
  ProfileCover(
    id: 'bokeh',
    nameRu: 'Боке',
    nameEn: 'Bokeh',
    builder: () => LiveCoverView(id: 'bokeh'),
  ),
  ProfileCover(
    id: 'ocean',
    nameRu: 'Океан',
    nameEn: 'Ocean',
    builder: () => LiveCoverView(id: 'ocean'),
  ),
  ProfileCover(
    id: 'rain_glass',
    nameRu: 'Дождь по стеклу',
    nameEn: 'Rain on glass',
    builder: () => LiveCoverView(id: 'rain_glass'),
  ),
  ProfileCover(
    id: 'soap_bubbles',
    nameRu: 'Мыльные пузыри',
    nameEn: 'Soap bubbles',
    builder: () => LiveCoverView(id: 'soap_bubbles'),
  ),
  ProfileCover(
    id: 'topography',
    nameRu: 'Топография',
    nameEn: 'Topography',
    builder: () => LiveCoverView(id: 'topography'),
  ),
  ProfileCover(
    id: 'silk',
    nameRu: 'Шёлк',
    nameEn: 'Silk',
    builder: () => LiveCoverView(id: 'silk'),
  ),
  ProfileCover(
    id: 'constellations',
    nameRu: 'Созвездия',
    nameEn: 'Constellations',
    builder: () => LiveCoverView(id: 'constellations'),
  ),
  ProfileCover(
    id: 'sakura_fx',
    nameRu: 'Сакура',
    nameEn: 'Sakura',
    builder: () => LiveCoverView(id: 'sakura_fx'),
  ),
  ProfileCover(
    id: 'clouds',
    nameRu: 'Облака',
    nameEn: 'Clouds',
    builder: () => LiveCoverView(id: 'clouds'),
  ),
  ProfileCover(
    id: 'night_city',
    nameRu: 'Ночной город',
    nameEn: 'Night city',
    builder: () => LiveCoverView(id: 'night_city'),
  ),
  ProfileCover(
    id: 'flow',
    nameRu: 'Поток',
    nameEn: 'Flow',
    builder: () => LiveCoverView(id: 'flow'),
  ),
  ProfileCover(
    id: 'hologram',
    nameRu: 'Голограмма',
    nameEn: 'Hologram',
    builder: () => LiveCoverView(id: 'hologram'),
  ),
  ProfileCover(
    id: 'dot_ocean',
    nameRu: 'Точечный океан',
    nameEn: 'Dot ocean',
    builder: () => LiveCoverView(id: 'dot_ocean'),
  ),
  ProfileCover(
    id: 'kaleidoscope',
    nameRu: 'Калейдоскоп',
    nameEn: 'Kaleidoscope',
    builder: () => LiveCoverView(id: 'kaleidoscope'),
  ),
  ProfileCover(
    id: 'eclipse',
    nameRu: 'Затмение',
    nameEn: 'Eclipse',
    builder: () => LiveCoverView(id: 'eclipse'),
  ),
  ProfileCover(
    id: 'moon_path',
    nameRu: 'Дорожка',
    nameEn: 'Moon path',
    builder: () => LiveCoverView(id: 'moon_path'),
  ),
  ProfileCover(
    id: 'ripples',
    nameRu: 'Круги на воде',
    nameEn: 'Ripples',
    builder: () => LiveCoverView(id: 'ripples'),
  ),
  ProfileCover(
    id: 'spotlight',
    nameRu: 'Прожектор',
    nameEn: 'Spotlight',
    builder: () => LiveCoverView(id: 'spotlight'),
  ),
];

/// Всё, что можно ВЫБРАТЬ в обложках.
final List<ProfileCover> kAllProfileCovers = [
  ...kProfileCovers,
  ...kLivingProfileCovers,
];

AvatarFrame? frameById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final f in kAllAvatarFrames) {
    if (f.id == id) return f;
  }
  return null;
}

/// A cover rendered as a STILL picture: one paint, no ticker, no repeated blur.
/// Pickers use it for every tile except the selected one — a grid of live
/// covers meant seventeen blur-heavy animations at once, and `galaxy` alone
/// costs 43ms a frame.
Widget coverStill(String id) => TickerMode(
  // Belt and braces: the painter-based covers take the still path below,
  // and TickerMode silences the ones that animate through their own widgets
  // (`space`'s dust field, `logos`, the black-hole shader) — a still cover
  // must not drive a ticker by ANY route.
  //
  // 🔴 Живые обложки набора рисуются СВОИМ виджетом, и `_AnimatedCover` про
  // них не знает: без этой ветки плитка выбора оставалась бы пустой у всех,
  // кроме выбранной. Движение у них гасит тот же `TickerMode`.
  enabled: false,
  child: isLiveCoverId(id)
      ? LiveCoverView(id: id, animate: false)
      : _AnimatedCover(kind: id, animate: false),
);

ProfileCover? coverById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final c in kAllProfileCovers) {
    if (c.id == id) return c;
  }
  return null;
}

/// Resolves a cover to a renderable widget. Priority: a user-picked custom
/// [customVideoPath] (looping muted video, owner-only) → a custom [customImagePath]
/// → the built-in animated cover for [coverId]. Returns null when there is none.
///
/// The video plays only where the owner has the local file; interlocutors get
/// [customImagePath] (a still frame grabbed from that video), so passing both is
/// expected — the still is the loading/fallback frame under the video too.
Widget? coverWidgetFor(
  String? coverId, {
  String? customImagePath,
  String? customVideoPath,
  Offset? avatarCenter,
  double? avatarRadius,
}) {
  if (customVideoPath != null && customVideoPath.isNotEmpty) {
    return _VideoCover(
      key: ValueKey(customVideoPath),
      videoPath: customVideoPath,
      stillImagePath: customImagePath,
      fallbackCoverId: coverId,
    );
  }
  if (customImagePath != null && customImagePath.isNotEmpty) {
    return Image.file(
      File(customImagePath),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          coverById(coverId)?.builder() ?? const SizedBox.shrink(),
    );
  }
  // 🔴 Сцены, построенные ВОКРУГ фотографии (затмение, дорожка, круги на
  // воде, прожектор), обязаны знать, где портрет стоит на самом деле: иначе
  // луна всходит мимо лица, а прожектор светит в пустоту. Значения приходят
  // от экрана — он один знает свою раскладку.
  if (isLiveCoverId(coverId) && avatarCenter != null && avatarRadius != null) {
    return LiveCoverView(
      id: coverId!,
      avatarCenter: avatarCenter,
      avatarRadius: avatarRadius,
    );
  }
  return coverById(coverId)?.builder();
}

/// Layered variant of [coverWidgetFor] for screens that draw the avatar photo
/// ON TOP of the cover (the profile hero): for covers that support it (the
/// black hole), returns the scene WITHOUT its foreground pass, so the photo can
/// sit INSIDE the scene; [coverFrontWidgetFor] then supplies the pass to draw
/// OVER the photo. For every other cover this is exactly [coverWidgetFor].
Widget? coverBackWidgetFor(
  String? coverId, {
  String? customImagePath,
  String? customVideoPath,
  Offset? avatarCenter,
  double? avatarRadius,
}) {
  final custom =
      (customVideoPath != null && customVideoPath.isNotEmpty) ||
      (customImagePath != null && customImagePath.isNotEmpty);
  if (!custom && coverId == 'blackhole') {
    return const _BlackHoleShaderCover(layer: 2);
  }
  return coverWidgetFor(
    coverId,
    customImagePath: customImagePath,
    customVideoPath: customVideoPath,
    avatarCenter: avatarCenter,
    avatarRadius: avatarRadius,
  );
}

/// The transparent foreground pass to draw OVER the avatar photo (see
/// [coverBackWidgetFor]) — the black hole's near disk edge crossing in front,
/// so the photo reads as being INSIDE the event horizon. Null when the active
/// cover has no foreground pass (or a custom photo/video cover is set).
Widget? coverFrontWidgetFor(
  String? coverId, {
  String? customImagePath,
  String? customVideoPath,
}) {
  final custom =
      (customVideoPath != null && customVideoPath.isNotEmpty) ||
      (customImagePath != null && customImagePath.isNotEmpty);
  if (!custom && coverId == 'blackhole') {
    return const _BlackHoleShaderCover(layer: 1);
  }
  return null;
}

/// A looping, muted custom video cover. Falls back to the still frame (or the
/// catalog cover) while loading or if the file/codec can't be played.
class _VideoCover extends StatefulWidget {
  const _VideoCover({
    super.key,
    required this.videoPath,
    this.stillImagePath,
    this.fallbackCoverId,
  });

  final String videoPath;
  final String? stillImagePath;
  final String? fallbackCoverId;

  @override
  State<_VideoCover> createState() => _VideoCoverState();
}

class _VideoCoverState extends State<_VideoCover> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final file = File(widget.videoPath);
      if (!file.existsSync()) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final c = VideoPlayerController.file(file);
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      // NOTE: no per-frame listener. [VideoPlayer] repaints itself from the
      // texture; a listener here rebuilt this subtree 30-60 times a second for
      // nothing.
      setState(() {
        _controller = c;
        _ready = true;
      });
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _still() {
    final p = widget.stillImagePath;
    if (p != null && p.isNotEmpty) {
      return Image.file(
        File(p),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            coverById(widget.fallbackCoverId)?.builder() ??
            ColoredBox(color: Theme.of(context).colorScheme.surface),
      );
    }
    return coverById(widget.fallbackCoverId)?.builder() ??
        ColoredBox(color: Theme.of(context).colorScheme.surface);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed || c == null || !_ready) return _still();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}

/// Turns a repeating 0→1 [AnimationController] value into a monotonically
/// increasing phase, so painters built from sin/cos/`% 1` of it loop with no
/// visible jump at the controller's wrap boundary: the raw value resets to 0
/// each cycle, but the phase keeps climbing, so the trig terms stay continuous
/// and particle phases wrap independently (after they've already faded out).
mixin _MonotonicPhase {
  int _phaseCycles = 0;
  double _phaseLast = -1;
  double monotonic(double v) {
    if (v < _phaseLast) _phaseCycles++;
    _phaseLast = v;
    return _phaseCycles + v;
  }
}

/// Snaps a monotonic phase (in cycles) to a ~[fps] grid so a CustomPainter's
/// `shouldRepaint` (which compares the phase) skips the in-between display
/// frames: the animation still advances, just at [fps] instead of the 60/120 Hz
/// display rate. Visually identical for these slow (2–18 s) cosmetic loops, but
/// halves the blur/gradient-heavy GPU repaints — the dominant cost (and heat)
/// when many premium avatar frames share a chat/rooms list at once.
/// [periodSeconds] is the loop duration so the grid is [fps] regardless of how
/// fast each kind spins.
double _quantizePhase(
  double monotonicPhase,
  double periodSeconds, {
  double fps = 30,
}) {
  final steps = fps * periodSeconds;
  if (steps <= 0) return monotonicPhase;
  return (monotonicPhase * steps).floorToDouble() / steps;
}

/// Fraction of the screen resolution a cover is RASTERISED at before being
/// scaled back up. Blur holds no fine detail, so for the heavy blurred kinds
/// this is nearly free visually — `test/covers_cost_probe_test.dart` measures
/// the loss at half raster: `waves` 0.22, `reef` 0.84, `galaxy` 1.01,
/// `aurora_sky` 1.38 out of 255. Blur cost scales with AREA, so half the side
/// is a quarter of the work.
///
/// `fog` is deliberately absent: it measures 6.49 — its soft columns do carry
/// structure, and halving them is visible. It gets a lower tick rate instead.
double _coverRasterScaleFor(String kind) {
  switch (kind) {
    case 'galaxy': // 43ms a frame, loses 1.01
    case 'aurora_sky': // 15ms, loses 1.38
    case 'waves': // 11ms, loses 0.22
    case 'reef': // 9ms, loses 0.84
      return 0.5;
    default:
      return 1.0;
  }
}

/// Repaints per second for a cover, sized by what one of its frames actually
/// costs (`test/covers_cost_probe_test.dart` times every kind): the catalogue
/// spans 300x, from 0.12ms for `meteors` to 43ms for `galaxy`. A slow, blurred
/// cover looks the same at 12fps as at 30 — its particles move a fraction of a
/// pixel per tick — so the expensive kinds simply tick less often instead of
/// being redrawn.
double _coverFpsFor(String kind) {
  switch (kind) {
    // Costs 42ms a frame and is the one heavy cover that CANNOT be rasterised
    // smaller (its soft columns lose 3.4/255 even at three quarters), so the
    // rate is where its budget comes from. Its particles drift a fraction of a
    // pixel per tick — 12 and 30 look the same.
    case 'fog':
      return 12;
    // Rasterised at half size (see [_coverRasterScaleFor]): a quarter of the
    // blur work, so the saving buys back SMOOTHNESS instead of being pocketed.
    // Still well inside the budget the cost test enforces.
    case 'galaxy':
    case 'aurora_sky':
    case 'waves':
    case 'reef':
      return 24;
    case 'fire': // 4.5ms
    case 'fireworks':
    case 'fireworks_gold':
    case 'rainbow':
      return 20;
    default:
      return 30; // bears, fireflies, goldhaze, marks, meteors — under 1ms
  }
}

/// Drives a repeating cosmetic animation the way a LIST needs it, where many
/// premium frames/covers animate at once.
///
/// Instead of a 60/120 Hz [AnimatedBuilder] per widget — plus a per-widget
/// `VisibilityDetector` that re-computed visibility on *every scroll frame*
/// (O(N) UI-thread work, a real scroll-jank tax when a screenful of contacts
/// carry frames) — it exposes ONE [phase] `ValueNotifier` quantised to ≈30fps.
/// Painters repaint off that: half the (blur-heavy) GPU repaints and no 60fps
/// rebuilds, while the slow 2–18 s loops look identical.
///
/// Pausing is free and needs no detector: the [SingleTickerProviderStateMixin]
/// controller is auto-muted by Flutter when its route is covered (`TickerMode`)
/// and the engine stops ticking it when the app is backgrounded; we also stop
/// it explicitly on lifecycle change as a belt-and-braces heat guard. Rows
/// scrolled fully out of the list are disposed by `ListView.builder`, which
/// tears the controller down entirely.
mixin _CosmeticRepaint<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver, _MonotonicPhase {
  /// The repeating controller to read + gate.
  AnimationController get pausableController;

  /// Quantised (≈30fps) monotonic phase in cycles; painters repaint off this.
  final ValueNotifier<double> phase = ValueNotifier<double>(0);
  double _lastPhase = double.nan;
  bool _resumed = true;

  /// Repaint rate for this cosmetic; kinds override it by cost.
  double get cosmeticFps => 30;

  /// Wire the controller → [phase] pump. Call from the State's `initState`
  /// once the (late) controller exists.
  void initCosmeticRepaint() {
    WidgetsBinding.instance.addObserver(this);
    pausableController.addListener(_pumpPhase);
    _pumpPhase();
  }

  void _pumpPhase() {
    // Running hot → hold the current picture. The animation keeps ADVANCING
    // (the phase is read from the controller, not accumulated), so when the
    // device cools the cosmetic resumes where it should be, not where it
    // stopped — but until then it costs nothing to draw.
    if (!ThermalGuard.effectsAllowed.value) return;
    final period = pausableController.duration!.inMicroseconds / 1e6;
    final q = _quantizePhase(
      monotonic(pausableController.value),
      period,
      fps: cosmeticFps,
    );
    if (q != _lastPhase) {
      _lastPhase = q;
      phase.value = q;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    _resumed = resumed;
    if (resumed) {
      if (!pausableController.isAnimating) pausableController.repeat();
    } else if (pausableController.isAnimating) {
      pausableController.stop();
    }
  }

  @override
  void dispose() {
    // The State disposes its controller immediately before super.dispose(),
    // which already drops the [_pumpPhase] listener — so only our own
    // resources remain to release here.
    WidgetsBinding.instance.removeObserver(this);
    phase.dispose();
    super.dispose();
  }

  /// Rebuilds [builder] at ≈30fps off [phase] — no 60fps AnimatedBuilder churn.
  Widget cosmeticBuilder(ValueWidgetBuilder<double> builder) =>
      ValueListenableBuilder<double>(valueListenable: phase, builder: builder);
}

// ───────────────────────── animated FRAME ─────────────────────────

class _AnimatedFrame extends StatefulWidget {
  const _AnimatedFrame({required this.size, required this.kind});

  final double size;
  final String kind;

  @override
  State<_AnimatedFrame> createState() => _AnimatedFrameState();
}

/// Quantize the requested texture resolution to a small set of buckets so
/// nearby avatar sizes SHARE one baked loop instead of fragmenting the atlas.
/// On 3× displays everything already collapsed into the 116-px bake cap, but
/// on 2× displays a 40-dp header avatar (80 px) and a 52-dp row avatar
/// (104 px) used to bake two full loops of the same frame. Ceiling-bucket →
/// only ever a mild downscale at draw time (FilterQuality.low), never a
/// blurry upscale.
int _quantizeFramePx(int px) {
  if (px <= 64) return 64;
  if (px <= 96) return 96;
  return 116; // == _FrameLoop._maxBakePx
}

int _frameDurationFor(String kind) {
  switch (kind) {
    case 'electric':
      return 2;
    case 'pulse':
    case 'flame':
      return 3;
    case 'butterfly':
      return 5;
    case 'gold':
    case 'neon':
      return 6;
    case 'ember':
      return 13; // {1,2} rises per loop (see the 'ember' painter)
    case 'rainbow':
      return 8;
    case 'aurora':
      return 13; // 1 turn per layer per loop (see the 'aurora' painter)
    case 'cosmic':
      return 23; // whole cycles per loop (see the 'cosmic' painter)
    case 'nebula':
      return 13;
    case 'smoke':
      // 1 rise per loop at 27s ≈ the old 0.6 per 16s — same speed, seamless.
      return 27;
    case 'phoenix':
      return 7; // whole cycles per loop (see the 'phoenix' painter)
    case 'comet':
      return 6;
    case 'prism':
      return 14; // 1 turn / 3 shimmers per loop (see the 'prism' painter)
    case 'frost':
      return 10;
    default:
      return 9; // includes 'sakura' — a gentle slow drift
  }
}

/// Extra transparent margin (fraction of the ring size, per side) baked AROUND
/// the frame texture. Blurred glow / rising particles near the ring used to be
/// hard-clipped at the square px×px texture edge — a visible square border. We
/// now render into a larger canvas with the ring centered, so the blur fades to
/// transparency INSIDE the texture, and the widget draws the texture overscanned
/// (overflowing the avatar box, which is unclipped) so the ring keeps its size.
/// Transparent margin baked around the ring, as a fraction of the ring size,
/// PER SIDE. Asymmetric on purpose: smoke rises, so it needs headroom above and
/// almost none below, and texture area — i.e. memory — is the PRODUCT of the
/// two dimensions. A square margin sized for the tallest side would pay for
/// three sides that draw nothing.
@immutable
class _Overscan {
  const _Overscan(this.l, this.t, this.r, this.b);
  const _Overscan.all(double v) : l = v, t = v, r = v, b = v;

  final double l, t, r, b;
}

const _Overscan _kFrameOverscan = _Overscan.all(0.14);

/// Measured reach past the ring, per kind. The numbers come from
/// `test/frames_overscan_probe_test.dart`, which bakes into an oversized canvas
/// and reads the bounding box of everything non-transparent — reading the
/// painters instead would miss blur radii and seeded offsets. Rounded up with a
/// little slack; every kind not listed here draws inside the shared margin.
_Overscan _overscanFor(String kind) {
  switch (kind) {
    case 'smoke': // measured l .32 t .48 r .29 b .02
      return const _Overscan(0.36, 0.54, 0.34, 0.06);
    case 'phoenix': // measured l .22 t .32 r .27 b .17
      return const _Overscan(0.26, 0.36, 0.31, 0.21);
    default:
      return _kFrameOverscan;
  }
}

/// Texture size for [kind] at [contentPx] ring resolution, plus where the ring
/// sits inside it.
({int w, int h, int ml, int mt}) _frameTextureFor(String kind, int contentPx) {
  final o = _overscanFor(kind);
  final ml = (contentPx * o.l).round();
  final mt = (contentPx * o.t).round();
  return (
    w: contentPx + ml + (contentPx * o.r).round(),
    h: contentPx + mt + (contentPx * o.b).round(),
    ml: ml,
    mt: mt,
  );
}

/// Records [_FramePainter] for [kind] at [phase] into a picture padded by
/// [_overscanFor] on each side. [contentPx] is the ring resolution; the
/// returned picture must be rasterized at [_frameTextureFor]'s size, with the
/// ring offset to (ml, mt) inside it.
ui.Picture _recordPaddedFrame(
  String kind,
  double phase,
  Color accent,
  int contentPx,
) {
  final tex = _frameTextureFor(kind, contentPx);
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.translate(tex.ml.toDouble(), tex.mt.toDouble());
  _FramePainter(
    kind,
    phase,
    accent,
  ).paint(canvas, Size.square(contentPx.toDouble()));
  return rec.endRecording();
}

/// Fraction of the requested ring resolution a kind is actually baked at.
///
/// The five colourful kinds that cannot be channel-packed are the last heavy
/// entries in the atlas, and `test/frames_resolution_probe_test.dart` measures
/// what each kind loses when its texture is baked smaller and scaled back up.
/// The soft ones — no hairline strokes, everything glow and blur — lose under
/// 1/255 at three quarters, which is nothing the eye can find, and 3/4 of the
/// side is 56% of the pixels. The crisp ones (`prism` 2.2, `neon` 2.4,
/// `nebula` 3.5, `aurora` 4.1) keep every pixel.
double _bakeScaleFor(String kind) {
  switch (kind) {
    case 'comet': // 0.71
    case 'sakura': // 0.87
    case 'bears': // 0.99
    case 'butterfly': // 0.55
      return 0.75;
    default:
      return 1.0;
  }
}

/// Kinds whose art is ONE colour modulated by opacity, measured — not guessed —
/// by `test/frames_monochrome_probe_test.dart`: rebuilding every pixel as
/// `tint x alpha` costs them ≤0.5/255 of error, i.e. nothing the eye can see.
/// Such a loop needs no colour channels at all, so THREE of its frames are
/// packed into the R, G and B of one texture and tinted back at draw time.
///
/// Three, not four: textures are stored premultiplied, so a mask living in the
/// alpha channel would scale the other three down with it. Alpha stays at 1 and
/// the saving is exactly 3x.
///
/// (`stars` and `comet` look monochrome and are NOT: they measure 2.7 and 4.5
/// error, with p99 above 26 — packing would visibly flatten them.)
bool _isPackedKind(String kind) =>
    kind == 'cosmic' ||
    kind == 'pulse' ||
    kind == 'orbit' ||
    kind == 'electric' ||
    kind == 'smoke';

/// The one colour a packed kind draws in. Verified against the painters AND
/// against the measured average — `test/frames_packing_test.dart` fails if a
/// tint here drifts from what the kind actually paints.
Color _packedTintFor(String kind, Color accent) {
  switch (kind) {
    case 'cosmic':
      return const Color(0xFFFFFFFF);
    case 'electric':
      return const Color(0xFF6FE0FF);
    case 'smoke':
      return const Color(0xFFC8CDD8);
    default:
      return accent; // pulse, orbit paint with the theme accent
  }
}

/// Frames per packed texture.
const int _kPackGroup = 3;

/// Moves a layer's ALPHA into one colour channel and pins the layer opaque, so
/// three such layers composited with [BlendMode.plus] land in R, G and B
/// without touching each other.
ColorFilter _alphaIntoChannel(int channel) {
  final m = List<double>.filled(20, 0);
  m[channel * 5 + 3] = 1; // out[channel] = in.alpha
  m[19] = 255; // out.alpha = 1
  return ColorFilter.matrix(m);
}

/// Reads one packed channel back as an alpha mask and paints it in [tint].
/// The matrix runs on un-premultiplied input, so the result re-premultiplies to
/// exactly `tint x mask` — the same pixels an unpacked bake would have made.
ColorFilter _channelAsTintedMask(int channel, Color tint) {
  final m = List<double>.filled(20, 0);
  m[4] = tint.r * 255;
  m[9] = tint.g * 255;
  m[14] = tint.b * 255;
  m[15 + channel] = 1; // out.alpha = in[channel]
  return ColorFilter.matrix(m);
}

/// Kinds whose loop cannot be closed by arithmetic: their slow motion (an
/// orbit) and their fast motion (a wingbeat, a twinkle) are in a ratio that
/// would need a loop 5–50x longer to hold whole cycles of both, and at a fixed
/// frame budget that turns the fast motion into a flicker — a worse artefact
/// than the seam itself.
///
/// For these the seam is dissolved instead of solved: the loop is baked from
/// `frameCount + fade` phases and the first [_crossfadeLen] frames are baked as
/// a blend of the loop's START with its CONTINUATION. The last frame then steps
/// into the first as the next moment in time, because that is literally what it
/// is. Cost at draw time: nothing — the blend is baked in.
bool _isCrossfadedKind(String kind) =>
    kind == 'nebula' ||
    kind == 'sakura' ||
    kind == 'flame' ||
    kind == 'bears' ||
    kind == 'butterfly' ||
    kind == 'frost';

/// Frames spent dissolving the seam. About a twelfth of the loop: long enough
/// to hide the join, short enough that the doubled image passes unnoticed.
int _crossfadeLen(int frameCount) => _clampInt(frameCount ~/ 12, 4, 10);

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// Records frame [index] of [kind]'s [frameCount]-frame loop — the ONE place
/// that decides what a numbered frame contains, so bakes, the disk cache and
/// the tests can never disagree about it.
/// Paints the loop of [kind] at a CONTINUOUS [phase] in [0,1) — the one
/// definition of what the animation looks like at a moment in time. Both the
/// baked path (which samples it at frame boundaries) and the live path (which
/// samples it every vsync) go through here, so a frame can never mean two
/// different things.
void _paintLoopPhase(
  Canvas canvas,
  Size size,
  String kind,
  double phase,
  Color accent,
) {
  final fadeFraction = _isCrossfadedKind(kind)
      ? _crossfadeLen(_frameCountFor(kind)) / _frameCountFor(kind)
      : 0.0;
  if (phase >= fadeFraction || fadeFraction <= 0) {
    _FramePainter(kind, phase, accent).paint(canvas, size);
    return;
  }
  // Inside the seam: dissolve the loop's start into its CONTINUATION, so the
  // wrap is the next moment in time rather than a jump back.
  final w = 1.0 - phase / fadeFraction;
  void layer(double p, double opacity) {
    canvas.saveLayer(
      null,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: opacity),
    );
    _FramePainter(kind, p, accent).paint(canvas, size);
    canvas.restore();
  }

  layer(phase, 1.0 - w);
  layer(phase + 1.0, w);
}

ui.Picture _recordLoopFrame(
  String kind,
  int index,
  int frameCount,
  Color accent,
  int contentPx,
) {
  final tex = _frameTextureFor(kind, contentPx);
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.translate(tex.ml.toDouble(), tex.mt.toDouble());
  _paintLoopPhase(
    canvas,
    Size.square(contentPx.toDouble()),
    kind,
    index / frameCount,
    accent,
  );
  return rec.endRecording();
}

/// Records [_kPackGroup] consecutive phases of a packed [kind] into one picture,
/// one per colour channel.
ui.Picture _recordPackedGroup(
  String kind,
  List<int> indices,
  int frameCount,
  Color accent,
  int contentPx,
) {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  // Opaque base: the packed texture must be fully opaque so premultiplication
  // leaves the three masks untouched.
  canvas.drawColor(const Color(0xFF000000), BlendMode.src);
  for (var c = 0; c < indices.length; c++) {
    canvas.saveLayer(
      null,
      Paint()
        ..blendMode = BlendMode.plus
        ..colorFilter = _alphaIntoChannel(c),
    );
    final frame = _recordLoopFrame(
      kind,
      indices[c],
      frameCount,
      accent,
      contentPx,
    );
    canvas.drawPicture(frame);
    frame.dispose();
    canvas.restore();
  }
  return rec.endRecording();
}

/// One frame ready to draw: a texture plus, for packed loops, which channel of
/// it holds the mask (-1 when the texture is an ordinary RGBA frame).
@immutable
class _FrameShot {
  const _FrameShot(this.image, this.channel);

  final ui.Image image;
  final int channel;

  @override
  bool operator ==(Object other) =>
      other is _FrameShot &&
      identical(other.image, image) &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(identityHashCode(image), channel);
}

/// Frames baked for ONE loop of [kind] — single source of truth shared by
/// [_FrameLoop] and the seam test, so a duration change can never drift the
/// two apart.
int _frameCountFor(String kind) =>
    (_frameDurationFor(kind) * _FrameLoop._bakeFps).round().clamp(
      _FrameLoop._minFrames,
      _maxFramesFor(kind),
    );

/// Frame ceiling per kind. What the eye needs is roughly a pixel of motion
/// between frames; `smoke` and `phoenix` drift 0.4px per frame at the shared
/// 96-frame ceiling, so half of their frames carry no new information. Halving
/// them keeps them smooth (0.8px per frame) and buys back the memory their
/// larger margin costs — snapping the clip off is free, not a memory trade.
int _maxFramesFor(String kind) {
  // Frames are spent per kind, in proportion to how much each one actually
  // MOVES between frames — measured by test/frames_loop_seam_test.dart, which
  // prints the mean pixel difference between neighbouring frames. Those numbers
  // spanned 20x across the catalogue at a shared 96-frame ceiling: `neon` crept
  // 0.0003 per frame while `prism` moved 0.0064. Everything below is sized to
  // land near 0.0035 — the step the fastest kinds already ship with, and which
  // reads as smooth — so no kind stores a frame the eye cannot tell from its
  // neighbour, and none is starved.
  switch (kind) {
    // Barely-moving glows: a third of the frames is indistinguishable.
    case 'neon':
    case 'stars':
    case 'gold':
    case 'rainbow':
    case 'ember':
    case 'aurora':
      return 36;
    case 'nebula':
    case 'flame':
    case 'phoenix': // also carries a wide asymmetric margin
      return 40;
    case 'electric': // 9 discrete strikes per loop; frames between are identical
      return 48;
    case 'smoke': // packed, wide margin, slow drift
      return 64;
    case 'butterfly':
      return 72;
    // Packed kinds hold three frames per texture, so twice the frames still
    // cost less memory than one unpacked loop did. Spending that on LENGTH is
    // what lets a loop hold whole cycles of both its slow and its fast motion —
    // the wrap closes without the fast motion turning into a flicker.
    case 'orbit':
    case 'cosmic':
      return 192;
    default:
      return _FrameLoop._maxFrames; // 96: comet, sakura, bears, frost, prism…
  }
}

/// Test-only: bakes ONE frame of [kind] at [phase] in [0,1) through exactly the
/// production path ([_recordPaddedFrame] at the production texture size), so
/// the loop-seam test measures the shipped art, not a re-implementation of it.
/// Never called by the app.
@visibleForTesting
Future<ui.Image> debugBakeFrame(
  String kind,
  double phase, {
  int contentPx = 116,
  Color accent = const Color(0xFF6C8CFF),
}) async {
  final pic = _recordPaddedFrame(kind, phase, accent, contentPx);
  final tex = _frameTextureFor(kind, contentPx);
  try {
    return await pic.toImage(tex.w, tex.h);
  } finally {
    pic.dispose();
  }
}

/// Test-only: frames in one baked loop of [kind]. See [debugBakeFrame].
@visibleForTesting
int debugFrameCount(String kind) => _frameCountFor(kind);

/// Test-only: bakes frame [index] of [kind]'s loop through [_recordLoopFrame] —
/// the same call the production bake makes, so tests see the SHIPPED frame,
/// crossfaded seam included, not a re-derivation of it.
@visibleForTesting
Future<ui.Image> debugBakeLoopFrame(
  String kind,
  int index, {
  int contentPx = 116,
  Color accent = const Color(0xFF6C8CFF),
}) async {
  final pic = _recordLoopFrame(
    kind,
    index,
    _frameCountFor(kind),
    accent,
    contentPx,
  );
  final tex = _frameTextureFor(kind, contentPx);
  try {
    return await pic.toImage(tex.w, tex.h);
  } finally {
    pic.dispose();
  }
}

/// Test-only: runs the FULL packed path for one frame — pack three phases into
/// R/G/B, then read [channel] back through the draw-time filter — so a test can
/// compare it against the unpacked bake of the same phase. Never called by the
/// app.
@visibleForTesting
Future<ui.Image> debugBakePackedFrame(
  String kind,
  List<int> indices,
  int channel, {
  int contentPx = 116,
  Color accent = const Color(0xFF6C8CFF),
}) async {
  final packed = _recordPackedGroup(
    kind,
    indices,
    _frameCountFor(kind),
    accent,
    contentPx,
  );
  final tex = _frameTextureFor(kind, contentPx);
  final ui.Image packedImg;
  try {
    packedImg = await packed.toImage(tex.w, tex.h);
  } finally {
    packed.dispose();
  }
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawImage(
    packedImg,
    Offset.zero,
    Paint()
      ..colorFilter = _channelAsTintedMask(
        channel,
        _packedTintFor(kind, accent),
      ),
  );
  final pic = rec.endRecording();
  packedImg.dispose();
  try {
    return await pic.toImage(tex.w, tex.h);
  } finally {
    pic.dispose();
  }
}

/// Test-only: whether [kind] takes the packed path. See [debugBakePackedFrame].
@visibleForTesting
bool debugIsPacked(String kind) => _isPackedKind(kind);

/// Test-only: how many atlas entries are live right now. A showcase frame must
/// hold NONE (it paints from vectors); a list must hold one per (kind, size,
/// accent) on screen.
@visibleForTesting
int debugAtlasEntryCount() => _FrameAtlas.debugEntryCount;

/// Test-only: drops every cached loop and stops the atlas ticker, so a test can
/// leave no background bake running behind it.
@visibleForTesting
void debugResetFrameAtlas() => _FrameAtlas.debugReset();

/// Test-only: paints ONE frame of [kind] at [phase] straight to a canvas at
/// [size] — the live (unbaked) path a showcase avatar uses. Lets a test time it
/// at profile-page size. Never called by the app.
@visibleForTesting
void Function(ui.Canvas)? debugLiveFramePainter(
  String kind,
  double phase,
  Size size, {
  Color accent = const Color(0xFF6C8CFF),
}) =>
    (canvas) => _FramePainter(kind, phase, accent).paint(canvas, size);

/// Test-only: the repaint rate a cover ships with. See [debugCoverPainterFor].
@visibleForTesting
double debugCoverFps(String id) => _coverFpsFor(id);

/// Test-only: exposes a cover's painter as `(canvas, phase) -> void` so a test
/// can time it. Returns null for covers that are not [_CoverPainter]-based
/// (`space`, `logos`, `blackhole` — a particle widget, a logo widget and a
/// fragment shader). Never called by the app.
@visibleForTesting
void Function(ui.Canvas, double)? debugCoverPainterFor(String id, Size size) {
  if (id == 'space' || id == 'logos' || id == 'blackhole') return null;
  final seed = List<double>.generate(
    40,
    (i) => math.Random(i * 7 + 3).nextDouble(),
  );
  return (canvas, phase) => _CoverPainter(
    id,
    phase,
    const Color(0xFF6C8CFF),
    seed,
  ).paint(canvas, size);
}

/// Test-only: bakes [kind] into a deliberately OVER-sized canvas ([probe]
/// margin per side, as a fraction of the ring) so a test can find where the art
/// actually ends. Used to size the real per-kind margins from measured pixels
/// instead of from reading the painters.
@visibleForTesting
Future<ui.Image> debugBakeProbe(
  String kind,
  double phase, {
  int contentPx = 116,
  double probe = 0.6,
  Color accent = const Color(0xFF6C8CFF),
}) async {
  final marginPx = (contentPx * probe).round();
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.translate(marginPx.toDouble(), marginPx.toDouble());
  _FramePainter(
    kind,
    phase,
    accent,
  ).paint(canvas, Size.square(contentPx.toDouble()));
  final pic = rec.endRecording();
  final tex = contentPx + 2 * marginPx;
  try {
    return await pic.toImage(tex, tex);
  } finally {
    pic.dispose();
  }
}

/// Shared frame renderer: ONE blur/gradient-heavy [_FramePainter] pass per
/// (kind, pixel-size, accent) per ~30fps tick — no matter how many rows show
/// that frame. Every [_AnimatedFrame] instance just blits the shared GPU
/// texture, so "5 contacts with the Gold frame" costs one paint, not five.
/// Один общий таймер на тридцать кадров заменяет N покадровых контроллеров.
/// Записи считаются по ссылкам; таймер останавливается, когда на экране не
/// осталось ни одного украшения.
///
/// Именно таймер, а не `Ticker`: тикер будит кадр на каждом вsync, то есть
/// шестьдесят раз в секунду, а обновлять текстуры нужно тридцать — см.
/// [_kTickPeriod].
class _FrameAtlas {
  static final Map<String, _FrameAtlasEntry> _entries = {}; // on screen now
  static final Map<String, _FrameLoop> _loops = {}; // persistent textures (LRU)
  static const int _maxLoops = 6;
  static int _useClock =
      0; // monotonic LRU stamp (stable across ticker restarts)
  /// 🔴 ТАЙМЕР, А НЕ `Ticker` — и это главное в этом классе.
  ///
  /// `Ticker` будит кадр на КАЖДОМ вsync, то есть шестьдесят раз в секунду.
  /// Текстуры при этом обновлялись тридцать раз: половина тиков не делала
  /// ничего и всё равно стоила полного прохода кадра. Пока на экране есть хоть
  /// одно украшение, приложение не простаивало никогда.
  ///
  /// Замер 12.09.2026 (отладочная сборка, macOS): чат с анимированным
  /// украшением — 43,7 %, тот же чат без украшений — 5,9 %.
  ///
  /// Таймер кадров НЕ ЗАКАЗЫВАЕТ. Кадр появляется сам, когда обновлённая
  /// текстура приходит слушателям, — то есть ровно тридцать раз в секунду и
  /// ровно тогда, когда картинка действительно сменилась.
  ///
  /// Побочная польза: отказы по [CosmeticMotionGate.holdAnimations] и
  /// [ThermalGuard] теперь пропускают не только работу, но и кадр. Раньше во
  /// время прокрутки и при перегреве кадры всё равно заказывались впустую.
  static const Duration _kTickPeriod = Duration(milliseconds: 33);

  /// Нижний порог на случай, если таймер сработает чуть раньше срока: он
  /// защищает от двойного обновления в одну и ту же миллисекунду и НЕ должен
  /// приближаться к периоду, иначе дрожание таймера начнёт съедать каждый
  /// второй тик и частота втихую упадёт вдвое.
  static const double _kMinTickGapSec = 0.020;

  static Timer? _timer;
  static double _lastTick = -1;

  /// 🔴 ФОН: ТАЙМЕР ОБЯЗАН ЗАМОЛКАТЬ, А ТИКЕР ДЕЛАЛ ЭТО САМ.
  ///
  /// `Ticker` живёт кадрами: приложение уходит в фон, движок перестаёт их
  /// выдавать — и тикер замолкает бесплатно. Таймер так не умеет, он будил бы
  /// событийный цикл тридцать раз в секунду на телефоне в кармане.
  ///
  /// Это была бы плата за переход на таймер, и платили бы её ТЫСЯЧИ людей на
  /// мобильной версии, где батарея дороже всего. Поэтому возвращаем то же
  /// поведение явно: в фоне таймер отменяется, при возврате — заводится снова,
  /// если на экране есть что показывать.
  ///
  /// Фаза настенная, поэтому возвращение не отматывает контуры назад и не
  /// догоняет пачкой — они просто продолжаются с нужного места.
  static bool _appResumed = true;
  static _FrameAtlasLifecycle? _lifecycle;

  static void _ensureLifecycleObserver() {
    if (_lifecycle != null) return;
    final observer = _FrameAtlasLifecycle();
    WidgetsBinding.instance.addObserver(observer);
    _lifecycle = observer;
  }

  static void _onAppLifecycle(bool resumed) {
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    if (resumed) {
      if (_entries.isNotEmpty) _startTimer();
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  static void _startTimer() {
    if (!_appResumed) return;
    _timer ??= Timer.periodic(_kTickPeriod, (_) => _onTick());
  }

  @visibleForTesting
  static int get debugEntryCount => _entries.length;

  @visibleForTesting
  static void debugReset() {
    for (final loop in _loops.values) {
      loop.dispose(abort: true);
    }
    _loops.clear();
    _entries.clear();
    _timer?.cancel();
    _timer = null;
    _lastTick = -1;
    final observer = _lifecycle;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _lifecycle = null;
    }
    _appResumed = true;
  }

  static String keyFor(String kind, int px, Color accent) =>
      '$kind|$px|${accent.toARGB32()}';

  static _FrameAtlasEntry acquire(String kind, int px, Color accent) {
    final key = keyFor(kind, px, accent);
    final entry = _entries.putIfAbsent(key, () {
      final loop = _loops[key] ??= _FrameLoop(
        kind: kind,
        px: px,
        accent: accent,
      );
      loop.lastUsedTick = ++_useClock;
      _evictLoopsIfNeeded(key);
      return _FrameAtlasEntry(key: key, kind: kind, loop: loop);
    });
    entry.refs++;
    _ensureLifecycleObserver();
    _startTimer();
    return entry;
  }

  static void release(_FrameAtlasEntry entry) {
    entry.refs--;
    if (entry.refs > 0) return;
    _entries.remove(entry.key);
    entry.loop.lastUsedTick = ++_useClock; // mark recently-released for the LRU
    entry.disposeEntry(); // frees the notifier only — the loop stays cached
    if (_entries.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _lastTick = -1;
    }
  }

  // Keep at most [_maxLoops] cached loops so re-entering a screen reuses its
  // textures instead of re-baking (the old "3s hitch on navigation"). Never
  // evict [keepKey] or a loop an on-screen entry still references; drop the
  // least-recently-used of the rest.
  static void _evictLoopsIfNeeded(String keepKey) {
    if (_loops.length <= _maxLoops) return;
    final evictable =
        _loops.entries
            .where((e) => e.key != keepKey && !_entries.containsKey(e.key))
            .toList()
          ..sort(
            (a, b) => a.value.lastUsedTick.compareTo(b.value.lastUsedTick),
          );
    for (final e in evictable) {
      if (_loops.length <= _maxLoops) break;
      _loops.remove(e.key);
      e.value.dispose();
    }
  }

  static void _onTick() {
    // WALL-CLOCK phase, not elapsed-since-start: the timer is cancelled
    // whenever the last animated frame leaves the screen and recreated on the
    // next one — a counter would restart from zero, which REWOUND every visible
    // loop to phase 0 mid-cycle ("рамки возвращаются назад"). Wall-clock time
    // is continuous across restarts, so loops always advance monotonically.
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (now - _lastTick < _kMinTickGapSec) return;
    // Fling in progress → hold the current textures (zero blits, the whole
    // frame budget goes to the scroll). Phase is wall-clock derived, so the
    // loop simply skips ahead on resume — no catch-up burst.
    if (CosmeticMotionGate.holdAnimations) return;
    // Same heat guard the covers use: hold the current texture while the device
    // is thermally throttled. Phase is wall-clock derived, so loops resume in
    // the right place rather than catching up in a burst.
    if (!ThermalGuard.effectsAllowed.value) return;
    _lastTick = now;
    for (final entry in _entries.values) {
      entry.updateForTick(now);
    }
  }
}

/// One on-screen (kind, px, accent) in use. Lightweight: it shares a persistent
/// [_FrameLoop] and just republishes the current phase's texture to listeners.
/// Слушает уход приложения в фон ради [_FrameAtlas]: таймер там должен
/// замолкать так же, как замолкал тикер.
class _FrameAtlasLifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _FrameAtlas._onAppLifecycle(state == AppLifecycleState.resumed);
  }
}

class _FrameAtlasEntry {
  _FrameAtlasEntry({required this.key, required this.kind, required this.loop});

  final String key;
  final String kind;
  final _FrameLoop loop;
  int refs = 0;

  final ValueNotifier<_FrameShot?> image = ValueNotifier<_FrameShot?>(null);

  void updateForTick(double nowSeconds) {
    final phase = (nowSeconds / _frameDurationFor(kind)) % 1.0;
    final shot = loop.frameForPhase(phase);
    if (shot != null && shot != image.value) {
      image.value = shot;
    }
  }

  void disposeEntry() {
    // Do NOT dispose [loop] — it is shared/persistent in the atlas cache.
    image.value = null;
    image.dispose();
  }
}

/// The rasterized loop textures for one (kind, px, accent). Built ONCE and
/// ASYNCHRONOUSLY: each frame is recorded (cheap, UI thread) then rasterized via
/// [ui.Picture.toImage] on the raster thread, so the UI thread never stalls
/// while a loop warms up — the previous version recorded the heavy vector frame
/// + a synchronous `toImageSync` every tick, which janked hard on first appear
/// AND re-baked on every navigation. Loops persist in [_FrameAtlas._loops] so
/// jumping between screens reuses them.
class _FrameLoop {
  _FrameLoop({required this.kind, required int px, required this.accent})
    : _bakePx = (px.clamp(8, _maxBakePx) * _bakeScaleFor(kind)).round(),
      frameCount = _frameCountFor(kind) {
    _frames = List<ui.Image?>.filled(_textureCount, null);
    unawaited(_build());
  }

  // Baked frames per loop-second. 24 fps is the Telegram-premium ballpark and
  // is indistinguishable from 30 for these blurred-glow effects (the display
  // ticker quantizes to ≤30fps anyway) — but it cuts bake work and texture
  // memory by ~40% vs the old 30fps/150-frame config. The whole loop is still
  // rasterized ONCE (async, cached), so runtime stays a cheap per-tick blit.
  // Long slow loops cap out at maxFrames (lower effective fps, but per-frame
  // motion is tiny so it still reads smooth).
  static const double _bakeFps = 24;
  static const int _minFrames = 36;
  static const int _maxFrames = 96;
  static const int _maxBakePx = 116; // cap texture size → bounded memory
  // (~96 frames × ~152px² × 4B ≈ 9MB per loop; LRU-capped in _FrameAtlas)

  final String kind;
  final Color accent;
  final int _bakePx;
  final int frameCount;

  /// Textures actually held: a packed loop stores [_kPackGroup] frames per
  /// texture, so it holds a third as many.
  int get _textureCount => _isPackedKind(kind)
      ? (frameCount + _kPackGroup - 1) ~/ _kPackGroup
      : frameCount;

  late final List<ui.Image?> _frames;
  int _builtCount = 0;
  bool _disposed = false; // images freed — terminal state
  bool _evictRequested = false; // dispose() while _build() was in flight
  // Hard stop for an in-flight bake. Normal LRU eviction deliberately lets a
  // started bake FINISH (an aborted one is wasted heat, and abandoning bakes
  // made lists with more kinds than the cache re-bake forever); this is only
  // for an explicit teardown, where nothing will ever look at the result.
  bool _abort = false;
  bool _buildInFlight = false;
  int lastUsedTick = 0;

  /// Serializes VECTOR BAKES process-wide: one loop bakes at a time, so the
  /// raster thread carries at most one extra blur-heavy texture per vsync in
  /// TOTAL — several loops warming up concurrently used to multiply the paced
  /// load back into a flood (heat + dropped frames on lists with many kinds).
  static Future<void> _bakeTail = Future<void>.value();

  // ── Disk cache of baked loops ────────────────────────────────────────
  // A fully-baked loop is persisted once and re-loaded on later launches via
  // image DECODE (codec threads) instead of re-running the blur-heavy vector
  // painter — after the first session a frame costs no raster-thread bake at
  // all. Container: 'SFL2' magic, uint32 frameCount, uint32 texW, uint32
  // texH, then per frame uint32 pngLength + png bytes. Filename carries kind/px/accent/
  // frameCount, the directory carries the format+art version — any change in
  // painter art must bump the directory suffix. Corruption/mismatch → delete
  // and fall back to the vector bake. All IO is best-effort: no cache failure
  // may ever surface to the UI.
  static const int _cacheMagic = 0x53464c32; // 'SFL2' (header carries w+h)
  static const int _maxCachedLoops = 16;
  static Directory? _cacheDir;
  static bool _cacheDirFailed = false;
  static bool _evictionDone = false;

  static Future<Directory?> _loopCacheDir() async {
    if (_cacheDirFailed) return null;
    final cached = _cacheDir;
    if (cached != null) return cached;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/frame_loops_v4');
      await dir.create(recursive: true);
      _cacheDir = dir;
      return dir;
    } catch (_) {
      _cacheDirFailed = true;
      return null;
    }
  }

  String get _cacheFileName =>
      '${kind}_${_bakePx}_${accent.toARGB32().toRadixString(16)}_$frameCount.sfl';

  Future<bool> _loadFromDisk() async {
    File? file;
    try {
      final dir = await _loopCacheDir();
      if (dir == null || _disposed) return false;
      file = File('${dir.path}/$_cacheFileName');
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      if (_disposed) return true; // stop quietly; nothing to publish
      final data = ByteData.sublistView(bytes);
      if (bytes.length < 16 ||
          data.getUint32(0) != _cacheMagic ||
          data.getUint32(4) != frameCount ||
          data.getUint32(8) != _frameTextureFor(kind, _bakePx).w ||
          data.getUint32(12) != _frameTextureFor(kind, _bakePx).h) {
        unawaited(file.delete().then((_) {}, onError: (_) {}));
        return false;
      }
      var off = 16;
      final decoded = <ui.Image>[];
      for (var i = 0; i < _textureCount; i++) {
        if (off + 4 > bytes.length) throw const FormatException('truncated');
        final len = data.getUint32(off);
        off += 4;
        if (len == 0 || off + len > bytes.length) {
          throw const FormatException('truncated');
        }
        final codec = await ui.instantiateImageCodec(
          Uint8List.sublistView(bytes, off, off + len),
        );
        final frameInfo = await codec.getNextFrame();
        codec.dispose();
        decoded.add(frameInfo.image);
        off += len;
        if (_disposed) {
          for (final d in decoded) {
            d.dispose();
          }
          return true;
        }
        // Decodes run on the engine's codec threads; this yield just keeps
        // the UI event loop responsive between them.
        if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
      }
      for (var i = 0; i < _textureCount; i++) {
        _frames[i] = decoded[i];
      }
      _builtCount = _textureCount;
      unawaited(
        file.setLastModified(DateTime.now()).then((_) {}, onError: (_) {}),
      );
      return true;
    } catch (_) {
      if (file != null) {
        unawaited(file.delete().then((_) {}, onError: (_) {}));
      }
      return false;
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final dir = await _loopCacheDir();
      if (dir == null || _disposed) return;
      final file = File('${dir.path}/$_cacheFileName');
      if (await file.exists()) return;
      final builder = BytesBuilder(copy: false);
      final header = ByteData(16)
        ..setUint32(0, _cacheMagic)
        ..setUint32(4, frameCount)
        ..setUint32(8, _frameTextureFor(kind, _bakePx).w)
        ..setUint32(12, _frameTextureFor(kind, _bakePx).h);
      builder.add(header.buffer.asUint8List());
      for (var i = 0; i < _textureCount; i++) {
        final img = _frames[i];
        if (img == null || _disposed) return;
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        if (png == null || png.lengthInBytes == 0) return;
        final rec = ByteData(4)..setUint32(0, png.lengthInBytes);
        builder.add(rec.buffer.asUint8List());
        builder.add(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
        await Future<void>.delayed(Duration.zero);
        if (_disposed) return;
      }
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(builder.takeBytes(), flush: true);
      await tmp.rename(file.path);
      unawaited(_evictOldLoops(dir));
    } catch (_) {
      // best-effort — cache IO must never break the UI
    }
  }

  static Future<void> _evictOldLoops(Directory dir) async {
    if (_evictionDone) return;
    _evictionDone = true;
    try {
      final files = <File>[];
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.sfl')) files.add(e);
      }
      if (files.length <= _maxCachedLoops) return;
      final stats = <(File, DateTime)>[];
      for (final f in files) {
        try {
          stats.add((f, (await f.stat()).modified));
        } catch (_) {}
      }
      stats.sort((a, b) => a.$2.compareTo(b.$2));
      for (var i = 0; i < stats.length - _maxCachedLoops; i++) {
        try {
          await stats[i].$1.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _build() async {
    _buildInFlight = true;
    try {
      // Fast path: a previous session already baked this exact loop.
      if (await _loadFromDisk()) return;
      if (_disposed || _evictRequested) return;
      // Join the global bake queue: exactly one loop bakes at a time.
      final prev = _bakeTail;
      final done = Completer<void>();
      _bakeTail = done.future;
      try {
        await prev;
        // Evicted while waiting in the queue → don't waste raster time; a
        // future acquire() will re-create the loop and bake then.
        if (_disposed || _evictRequested) return;
        // An evicted twin of this key may have finished baking + saving while
        // we sat in the queue — decode its result instead of re-baking.
        if (await _loadFromDisk()) return;
        if (_disposed || _evictRequested) return;
        await _bakeAllFrames();
        if (_builtCount == frameCount && !_disposed) {
          // Persist so later launches (and post-eviction re-acquires) decode
          // instead of re-baking the vector art. Awaited inside the queue so
          // PNG encoding doesn't overlap the next loop's bake either.
          await _saveToDisk();
        }
      } finally {
        done.complete();
      }
    } catch (_) {
      // Defensive: a failed bake must never surface as an unhandled async
      // error — rows simply keep the static texture.
    } finally {
      _buildInFlight = false;
      _finishEvictionIfRequested();
    }
  }

  Future<void> _bakeAllFrames() async {
    for (var i = 0; i < _textureCount; i++) {
      if (_disposed || _abort) return;
      // PERF(bake): each loop texture is a blur-heavy offscreen raster pass.
      // Baking back-to-back used to flood the raster thread — the same thread
      // that rasterizes scroll frames. While the app is producing frames
      // (scroll / the atlas ticker itself), rasterize at most ONE texture per
      // vsync; when the UI is idle, bake at full speed. NOTE: once started, a
      // bake runs to completion even if the loop got evicted — an aborted
      // bake used to be pure wasted heat (nothing published, nothing saved),
      // and lists with >_maxLoops distinct frames re-baked in a loop forever.
      // One texture per vsync — and a PACKED texture rasterises [_kPackGroup]
      // blur-heavy layers at once, so it waits that many vsyncs. Warm-up stays
      // exactly as gentle on the raster thread as it was before packing.
      final sb = SchedulerBinding.instance;
      final waits = _isPackedKind(kind) ? _kPackGroup : 1;
      for (var w = 0; w < waits; w++) {
        if (_disposed || _abort) return;
        if (sb.hasScheduledFrame) {
          await sb.endOfFrame;
        } else {
          await Future<void>.delayed(Duration.zero);
        }
        if (_disposed || _abort) return;
      }
      if (_disposed) return;
      if (_frames[i] != null) continue;
      final packed = _isPackedKind(kind);
      final ui.Picture pic;
      if (packed) {
        // Three consecutive frames of the loop, one per colour channel.
        final indices = <int>[
          for (var k = 0; k < _kPackGroup; k++)
            (i * _kPackGroup + k) % frameCount,
        ];
        pic = _recordPackedGroup(kind, indices, frameCount, accent, _bakePx);
      } else {
        pic = _recordLoopFrame(kind, i, frameCount, accent, _bakePx);
      }
      final tex = _frameTextureFor(kind, _bakePx);
      ui.Image img;
      try {
        img = await pic.toImage(tex.w, tex.h); // async — off the UI thread
      } finally {
        pic.dispose();
      }
      if (_disposed) {
        img.dispose();
        return;
      }
      _frames[i] = img;
      _builtCount++;
    }
  }

  /// Texture for [phase] in [0,1), or null until the loop is COMPLETE (the
  /// caller shows the cheap static frame meanwhile). Publishing partial loops
  /// looked broken: playback through sparse baked frames sped up, stalled and
  /// visibly jumped backwards ("то быстрей, то медленней, то назад").
  _FrameShot? frameForPhase(double phase) {
    if (_builtCount < _textureCount) return null;
    var idx = (phase * frameCount).floor();
    if (idx >= frameCount) idx = frameCount - 1;
    if (!_isPackedKind(kind)) {
      final img = _frames[idx];
      return img == null ? null : _FrameShot(img, -1);
    }
    final img = _frames[idx ~/ _kPackGroup];
    return img == null ? null : _FrameShot(img, idx % _kPackGroup);
  }

  void dispose({bool abort = false}) {
    _evictRequested = true;
    if (abort) _abort = true;
    if (!_buildInFlight) _finishEvictionIfRequested();
  }

  void _finishEvictionIfRequested() {
    if (!_evictRequested || _disposed) return;
    _disposed = true;
    for (final f in _frames) {
      f?.dispose();
    }
    _frames.fillRange(0, _frames.length, null);
    _builtCount = 0;
  }
}

/// Cache of the STATIC (animations-off) frame rendered ONCE per
/// (kind, pixel-size, accent) to a GPU texture. The animations-off path used to
/// re-run the heavy vector [_FramePainter] (blurred glow dots + dozens of
/// draw ops) for EVERY row as it scrolled into view — a burst of expensive
/// paints on the UI thread during a fling = the reported jank. Now the first
/// row builds the texture once and every other row (and re-appearance) just
/// blits it via [RawImage], exactly like the animated atlas path but with no
/// ticker. The accent is the (uniform) theme primary and the phase is fixed, so
/// there is effectively one small texture per frame kind on screen.
class _StaticFrameCache {
  _StaticFrameCache._();

  /// Fixed mid-animation phase — matches the previous static CustomPaint look.
  static const double staticPhase = 0.35;

  static final Map<String, ui.Image> _images = <String, ui.Image>{};

  static ui.Image imageFor(String kind, int px, Color accent) {
    final key = '$kind|$px|${accent.toARGB32()}';
    final cached = _images[key];
    if (cached != null) return cached;
    // Same resolution policy as the animated loop, so switching between the
    // static and animated texture never changes how sharp the frame looks.
    final bakePx = (px * _bakeScaleFor(kind)).round();
    final pic = _recordPaddedFrame(kind, staticPhase, accent, bakePx);
    final tex = _frameTextureFor(kind, bakePx);
    // toImageSync defers GPU rasterization and is cheap here; it runs once per
    // (kind, px, accent) — never per row and never per scroll frame.
    final img = pic.toImageSync(tex.w, tex.h);
    pic.dispose();
    _images[key] = img;
    return img;
  }
}

class _AnimatedFrameState extends State<_AnimatedFrame> {
  _FrameAtlasEntry? _entry;

  /// Whether this frame is a showcase (profile page) and paints live. Cached
  /// from the last dependency change: [build] and [_syncEntry] must agree, and
  /// neither may look it up while the element is deactivating.
  bool _showcase = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncEntry();
  }

  @override
  void didUpdateWidget(covariant _AnimatedFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind || oldWidget.size != widget.size) {
      _syncEntry();
    }
  }

  void _syncEntry() {
    // Animate only when BOTH the user's peer-cosmetics setting allows it here
    // (CosmeticAnimationScope — lists/chat) AND tickers are unmuted (TickerMode
    // is off behind covered routes, so a chat list under an open chat stops).
    final enabled =
        CosmeticAnimationScope.of(context) &&
        TickerMode.valuesOf(context).enabled;
    _showcase = enabled && CosmeticShowcaseScope.of(context);
    // A showcase paints from vectors, so it must NOT hold an atlas entry: that
    // would bake and tick a texture nothing draws.
    final animate = enabled && !_showcase;
    final accent = Theme.of(context).colorScheme.primary;
    final px = _quantizeFramePx(
      (widget.size * MediaQuery.of(context).devicePixelRatio).round().clamp(
        8,
        2048,
      ),
    );
    final wantedKey = animate
        ? _FrameAtlas.keyFor(widget.kind, px, accent)
        : null;
    if (_entry?.key == wantedKey) return;
    if (_entry != null) {
      _FrameAtlas.release(_entry!);
      _entry = null;
    }
    if (wantedKey != null) {
      _entry = _FrameAtlas.acquire(widget.kind, px, accent);
    }
  }

  @override
  void dispose() {
    if (_entry != null) {
      _FrameAtlas.release(_entry!);
      _entry = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    // A showcase (profile page) paints live: full resolution, one frame per
    // vsync. Lists and chat stay on the shared baked atlas.
    if (_showcase) {
      return _LiveFrame(size: widget.size, kind: widget.kind);
    }
    // Same bucket as _syncEntry so the static fallback and the animated loop
    // always resolve to one shared texture resolution.
    final px = _quantizeFramePx(
      (widget.size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
        8,
        2048,
      ),
    );
    // The texture is baked with [_kFrameOverscan] transparent margin so blur
    // fades within it; draw it that much larger than the ring so the ring keeps
    // its size and the fade spills past the (unclipped) avatar box.
    final o = _overscanFor(widget.kind);
    final entry = _entry;
    if (entry == null) {
      // Static frame (animations off / tickers muted): blit a texture rendered
      // ONCE per (kind, px, accent) instead of re-running the heavy vector
      // painter for EVERY row as it scrolls in — that per-row burst of blurred
      // draw ops was the Android chats-list jank. Now every row just composites
      // a cached image, like the animated path but with no ticker.
      final img = _StaticFrameCache.imageFor(widget.kind, px, accent);
      return IgnorePointer(
        child: RepaintBoundary(child: _overscanned(_FrameShot(img, -1), o)),
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<_FrameShot?>(
          valueListenable: entry.image,
          // Until the async loop bakes its first frame, show the cheap STATIC
          // texture so entering the screen is instant and never blank — no
          // UI-thread bake spike; the animation fades in once the loop is ready.
          builder: (context, shot, _) => _overscanned(
            shot ??
                _FrameShot(
                  _StaticFrameCache.imageFor(widget.kind, px, accent),
                  -1,
                ),
            o,
            accent,
          ),
        ),
      ),
    );
  }

  // Draws the (padded) frame texture larger than its box via an OverflowBox so
  // the blur margin overflows the avatar bounds instead of being clipped.
  /// Draws the padded texture larger than its box (via [OverflowBox], so the
  /// margin spills past the unclipped avatar bounds instead of being clipped)
  /// and — since the margin is asymmetric — shifts it so the RING, not the
  /// texture, stays centred on the avatar. The ring centre sits (t-b)/2 below
  /// the texture centre, so the texture moves up by exactly that much.
  Widget _overscanned(_FrameShot shot, _Overscan o, [Color? accent]) {
    // A packed texture carries three frames in R/G/B; the filter reads the right
    // channel back as an alpha mask and paints it in the kind's colour — the
    // same pixels an unpacked bake would produce, at a third of the memory.
    //
    // The filter rides in the Paint of a single drawImageRect rather than in a
    // ColorFiltered widget: that would open a saveLayer per frame per row, and
    // a chats list can carry twenty of them.
    final filter = shot.channel < 0
        ? null
        : _channelAsTintedMask(
            shot.channel,
            _packedTintFor(widget.kind, accent ?? const Color(0xFF6C8CFF)),
          );
    return OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: SizedBox(
        width: widget.size * (1 + o.l + o.r),
        height: widget.size * (1 + o.t + o.b),
        child: CustomPaint(
          painter: _FrameTexturePainter(
            image: shot.image,
            filter: filter,
            // The ring, not the texture, must stay centred on the avatar: the
            // ring centre sits (t-b)/2 below the texture centre.
            shift: Offset(
              widget.size * (o.r - o.l) / 2,
              widget.size * (o.b - o.t) / 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints an animated frame LIVE from vectors, one frame per display tick, at
/// whatever resolution the screen actually has. Used inside a
/// [CosmeticShowcaseScope] (profile pages), where exactly one frame is on
/// screen and it is large — the two conditions that make baking the wrong
/// trade: a baked texture is capped at 116px (a visible stretch at profile
/// size) and holds a thinned set of frames (visible stutter at profile size).
class _LiveFrame extends StatefulWidget {
  const _LiveFrame({required this.size, required this.kind});

  final double size;
  final String kind;

  @override
  State<_LiveFrame> createState() => _LiveFrameState();
}

class _LiveFrameState extends State<_LiveFrame>
    with SingleTickerProviderStateMixin {
  // NOT `late final`: a lazily-created ticker would be constructed BY dispose()
  // if the widget never built, and createTicker looks up TickerMode on an
  // already-deactivated element.
  Ticker? _ticker;
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  double _lastPublished = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    // Thermal guard: hold the picture while the device is throttled.
    if (!ThermalGuard.effectsAllowed.value) return;
    // And hold it while the page is flung: during a ballistic scroll every
    // millisecond belongs to the scroll, and nobody is studying the ring.
    if (CosmeticMotionGate.holdAnimations) return;
    // WALL-CLOCK phase, like the atlas: continuous across ticker restarts, so
    // reopening a profile never rewinds the animation mid-cycle.
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    // 60fps is plenty for these loops; on a 120Hz screen this halves the work
    // for motion nobody can see.
    if (_lastPublished >= 0 && now - _lastPublished < 1 / 60) return;
    _lastPublished = now;
    _phase.value = (now / _frameDurationFor(widget.kind)) % 1.0;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final o = _overscanFor(widget.kind);
    return IgnorePointer(
      child: RepaintBoundary(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          // The padded box is ASYMMETRIC (smoke needs headroom above and none
          // below), so centring the box would leave the RING off-centre — the
          // ring sits (t-b)/2 below the box centre. Shift by exactly that, the
          // same correction the baked path applies to its texture.
          child: Transform.translate(
            offset: Offset(
              widget.size * (o.r - o.l) / 2,
              widget.size * (o.b - o.t) / 2,
            ),
            child: SizedBox(
              width: widget.size * (1 + o.l + o.r),
              height: widget.size * (1 + o.t + o.b),
              child: ValueListenableBuilder<double>(
                valueListenable: _phase,
                builder: (context, phase, _) => CustomPaint(
                  painter: _LiveFramePainter(
                    kind: widget.kind,
                    phase: phase,
                    accent: accent,
                    ring: widget.size,
                    overscan: o,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveFramePainter extends CustomPainter {
  const _LiveFramePainter({
    required this.kind,
    required this.phase,
    required this.accent,
    required this.ring,
    required this.overscan,
  });

  final String kind;
  final double phase;
  final Color accent;
  final double ring;
  final _Overscan overscan;

  @override
  void paint(Canvas canvas, Size size) {
    // Same geometry as a baked texture: the ring sits at (l, t) inside the
    // padded box, so the margin spills past the avatar instead of clipping.
    canvas.translate(overscan.l * ring, overscan.t * ring);
    _paintLoopPhase(canvas, Size.square(ring), kind, phase, accent);
  }

  @override
  bool shouldRepaint(_LiveFramePainter old) =>
      old.phase != phase ||
      old.kind != kind ||
      old.accent != accent ||
      old.ring != ring;
}

/// Blits one baked frame texture: a single [Canvas.drawImageRect] with the
/// unpack filter (if any) in its [Paint]. No saveLayer, no intermediate
/// widgets — the cheapest way to get a texture on screen with a colour filter.
class _FrameTexturePainter extends CustomPainter {
  const _FrameTexturePainter({
    required this.image,
    required this.filter,
    required this.shift,
  });

  final ui.Image image;
  final ColorFilter? filter;
  final Offset shift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(shift.dx, shift.dy, size.width, size.height),
      Paint()
        ..filterQuality = FilterQuality.low
        ..colorFilter = filter,
    );
  }

  @override
  bool shouldRepaint(_FrameTexturePainter old) =>
      !identical(old.image, image) ||
      old.filter != filter ||
      old.shift != shift;
}

/// Precomputed hue→RGB ramp (72 buckets, S=0.85 V=1.0) for the prism shards, so
/// baking doesn't run an HSVColor→RGB conversion per shard per frame (12×72=864
/// per loop). Built once; shards just index it and set their own alpha.
final List<Color> _prismHueLut = List<Color>.generate(
  72,
  (i) => HSVColor.fromAHSV(1.0, i * 5.0, 0.85, 1.0).toColor(),
  growable: false,
);

class _FramePainter extends CustomPainter {
  _FramePainter(this.kind, this.t, this.accent);

  final String kind;
  final double t;
  final Color accent;

  static const _gold = [
    Color(0xFFB9791E),
    Color(0xFFFFF3C8),
    Color(0xFFE8A33D),
    Color(0xFFFFF3C8),
    Color(0xFFB9791E),
  ];
  static const _purple = Color(0xFF8E5BFF);

  void _glowDot(Canvas c, Offset p, double r, Color color) {
    c.drawCircle(
      p,
      r * 2.6,
      Paint()
        ..color = color.withValues(alpha: (color.a * 0.28))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    c.drawCircle(p, r, Paint()..color = color);
  }

  /// Cute teddy-bear head of radius [s] at [p] (ears + muzzle + eyes + nose).
  void _bear(Canvas c, Offset p, double s) {
    const fur = Color(0xFF9C6B3F);
    const dark = Color(0xFF4A2F18);
    final fp = Paint()..color = fur;
    c.drawCircle(p + Offset(-s * 0.62, -s * 0.62), s * 0.42, fp);
    c.drawCircle(p + Offset(s * 0.62, -s * 0.62), s * 0.42, fp);
    c.drawCircle(
      p + Offset(-s * 0.62, -s * 0.62),
      s * 0.2,
      Paint()..color = dark,
    );
    c.drawCircle(
      p + Offset(s * 0.62, -s * 0.62),
      s * 0.2,
      Paint()..color = dark,
    );
    c.drawCircle(p, s, fp);
    c.drawCircle(
      p + Offset(0, s * 0.28),
      s * 0.45,
      Paint()..color = const Color(0xFFE8C9A0),
    );
    final dp = Paint()..color = dark;
    c.drawCircle(p + Offset(-s * 0.38, -s * 0.12), s * 0.12, dp);
    c.drawCircle(p + Offset(s * 0.38, -s * 0.12), s * 0.12, dp);
    c.drawCircle(p + Offset(0, s * 0.16), s * 0.13, dp);
  }

  /// Butterfly of size [s] with flapping wings ([flap] 0..1) facing [ang].
  void _butterfly(
    Canvas c,
    Offset p,
    double s,
    double flap,
    double ang,
    Color col,
  ) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(ang + math.pi / 2);
    final wingW = s * (0.3 + 0.7 * flap); // horizontal squash = folding
    final wp = Paint()..color = col.withValues(alpha: 0.92);
    final wp2 = Paint()..color = col.withValues(alpha: 0.6);
    for (final sgn in [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(sgn * wingW * 0.6, -s * 0.18),
          width: wingW,
          height: s * 0.9,
        ),
        wp,
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(sgn * wingW * 0.5, s * 0.28),
          width: wingW * 0.8,
          height: s * 0.6,
        ),
        wp2,
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 0.16, height: s * 1.2),
        Radius.circular(s * 0.1),
      ),
      Paint()..color = const Color(0xFF3A2A22),
    );
    c.restore();
  }

  /// A single soft cherry-blossom petal of size [s] at [p], rotated [ang].
  void _petal(Canvas c, Offset p, double s, double ang, Color col) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(ang);
    final path = Path()
      ..moveTo(0, -s)
      ..cubicTo(s * 0.72, -s * 0.62, s * 0.5, s * 0.52, 0, s * 0.86)
      ..cubicTo(-s * 0.5, s * 0.52, -s * 0.72, -s * 0.62, 0, -s);
    c.drawPath(path, Paint()..color = col.withValues(alpha: col.a * 0.92));
    // faint notch shading at the rounded tip + a warm vein
    c.drawLine(
      const Offset(0, 0),
      Offset(0, -s * 0.7),
      Paint()
        ..strokeWidth = s * 0.06
        ..color = const Color(0xFFE86FA0).withValues(alpha: 0.28),
    );
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ctr = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.455;
    const tau = math.pi * 2;
    switch (kind) {
      case 'gold':
      case 'neon':
        final colors = kind == 'gold'
            ? _gold
            : [accent, _purple, accent, _purple, accent];
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.055
          ..shader = SweepGradient(
            colors: colors,
            transform: GradientRotation(t * tau),
          ).createShader(Rect.fromCircle(center: ctr, radius: r));
        if (kind == 'neon') {
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.075
              ..color = accent.withValues(alpha: 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
        canvas.drawCircle(ctr, r, ring);
        break;
      case 'orbit':
        canvas.drawCircle(
          ctr,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = accent.withValues(alpha: 0.30),
        );
        for (var i = 0; i < 3; i++) {
          final ang = t * tau + i * tau / 3;
          final p = ctr + Offset(math.cos(ang), math.sin(ang)) * r;
          _glowDot(canvas, p, size.width * 0.035, accent);
        }
        break;
      case 'cosmic':
        canvas.drawCircle(
          ctr,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 0.22),
        );
        // LOOP: 1 orbit / 3 breaths / 4 twinkles per loop (was 0.4 / 1 / 1.4 —
        // the orbit jumped 0.6 of a turn at the wrap). Duration 9s→23s holds
        // every speed within 17%; the packed texture pays for the extra frames.
        for (var i = 0; i < 11; i++) {
          final ang = i * tau / 11 + t * tau;
          final rr = r + math.sin(t * tau * 3 + i) * size.width * 0.012;
          final p = ctr + Offset(math.cos(ang), math.sin(ang)) * rr;
          final tw = 0.4 + 0.6 * ((math.sin(t * tau * 4 + i) + 1) / 2);
          _glowDot(
            canvas,
            p,
            size.width * 0.016,
            Colors.white.withValues(alpha: tw),
          );
        }
        break;
      case 'stars':
        const palette = [Colors.white, Color(0xFFBFD0FF), _purple];
        for (var i = 0; i < 12; i++) {
          final ang = i * tau / 12;
          final p = ctr + Offset(math.cos(ang), math.sin(ang)) * r;
          final tw = (math.sin(t * tau + i * 0.6) + 1) / 2;
          _glowDot(
            canvas,
            p,
            size.width * 0.018 * (0.55 + tw),
            palette[i % 3].withValues(alpha: 0.5 + 0.5 * tw),
          );
        }
        break;
      case 'aurora': // flowing northern-lights gradient ring
        for (var layer = 0; layer < 2; layer++) {
          // LOOP: whole turns per loop (at -0.7 the counter-layer jumped 0.3
          // of a turn at the wrap). Duration 11s→13s splits the resulting
          // speed change between the two layers (±20% each).
          final rot = t * tau * (layer == 0 ? 1 : -1) + layer * 0.6;
          canvas.drawCircle(
            ctr,
            r - layer * size.width * 0.012,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * (0.062 - layer * 0.022)
              ..shader = SweepGradient(
                colors: const [
                  Color(0xFF2BD0C0),
                  Color(0xFF3AA0FF),
                  Color(0xFF8E5BFF),
                  Color(0xFFFF6FD8),
                  Color(0xFF2BD0C0),
                ],
                transform: GradientRotation(rot),
              ).createShader(Rect.fromCircle(center: ctr, radius: r))
              ..maskFilter = MaskFilter.blur(
                BlurStyle.normal,
                layer == 0 ? 3 : 1.5,
              ),
          );
        }
        break;
      case 'pulse': // sonar/radar — concentric rings expanding outward
        canvas.drawCircle(
          ctr,
          r * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.04
            ..color = accent.withValues(alpha: 0.85),
        );
        for (var i = 0; i < 3; i++) {
          final ph = (t + i / 3) % 1.0;
          final rr = r * 0.9 + ph * size.width * 0.11;
          final op = (1.0 - ph).clamp(0.0, 1.0) * 0.7;
          canvas.drawCircle(
            ctr,
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = accent.withValues(alpha: op),
          );
        }
        break;
      case 'ember': // rising flickering fire embers
        canvas.drawCircle(
          ctr,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFFF8A3D).withValues(alpha: 0.22),
        );
        for (var i = 0; i < 16; i++) {
          final base = i / 16;
          // LOOP: the per-particle speed spread must be over WHOLE cycles
          // (0.60…1.08 left every ember mid-flight at the wrap). {1,2} at
          // 13s ≈ the old 0.086…0.154 per second, and the `+ base` phase
          // offset (untouched) still keeps the embers out of lockstep.
          final rise = (t * (1 + (i % 2)) + base) % 1.0;
          final ang = base * tau + math.sin(t * tau + i) * 0.12;
          final rr = r * (0.82 + rise * 0.28);
          final p = ctr + Offset(math.cos(ang), math.sin(ang)) * rr;
          final op = (1.0 - rise).clamp(0.0, 1.0);
          final warm = Color.lerp(
            const Color(0xFFFFE08A),
            const Color(0xFFFF4D2E),
            rise,
          )!;
          _glowDot(
            canvas,
            p,
            size.width * 0.013 * (0.5 + op),
            warm.withValues(alpha: op),
          );
        }
        break;
      case 'nebula': // swirling galaxy ring + stars
        canvas.drawCircle(
          ctr,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.075
            ..shader = SweepGradient(
              colors: const [
                Color(0xFF2A2C6E),
                Color(0xFF7A3DFF),
                Color(0xFFD43AC0),
                Color(0xFF3AA0FF),
                Color(0xFF2A2C6E),
              ],
              transform: GradientRotation(t * tau * 0.5),
            ).createShader(Rect.fromCircle(center: ctr, radius: r))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        for (var i = 0; i < 10; i++) {
          final ang = i * tau / 10 + t * tau * 0.2;
          final p = ctr + Offset(math.cos(ang), math.sin(ang)) * r;
          final tw = (math.sin(t * tau * 2 + i) + 1) / 2;
          canvas.drawCircle(
            p,
            size.width * 0.011 * (0.5 + tw),
            Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.6 * tw),
          );
        }
        break;
      case 'electric': // crackling electric arcs
        canvas.drawCircle(
          ctr,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF6FE0FF).withValues(alpha: 0.22),
        );
        final rnd = math.Random((t * 9).floor());
        for (var a = 0; a < 5; a++) {
          if (rnd.nextDouble() < 0.45) continue;
          final ang0 = a * tau / 5 + rnd.nextDouble() * 0.4;
          final path = Path();
          for (var k = 0; k <= 5; k++) {
            final ang = ang0 + k * 0.11;
            final jit = (rnd.nextDouble() - 0.5) * size.width * 0.05;
            final pp = ctr + Offset(math.cos(ang), math.sin(ang)) * (r + jit);
            if (k == 0) {
              path.moveTo(pp.dx, pp.dy);
            } else {
              path.lineTo(pp.dx, pp.dy);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF6FE0FF).withValues(alpha: 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        break;
      case 'flame':
        {
          // Smouldering ember ring: glowing coals around the rim, denser and
          // brighter toward the bottom (the fire base) and thinning out near the
          // top as they burn out — plus sparks that rise off them and fade.
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.05
              ..color = const Color(0xFFFF5A1A).withValues(alpha: 0.20)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          const n = 54;
          for (var i = 0; i < n; i++) {
            final ang = i * tau / n;
            final radial = Offset(math.cos(ang), math.sin(ang));
            final lowness = (radial.dy + 1) / 2; // 0 top .. 1 bottom
            final flick =
                (math.sin(t * tau * 2.4 + i * 1.3) +
                        math.sin(t * tau * 3.7 + i * 0.6)) *
                    0.25 +
                0.5;
            // Bottom-heavy: coals near the base glow strongest, top almost out.
            final intensity = (lowness * lowness) * (0.35 + 0.65 * flick);
            if (intensity < 0.05) continue;
            final jitter = math.sin(t * tau * 1.6 + i) * size.width * 0.006;
            final p = ctr + radial * (r + jitter);
            final col = Color.lerp(
              const Color(0xFF8C1A00),
              const Color(0xFFFF8A1E),
              flick,
            )!;
            _glowDot(
              canvas,
              p,
              size.width * 0.02 * intensity,
              col.withValues(alpha: intensity.clamp(0.0, 1.0)),
            );
          }
          // Sparks rising off the embers, burning out before they reach the top.
          for (var s = 0; s < 20; s++) {
            final rise = (t * (0.6 + (s % 5) * 0.12) + s / 20) % 1.0;
            final ang0 = math.pi / 2 + math.sin(s * 1.7) * 1.5; // lower arc
            final spawn =
                ctr + Offset(math.cos(ang0), math.sin(ang0)) * (r * 0.92);
            final p =
                spawn +
                Offset(
                  math.sin(t * tau + s) * size.width * 0.02,
                  -rise * r * 1.5,
                );
            final op = (1.0 - rise / 0.62).clamp(0.0, 1.0);
            if (op <= 0) continue;
            _glowDot(
              canvas,
              p,
              size.width * 0.011 * (0.4 + op),
              Color.lerp(
                const Color(0xFFFFD27A),
                const Color(0xFFFF5A1E),
                rise,
              )!.withValues(alpha: op * 0.9),
            );
          }
        }
        break;
      case 'smoke':
        {
          // Visible curling smoke rising upward and swaying.
          // LOOP: every t-driven term completes a WHOLE number of cycles per
          // loop (1 rise, 1 sway) so the last frame steps into the first —
          // 0.6/0.8 used to jump the particle 0.4 of its life backwards at the
          // wrap. Speed is preserved by the loop DURATION instead
          // (_frameDurationFor: 16s → 27s ⇒ 1/27 ≈ the old 0.6/16).
          for (var i = 0; i < 14; i++) {
            final ph = (t + i / 14) % 1.0;
            final ang = i * tau / 14;
            final radial = Offset(math.cos(ang), math.sin(ang));
            final lean = Offset(radial.dx * 0.5, -1.0);
            final up = lean / lean.distance;
            final perp = Offset(-up.dy, up.dx);
            final base = ctr + radial * (r - size.width * 0.01);
            final sway = math.sin(t * tau + i * 1.5) * size.width * 0.05;
            final p = base + up * (ph * size.width * 0.34) + perp * sway;
            final op = (math.sin(ph * math.pi) * 0.6).clamp(0.0, 1.0);
            final rad = size.width * (0.05 + ph * 0.08);
            canvas.drawCircle(
              p,
              rad,
              Paint()
                ..color = const Color(0xFFC8CDD8).withValues(alpha: op)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.7),
            );
          }
        }
        break;
      case 'bears':
        {
          // Cute teddy bears slowly orbiting the avatar, each gently bobbing.
          const n = 7;
          for (var i = 0; i < n; i++) {
            final ang = i * tau / n + t * tau * 0.15;
            final bob = math.sin(t * tau * 2 + i) * size.width * 0.01;
            final p = ctr + Offset(math.cos(ang), math.sin(ang)) * (r + bob);
            _bear(canvas, p, size.width * 0.06);
          }
        }
        break;
      case 'rainbow':
        canvas.drawCircle(
          ctr,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.06
            ..shader = SweepGradient(
              colors: const [
                Color(0xFFFF3B30),
                Color(0xFFFF9500),
                Color(0xFFFFCC00),
                Color(0xFF34C759),
                Color(0xFF00C7BE),
                Color(0xFF007AFF),
                Color(0xFF5856D6),
                Color(0xFFAF52DE),
                Color(0xFFFF3B30),
              ],
              transform: GradientRotation(t * tau),
            ).createShader(Rect.fromCircle(center: ctr, radius: r))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
        );
        break;
      case 'butterfly':
        {
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = accent.withValues(alpha: 0.18),
          );
          const cols = [
            Color(0xFFFF6FD8),
            Color(0xFF7AC7FF),
            Color(0xFFFFD166),
          ];
          for (var i = 0; i < 3; i++) {
            final ang = t * tau * 0.4 + i * tau / 3;
            final p = ctr + Offset(math.cos(ang), math.sin(ang)) * r;
            final flap = (math.sin(t * tau * 5 + i * 2) + 1) / 2;
            _butterfly(canvas, p, size.width * 0.055, flap, ang, cols[i]);
          }
        }
        break;
      case 'comet': // a glowing comet racing around the ring, long tail behind
        {
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.012
              ..color = accent.withValues(alpha: 0.12),
          );
          final headAng = t * tau; // one lap per loop → seamless
          const tailSpan = 1.7; // radians of tail trailing the head
          const segs = 30;
          for (var i = 1; i <= segs; i++) {
            final f = i / segs; // →1 at the head
            final a = headAng - tailSpan * (1 - f);
            final p = ctr + Offset(math.cos(a), math.sin(a)) * r;
            canvas.drawCircle(
              p,
              size.width * 0.05 * f * f,
              Paint()
                ..color = Color.lerp(
                  const Color(0x004AA8FF),
                  const Color(0xFF9AD8FF),
                  f,
                )!.withValues(alpha: 0.55 * f)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
            );
          }
          final head = ctr + Offset(math.cos(headAng), math.sin(headAng)) * r;
          _glowDot(canvas, head, size.width * 0.05, Colors.white);
          for (var i = 0; i < 4; i++) {
            final a = i * tau / 4 + t * 0.3;
            final tw = (math.sin(t * tau * 2 + i * 2) + 1) / 2;
            final p = ctr + Offset(math.cos(a), math.sin(a)) * r;
            canvas.drawCircle(
              p,
              size.width * 0.01 * (0.5 + tw),
              Paint()..color = Colors.white.withValues(alpha: 0.18 + 0.5 * tw),
            );
          }
        }
        break;
      case 'sakura': // cherry-blossom petals drifting + spinning around the ring
        {
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFFFFC8DD).withValues(alpha: 0.16),
          );
          const cols = [
            Color(0xFFFFD7E6),
            Color(0xFFFF9EC4),
            Color(0xFFFFF0F5),
          ];
          const n = 7;
          for (var i = 0; i < n; i++) {
            final ang = i / n * tau + t * tau * 0.22; // slow orbit
            final bob = math.sin(t * tau * 0.8 + i * 1.7) * size.width * 0.03;
            final p = ctr + Offset(math.cos(ang), math.sin(ang)) * (r + bob);
            final spin = t * tau * (0.6 + (i % 3) * 0.2) + i;
            _petal(canvas, p, size.width * 0.055, spin, cols[i % 3]);
          }
        }
        break;
      case 'phoenix': // fiery plumage licking outward + embers rising off it
        {
          const flames = 20;
          for (var i = 0; i < flames; i++) {
            final a = i / flames * tau;
            final flick =
                (math.sin(t * tau * 4 + i * 1.3) + 1) / 2; // whole cycles
            final dir = Offset(math.cos(a), math.sin(a));
            final base = ctr + dir * (r - size.width * 0.02);
            final tip = ctr + dir * (r + size.width * (0.05 + 0.07 * flick));
            canvas.drawLine(
              base,
              tip,
              Paint()
                ..strokeWidth = size.width * 0.03
                ..strokeCap = StrokeCap.round
                ..shader = ui.Gradient.linear(base, tip, [
                  Color.lerp(
                    const Color(0xFFFF3B0A),
                    const Color(0xFFFFD24A),
                    flick,
                  )!.withValues(alpha: 0.9),
                  const Color(0x00FFD24A),
                ])
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
            );
          }
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.03
              ..shader = SweepGradient(
                colors: const [
                  Color(0xFFFF6A00),
                  Color(0xFFFFC247),
                  Color(0xFFFF3B0A),
                  Color(0xFFFF6A00),
                ],
                transform: GradientRotation(t * tau * 2),
              ).createShader(Rect.fromCircle(center: ctr, radius: r)),
          );
          for (var i = 0; i < 12; i++) {
            final a = i / 12 * tau + i * 0.7;
            // LOOP: 1 rise / 4 flickers / 2 gradient turns per loop; duration
            // 4s→7s holds all three within 15% of their old speed.
            final rise = (t + i * 0.13) % 1.0;
            final p =
                ctr +
                Offset(math.cos(a), math.sin(a)) *
                    (r + rise * size.width * 0.28) -
                Offset(0, rise * size.width * 0.06);
            final op = math.sin(rise * math.pi);
            _glowDot(
              canvas,
              p,
              size.width * 0.014 * (0.6 + op),
              Color.lerp(
                const Color(0xFFFFE0A0),
                const Color(0xFFFF5A1E),
                rise,
              )!.withValues(alpha: op),
            );
          }
        }
        break;
      case 'frost': // crystalline ice shards + a bright glint gliding the rim
        {
          const shards = 18;
          for (var i = 0; i < shards; i++) {
            final a = i / shards * tau;
            final sh = (math.sin(t * tau * 1.2 + i) + 1) / 2;
            final dir = Offset(math.cos(a), math.sin(a));
            final inner = ctr + dir * (r - size.width * 0.03);
            final outer = ctr + dir * (r + size.width * 0.045 * (0.5 + sh));
            canvas.drawLine(
              inner,
              outer,
              Paint()
                ..strokeWidth = size.width * 0.016
                ..strokeCap = StrokeCap.round
                ..color = const Color(
                  0xFFCDEBFF,
                ).withValues(alpha: 0.3 + 0.4 * sh),
            );
          }
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.02
              ..color = const Color(0xFFEAF7FF).withValues(alpha: 0.5),
          );
          final ga = t * tau;
          _glowDot(
            canvas,
            ctr + Offset(math.cos(ga), math.sin(ga)) * r,
            size.width * 0.03,
            Colors.white,
          );
          final ga2 = -t * tau * 0.7 + math.pi;
          _glowDot(
            canvas,
            ctr + Offset(math.cos(ga2), math.sin(ga2)) * r,
            size.width * 0.022,
            const Color(0xFFBFE6FF),
          );
        }
        break;
      case 'prism': // rotating spectral ring + shimmering refraction shards
        {
          // LOOP: 1 turn + 3 shimmer cycles per loop (was 0.5 / 1.5 — half a
          // turn short at the wrap). Duration 7s→14s keeps both speeds EXACT.
          final rot = t * tau;
          canvas.drawCircle(
            ctr,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.05
              ..shader = SweepGradient(
                colors: const [
                  Color(0xFFFF5D5D),
                  Color(0xFFFFC24A),
                  Color(0xFF5DFF8F),
                  Color(0xFF5DC8FF),
                  Color(0xFFB05DFF),
                  Color(0xFFFF5D5D),
                ],
                transform: GradientRotation(rot),
              ).createShader(Rect.fromCircle(center: ctr, radius: r))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
          );
          const shards = 12;
          for (var i = 0; i < shards; i++) {
            final a = i / shards * tau + rot;
            final sh = (math.sin(t * tau * 3 + i * 2) + 1) / 2;
            final dir = Offset(math.cos(a), math.sin(a));
            final inner = ctr + dir * (r + size.width * 0.03);
            final outer = ctr + dir * (r + size.width * (0.06 + 0.05 * sh));
            canvas.drawLine(
              inner,
              outer,
              Paint()
                ..strokeWidth = size.width * 0.012
                ..strokeCap = StrokeCap.round
                ..color =
                    _prismHueLut[((i / shards * 360 + rot * 57) % 360 / 5)
                                .floor() %
                            72]
                        .withValues(alpha: 0.5 + 0.4 * sh),
            );
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.t != t || old.kind != kind;
}

// ───────────────────── black-hole shader COVER ─────────────────────

/// Premium "black hole" cover — a real-time Schwarzschild gravitational-lensing
/// fragment shader (event-horizon shadow, photon ring, lensed accretion-disk
/// arcs over/under, relativistic Doppler beaming + differential rotation, and a
/// slow camera drift). Physics is integrated per-pixel in `black_hole.frag`.
///
/// Shows a black fallback while the shader compiles/loads, or if it can't load
/// (old engine / headless test) — never crashes. The [Ticker] comes from
/// [SingleTickerProviderStateMixin] so it auto-mutes behind a covered route;
/// we also stop it when the app is backgrounded, so it never burns GPU unseen.
class _BlackHoleShaderCover extends StatefulWidget {
  const _BlackHoleShaderCover({this.layer = 0});

  /// 0 = full scene (standalone cover), 1 = ONLY the near/front disk edge on a
  /// transparent background (drawn OVER the profile photo), 2 = everything
  /// EXCEPT the near edge (drawn UNDER the photo). 1+2 together put the photo
  /// INSIDE the black hole.
  final int layer;

  @override
  State<_BlackHoleShaderCover> createState() => _BlackHoleShaderCoverState();
}

class _BlackHoleShaderCoverState extends State<_BlackHoleShaderCover>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // The profile page runs TWO instances (back + front layers) — load the
  // program once and share it; each instance still gets its own shader.
  static Future<ui.FragmentProgram>? _programFuture;

  /// Heat budget. The geodesic march is per-PIXEL, so frame-rate × pixel-count
  /// is the whole GPU bill. Three multiplicative savings, visually invisible
  /// for this soft slow-drift scene: 30 fps instead of the display's (120 Hz)
  /// vsync; the march runs into a REDUCED-RESOLUTION GPU texture that build()
  /// merely stretches (0.55× linear ≈ 3.3× fewer pixels; the front gas overlay
  /// is softer still → 0.40×); and a coarser integration step (quality 0.65 →
  /// rays terminate in fewer of the 150 max steps). Net ≈ 15× less GPU work
  /// than shading the full cover every vsync — the "phone melts on the profile
  /// page" fix.
  static const double _fps = 30;
  static const double _quality = 0.65;

  ui.FragmentShader? _shader;
  Ticker? _ticker;
  ui.Image? _frame;
  double _lastFrameAt = -1;
  Size _texSize = Size.zero; // shader render target, in physical pixels

  double get _renderScale => widget.layer == 1 ? 0.40 : 0.55;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      _programFuture ??= ui.FragmentProgram.fromAsset(
        'assets/shaders/black_hole.frag',
      );
      final program = await _programFuture!;
      if (!mounted) return;
      _shader = program.fragmentShader();
      _ticker ??= createTicker(_onTick)..start();
    } catch (_) {
      // Shader unavailable — stay on the fallback rather than crash.
    }
  }

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    if (now - _lastFrameAt < 1 / _fps) return; // 30 fps, not every vsync
    _lastFrameAt = now;
    _render(now);
  }

  /// Runs the ray-march ONCE into a small GPU texture — [ui.Picture.toImageSync]
  /// rasterises on the GPU with no CPU readback — and build() stretches that
  /// texture, so the expensive shader never runs at full display resolution.
  void _render(double t) {
    final sh = _shader;
    if (sh == null || _texSize.isEmpty || !mounted) return;
    final w = _texSize.width, h = _texSize.height;
    sh
      ..setFloat(0, w)
      ..setFloat(1, h)
      ..setFloat(2, t)
      ..setFloat(3, _quality)
      ..setFloat(4, widget.layer.toDouble());
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = sh);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w.round(), h.round());
    pic.dispose();
    _frame?.dispose();
    _frame = img;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _ticker?.start();
    } else {
      _ticker?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _frame?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        if (cons.maxWidth.isFinite && cons.maxHeight.isFinite) {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          _texSize = Size(
            (cons.maxWidth * dpr * _renderScale).clamp(1.0, 4096.0).toDouble(),
            (cons.maxHeight * dpr * _renderScale).clamp(1.0, 4096.0).toDouble(),
          ); // picked up by the next 30fps tick
        }
        final img = _frame;
        if (img == null) {
          // Loading/first tick: the FRONT overlay must stay transparent (it
          // sits over the profile photo); full/back covers show space-black.
          return widget.layer == 1
              ? const SizedBox.expand()
              : const ColoredBox(color: Color(0xFF01020A));
        }
        return RepaintBoundary(
          child: RawImage(
            image: img,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.low,
          ),
        );
      },
    );
  }
}

// ───────────────────────── animated COVER ─────────────────────────

/// Mid-animation phase for a still cover — the same seed the animated one uses,
/// so a preview and the live cover are the same picture, just stopped.
const double _kCoverStillPhase = 0.35;
final List<double> _kCoverStillSeed = List.generate(
  40,
  (i) => math.Random(i * 7 + 3).nextDouble(),
);

class _AnimatedCover extends StatelessWidget {
  const _AnimatedCover({required this.kind, this.animate = true});

  final String kind;

  /// A still cover costs ONE paint instead of a ticker plus a blur-heavy
  /// repaint several times a second — what a grid of previews needs, where only
  /// the chosen one has to move.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    // Base dark gradient so covers read on any screen.
    final base = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.22),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
    );
    if (kind == 'space') {
      return Stack(
        fit: StackFit.expand,
        children: [base, const CosmicDustField(count: 90)],
      );
    }
    if (kind == 'logos') {
      return Stack(fit: StackFit.expand, children: [base, const _LogoCover()]);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        if (animate)
          _CoverAnim(kind: kind, accent: accent)
        else
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _CoverPainter(
                  kind,
                  _kCoverStillPhase,
                  accent,
                  _kCoverStillSeed,
                  dpr: MediaQuery.devicePixelRatioOf(context),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoverAnim extends StatefulWidget {
  const _CoverAnim({required this.kind, required this.accent});

  final String kind;
  final Color accent;

  @override
  State<_CoverAnim> createState() => _CoverAnimState();
}

class _CoverAnimState extends State<_CoverAnim>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        _MonotonicPhase,
        _CosmeticRepaint<_CoverAnim> {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  AnimationController get pausableController => _c;

  /// On a profile page the cover is the largest thing on screen, so it gets the
  /// full raster and a rate no lower than 24 — the savings elsewhere (pickers,
  /// where covers are small and many) are untouched.
  bool _showcase = false;

  @override
  double get cosmeticFps {
    final base = _coverFpsFor(widget.kind);
    return _showcase && base < 24 ? 24 : base;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showcase = CosmeticShowcaseScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    initCosmeticRepaint();
  }

  late final List<double> _seed = List.generate(
    40,
    (i) => math.Random(i * 7 + 3).nextDouble(),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: cosmeticBuilder(
          (context, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _CoverPainter(
              widget.kind,
              t,
              widget.accent,
              _seed,
              dpr: MediaQuery.devicePixelRatioOf(context),
              rasterScale: _showcase ? 1.0 : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(
    this.kind,
    this.t,
    this.accent,
    this.seed, {
    this.dpr = 1.0,
    this.rasterScale,
  });

  final String kind;
  final double t;
  final Color accent;
  final List<double> seed;

  /// Device pixel ratio, needed to rasterise the reduced-resolution pass at a
  /// known pixel size (a CustomPainter otherwise works in logical units only).
  final double dpr;

  /// Overrides the per-kind raster scale. A showcase (profile page) passes 1.0:
  /// there the banner is the biggest thing on screen and the reduced raster is
  /// exactly where it would be noticed, while the saving it buys is only worth
  /// having where many covers are drawn at once.
  final double? rasterScale;

  static const _gold = Color(0xFFE8A33D);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = rasterScale ?? _coverRasterScaleFor(kind);
    if (scale >= 1.0) {
      _paintArt(canvas, size);
      return;
    }
    // Draw the art into an offscreen a quarter of the area, then stretch it.
    // Everything this path is used for is blur, which has no detail to lose.
    final pxW = (size.width * dpr * scale).round();
    final pxH = (size.height * dpr * scale).round();
    if (pxW < 8 || pxH < 8) {
      _paintArt(canvas, size);
      return;
    }
    final rec = ui.PictureRecorder();
    final small = ui.Canvas(rec);
    small.scale(dpr * scale);
    _paintArt(small, size);
    final pic = rec.endRecording();
    final img = pic.toImageSync(pxW, pxH);
    pic.dispose();
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.low,
    );
    img.dispose();
  }

  void _paintArt(Canvas canvas, Size size) {
    const tau = math.pi * 2;
    switch (kind) {
      case 'waves':
        for (var b = 0; b < 3; b++) {
          final path = Path();
          final amp = size.height * (0.06 + b * 0.03);
          final yBase = size.height * (0.4 + b * 0.18);
          final phase = t * tau + b * 1.3;
          path.moveTo(0, yBase);
          for (double x = 0; x <= size.width; x += 8) {
            final y =
                yBase + math.sin(x / size.width * tau * 1.5 + phase) * amp;
            path.lineTo(x, y);
          }
          path.lineTo(size.width, size.height);
          path.lineTo(0, size.height);
          path.close();
          canvas.drawPath(
            path,
            Paint()
              ..color = accent.withValues(alpha: 0.12 - b * 0.03)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        break;
      case 'meteors':
        // faint twinkling background stars
        for (var i = 0; i < seed.length; i++) {
          final sx = seed[i];
          final sy = seed[(i * 3) % seed.length];
          final tw = (math.sin(t * tau * (1 + sx) + i) + 1) / 2;
          canvas.drawCircle(
            Offset(sx * size.width, sy * size.height),
            0.8 + sx * 1.4,
            Paint()..color = Colors.white.withValues(alpha: 0.16 + 0.4 * tw),
          );
        }
        // a meteor that FALLS diagonally for ~1s leaving a tail, then repeats.
        final cycle = (t * 6).floor(); // six passes per loop
        final mp = (t * 6) - cycle; // 0..1 within a pass
        if (mp < 0.5) {
          final p = mp / 0.5; // fall progress 0..1 (the visible ~1s)
          final sx = seed[cycle % seed.length];
          final start = Offset(
            (0.06 + sx * 0.5) * size.width,
            -size.height * 0.25,
          );
          // The fall vector. The tail is drawn EXACTLY along it (and the head
          // moves along it), so the tail angle always matches the travel angle.
          final fall = Offset(size.width * 0.45, size.height * 1.5);
          final head = start + fall * p;
          final norm = fall / fall.distance;
          final tail = head - norm * (size.width * 0.30);
          final fade = (p < 0.12 ? p / 0.12 : (p > 0.82 ? (1 - p) / 0.18 : 1.0))
              .clamp(0.0, 1.0);
          canvas.drawLine(
            tail,
            head,
            Paint()
              ..strokeWidth = 2.4
              ..strokeCap = StrokeCap.round
              ..shader = ui.Gradient.linear(tail, head, [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.92 * fade),
              ]),
          );
          canvas.drawCircle(
            head,
            2.6,
            Paint()
              ..color = Colors.white.withValues(alpha: fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        break;
      case 'marks':
        for (var i = 0; i < 18; i++) {
          final sx = seed[i % seed.length];
          final sy = seed[(i * 5) % seed.length];
          final drift = (t * (0.15 + sx * 0.25) + sy) % 1.0;
          final p = Offset(sx * size.width, (1.0 - drift) * size.height);
          final tw = 0.3 + 0.5 * ((math.sin(t * tau + i) + 1) / 2);
          _mark(canvas, p, 5 + sx * 5, accent.withValues(alpha: tw));
        }
        break;
      case 'goldhaze':
        for (var i = 0; i < seed.length; i++) {
          final sx = seed[i];
          final sy = seed[(i * 2) % seed.length];
          final drift = (t * (0.2 + sx * 0.3) + sy) % 1.0;
          final p = Offset(
            ((sx + math.sin(t * tau + i) * 0.02) % 1.0) * size.width,
            (1.0 - drift) * size.height,
          );
          final tw = (math.sin(t * tau * (0.8 + sx) + i) + 1) / 2;
          canvas.drawCircle(
            p,
            1.2 + sx * 2.0,
            Paint()
              ..color = _gold.withValues(alpha: 0.25 + 0.45 * tw)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
          );
        }
        break;
      case 'fire':
        {
          // A real burnt-out campfire: a glowing coal bed at the very bottom,
          // bright sparks leaping off it and dying as they rise, and dark ash
          // flakes tumbling up through the heat. No open flame.
          // Soft heat glow — two generously-blurred layers so there is no hard
          // band edge at the bottom.
          for (final lay in const [0.52, 0.72]) {
            canvas.drawRect(
              Rect.fromLTWH(
                0,
                size.height * lay,
                size.width,
                size.height * (1 - lay),
              ),
              Paint()
                ..shader = ui.Gradient.linear(
                  Offset(0, size.height),
                  Offset(0, size.height * lay),
                  [
                    const Color(0xFFFF4A0A).withValues(alpha: 0.36),
                    const Color(0x00FF4A0A),
                  ],
                )
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
            );
          }
          // Coal bed — dense glowing embers packed along the very bottom.
          for (var i = 0; i < seed.length * 2; i++) {
            final sx = seed[i % seed.length];
            final sy = seed[(i * 3) % seed.length];
            final yFrac = 1.0 - sy * sy * sy; // strongly bottom-biased
            final y = (size.height * (0.5 + yFrac * 0.55)).clamp(
              0.0,
              size.height,
            );
            final x =
                ((sx + math.sin(t * tau * 0.4 + i) * 0.008) % 1.0) * size.width;
            final flick = (math.sin(t * tau * 2 + i * 1.7) + 1) / 2;
            final bright = yFrac * (0.35 + 0.65 * flick);
            if (bright < 0.06) continue;
            final col = Color.lerp(
              const Color(0xFF6E1200),
              const Color(0xFFFFC247),
              flick,
            )!;
            canvas.drawCircle(
              Offset(x, y),
              (1.4 + sx * 2.8) * bright * 1.7,
              Paint()
                ..color = col.withValues(alpha: (bright * 0.6).clamp(0.0, 1.0))
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
            );
            canvas.drawCircle(
              Offset(x, y),
              (0.8 + sx) * bright,
              Paint()..color = col.withValues(alpha: bright.clamp(0.0, 1.0)),
            );
          }
          // Sparks — bright, leaping off the coals and burning out as they rise.
          for (var i = 0; i < seed.length * 2; i++) {
            final sx = seed[i % seed.length];
            final sy = seed[(i * 5 + 1) % seed.length];
            final rise = (t * (0.45 + sx * 0.8) + sy) % 1.0;
            final x =
                ((sx + math.sin(t * tau * 1.3 + i) * 0.05) % 1.0) * size.width;
            final y = size.height - rise * size.height * 0.95;
            final op = (1.0 - rise / 0.72).clamp(0.0, 1.0);
            if (op <= 0) continue;
            final c = Color.lerp(
              const Color(0xFFFFE6A0),
              const Color(0xFFFF4A12),
              rise,
            )!;
            canvas.drawCircle(
              Offset(x, y),
              (1.2 + sx * 2.0) * (0.4 + op),
              Paint()
                ..color = c.withValues(alpha: op * 0.5)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
            );
            canvas.drawCircle(
              Offset(x, y),
              (0.7 + sx * 1.1) * (0.4 + op),
              Paint()..color = c.withValues(alpha: op.clamp(0.0, 1.0)),
            );
          }
          // Ash flakes — dark charred bits tumbling up through the heat, fading.
          for (var i = 0; i < seed.length; i++) {
            final sx = seed[(i * 7 + 2) % seed.length];
            final sy = seed[(i * 3 + 5) % seed.length];
            final rise = (t * (0.18 + sx * 0.22) + sy) % 1.0;
            final x =
                ((sx + math.sin(t * tau * 0.8 + i * 2) * 0.06) % 1.0) *
                size.width;
            final y = size.height - rise * size.height * 1.05;
            final op = math.sin(rise * math.pi).clamp(0.0, 1.0); // fade in+out
            if (op <= 0.02) continue;
            final shade = Color.lerp(
              const Color(0xFF3A3330),
              const Color(0xFF8A8074),
              sx,
            )!;
            canvas.save();
            canvas.translate(x, y);
            canvas.rotate(rise * math.pi * 2 * (sx > 0.5 ? 1 : -1) + i);
            final s = 1.2 + sx * 2.2;
            canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.6),
              Paint()..color = shade.withValues(alpha: op * 0.55),
            );
            canvas.restore();
          }
        }
        break;
      case 'fog':
        {
          for (var i = 0; i < 9; i++) {
            final sx = seed[i];
            final x = ((sx + t * (0.06 + sx * 0.05)) % 1.2 - 0.1) * size.width;
            final y =
                size.height * (0.22 + seed[(i * 3) % seed.length] * 0.55) +
                math.sin(t * tau * 0.4 + i) * size.height * 0.04;
            final rad = size.height * (0.25 + sx * 0.28);
            canvas.drawCircle(
              Offset(x, y),
              rad,
              Paint()
                ..color = const Color(
                  0xFFAEB4C0,
                ).withValues(alpha: 0.10 + sx * 0.06)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.7),
            );
          }
        }
        break;
      case 'bears':
        {
          // Teddy bears scattered across the cover (varied size + gentle bob),
          // not lined up in a row.
          const n = 6;
          for (var i = 0; i < n; i++) {
            final sx = seed[(i * 5) % seed.length];
            final sy = seed[(i * 7 + 3) % seed.length];
            final x =
                (0.12 + sx * 0.76) * size.width +
                math.sin(t * tau * 0.5 + i) * size.width * 0.015;
            final y =
                (0.2 + sy * 0.62) * size.height +
                math.sin(t * tau * 2 + i) * size.height * 0.03;
            _bear(canvas, Offset(x, y), size.height * (0.12 + sx * 0.07));
          }
        }
        break;
      case 'rainbow':
        {
          final rect = Offset.zero & size;
          canvas.drawRect(
            rect,
            Paint()
              ..shader = LinearGradient(
                begin: const Alignment(-1, -0.5),
                end: const Alignment(1, 0.5),
                tileMode: TileMode.mirror,
                colors: const [
                  Color(0x99FF3B30),
                  Color(0x99FF9500),
                  Color(0x99FFCC00),
                  Color(0x9934C759),
                  Color(0x9900C7BE),
                  Color(0x99007AFF),
                  Color(0x995856D6),
                  Color(0x99AF52DE),
                ],
                transform: GradientRotation(0.5 + math.sin(t * tau) * 0.18),
              ).createShader(rect)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
        break;
      case 'fireflies':
        {
          for (var i = 0; i < seed.length; i++) {
            final sx = seed[i];
            final sy = seed[(i * 3) % seed.length];
            final dx = math.sin(t * tau * (0.3 + sx * 0.4) + i) * 0.06;
            final dy = math.cos(t * tau * (0.25 + sy * 0.3) + i * 1.3) * 0.06;
            final p = Offset(
              ((sx + dx) % 1.0) * size.width,
              ((sy + dy) % 1.0) * size.height,
            );
            final tw = (math.sin(t * tau * 1.5 + i * 2) + 1) / 2;
            canvas.drawCircle(
              p,
              (1.5 + sx * 2.0) * (0.5 + tw),
              Paint()
                ..color = const Color(
                  0xFFCFFF7A,
                ).withValues(alpha: 0.12 + 0.5 * tw)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
            );
            canvas.drawCircle(
              p,
              1.0 * (0.5 + tw),
              Paint()..color = Colors.white.withValues(alpha: 0.3 + 0.5 * tw),
            );
          }
        }
        break;
      case 'fireworks':
        _fireworks(canvas, size, gold: false);
        break;
      case 'fireworks_gold':
        _fireworks(canvas, size, gold: true);
        break;
      case 'reef':
        _reef(canvas, size);
        break;
      case 'galaxy':
        _galaxy(canvas, size);
        break;
      case 'aurora_sky':
        _auroraSky(canvas, size);
        break;
    }
  }

  static double _tanh(double x) {
    if (x > 15) return 1.0;
    if (x < -15) return -1.0;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static const _fireworkPalette = [
    Color(0xFFFF5D6C),
    Color(0xFF5DA8FF),
    Color(0xFFB98BFF),
    Color(0xFF5DFFA8),
    Color(0xFFFFD24A),
    Color(0xFFFF7AD9),
    Color(0xFF6FF0FF),
  ];

  Color _fireworkHue(double r) =>
      _fireworkPalette[(r * _fireworkPalette.length).floor() %
          _fireworkPalette.length];

  /// Fireworks that lift off from the bottom-centre and burst to the LEFT and
  /// RIGHT of the middle — framing a centred profile photo. Each shell has a
  /// real lifecycle: a decelerating rising comet, then radial sparks that drag,
  /// fall under gravity, flicker and fade. Several staggered launchers keep the
  /// sky busy; every shell fades fully to nothing at both ends of its life, so
  /// the loop is seamless. [gold] = elegant golden willow (heavy droop + glitter
  /// trails); otherwise vibrant multi-colour peonies.
  void _fireworks(Canvas canvas, Size size, {required bool gold}) {
    const tau = math.pi * 2;
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, 0),
          Offset(w / 2, h),
          const [Color(0xFF0A0E1F), Color(0xFF141A33)],
        ),
    );
    for (var i = 0; i < seed.length; i++) {
      final sx = seed[i], sy = seed[(i * 3) % seed.length];
      final tw = (math.sin(t * tau * (1 + sx) + i) + 1) / 2;
      canvas.drawCircle(
        Offset(sx * w, sy * h * 0.7),
        0.6 + sx * 1.0,
        Paint()..color = Colors.white.withValues(alpha: 0.08 + 0.28 * tw),
      );
    }
    const launchers = 4;
    for (var s = 0; s < launchers; s++) {
      final rate = 2.6 + s * 0.35;
      final n = t * rate + s * 0.53;
      final idx = n.floor();
      final lp = n - idx;
      final r1 = seed[(idx * 7 + s * 3) % seed.length];
      final r2 = seed[(idx * 5 + s * 2 + 11) % seed.length];
      final r3 = seed[(idx * 11 + s + 5) % seed.length];
      final side = ((idx + s) % 2 == 0) ? -1.0 : 1.0;
      final bx = w * (0.5 + side * (0.16 + r1 * 0.22));
      final by = h * (0.18 + r2 * 0.30);
      final launchX = w * (0.5 + side * 0.05 * r3);
      const riseFrac = 0.3;
      if (lp < riseFrac) {
        final u = lp / riseFrac;
        // Curved mortar climb — a quadratic Bézier from the bottom-centre
        // launch. The control point sits straight above the launch at burst
        // height, so the tangent is vertical at lift-off and swings sideways at
        // the top: a light semicircle arcing out to the burst side.
        final p0 = Offset(launchX, h * 0.98);
        final p1 = Offset(launchX, by);
        final p2 = Offset(bx, by);
        Offset bez(double q) =>
            p0 * ((1 - q) * (1 - q)) + p1 * (2 * (1 - q) * q) + p2 * (q * q);
        final ease = 1 - (1 - u) * (1 - u); // decelerate toward the apex
        final head = bez(ease);
        final headOp = (1 - u * 0.35) * math.min(1.0, u / 0.06);
        // Trail = short samples of the SAME curve just behind the head, so it
        // always points opposite the (curved) travel direction and bends along
        // the arc — never straight down.
        const tSegs = 8;
        for (var j = 1; j <= tSegs; j++) {
          final q0 = (ease - 0.045 * (j - 1)).clamp(0.0, 1.0);
          final q1 = (ease - 0.045 * j).clamp(0.0, 1.0);
          if (q1 >= q0) break;
          final f = 1 - j / tSegs; // →0 at the far tail
          canvas.drawLine(
            bez(q1),
            bez(q0),
            Paint()
              ..strokeWidth = 2.2 * (0.35 + 0.65 * f)
              ..strokeCap = StrokeCap.round
              ..color = (gold ? const Color(0xFFFFE7A0) : Colors.white)
                  .withValues(alpha: 0.7 * headOp * f),
          );
        }
        canvas.drawCircle(
          head,
          2.4,
          Paint()
            ..color = (gold ? const Color(0xFFFFF0C0) : Colors.white)
                .withValues(alpha: headOp)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      } else {
        final bp = (lp - riseFrac) / (1 - riseFrac);
        final fade = 1 - bp;
        if (fade <= 0) continue;
        final spread = (gold ? 0.36 : 0.46) * math.min(w, h);
        final grav =
            (gold ? 0.85 : 0.30) * h; // peony flies out before dropping
        final drag = 1 - (1 - bp) * (1 - bp);
        final sparks = gold ? 28 : 38;
        if (bp < 0.14) {
          final fl = 1 - bp / 0.14;
          canvas.drawCircle(
            Offset(bx, by),
            spread * (0.15 + bp * 1.5),
            Paint()
              ..color = (gold ? const Color(0xFFFFE7A0) : Colors.white)
                  .withValues(alpha: 0.5 * fl)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread * 0.2),
          );
        }
        for (var k = 0; k < sparks; k++) {
          final a = k / sparks * tau + r1 * tau;
          final sp = 0.68 + 0.32 * seed[(k * 3 + idx) % seed.length];
          final dist = spread * drag * sp;
          final pos = Offset(
            bx + math.cos(a) * dist,
            by + math.sin(a) * dist + grav * bp * bp,
          );
          final col = gold
              ? Color.lerp(
                  const Color(0xFFFFF3C0),
                  const Color(0xFFE8912F),
                  bp,
                )!
              : _fireworkHue(r3);
          final flick = 0.6 + 0.4 * math.sin(t * tau * 8 + k * 1.7 + idx);
          final op = (fade * fade * flick).clamp(0.0, 1.0);
          // Each spark's velocity (d pos / d bp): the radial term decays (drag)
          // while gravity grows — so the streak points OUTWARD early and only
          // swings downward late. Draw a comet streak opposite that velocity so
          // the sparks read as flying, not just dropping.
          final ddist = spread * sp * 2 * (1 - bp);
          final vx = math.cos(a) * ddist;
          final vy = math.sin(a) * ddist + grav * 2 * bp;
          final vmag = math.sqrt(vx * vx + vy * vy);
          final tdir = vmag > 0.001
              ? Offset(vx / vmag, vy / vmag)
              : Offset(math.cos(a), math.sin(a));
          final tail = pos - tdir * ((gold ? 11.0 : 7.0) + vmag * 0.02);
          canvas.drawLine(
            tail,
            pos,
            Paint()
              ..strokeWidth = gold ? 1.5 : 1.3
              ..strokeCap = StrokeCap.round
              ..shader = ui.Gradient.linear(tail, pos, [
                col.withValues(alpha: 0.0),
                col.withValues(alpha: op * 0.75),
              ]),
          );
          canvas.drawCircle(
            pos,
            gold ? 1.3 : 1.7,
            Paint()
              ..color = col.withValues(alpha: op * 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
          canvas.drawCircle(
            pos,
            gold ? 0.8 : 1.0,
            Paint()..color = col.withValues(alpha: op),
          );
        }
      }
    }
  }

  /// A living reef: a lit water column, swaying god-rays, rising bubbles and
  /// FIVE species of fish gliding back and forth. Each fish body is a travelling
  /// sine wave (tail wiggles most), its caudal fin swishes, and it banks
  /// (foreshortens) through each turn instead of hard-flipping — all periodic,
  /// so it loops with no seam.
  void _reef(Canvas canvas, Size size) {
    const tau = math.pi * 2;
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, 0),
          Offset(w / 2, h),
          const [Color(0xFF1FA7B8), Color(0xFF0A3A6B), Color(0xFF06203F)],
          const [0.0, 0.55, 1.0],
        ),
    );
    for (var i = 0; i < 4; i++) {
      final baseX = w * (0.15 + i * 0.24);
      final sway = math.sin(t * tau * 0.15 + i) * w * 0.04;
      final topX = baseX + sway;
      final path = Path()
        ..moveTo(topX - w * 0.03, 0)
        ..lineTo(topX + w * 0.03, 0)
        ..lineTo(topX + sway * 0.5 + w * 0.10, h)
        ..lineTo(topX + sway * 0.5 - w * 0.02, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    _drawFish(
      canvas,
      size,
      species: 4,
      cy: 0.30,
      len: 0.12,
      speed: 1.0,
      range: 0.32,
      phase: 0.0,
    );
    _drawFish(
      canvas,
      size,
      species: 1,
      cy: 0.55,
      len: 0.13,
      speed: 1.1,
      range: 0.36,
      phase: 1.7,
    );
    _drawFish(
      canvas,
      size,
      species: 3,
      cy: 0.72,
      len: 0.065,
      speed: 2.3,
      range: 0.28,
      phase: 3.0,
    );
    _drawFish(
      canvas,
      size,
      species: 2,
      cy: 0.44,
      len: 0.085,
      speed: 1.5,
      range: 0.24,
      phase: 4.5,
    );
    _drawFish(
      canvas,
      size,
      species: 0,
      cy: 0.63,
      len: 0.105,
      speed: 1.3,
      range: 0.33,
      phase: 5.6,
    );
    // A couple of extra small darters keep the (now smaller) reef feeling alive.
    _drawFish(
      canvas,
      size,
      species: 3,
      cy: 0.38,
      len: 0.055,
      speed: 2.6,
      range: 0.30,
      phase: 2.2,
    );
    _drawFish(
      canvas,
      size,
      species: 0,
      cy: 0.82,
      len: 0.07,
      speed: 1.7,
      range: 0.27,
      phase: 4.0,
    );
    for (var i = 0; i < seed.length; i++) {
      final sx = seed[i], sy = seed[(i * 3) % seed.length];
      final rise = (t * (0.18 + sx * 0.25) + sy) % 1.0;
      final x = ((sx + math.sin(t * tau * 0.5 + i) * 0.02) % 1.0) * w;
      final y = h - rise * h * 1.05;
      final op = math.sin(rise * math.pi) * 0.5;
      if (op <= 0.02) continue;
      final rad = 1.0 + sx * 2.5;
      canvas.drawCircle(
        Offset(x, y),
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: op),
      );
      canvas.drawCircle(
        Offset(x - rad * 0.3, y - rad * 0.3),
        rad * 0.3,
        Paint()..color = Colors.white.withValues(alpha: op * 0.8),
      );
    }
  }

  /// Natural-looking reef fish. Anatomy per species: a real fusiform body
  /// profile (narrow caudal peduncle, species-specific snout taper and dorsal
  /// hump), species caudal fins (rounded fan / triangle / deep fork / trailing
  /// sails), markings (clown bands with dark edging, tang "palette", lateral
  /// line…), gill-cover line, iris+pupil+glint eye, translucent fins, a faint
  /// countershaded outline — plus the travelling body wave, caudal swish,
  /// pectoral flap and tanh-banked turns of the original.
  void _drawFish(
    Canvas canvas,
    Size size, {
    required int species,
    required double cy,
    required double len,
    required double speed,
    required double range,
    required double phase,
  }) {
    const tau = math.pi * 2;
    final w = size.width, h = size.height;
    final theta = t * tau * (speed * 0.55) + phase;
    final xN = 0.5 + math.sin(theta) * range;
    final face = _tanh(math.cos(theta) * 3.0);
    final cyBob = cy + math.sin(t * tau * 0.6 + phase) * 0.02;
    final L = len * w;
    final sw = t * tau * (2.0 + speed) + phase; // body/tail beat

    // ── species sheet ──
    // top/bottom half-height (·L), peak position, snout taper power,
    // colours, caudal kind: 0 fan, 1 triangle, 2 deep fork, 3 fan+sails.
    double hT, hB, peak, nose;
    Color cTop, cBot, cFin;
    int caudalKind;
    switch (species) {
      case 0: // clownfish
        hT = 0.15;
        hB = 0.13;
        peak = 0.55;
        nose = 1.3;
        cTop = const Color(0xFFE86A12);
        cBot = const Color(0xFFFFA24F);
        cFin = const Color(0xFFF07A1E);
        caudalKind = 0;
        break;
      case 1: // blue tang
        hT = 0.17;
        hB = 0.15;
        peak = 0.5;
        nose = 1.9;
        cTop = const Color(0xFF1E4FD8);
        cBot = const Color(0xFF4E8CF0);
        cFin = const Color(0xFFFFD24A);
        caudalKind = 1;
        break;
      case 2: // yellow tang
        hT = 0.21;
        hB = 0.18;
        peak = 0.5;
        nose = 2.6;
        cTop = const Color(0xFFF6B70E);
        cBot = const Color(0xFFFFDE6A);
        cFin = const Color(0xFFF6B70E);
        caudalKind = 1;
        break;
      case 3: // silver darter
        hT = 0.07;
        hB = 0.065;
        peak = 0.55;
        nose = 1.6;
        cTop = const Color(0xFF7FB6C9);
        cBot = const Color(0xFFEAF7FB);
        cFin = const Color(0xFFB9DCE8);
        caudalKind = 2;
        break;
      default: // freshwater angel
        hT = 0.24;
        hB = 0.21;
        peak = 0.52;
        nose = 1.7;
        cTop = const Color(0xFFD9D2BC);
        cBot = const Color(0xFFF6EFDB);
        cFin = const Color(0xFFCDB878);
        caudalKind = 3;
        break;
    }
    final maxT = hT * L, maxB = hB * L;
    final amp = L * 0.05;

    // Body profile: peduncle (0.24·max) → hump at [peak] → snout taper.
    double prof(double u) {
      if (u < peak) {
        final s = u / peak;
        return 0.24 + 0.76 * math.sin(s * math.pi / 2);
      }
      final s = (u - peak) / (1 - peak);
      return math.pow(math.cos(s * math.pi / 2), nose).toDouble();
    }

    double centerline(double u) => math.sin(u * 2.6 - sw) * amp * (1 - u);
    double topAt(double u) => centerline(u) - maxT * prof(u);
    double botAt(double u) => centerline(u) + maxB * prof(u);
    Offset lp(double u, double y) => Offset((u - 0.5) * L, y);

    canvas.save();
    canvas.translate(xN * w, cyBob * h);
    // Banked turn (foreshorten) + a whisper of pitch with the bob.
    final sx = face.abs() < 0.14 ? (face.isNegative ? -0.14 : 0.14) : face;
    canvas.scale(sx, 1.0);
    canvas.rotate(math.cos(t * tau * 0.6 + phase) * 0.05);

    final tb = Offset(-L * 0.5, centerline(0.0)); // tail base
    final swish = math.sin(-sw + 0.7);

    // ── caudal fin (behind the body) ──
    final finP = Paint()..color = cFin.withValues(alpha: 0.88);
    switch (caudalKind) {
      case 0: // rounded fan (clown) — soft convex fan with a thin dark rim
        final tl = L * 0.22;
        final tip = tb + Offset(-tl, swish * tl * 0.55);
        Path fanAt(double k) => Path()
          ..moveTo(tb.dx + L * 0.02, tb.dy - maxT * 0.26)
          ..cubicTo(
            tb.dx - tl * 0.5,
            tb.dy - maxT * 0.5 * k,
            tip.dx + tl * 0.10,
            tip.dy - maxT * 0.55 * k,
            tip.dx,
            tip.dy - maxT * 0.42 * k,
          )
          // rounded trailing edge instead of a pinched point
          ..quadraticBezierTo(
            tip.dx - tl * 0.16 * k,
            tip.dy,
            tip.dx,
            tip.dy + maxB * 0.42 * k,
          )
          ..cubicTo(
            tip.dx + tl * 0.10,
            tip.dy + maxB * 0.55 * k,
            tb.dx - tl * 0.5,
            tb.dy + maxB * 0.5 * k,
            tb.dx + L * 0.02,
            tb.dy + maxB * 0.26,
          )
          ..close();
        canvas.drawPath(
          fanAt(1.12),
          Paint()..color = const Color(0xFF241A10).withValues(alpha: 0.5),
        );
        canvas.drawPath(fanAt(1.0), finP);
        break;
      case 1: // shallow triangle lobes (tangs)
        final tl = L * 0.22;
        final tip = tb + Offset(-tl, swish * tl * 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(tb.dx + L * 0.02, tb.dy - maxT * 0.26)
            ..lineTo(tip.dx, tip.dy - maxT * 0.52)
            ..quadraticBezierTo(
              tip.dx + tl * 0.30,
              tip.dy,
              tip.dx,
              tip.dy + maxB * 0.52,
            )
            ..lineTo(tb.dx + L * 0.02, tb.dy + maxB * 0.26)
            ..close(),
          finP,
        );
        break;
      case 2: // deep fork (darter)
        final tl = L * 0.26;
        final tip = tb + Offset(-tl, swish * tl * 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(tb.dx + L * 0.02, tb.dy - maxT * 0.30)
            ..lineTo(tip.dx, tip.dy - maxT * 1.5)
            ..lineTo(tb.dx - tl * 0.35, tb.dy + swish * tl * 0.3)
            ..lineTo(tip.dx, tip.dy + maxB * 1.5)
            ..lineTo(tb.dx + L * 0.02, tb.dy + maxB * 0.30)
            ..close(),
          finP,
        );
        break;
      default: // angel: soft fan + long trailing filaments
        final tl = L * 0.20;
        final tip = tb + Offset(-tl, swish * tl * 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(tb.dx + L * 0.02, tb.dy - maxT * 0.34)
            ..quadraticBezierTo(
              tip.dx,
              tip.dy - maxT * 0.6,
              tip.dx - tl * 0.2,
              tip.dy,
            )
            ..quadraticBezierTo(
              tip.dx,
              tip.dy + maxB * 0.6,
              tb.dx + L * 0.02,
              tb.dy + maxB * 0.34,
            )
            ..close(),
          Paint()..color = cFin.withValues(alpha: 0.75),
        );
    }

    // ── dorsal / anal fins ──
    final finSoft = Paint()..color = cFin.withValues(alpha: 0.68);
    if (species == 4) {
      // Angel: slender crescent sails — a tall dorsal and anal that rise from
      // the body and sweep BACK to a fine point (concave trailing edge), plus
      // hair-thin trailing filaments. Translucent so the water shows through.
      final sail = Paint()..color = cFin.withValues(alpha: 0.55);
      final dTip = Offset((0.10 - 0.5) * L, topAt(0.30) - maxT * 1.65);
      canvas.drawPath(
        Path()
          ..moveTo(lp(0.62, topAt(0.62)).dx, topAt(0.62))
          ..quadraticBezierTo(
            (0.42 - 0.5) * L,
            topAt(0.42) - maxT * 1.25,
            dTip.dx,
            dTip.dy,
          )
          ..quadraticBezierTo(
            (0.30 - 0.5) * L,
            topAt(0.34) - maxT * 0.35,
            lp(0.24, topAt(0.24)).dx,
            topAt(0.24),
          )
          ..close(),
        sail,
      );
      final aTip = Offset((0.08 - 0.5) * L, botAt(0.28) + maxB * 1.65);
      canvas.drawPath(
        Path()
          ..moveTo(lp(0.60, botAt(0.60)).dx, botAt(0.60))
          ..quadraticBezierTo(
            (0.40 - 0.5) * L,
            botAt(0.40) + maxB * 1.25,
            aTip.dx,
            aTip.dy,
          )
          ..quadraticBezierTo(
            (0.28 - 0.5) * L,
            botAt(0.32) + maxB * 0.35,
            lp(0.22, botAt(0.22)).dx,
            botAt(0.22),
          )
          ..close(),
        sail,
      );
      // trailing filaments off both sail tips
      final fil = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, L * 0.006)
        ..strokeCap = StrokeCap.round
        ..color = cFin.withValues(alpha: 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(dTip.dx, dTip.dy)
          ..quadraticBezierTo(
            dTip.dx - L * 0.16,
            dTip.dy + maxT * 0.2,
            dTip.dx - L * 0.30,
            dTip.dy + maxT * 0.55,
          ),
        fil,
      );
      canvas.drawPath(
        Path()
          ..moveTo(aTip.dx, aTip.dy)
          ..quadraticBezierTo(
            aTip.dx - L * 0.16,
            aTip.dy - maxB * 0.2,
            aTip.dx - L * 0.30,
            aTip.dy - maxB * 0.55,
          ),
        fil,
      );
    } else {
      // Continuous low dorsal ribbon along the back (u 0.10..0.78) — smooth
      // rounded crest (sin^0.7), no spiky peak even on the tall yellow tang.
      final dorsal = Path()..moveTo(lp(0.78, topAt(0.78)).dx, topAt(0.78));
      const nD = 12;
      for (var i = 1; i <= nD; i++) {
        final u = 0.78 - (0.78 - 0.10) * (i / nD);
        final lift =
            math.pow(math.sin((i / nD) * math.pi), 0.7) *
            maxT *
            (species == 2 ? 0.7 : 0.34); // yellow tang = tall sail
        dorsal.lineTo(lp(u, topAt(u)).dx, topAt(u) - lift);
      }
      dorsal.lineTo(lp(0.10, topAt(0.10)).dx, topAt(0.10));
      for (var i = 1; i <= nD; i++) {
        final u = 0.10 + (0.78 - 0.10) * (i / nD);
        dorsal.lineTo(lp(u, topAt(u)).dx, topAt(u));
      }
      dorsal.close();
      canvas.drawPath(dorsal, finSoft);
      // anal fin (small, mirrored, rear-set)
      canvas.drawPath(
        Path()
          ..moveTo(lp(0.42, botAt(0.42)).dx, botAt(0.42))
          ..quadraticBezierTo(
            (0.28 - 0.5) * L,
            botAt(0.30) + maxB * (species == 2 ? 0.8 : 0.42),
            lp(0.16, botAt(0.16)).dx,
            botAt(0.16),
          )
          ..close(),
        finSoft,
      );
    }

    // ── body ──
    final body = Path();
    const N = 30;
    for (var i = 0; i <= N; i++) {
      final u = 1 - i / N;
      final x = (u - 0.5) * L, y = topAt(u);
      if (i == 0) {
        body.moveTo(x, y);
      } else {
        body.lineTo(x, y);
      }
    }
    for (var i = 0; i <= N; i++) {
      final u = i / N;
      body.lineTo((u - 0.5) * L, botAt(u));
    }
    body.close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -maxT),
          Offset(0, maxB),
          [cTop, Color.lerp(cTop, cBot, 0.55)!, cBot],
          const [0.0, 0.45, 1.0],
        ),
    );
    // faint darker outline for definition
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, L * 0.008)
        ..color = Color.lerp(cTop, Colors.black, 0.45)!.withValues(alpha: 0.35),
    );

    // ── markings (clipped to the body) ──
    canvas.save();
    canvas.clipPath(body);
    switch (species) {
      case 0: // clown: 3 white bands, dark-edged
        for (final u in const [0.74, 0.46, 0.14]) {
          final x = (u - 0.5) * L;
          final bw = L * (u == 0.46 ? 0.10 : 0.075);
          canvas.drawRect(
            Rect.fromLTWH(
              x - bw * 0.72,
              -maxT * 1.6,
              bw * 1.44,
              (maxT + maxB) * 1.7,
            ),
            Paint()..color = const Color(0xFF241A12).withValues(alpha: 0.8),
          );
          canvas.drawRect(
            Rect.fromLTWH(x - bw * 0.5, -maxT * 1.6, bw, (maxT + maxB) * 1.7),
            Paint()..color = const Color(0xFFF8F4EC),
          );
        }
        break;
      case 1: // blue tang "palette": dark sweep along the spine to the tail
        final palette = Path()
          ..moveTo((0.78 - 0.5) * L, topAt(0.78) + maxT * 0.30)
          ..quadraticBezierTo(
            (0.45 - 0.5) * L,
            topAt(0.45) + maxT * 0.14,
            (0.06 - 0.5) * L,
            centerline(0.06) - maxT * 0.05,
          )
          ..quadraticBezierTo(
            (0.10 - 0.5) * L,
            centerline(0.10) + maxB * 0.35,
            (0.40 - 0.5) * L,
            topAt(0.40) + maxT * 0.75,
          )
          ..quadraticBezierTo(
            (0.62 - 0.5) * L,
            topAt(0.62) + maxT * 0.75,
            (0.78 - 0.5) * L,
            topAt(0.78) + maxT * 0.30,
          )
          ..close();
        canvas.drawPath(
          palette,
          Paint()..color = const Color(0xFF06122E).withValues(alpha: 0.85),
        );
        break;
      case 2: // yellow tang: white scalpel spur at the peduncle
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset((0.07 - 0.5) * L, centerline(0.07)),
              width: L * 0.055,
              height: maxT * 0.34,
            ),
            Radius.circular(L * 0.02),
          ),
          Paint()..color = const Color(0xFFF8F4EC).withValues(alpha: 0.9),
        );
        break;
      case 3: // darter: bright lateral line + darker back
        canvas.drawLine(
          lp(0.06, centerline(0.06)),
          lp(0.88, centerline(0.88)),
          Paint()
            ..strokeWidth = maxT * 0.30
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.55),
        );
        break;
      default: // angel: two soft dark vertical bands
        for (final u in const [0.60, 0.34]) {
          final x = (u - 0.5) * L;
          canvas.drawRect(
            Rect.fromLTWH(
              x - L * 0.035,
              -maxT * 1.9,
              L * 0.07,
              (maxT + maxB) * 2.0,
            ),
            Paint()..color = const Color(0xFF2A241C).withValues(alpha: 0.55),
          );
        }
    }
    // belly sheen
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(L * 0.02, maxB * 0.45),
        width: L * 0.5,
        height: maxB * 0.6,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxB * 0.3),
    );
    canvas.restore();

    // ── gill-cover line ──
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset((0.66 - 0.5) * L, centerline(0.66)),
        width: L * 0.24,
        height: (maxT + maxB) * 0.86,
      ),
      -1.1,
      2.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, L * 0.007)
        ..color = Colors.black.withValues(alpha: 0.16),
    );

    // ── pectoral fin (flapping teardrop) ──
    final flap = math.sin(sw * 1.3) * 0.5 + 0.5;
    canvas.save();
    canvas.translate(L * 0.07, centerline(0.55) + maxB * 0.28);
    canvas.rotate(0.5 - flap * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-L * 0.05, 0),
        width: L * 0.16 * (0.45 + flap * 0.55),
        height: maxB * 0.5,
      ),
      Paint()..color = cFin.withValues(alpha: 0.55),
    );
    canvas.restore();

    // ── eye: iris ring + pupil + glint ──
    final eyeC = Offset((0.82 - 0.5) * L, centerline(0.82) - maxT * 0.14);
    final eyeR = math.max(maxT, maxB) * 0.15;
    canvas.drawCircle(eyeC, eyeR, Paint()..color = const Color(0xFFE8E2D4));
    canvas.drawCircle(
      eyeC,
      eyeR * 0.78,
      Paint()
        ..color = (species == 3
            ? const Color(0xFFB9CCD8)
            : const Color(0xFFC49A3A)),
    );
    canvas.drawCircle(
      eyeC,
      eyeR * 0.52,
      Paint()..color = const Color(0xFF0C0F16),
    );
    canvas.drawCircle(
      eyeC + Offset(-eyeR * 0.22, -eyeR * 0.24),
      eyeR * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    canvas.restore();
  }

  /// A big, deep spiral galaxy: three winding arms of a thousand-plus stars over
  /// a drifting coloured nebula, dark dust lanes, and a hot multi-layer core.
  /// Tilted for depth; spins (now the other way) with sinusoidal twinkles, so it
  /// loops seamlessly.
  void _galaxy(Canvas canvas, Size size) {
    const tau = math.pi * 2;
    final w = size.width, h = size.height;
    final ctr = Offset(w * 0.5, h * 0.5);
    final rot = -t * tau * 0.09; // spins the OTHER way now
    final maxR = math.min(w, h) * 0.92; // bigger
    const tilt = 0.55; // vertical squash → we look at the disk on an angle

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          ctr,
          math.max(w, h) * 0.75,
          const [Color(0xFF160E38), Color(0xFF090622), Color(0xFF03020C)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // Faint background star DUST across the whole field (the "billions").
    for (var i = 0; i < seed.length * 10; i++) {
      final sx = seed[i % seed.length];
      final sy = seed[(i * 7 + 3) % seed.length];
      final gx = ((sx * 1.37 + (i ~/ seed.length) * 0.191) % 1.0) * w;
      final gy = ((sy * 1.51 + (i ~/ seed.length) * 0.234) % 1.0) * h;
      final tw = (math.sin(t * tau * (0.6 + sx) + i) + 1) / 2;
      canvas.drawCircle(
        Offset(gx, gy),
        0.4 + sx * 0.7,
        Paint()..color = Colors.white.withValues(alpha: 0.05 + 0.22 * tw),
      );
    }

    // Coloured nebula haze drifting along the disk, tinting the arms.
    const nebCols = [
      Color(0xFF6E4BFF),
      Color(0xFF2E7BFF),
      Color(0xFFFF5DAE),
      Color(0xFF23C9C0),
    ];
    for (var i = 0; i < 10; i++) {
      final f = 0.2 + (i / 10) * 0.8;
      final ang = i * 2.2 + rot * (1 + i * 0.05);
      final p = ctr + Offset(math.cos(ang), math.sin(ang) * tilt) * (f * maxR);
      final rad = maxR * (0.18 + seed[i % seed.length] * 0.16);
      canvas.drawCircle(
        p,
        rad,
        Paint()
          ..color = nebCols[i % nebCols.length].withValues(
            alpha: 0.06 + 0.05 * ((math.sin(t * tau * 0.3 + i) + 1) / 2),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.6),
      );
    }

    // Three logarithmic arms, densely packed and denser toward the core.
    const arms = 3;
    final starCount = seed.length * 18;
    for (var i = 0; i < starCount; i++) {
      final f = math.pow(i / starCount, 0.7).toDouble();
      final arm = (i % arms) * (tau / arms);
      // tight jitter so the stars actually TRACE the arms (was too scattered).
      final jit = (seed[(i * 3) % seed.length] - 0.5) * (0.12 + (1 - f) * 0.38);
      final ang = arm + f * 6.0 + rot + jit; // 6.0 = winding tightness
      final p = ctr + Offset(math.cos(ang), math.sin(ang) * tilt) * (f * maxR);
      final tw =
          (math.sin(t * tau * (0.8 + seed[i % seed.length]) + i) + 1) / 2;
      final col = Color.lerp(
        const Color(0xFFFFF0D0),
        const Color(0xFFAFCBFF),
        f,
      )!;
      canvas.drawCircle(
        p,
        (0.5 + (1 - f) * 1.4) * (0.6 + 0.7 * tw),
        Paint()
          ..color = col.withValues(alpha: (0.3 + 0.6 * tw) * (1 - f * 0.3)),
      );
    }

    // Dark dust lanes weaving through the arms.
    for (var i = 0; i < 3; i++) {
      final arm = i * (tau / 3) + 0.5;
      final path = Path();
      for (var s = 0; s <= 40; s++) {
        final f = s / 40;
        final ang = arm + f * 6.2 + rot + 0.35;
        final p =
            ctr + Offset(math.cos(ang), math.sin(ang) * tilt) * (f * maxR);
        if (s == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = maxR * 0.05
          ..color = const Color(0xFF0A0618).withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxR * 0.03),
      );
    }

    // Compact glowing core (a bright bulge, NOT a giant sun).
    final core = maxR * 0.13;
    // soft golden bulge halo
    canvas.drawCircle(
      ctr,
      core * 2.6,
      Paint()
        ..shader = ui.Gradient.radial(ctr, core * 2.6, [
          const Color(0xFFFFD98A).withValues(alpha: 0.42),
          const Color(0x00FFB86B),
        ])
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, core),
    );
    // dense core star cluster
    for (var i = 0; i < seed.length * 3; i++) {
      final sx = seed[i % seed.length], sy = seed[(i * 5 + 2) % seed.length];
      final a = (sx + sy) * tau + rot;
      final rr =
          math.pow(seed[(i * 2) % seed.length], 1.6).toDouble() * core * 1.6;
      final p = ctr + Offset(math.cos(a), math.sin(a) * 0.7) * rr;
      final tw = (math.sin(t * tau * (1 + sx) + i) + 1) / 2;
      canvas.drawCircle(
        p,
        0.4 + sx * 0.9,
        Paint()
          ..color = const Color(0xFFFFF6E0).withValues(alpha: 0.4 + 0.5 * tw),
      );
    }
    // bright hot centre
    canvas.drawCircle(
      ctr,
      core,
      Paint()
        ..shader = ui.Gradient.radial(
          ctr,
          core,
          const [Color(0xFFFFFFFF), Color(0xFFFFF0C0), Color(0x00FFD27A)],
          const [0.0, 0.4, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, core * 0.2),
    );
    canvas.drawCircle(
      ctr,
      core * 0.34,
      Paint()
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, core * 0.22),
    );
  }

  /// Northern lights: layered curtains of green/cyan/violet waving over a starry
  /// sky and a dark mountain ridge. Curtains are sine-driven → seamless.
  void _auroraSky(Canvas canvas, Size size) {
    const tau = math.pi * 2;
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, 0),
          Offset(w / 2, h),
          const [Color(0xFF041028), Color(0xFF0A1E3A)],
        ),
    );
    for (var i = 0; i < seed.length; i++) {
      final sx = seed[i], sy = seed[(i * 3) % seed.length];
      final tw = (math.sin(t * tau * (1 + sx) + i) + 1) / 2;
      canvas.drawCircle(
        Offset(sx * w, sy * h * 0.6),
        0.6 + sx * 0.9,
        Paint()..color = Colors.white.withValues(alpha: 0.15 + 0.35 * tw),
      );
    }
    const hues = [Color(0xFF3BFFA6), Color(0xFF43D9FF), Color(0xFFB07BFF)];
    for (var b = 0; b < 3; b++) {
      final yTop = h * (0.1 + b * 0.05);
      final amp = h * 0.1;
      final path = Path()..moveTo(0, yTop);
      for (double x = 0; x <= w; x += 10) {
        final xn = x / w;
        final y =
            yTop +
            math.sin(xn * tau * 1.5 + t * tau * 0.3 + b * 1.2) * amp +
            math.sin(xn * tau * 3.0 - t * tau * 0.5 + b) * amp * 0.35;
        path.lineTo(x, y);
      }
      path.lineTo(w, yTop + h * 0.5);
      path.lineTo(0, yTop + h * 0.5);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, yTop),
            Offset(0, yTop + h * 0.5),
            [hues[b].withValues(alpha: 0.42), hues[b].withValues(alpha: 0.0)],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    final mtn = Path()..moveTo(0, h);
    const xs = [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.85, 1.0];
    const ys = [0.82, 0.68, 0.78, 0.6, 0.73, 0.64, 0.8, 0.72];
    mtn.lineTo(0, ys[0] * h);
    for (var i = 0; i < xs.length; i++) {
      mtn.lineTo(xs[i] * w, ys[i] * h);
    }
    mtn.lineTo(w, h);
    mtn.close();
    canvas.drawPath(mtn, Paint()..color = const Color(0xFF05070F));
  }

  /// Cute teddy-bear head of radius [s] at [p] (cover variant).
  void _bear(Canvas c, Offset p, double s) {
    const fur = Color(0xFF9C6B3F);
    const dark = Color(0xFF4A2F18);
    final fp = Paint()..color = fur;
    c.drawCircle(p + Offset(-s * 0.62, -s * 0.62), s * 0.42, fp);
    c.drawCircle(p + Offset(s * 0.62, -s * 0.62), s * 0.42, fp);
    c.drawCircle(
      p + Offset(-s * 0.62, -s * 0.62),
      s * 0.2,
      Paint()..color = dark,
    );
    c.drawCircle(
      p + Offset(s * 0.62, -s * 0.62),
      s * 0.2,
      Paint()..color = dark,
    );
    c.drawCircle(p, s, fp);
    c.drawCircle(
      p + Offset(0, s * 0.28),
      s * 0.45,
      Paint()..color = const Color(0xFFE8C9A0),
    );
    final dp = Paint()..color = dark;
    c.drawCircle(p + Offset(-s * 0.38, -s * 0.12), s * 0.12, dp);
    c.drawCircle(p + Offset(s * 0.38, -s * 0.12), s * 0.12, dp);
    c.drawCircle(p + Offset(0, s * 0.16), s * 0.13, dp);
  }

  /// A small stylized "spark" mark (4-point) for the app-icon motif cover.
  void _mark(Canvas c, Offset p, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx + r * 0.2, p.dy - r * 0.2, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx + r * 0.2, p.dy + r * 0.2, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx - r * 0.2, p.dy + r * 0.2, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx - r * 0.2, p.dy - r * 0.2, p.dx, p.dy - r)
      ..close();
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.t != t ||
      old.kind != kind ||
      old.dpr != dpr ||
      old.rasterScale != rasterScale;
}

/// Cover with our app mark drifting gently as a faint, subtle watermark.
class _LogoCover extends StatefulWidget {
  const _LogoCover();

  @override
  State<_LogoCover> createState() => _LogoCoverState();
}

class _LogoCoverState extends State<_LogoCover>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        _MonotonicPhase,
        _CosmeticRepaint<_LogoCover> {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  AnimationController get pausableController => _c;

  @override
  void initState() {
    super.initState();
    initCosmeticRepaint();
  }

  late final List<_Floaty> _items = List.generate(9, (i) {
    final r = math.Random(i * 9 + 1);
    return _Floaty(
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 22 + r.nextDouble() * 24,
      speed: 0.35 + r.nextDouble() * 0.45,
      phase: r.nextDouble() * math.pi * 2,
      opacity: 0.05 + r.nextDouble() * 0.06,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, cons) {
            final w = cons.maxWidth;
            final h = cons.maxHeight;
            return cosmeticBuilder(
              (context, t, _) => Stack(
                children: [for (final f in _items) _floaty(f, t, w, h)],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _floaty(_Floaty f, double t, double w, double h) {
    final drift = (t * f.speed + f.y) % 1.0;
    final y = (1.0 - drift) * (h + 70) - 35;
    final x = (f.x + math.sin(t * math.pi * 2 + f.phase) * 0.03) * w;
    return Positioned(
      left: x - f.size / 2,
      top: y - f.size / 2,
      width: f.size,
      height: f.size,
      child: Opacity(
        opacity: f.opacity,
        child: Image.asset(
          'assets/app_ui/icons/png/premium_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _Floaty {
  const _Floaty({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
  });
  final double x, y, size, speed, phase, opacity;
}
