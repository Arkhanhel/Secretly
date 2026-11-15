// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../wave1_l10n.dart';
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
    this.exclusive = false,
  });

  /// Эксклюзивная коллекция 13.11.2026 — значок коллекции на плитке выбора.
  /// Это пометка новинки, а не признак платности: платность решает
  /// `isCosmeticAllowed`.
  final bool exclusive;

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
    this.exclusive = false,
  });

  /// Эксклюзивная коллекция 13.11.2026 — значок коллекции на плитке выбора.
  /// Это пометка новинки, а не признак платности: платность решает
  /// `isCosmeticAllowed`.
  final bool exclusive;

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
  // ── эксклюзивная коллекция (13.11.2026); 'flow' — общий с обложкой «Поток» ──
  'dragon': {
    'uk': 'Дракон',
    'es': 'Dragón',
    'pt': 'Dragão',
    'pt_BR': 'Dragão',
    'fr': 'Dragon',
    'de': 'Drache',
  },
  'ferro': {
    'uk': 'Ферофлюїд',
    'es': 'Ferrofluido',
    'pt': 'Ferrofluido',
    'pt_BR': 'Ferrofluido',
    'fr': 'Ferrofluide',
    'de': 'Ferrofluid',
  },
  'jelly': {
    'uk': 'Желе',
    'es': 'Gelatina',
    'pt': 'Gelatina',
    'pt_BR': 'Gelatina',
    'fr': 'Gelée',
    'de': 'Gelee',
  },
  'beads': {
    'uk': 'Намистини',
    'es': 'Cuentas',
    'pt': 'Contas',
    'pt_BR': 'Miçangas',
    'fr': 'Perles',
    'de': 'Perlen',
  },
  'liquid': {
    'uk': 'Колба',
    'es': 'Matraz',
    'pt': 'Frasco',
    'pt_BR': 'Frasco',
    'fr': 'Fiole',
    'de': 'Kolben',
  },
  'gears': {
    'uk': 'Механізм',
    'es': 'Engranaje',
    'pt': 'Engrenagem',
    'pt_BR': 'Engrenagem',
    'fr': 'Mécanisme',
    'de': 'Uhrwerk',
  },
  'flock': {
    'uk': 'Зграя',
    'es': 'Bandada',
    'pt': 'Bando',
    'pt_BR': 'Bando',
    'fr': 'Nuée',
    'de': 'Schwarm',
  },
  'pwave': {
    'uk': 'Маятники',
    'es': 'Péndulos',
    'pt': 'Pêndulos',
    'pt_BR': 'Pêndulos',
    'fr': 'Pendules',
    'de': 'Pendelwelle',
  },
  'spiro': {
    'uk': 'Спірограф',
    'es': 'Espirógrafo',
    'pt': 'Espirógrafo',
    'pt_BR': 'Espirógrafo',
    'fr': 'Spirographe',
    'de': 'Spirograph',
  },
  'cloth': {
    'uk': 'Полотно',
    'es': 'Tela de seda',
    'pt': 'Tecido de seda',
    'pt_BR': 'Tecido de seda',
    'fr': 'Voile de soie',
    'de': 'Seidentuch',
  },
  'balls': {
    'uk': 'Кульки',
    'es': 'Canicas',
    'pt': 'Berlindes',
    'pt_BR': 'Bolinhas de gude',
    'fr': 'Billes',
    'de': 'Murmeln',
  },
  'orbits': {
    'uk': 'Тяжіння',
    'es': 'Gravedad',
    'pt': 'Gravidade',
    'pt_BR': 'Gravidade',
    'fr': 'Gravité',
    'de': 'Schwerkraft',
  },
  'chaos': {
    'uk': 'Хаос',
    'es': 'Caos',
    'pt': 'Caos',
    'pt_BR': 'Caos',
    'fr': 'Chaos',
    'de': 'Chaos',
  },
  'life': {
    'uk': 'Життя',
    'es': 'Vida',
    'pt': 'Vida',
    'pt_BR': 'Vida',
    'fr': 'Vie',
    'de': 'Leben',
  },
  'compass': {
    'uk': 'Компаси',
    'es': 'Brújulas',
    'pt': 'Bússolas',
    'pt_BR': 'Bússolas',
    'fr': 'Boussoles',
    'de': 'Kompasse',
  },
  'plush': {
    'uk': 'Плюш',
    'es': 'Peluche',
    'pt': 'Peluche',
    'pt_BR': 'Pelúcia',
    'fr': 'Peluche',
    'de': 'Plüsch',
  },
  'storm': {
    'uk': 'Гроза',
    'es': 'Tormenta',
    'pt': 'Trovoada',
    'pt_BR': 'Tempestade',
    'fr': 'Orage',
    'de': 'Gewitter',
  },
  'ink': {
    'uk': 'Чорнило',
    'es': 'Tinta',
    'pt': 'Tinta',
    'pt_BR': 'Tinta',
    'fr': 'Encre',
    'de': 'Tinte',
  },
  'warp': {
    'uk': 'Гіперстрибок',
    'es': 'Hipersalto',
    'pt': 'Hipersalto',
    'pt_BR': 'Hipersalto',
    'fr': 'Hypersaut',
    'de': 'Hypersprung',
  },
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
    builder: (s) => LiveFrameView(size: s, id: 'cosmic'),
  ),
  AvatarFrame(
    id: 'gold',
    nameRu: 'Золото',
    nameEn: 'Gold',
    builder: (s) => LiveFrameView(size: s, id: 'gold'),
  ),
  AvatarFrame(
    id: 'orbit',
    nameRu: 'Орбита',
    nameEn: 'Orbit',
    builder: (s) => LiveFrameView(size: s, id: 'orbit'),
  ),
  AvatarFrame(
    id: 'neon',
    nameRu: 'Неон',
    nameEn: 'Neon',
    builder: (s) => LiveFrameView(size: s, id: 'neon'),
  ),
  AvatarFrame(
    id: 'stars',
    nameRu: 'Звёзды',
    nameEn: 'Stars',
    builder: (s) => LiveFrameView(size: s, id: 'stars'),
  ),
  AvatarFrame(
    id: 'aurora',
    nameRu: 'Аврора',
    nameEn: 'Aurora',
    builder: (s) => LiveFrameView(size: s, id: 'aurora'),
  ),
  AvatarFrame(
    id: 'pulse',
    nameRu: 'Пульс',
    nameEn: 'Pulse',
    builder: (s) => LiveFrameView(size: s, id: 'pulse'),
  ),
  AvatarFrame(
    id: 'ember',
    nameRu: 'Угли',
    nameEn: 'Embers',
    builder: (s) => LiveFrameView(size: s, id: 'ember'),
  ),
  AvatarFrame(
    id: 'nebula',
    nameRu: 'Туманность',
    nameEn: 'Nebula',
    builder: (s) => LiveFrameView(size: s, id: 'nebula'),
  ),
  AvatarFrame(
    id: 'electric',
    nameRu: 'Электро',
    nameEn: 'Electric',
    builder: (s) => LiveFrameView(size: s, id: 'electric'),
  ),
  AvatarFrame(
    id: 'flame',
    nameRu: 'Пламя',
    nameEn: 'Flame',
    builder: (s) => LiveFrameView(size: s, id: 'flame'),
  ),
  AvatarFrame(
    id: 'smoke',
    nameRu: 'Дым',
    nameEn: 'Smoke',
    builder: (s) => LiveFrameView(size: s, id: 'smoke'),
  ),
  AvatarFrame(
    id: 'bears',
    nameRu: 'Мишки',
    nameEn: 'Bears',
    builder: (s) => LiveFrameView(size: s, id: 'bears'),
  ),
  AvatarFrame(
    id: 'rainbow',
    nameRu: 'Радуга',
    nameEn: 'Rainbow',
    builder: (s) => LiveFrameView(size: s, id: 'rainbow'),
  ),
  AvatarFrame(
    id: 'butterfly',
    nameRu: 'Бабочки',
    nameEn: 'Butterflies',
    builder: (s) => LiveFrameView(size: s, id: 'butterfly'),
  ),
  AvatarFrame(
    id: 'comet',
    nameRu: 'Комета',
    nameEn: 'Comet',
    builder: (s) => LiveFrameView(size: s, id: 'comet'),
  ),
  AvatarFrame(
    id: 'sakura',
    nameRu: 'Сакура',
    nameEn: 'Sakura',
    builder: (s) => LiveFrameView(size: s, id: 'sakura'),
  ),
  AvatarFrame(
    id: 'phoenix',
    nameRu: 'Феникс',
    nameEn: 'Phoenix',
    builder: (s) => LiveFrameView(size: s, id: 'phoenix'),
  ),
  AvatarFrame(
    id: 'frost',
    nameRu: 'Иней',
    nameEn: 'Frost',
    builder: (s) => LiveFrameView(size: s, id: 'frost'),
  ),
  AvatarFrame(
    id: 'prism',
    nameRu: 'Призма',
    nameEn: 'Prism',
    builder: (s) => LiveFrameView(size: s, id: 'prism'),
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

/// 🔴 ЭКСКЛЮЗИВНАЯ КОЛЛЕКЦИЯ (13.11.2026) — десять рамок из дизайна
/// «Рамки и обложки»: физика, пружины, отклик на перетаскивание портрета.
/// Целиком в Premium.
final List<AvatarFrame> kCollectionAvatarFrames = [
  AvatarFrame(
    id: 'dragon',
    nameRu: 'Дракон',
    nameEn: 'Dragon',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'dragon'),
  ),
  AvatarFrame(
    id: 'ferro',
    nameRu: 'Феррофлюид',
    nameEn: 'Ferrofluid',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'ferro'),
  ),
  AvatarFrame(
    id: 'jelly',
    nameRu: 'Желе',
    nameEn: 'Jelly',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'jelly'),
  ),
  AvatarFrame(
    id: 'beads',
    nameRu: 'Бусины',
    nameEn: 'Beads',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'beads'),
  ),
  AvatarFrame(
    id: 'liquid',
    nameRu: 'Колба',
    nameEn: 'Flask',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'liquid'),
  ),
  AvatarFrame(
    id: 'gears',
    nameRu: 'Механизм',
    nameEn: 'Clockwork',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'gears'),
  ),
  AvatarFrame(
    id: 'flow',
    nameRu: 'Поток',
    nameEn: 'Airflow',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'flow'),
  ),
  AvatarFrame(
    id: 'flock',
    nameRu: 'Стая',
    nameEn: 'Flock',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'flock'),
  ),
  AvatarFrame(
    id: 'pwave',
    nameRu: 'Маятники',
    nameEn: 'Pendulum wave',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'pwave'),
  ),
  AvatarFrame(
    id: 'spiro',
    nameRu: 'Спирограф',
    nameEn: 'Spirograph',
    exclusive: true,
    builder: (s) => LiveFrameView(size: s, id: 'spiro'),
  ),
];

/// Всё, что можно ВЫБРАТЬ, в порядке экрана выбора: сначала коллекция, затем
/// переделанные старые, затем персонажи.
final List<AvatarFrame> kAllAvatarFrames = [
  ...kCollectionAvatarFrames,
  ...kAvatarFrames,
  ...kLivingAvatarFrames,
];

final List<ProfileCover> kProfileCovers = [
  ProfileCover(
    id: 'space',
    nameRu: 'Космос',
    nameEn: 'Space',
    builder: () => const LiveCoverView(id: 'space'),
  ),
  ProfileCover(
    id: 'waves',
    nameRu: 'Волны',
    nameEn: 'Waves',
    builder: () => const LiveCoverView(id: 'waves'),
  ),
  ProfileCover(
    id: 'meteors',
    nameRu: 'Метеоры',
    nameEn: 'Meteors',
    builder: () => const LiveCoverView(id: 'meteors'),
  ),
  ProfileCover(
    id: 'marks',
    nameRu: 'Иконки',
    nameEn: 'Marks',
    builder: () => const LiveCoverView(id: 'marks'),
  ),
  ProfileCover(
    id: 'goldhaze',
    nameRu: 'Золотая дымка',
    nameEn: 'Gold haze',
    builder: () => const LiveCoverView(id: 'goldhaze'),
  ),
  ProfileCover(
    id: 'logos',
    nameRu: 'Наши иконки',
    nameEn: 'App marks',
    builder: () => const LiveCoverView(id: 'logos'),
  ),
  ProfileCover(
    id: 'fire',
    nameRu: 'Костёр',
    nameEn: 'Fire',
    builder: () => const LiveCoverView(id: 'fire'),
  ),
  ProfileCover(
    id: 'fog',
    nameRu: 'Дым',
    nameEn: 'Smoke',
    builder: () => const LiveCoverView(id: 'fog'),
  ),
  ProfileCover(
    id: 'bears',
    nameRu: 'Мишки',
    nameEn: 'Bears',
    builder: () => const LiveCoverView(id: 'bears'),
  ),
  ProfileCover(
    id: 'rainbow',
    nameRu: 'Радуга',
    nameEn: 'Rainbow',
    builder: () => const LiveCoverView(id: 'rainbow'),
  ),
  ProfileCover(
    id: 'fireflies',
    nameRu: 'Светлячки',
    nameEn: 'Fireflies',
    builder: () => const LiveCoverView(id: 'fireflies'),
  ),
  ProfileCover(
    id: 'fireworks',
    nameRu: 'Салют',
    nameEn: 'Fireworks',
    builder: () => const LiveCoverView(id: 'fireworks'),
  ),
  ProfileCover(
    id: 'fireworks_gold',
    nameRu: 'Золотой салют',
    nameEn: 'Golden fireworks',
    builder: () => const LiveCoverView(id: 'fireworks_gold'),
  ),
  ProfileCover(
    id: 'reef',
    nameRu: 'Подводный мир',
    nameEn: 'Coral reef',
    builder: () => const LiveCoverView(id: 'reef'),
  ),
  ProfileCover(
    id: 'galaxy',
    nameRu: 'Галактика',
    nameEn: 'Galaxy',
    builder: () => const LiveCoverView(id: 'galaxy'),
  ),
  ProfileCover(
    id: 'aurora_sky',
    nameRu: 'Северное сияние',
    nameEn: 'Aurora',
    builder: () => const LiveCoverView(id: 'aurora_sky'),
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
/// 🔴 ЭКСКЛЮЗИВНАЯ КОЛЛЕКЦИЯ ОБЛОЖЕК (13.11.2026). Целиком в Premium.
final List<ProfileCover> kCollectionProfileCovers = [
  ProfileCover(
    id: 'cloth',
    nameRu: 'Полотно',
    nameEn: 'Silk sheet',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'cloth'),
  ),
  ProfileCover(
    id: 'balls',
    nameRu: 'Шарики',
    nameEn: 'Marbles',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'balls'),
  ),
  ProfileCover(
    id: 'orbits',
    nameRu: 'Притяжение',
    nameEn: 'Gravity',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'orbits'),
  ),
  ProfileCover(
    id: 'chaos',
    nameRu: 'Хаос',
    nameEn: 'Chaos',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'chaos'),
  ),
  ProfileCover(
    id: 'life',
    nameRu: 'Жизнь',
    nameEn: 'Life',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'life'),
  ),
  ProfileCover(
    id: 'compass',
    nameRu: 'Компасы',
    nameEn: 'Compasses',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'compass'),
  ),
  ProfileCover(
    id: 'plush',
    nameRu: 'Плюш',
    nameEn: 'Plush',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'plush'),
  ),
  ProfileCover(
    id: 'storm',
    nameRu: 'Гроза',
    nameEn: 'Thunderstorm',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'storm'),
  ),
  ProfileCover(
    id: 'ink',
    nameRu: 'Чернила',
    nameEn: 'Ink',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'ink'),
  ),
  ProfileCover(
    id: 'warp',
    nameRu: 'Гиперпрыжок',
    nameEn: 'Hyperjump',
    exclusive: true,
    builder: () => const LiveCoverView(id: 'warp'),
  ),
];

final List<ProfileCover> kAllProfileCovers = [
  ...kCollectionProfileCovers,
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
      : (coverById(id)?.builder() ?? const SizedBox.shrink()),
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
