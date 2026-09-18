// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import 'icons/app_icons.dart';
import 'wave1_l10n.dart';
import 'widgets/premium_glass.dart';

/// A localized, read-only sheet that lists what an active Premium subscriber
/// gets — one row per feature: name, then a lighter, smaller one-line blurb.
/// Opened by tapping the gold "Premium" badge in the chats header.
Future<void> showPremiumFeaturesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PremiumFeaturesSheet(),
  );
}

class _PremiumFeaturesSheet extends StatelessWidget {
  const _PremiumFeaturesSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final features = _features(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1116),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: kPremiumGold, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Secretly Premium',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                wave1Text(
                  context,
                  ru: 'Активно — вам доступно',
                  en: 'Active — everything you get',
                  uk: 'Активно — вам доступно',
                  es: 'Activo: todo lo que incluye',
                  pt: 'Ativo — tudo o que inclui',
                  ptBr: 'Ativo — tudo o que inclui',
                  fr: 'Actif — tout ce qui est inclus',
                  de: 'Aktiv – alles inklusive',
                ),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  itemCount: features.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => _FeatureRow(feature: features[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: kPremiumGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(feature.icon, color: kPremiumGold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.name,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              // Lighter, smaller description per the request.
              Text(
                feature.description,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumFeature {
  const _PremiumFeature(this.icon, this.name, this.description);
  final IconData icon;
  final String name;
  final String description;
}

List<_PremiumFeature> _features(BuildContext context) => [
  _PremiumFeature(
    Icons.auto_awesome_rounded,
    wave1Text(context,
        ru: 'Рамки и обложки профиля',
        en: 'Profile frames & covers',
        uk: 'Рамки та обкладинки профілю',
        es: 'Marcos y portadas de perfil',
        pt: 'Molduras e capas de perfil',
        ptBr: 'Molduras e capas de perfil',
        fr: 'Cadres et couvertures de profil',
        de: 'Profilrahmen und -cover'),
    wave1Text(context,
        ru: 'Анимированные рамки вокруг аватара и обложки — свои фото и видео.',
        en: 'Animated rings around your avatar and cover images — your own photo or video.',
        uk: 'Анімовані рамки навколо аватара та обкладинки — свої фото й відео.',
        es: 'Marcos animados alrededor del avatar y portadas con tu foto o vídeo.',
        pt: 'Molduras animadas à volta do avatar e capas com a tua foto ou vídeo.',
        ptBr: 'Molduras animadas ao redor do avatar e capas com sua foto ou vídeo.',
        fr: 'Cadres animés autour de l’avatar et couvertures avec votre photo ou vidéo.',
        de: 'Animierte Rahmen um deinen Avatar und Cover mit eigenem Foto oder Video.'),
  ),
  _PremiumFeature(
    Icons.wallpaper_rounded,
    wave1Text(context,
        ru: 'Премиум-обои чатов',
        en: 'Premium chat wallpapers',
        uk: 'Преміум-шпалери чатів',
        es: 'Fondos de chat premium',
        pt: 'Fundos de conversa premium',
        ptBr: 'Papéis de parede de conversa premium',
        fr: 'Fonds d’écran de discussion premium',
        de: 'Premium-Chat-Hintergründe'),
    wave1Text(context,
        ru: 'Живые анимированные обои и премиум-темы оформления.',
        en: 'Live animated wallpapers and premium themes.',
        uk: 'Живі анімовані шпалери та преміум-теми.',
        es: 'Fondos animados en vivo y temas premium.',
        pt: 'Fundos animados ao vivo e temas premium.',
        ptBr: 'Papéis de parede animados e temas premium.',
        fr: 'Fonds d’écran animés et thèmes premium.',
        de: 'Lebendige animierte Hintergründe und Premium-Designs.'),
  ),
  _PremiumFeature(
    Icons.emoji_emotions_rounded,
    wave1Text(context,
        ru: 'Эмодзи-статусы и стикеры',
        en: 'Emoji statuses & stickers',
        uk: 'Емодзі-статуси та стикери',
        es: 'Estados con emoji y stickers',
        pt: 'Estados com emoji e stickers',
        ptBr: 'Status com emoji e figurinhas',
        fr: 'Statuts emoji et stickers',
        de: 'Emoji-Status und Sticker'),
    wave1Text(context,
        ru: 'Статус-эмодзи рядом с именем и премиум-наборы стикеров.',
        en: 'An emoji status next to your name and premium sticker packs.',
        uk: 'Емодзі-статус біля імені та преміум-набори стикерів.',
        es: 'Un emoji de estado junto a tu nombre y packs de stickers premium.',
        pt: 'Um emoji de estado ao lado do teu nome e packs de stickers premium.',
        ptBr: 'Um emoji de status ao lado do seu nome e pacotes de figurinhas premium.',
        fr: 'Un statut emoji près de votre nom et des packs de stickers premium.',
        de: 'Ein Emoji-Status neben deinem Namen und Premium-Sticker-Pakete.'),
  ),
  _PremiumFeature(
    Icons.badge_rounded,
    wave1Text(context,
        ru: 'Свой Secretly ID',
        en: 'Custom Secretly ID',
        uk: 'Власний Secretly ID',
        es: 'Secretly ID personalizado',
        pt: 'Secretly ID personalizado',
        ptBr: 'Secretly ID personalizado',
        fr: 'Secretly ID personnalisé',
        de: 'Eigene Secretly-ID'),
    wave1Text(context,
        ru: 'Красивый запоминающийся идентификатор вместо случайного.',
        en: 'A memorable, good-looking ID instead of a random one.',
        uk: 'Гарний запам’ятовуваний ідентифікатор замість випадкового.',
        es: 'Un ID bonito y fácil de recordar en vez de uno aleatorio.',
        pt: 'Um ID bonito e memorável em vez de um aleatório.',
        ptBr: 'Um ID bonito e fácil de lembrar em vez de um aleatório.',
        fr: 'Un identifiant mémorable et élégant au lieu d’un aléatoire.',
        de: 'Eine einprägsame, schöne ID statt einer zufälligen.'),
  ),
  _PremiumFeature(
    Icons.folder_special_rounded,
    wave1Text(context,
        ru: 'Папки и умная сортировка',
        en: 'Folders & smart sorting',
        uk: 'Папки та розумне сортування',
        es: 'Carpetas y orden inteligente',
        pt: 'Pastas e ordenação inteligente',
        ptBr: 'Pastas e ordenação inteligente',
        fr: 'Dossiers et tri intelligent',
        de: 'Ordner und intelligente Sortierung'),
    wave1Text(context,
        ru: 'Раскладывайте чаты по папкам и сортируйте список как удобно.',
        en: 'Organize chats into folders and sort the list however you like.',
        uk: 'Розкладайте чати по папках і сортуйте список як зручно.',
        es: 'Organiza los chats en carpetas y ordénalos como quieras.',
        pt: 'Organize conversas em pastas e ordene a lista como quiser.',
        ptBr: 'Organize conversas em pastas e ordene a lista como quiser.',
        fr: 'Rangez les discussions dans des dossiers et triez la liste à votre goût.',
        de: 'Ordne Chats in Ordnern und sortiere die Liste nach Belieben.'),
  ),
  _PremiumFeature(
    Icons.schedule_send_rounded,
    wave1Text(context,
        ru: 'Запланированные сообщения',
        en: 'Scheduled messages',
        uk: 'Заплановані повідомлення',
        es: 'Mensajes programados',
        pt: 'Mensagens agendadas',
        ptBr: 'Mensagens agendadas',
        fr: 'Messages programmés',
        de: 'Geplante Nachrichten'),
    wave1Text(context,
        ru: 'Пишите сейчас — отправится в выбранное время.',
        en: 'Write now — it sends at the time you pick.',
        uk: 'Пишіть зараз — надішлеться у вибраний час.',
        es: 'Escribe ahora y se envía a la hora que elijas.',
        pt: 'Escreve agora e envia à hora que escolheres.',
        ptBr: 'Escreva agora e envie na hora que escolher.',
        fr: 'Écrivez maintenant, l’envoi se fait à l’heure choisie.',
        de: 'Jetzt schreiben – Versand zur gewählten Zeit.'),
  ),
  _PremiumFeature(
    Icons.record_voice_over_rounded,
    wave1Text(context,
        ru: 'ИИ: голос в текст и перевод',
        en: 'AI: voice-to-text & translation',
        uk: 'ШІ: голос у текст і переклад',
        es: 'IA: voz a texto y traducción',
        pt: 'IA: voz para texto e tradução',
        ptBr: 'IA: voz para texto e tradução',
        fr: 'IA : voix en texte et traduction',
        de: 'KI: Sprache-zu-Text und Übersetzung'),
    wave1Text(context,
        ru: 'Расшифровка голосовых и перевод сообщений на лету.',
        en: 'Transcribe voice messages and translate chats on the fly.',
        uk: 'Розшифрування голосових і переклад повідомлень на льоту.',
        es: 'Transcribe notas de voz y traduce chats al instante.',
        pt: 'Transcreve mensagens de voz e traduz conversas em tempo real.',
        ptBr: 'Transcreva mensagens de voz e traduza conversas em tempo real.',
        fr: 'Transcrivez les messages vocaux et traduisez les discussions à la volée.',
        de: 'Sprachnachrichten transkribieren und Chats in Echtzeit übersetzen.'),
  ),
  _PremiumFeature(
    Icons.cloud_done_rounded,
    wave1Text(context,
        ru: 'Зашифрованный бэкап',
        en: 'Encrypted backup',
        uk: 'Зашифрований бекап',
        es: 'Copia de seguridad cifrada',
        pt: 'Cópia de segurança cifrada',
        ptBr: 'Backup criptografado',
        fr: 'Sauvegarde chiffrée',
        de: 'Verschlüsseltes Backup'),
    wave1Text(context,
        ru: 'Безопасная резервная копия переписки — только для вас.',
        en: 'A secure backup of your chats — readable only by you.',
        uk: 'Безпечна резервна копія листування — лише для вас.',
        es: 'Una copia segura de tus chats, legible solo por ti.',
        pt: 'Uma cópia segura das conversas — só tu consegues ler.',
        ptBr: 'Uma cópia segura das conversas — só você consegue ler.',
        fr: 'Une sauvegarde sécurisée de vos discussions, lisible par vous seul.',
        de: 'Ein sicheres Backup deiner Chats – nur von dir lesbar.'),
  ),
  _PremiumFeature(
    AppIcons.callSolid,
    wave1Text(context,
        ru: 'Рингтоны и премиум-иконки',
        en: 'Ringtones & premium icons',
        uk: 'Рингтони та преміум-іконки',
        es: 'Tonos y iconos premium',
        pt: 'Toques e ícones premium',
        ptBr: 'Toques e ícones premium',
        fr: 'Sonneries et icônes premium',
        de: 'Klingeltöne und Premium-Icons'),
    wave1Text(context,
        ru: 'Свои звуки вызова и премиум-иконка приложения.',
        en: 'Your own call sounds and a premium app icon.',
        uk: 'Свої звуки виклику та преміум-іконка застосунку.',
        es: 'Tus propios sonidos de llamada y un icono de app premium.',
        pt: 'Os teus sons de chamada e um ícone de app premium.',
        ptBr: 'Seus próprios sons de chamada e um ícone de app premium.',
        fr: 'Vos propres sons d’appel et une icône d’app premium.',
        de: 'Eigene Anrufklänge und ein Premium-App-Icon.'),
  ),
];
