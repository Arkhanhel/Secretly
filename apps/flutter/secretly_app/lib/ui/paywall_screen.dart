// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Paywall screen (TZ-MONETIZE-01 §C-4) — premium Telegram-style redesign.
//
// One screen, parameterised by [trigger]. Shown ONLY when a gated feature is hit
// AND monetization is enabled — never on onboarding/first launch.
//
// Layout: island top bar (✕ left · «Premium» island center · Restore right) →
// hero (cosmic dust + animated 3D Secretly mark) → PLAN CARDS (tap a card to buy
// directly, no confirm button) → feature list → legal. Dark canvas so the dust
// and glow read like Telegram. Gold is used sparingly (wordmark island + the
// selected plan glow is the brand colour).
//
// Ethics (§C-4): no countdown timers, no card-required "free trial", always a
// visible close button, Terms/Privacy links (Apple review). Upcoming perks are
// honestly tagged «Скоро».

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../billing/restore_outcome.dart';
import '../entitlements/feature_gate.dart';
import 'wave1_l10n.dart';
import 'widgets/premium_glass.dart';

/// The reason the paywall was shown. 1:1 with [paywallTriggerFromFeature].
enum PaywallTrigger { desktop, file, id, cosmetic, group, general }

PaywallTrigger paywallTriggerFromFeature(GatedFeature feature) {
  switch (feature) {
    case GatedFeature.desktop:
      return PaywallTrigger.desktop;
    case GatedFeature.customId:
      return PaywallTrigger.id;
    case GatedFeature.attachment:
      return PaywallTrigger.file;
    case GatedFeature.group:
      return PaywallTrigger.group;
    case GatedFeature.cosmetic:
    case GatedFeature.premiumStickers:
      return PaywallTrigger.cosmetic;
    case GatedFeature.voiceToText:
      return PaywallTrigger.general;
  }
}

/// A purchasable plan. `priceLabel` is the localized store price (C-2), falling
/// back to the TZ reference price. `badge`/`perMonthLabel` drive the discount
/// pill and per-month breakdown.
class PaywallSku {
  const PaywallSku({
    required this.productId,
    required this.title,
    required this.priceLabel,
    this.subtitle,
    this.highlighted = false,
    this.badge,
    this.perMonthLabel,
    this.originalPriceLabel,
  });

  final String productId;
  final String title;
  final String priceLabel;
  final String? subtitle;
  final bool highlighted;
  final String? badge; // e.g. "−58%"
  final String? perMonthLabel; // e.g. "≈ $1,25 / мес"
  final String? originalPriceLabel; // struck-through original, e.g. "$35.88"

  PaywallSku copyWith({
    String? priceLabel,
    String? badge,
    String? perMonthLabel,
    String? originalPriceLabel,
  }) =>
      PaywallSku(
        productId: productId,
        title: title,
        priceLabel: priceLabel ?? this.priceLabel,
        subtitle: subtitle,
        highlighted: highlighted,
        badge: badge ?? this.badge,
        perMonthLabel: perMonthLabel ?? this.perMonthLabel,
        originalPriceLabel: originalPriceLabel ?? this.originalPriceLabel,
      );
}

/// Localized short "per month" suffix for the per-month price figure shown on
/// the monthly & yearly plan cards — a compact slash form so it sits on ONE
/// right-aligned line (e.g. "3,33 €/мес" instead of "3,33 € в месяц"). Includes
/// the leading slash; concatenate directly after the price WITHOUT a space.
/// Public so the billing layer builds the same string from live store prices.
String premiumPerMonthSuffix(String localeTag) => wave1TextForLocale(
  localeTag,
  ru: '/мес',
  en: '/mo',
  uk: '/міс',
  es: '/mes',
  pt: '/mês',
  ptBr: '/mês',
  fr: '/mois',
  de: '/Mon.',
);

/// Reference SKUs/prices (TZ §6). Yearly ≈58% cheaper than 12× monthly.
///
/// [localeTag] is a wave1 locale tag (en/ru/uk/es/pt/pt_BR/fr/de) so the plan
/// names are localized across all 8 app locales without needing a BuildContext
/// — this keeps the billing layer UI-free and unit-testable.
List<PaywallSku> defaultPaywallSkus({String localeTag = 'en'}) => [
  PaywallSku(
    productId: 'secretly_premium_monthly',
    title: wave1TextForLocale(
      localeTag,
      ru: 'Ежемесячно',
      en: 'Monthly',
      uk: 'Щомісяця',
      es: 'Mensual',
      pt: 'Mensal',
      ptBr: 'Mensal',
      fr: 'Mensuel',
      de: 'Monatlich',
    ),
    priceLabel: r'$2.99',
    perMonthLabel: '\$2.99${premiumPerMonthSuffix(localeTag)}',
  ),
  PaywallSku(
    productId: 'secretly_premium_yearly',
    title: wave1TextForLocale(
      localeTag,
      ru: 'Ежегодно',
      en: 'Yearly',
      uk: 'Щороку',
      es: 'Anual',
      pt: 'Anual',
      ptBr: 'Anual',
      fr: 'Annuel',
      de: 'Jährlich',
    ),
    priceLabel: r'$14.99',
    originalPriceLabel: r'$35.88',
    highlighted: true,
    badge: '−58%',
    perMonthLabel: '\$1.25${premiumPerMonthSuffix(localeTag)}',
  ),
  PaywallSku(
    productId: 'secretly_premium_life',
    title: wave1TextForLocale(
      localeTag,
      ru: 'Пожизненно',
      en: 'Lifetime',
      uk: 'Назавжди',
      es: 'Para siempre',
      pt: 'Para sempre',
      ptBr: 'Para sempre',
      fr: 'À vie',
      de: 'Für immer',
    ),
    priceLabel: r'$29.99',
    subtitle: wave1TextForLocale(
      localeTag,
      ru: 'разовый платёж',
      en: 'one-time',
      uk: 'разовий платіж',
      es: 'pago único',
      pt: 'pagamento único',
      ptBr: 'pagamento único',
      fr: 'paiement unique',
      de: 'einmalige Zahlung',
    ),
  ),
];

/// Screenshot/test hook: forces the renewal disclosure store name. Null in app.
bool? debugPaywallForceAppleStore;

/// Тексты плашки «ожидаем оплату» — в идиоме этого экрана (wave1), а не через
/// общий AppLocalizations: экран намеренно самодостаточен.
String _pendingPaymentTitle(String localeTag) => wave1TextForLocale(
      localeTag,
      ru: 'Ожидаем оплату',
      en: 'Waiting for payment',
      uk: 'Очікуємо оплату',
      es: 'Esperando el pago',
      pt: 'A aguardar o pagamento',
      ptBr: 'Aguardando o pagamento',
      fr: 'En attente du paiement',
      de: 'Warten auf Zahlung',
    );

String _pendingPaymentBody(String localeTag) => wave1TextForLocale(
      localeTag,
      ru: 'Заказ создан, но платёж ещё не подтверждён. Завершите оплату '
          'выбранным способом — премиум включится сам.',
      en: 'The order was created but payment is not confirmed yet. Finish '
          'paying with your chosen method — Premium will switch on by itself.',
      uk: 'Замовлення створено, але платіж ще не підтверджено. Завершіть '
          'оплату вибраним способом — преміум увімкнеться сам.',
      es: 'El pedido se creó pero el pago aún no está confirmado. Completa el '
          'pago con el método elegido: Premium se activará solo.',
      pt: 'O pedido foi criado, mas o pagamento ainda não está confirmado. '
          'Conclua o pagamento com o método escolhido — o Premium será '
          'ativado sozinho.',
      ptBr: 'O pedido foi criado, mas o pagamento ainda não foi confirmado. '
          'Conclua o pagamento pelo método escolhido — o Premium será '
          'ativado sozinho.',
      fr: "La commande est créée mais le paiement n'est pas encore confirmé. "
          "Terminez le paiement avec le moyen choisi — Premium s'activera "
          'tout seul.',
      de: 'Die Bestellung wurde erstellt, die Zahlung ist aber noch nicht '
          'bestätigt. Bezahle mit der gewählten Methode — Premium wird von '
          'selbst aktiviert.',
    );

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.trigger,
    this.skus,
    this.onPurchase,
    this.onRestore,
    this.onOpenTerms,
    this.onOpenPrivacy,
    this.pendingPayment = false,
    this.pendingPaymentToastShown = true,
    this.onPendingPaymentToastShown,
  });

  final PaywallTrigger trigger;
  final List<PaywallSku>? skus;
  // Returns true if the purchase flow was actually started. False means the
  // product/store was unavailable (e.g. the subscription isn't loaded on iOS),
  // so the UI must surface that instead of silently doing nothing.
  final Future<bool> Function(PaywallSku sku)? onPurchase;
  /// Restores purchases AND re-pulls the server entitlement. Reports which of
  /// the three real outcomes happened so the screen can confirm success, or
  /// explain honestly — a buyer whose purchase exists must never be told there
  /// is nothing to restore.
  final Future<RestoreOutcome> Function()? onRestore;
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  /// Магазин создал заказ и ЖДЁТ доплаты (наличными в магазине, через
  /// оператора). Премиум при этом правильно не выдан — но раньше покупателю не
  /// говорили ничего, и прод-заказ от 24.07.2026 так и остался неоплаченным:
  /// человек не знал, что от него ждут.
  final bool pendingPayment;

  /// Тихая подсказка полагается РОВНО ОДИН РАЗ на заказ. Полоска ниже остаётся,
  /// пока ожидание не кончится, — напоминание там, где человек сам его ищет.
  final bool pendingPaymentToastShown;
  final VoidCallback? onPendingPaymentToastShown;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late List<PaywallSku> _items;
  bool _buyInFlight = false;
  bool _restoreInFlight = false;

  bool _pendingToastQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pendingPayment &&
        !widget.pendingPaymentToastShown &&
        !_pendingToastQueued) {
      _pendingToastQueued = true;
      // После первого кадра: до него ScaffoldMessenger ещё не готов.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              _pendingPaymentBody(wave1LocaleTagFromContext(context)),
            ),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onPendingPaymentToastShown?.call();
      });
    }
    _items =
        widget.skus ??
        defaultPaywallSkus(localeTag: wave1LocaleTagFromContext(context));
  }

  /// Starts a purchase and, crucially, gives FEEDBACK when it can't start.
  /// Previously the tap result was discarded, so on iOS a plan whose product
  /// failed to load (e.g. the yearly subscription not yet approved in App Store
  /// Connect) just did nothing on tap. Now we show a clear message and guard
  /// against double-taps.
  Future<void> _handlePurchase(PaywallSku sku) async {
    final cb = widget.onPurchase;
    if (cb == null || _buyInFlight) return;
    setState(() => _buyInFlight = true);
    var started = false;
    try {
      started = await cb(sku);
    } catch (_) {
      started = false;
    }
    if (!mounted) return;
    setState(() => _buyInFlight = false);
    if (!started) {
      final localeTag = wave1LocaleTagFromContext(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              wave1TextForLocale(
                localeTag,
                ru: 'Покупка временно недоступна. Попробуйте позже или проверьте подключение.',
                en: 'Purchase is temporarily unavailable. Try again later or check your connection.',
                uk: 'Покупка тимчасово недоступна. Спробуйте пізніше.',
                es: 'La compra no está disponible. Inténtalo de nuevo más tarde.',
                pt: 'A compra está indisponível. Tente novamente mais tarde.',
                ptBr: 'A compra está indisponível. Tente novamente mais tarde.',
                fr: "L'achat est indisponible. Réessayez plus tard.",
                de: 'Kauf derzeit nicht verfügbar. Bitte später erneut versuchen.',
              ),
            ),
          ),
        );
    }
  }

  /// Restores purchases and gives FEEDBACK — previously the tap result was
  /// discarded, so on a tester whose purchase was never credited (or who was
  /// comped server-side) the button looked dead. Now it shows progress, then
  /// confirms success (and closes) or explains that nothing was found.
  Future<void> _handleRestore() async {
    final cb = widget.onRestore;
    if (cb == null || _restoreInFlight) return;
    final localeTag = wave1LocaleTagFromContext(context);
    setState(() => _restoreInFlight = true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wave1TextForLocale(
              localeTag,
              ru: 'Восстанавливаем покупки…',
              en: 'Restoring purchases…',
              uk: 'Відновлюємо покупки…',
              es: 'Restaurando compras…',
              pt: 'A restaurar compras…',
              ptBr: 'Restaurando compras…',
              fr: 'Restauration des achats…',
              de: 'Käufe werden wiederhergestellt…',
            ),
          ),
        ),
      );
    var outcome = RestoreOutcome.nothingToRestore;
    try {
      outcome = await cb();
    } catch (_) {
      outcome = RestoreOutcome.purchaseNotApplied;
    }
    if (!mounted) return;
    setState(() => _restoreInFlight = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            outcome == RestoreOutcome.restored
                ? wave1TextForLocale(
                    localeTag,
                    ru: 'Премиум восстановлен ✓',
                    en: 'Premium restored ✓',
                    uk: 'Преміум відновлено ✓',
                    es: 'Premium restaurado ✓',
                    pt: 'Premium restaurado ✓',
                    ptBr: 'Premium restaurado ✓',
                    fr: 'Premium restauré ✓',
                    de: 'Premium wiederhergestellt ✓',
                  )
                : outcome == RestoreOutcome.purchaseNotApplied
                    // The store DID return a purchase — never tell this person
                    // there is nothing to restore; they paid and can see it in
                    // their store account.
                    ? wave1TextForLocale(
                        localeTag,
                        ru: 'Покупка найдена, но пока не применилась. Проверьте связь и повторите — если не поможет, напишите в поддержку.',
                        en: 'Purchase found but not applied yet. Check your connection and retry — contact support if it persists.',
                        uk: 'Покупку знайдено, але вона ще не застосувалася. Перевірте зв’язок і повторіть — якщо не допоможе, напишіть у підтримку.',
                        es: 'Compra encontrada pero aún no aplicada. Revisa la conexión y reinténtalo; si persiste, contacta con soporte.',
                        pt: 'Compra encontrada mas ainda não aplicada. Verifique a ligação e tente de novo; se persistir, contacte o suporte.',
                        ptBr: 'Compra encontrada mas ainda não aplicada. Verifique a conexão e tente de novo; se persistir, contate o suporte.',
                        fr: 'Achat trouvé mais pas encore appliqué. Vérifiez la connexion et réessayez ; si cela persiste, contactez le support.',
                        de: 'Kauf gefunden, aber noch nicht angewendet. Verbindung prüfen und erneut versuchen — bei Bedarf den Support kontaktieren.',
                      )
                    : wave1TextForLocale(
                    localeTag,
                    ru: 'Покупок для восстановления не найдено. Если вы оплачивали — напишите в поддержку.',
                    en: 'No purchases to restore. If you were charged, contact support.',
                    uk: 'Покупок для відновлення не знайдено. Якщо ви платили — напишіть у підтримку.',
                    es: 'No hay compras que restaurar. Si se te cobró, contacta con soporte.',
                    pt: 'Nenhuma compra para restaurar. Se foi cobrado, contacte o suporte.',
                    ptBr: 'Nenhuma compra para restaurar. Se foi cobrado, contate o suporte.',
                    fr: "Aucun achat à restaurer. Si vous avez été débité, contactez le support.",
                    de: 'Keine Käufe zum Wiederherstellen. Falls abgebucht, Support kontaktieren.',
                  ),
          ),
        ),
      );
    // On success, close the paywall — the unlocked UI is the confirmation.
    if (outcome == RestoreOutcome.restored && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  String _heroSubtitle(BuildContext context) {
    switch (widget.trigger) {
      case PaywallTrigger.desktop:
        return wave1Text(
          context,
          ru: 'Secretly на компьютере и нескольких устройствах сразу',
          en: 'Secretly on your computer and many devices at once',
          uk: 'Secretly на компʼютері та кількох пристроях одночасно',
          es: 'Secretly en tu ordenador y en varios dispositivos a la vez',
          pt: 'O Secretly no seu computador e em vários dispositivos ao mesmo tempo',
          ptBr:
              'O Secretly no seu computador e em vários dispositivos ao mesmo tempo',
          fr: 'Secretly sur votre ordinateur et plusieurs appareils à la fois',
          de: 'Secretly auf deinem Computer und mehreren Geräten gleichzeitig',
        );
      case PaywallTrigger.file:
        return wave1Text(
          context,
          ru: 'Делитесь файлами до 1 ГБ вместо 100 МБ',
          en: 'Share files up to 1 GB instead of 100 MB',
          uk: 'Надсилайте файли до 1 ГБ замість 100 МБ',
          es: 'Comparte archivos de hasta 1 GB en lugar de 100 MB',
          pt: 'Partilhe ficheiros até 1 GB em vez de 100 MB',
          ptBr: 'Compartilhe arquivos de até 1 GB em vez de 100 MB',
          fr: 'Partagez des fichiers jusqu’à 1 Go au lieu de 100 Mo',
          de: 'Teile Dateien bis zu 1 GB statt 100 MB',
        );
      case PaywallTrigger.id:
        return wave1Text(
          context,
          ru: 'Свой Secretly ID и премиум-темы',
          en: 'Your custom Secretly ID and premium themes',
          uk: 'Власний Secretly ID і преміум-теми',
          es: 'Tu Secretly ID personalizado y temas premium',
          pt: 'O seu Secretly ID personalizado e temas premium',
          ptBr: 'Seu Secretly ID personalizado e temas premium',
          fr: 'Votre Secretly ID personnalisé et des thèmes premium',
          de: 'Deine eigene Secretly-ID und Premium-Designs',
        );
      case PaywallTrigger.cosmetic:
        return wave1Text(
          context,
          ru: 'Премиум-темы, обои, рамки и реакции',
          en: 'Premium themes, wallpapers, frames and reactions',
          uk: 'Преміум-теми, шпалери, рамки та реакції',
          es: 'Temas, fondos, marcos y reacciones premium',
          pt: 'Temas, fundos, molduras e reações premium',
          ptBr: 'Temas, papéis de parede, molduras e reações premium',
          fr: 'Thèmes, fonds d’écran, cadres et réactions premium',
          de: 'Premium-Designs, Hintergründe, Rahmen und Reaktionen',
        );
      case PaywallTrigger.group:
        return wave1Text(
          context,
          ru: 'Группы до 500 человек и звонки до 50 участников',
          en: 'Groups up to 500 people and calls up to 50',
          uk: 'Групи до 500 осіб і дзвінки до 50 учасників',
          es: 'Grupos de hasta 500 personas y llamadas de hasta 50',
          pt: 'Grupos até 500 pessoas e chamadas até 50',
          ptBr: 'Grupos de até 500 pessoas e chamadas de até 50',
          fr: 'Groupes jusqu’à 500 personnes et appels jusqu’à 50',
          de: 'Gruppen mit bis zu 500 Personen und Anrufe mit bis zu 50',
        );
      case PaywallTrigger.general:
        return wave1Text(
          context,
          ru: 'Всё лучшее в Secretly — без рекламы и с полной приватностью',
          en: 'Everything great in Secretly — no ads, full privacy',
          uk: 'Усе найкраще в Secretly — без реклами та з повною приватністю',
          es: 'Todo lo mejor de Secretly: sin anuncios y con total privacidad',
          pt: 'Tudo o que o Secretly tem de melhor — sem anúncios e com total privacidade',
          ptBr:
              'Tudo de melhor no Secretly — sem anúncios e com total privacidade',
          fr: 'Tout le meilleur de Secretly — sans publicité et en toute confidentialité',
          de: 'Alles Beste in Secretly — keine Werbung, volle Privatsphäre',
        );
    }
  }

  /// Current perks (live today). (icon, title, subtitle?)
  List<(IconData, String, String?)> _currentPerks(BuildContext context) {
    return [
      (
        Icons.devices_rounded,
        wave1Text(
          context,
          ru: 'Несколько устройств, включая компьютер',
          en: 'Multiple devices, including desktop',
          uk: 'Кілька пристроїв, разом із компʼютером',
          es: 'Varios dispositivos, incluido el ordenador',
          pt: 'Vários dispositivos, incluindo o computador',
          ptBr: 'Vários dispositivos, incluindo o computador',
          fr: 'Plusieurs appareils, y compris l’ordinateur',
          de: 'Mehrere Geräte, auch Desktop',
        ),
        null,
      ),
      (
        Icons.cloud_upload_rounded,
        wave1Text(
          context,
          ru: 'Файлы до 1 ГБ',
          en: 'Files up to 1 GB',
          uk: 'Файли до 1 ГБ',
          es: 'Archivos de hasta 1 GB',
          pt: 'Ficheiros até 1 GB',
          ptBr: 'Arquivos de até 1 GB',
          fr: 'Fichiers jusqu’à 1 Go',
          de: 'Dateien bis zu 1 GB',
        ),
        wave1Text(
          context,
          ru: 'вместо 25 МБ на бесплатном тарифе',
          en: 'instead of 25 MB on the free plan',
          uk: 'замість 25 МБ на безкоштовному тарифі',
          es: 'en lugar de 25 MB en el plan gratuito',
          pt: 'em vez de 25 MB no plano gratuito',
          ptBr: 'em vez de 25 MB no plano gratuito',
          fr: 'au lieu de 25 Mo dans l’offre gratuite',
          de: 'statt 25 MB im kostenlosen Tarif',
        ),
      ),
      (
        Icons.groups_rounded,
        wave1Text(
          context,
          ru: 'Группы до 500 человек и звонки до 50 участников',
          en: 'Groups up to 500 people and calls up to 50',
          uk: 'Групи до 500 осіб і дзвінки до 50 учасників',
          es: 'Grupos de hasta 500 personas y llamadas de hasta 50',
          pt: 'Grupos até 500 pessoas e chamadas até 50',
          ptBr: 'Grupos de até 500 pessoas e chamadas de até 50',
          fr: 'Groupes jusqu’à 500 personnes et appels jusqu’à 50',
          de: 'Gruppen mit bis zu 500 Personen und Anrufe mit bis zu 50',
        ),
        null,
      ),
      (
        Icons.workspaces_rounded,
        wave1Text(
          context,
          ru: 'Больше своих групп и комнат',
          en: 'More owned groups and rooms',
          uk: 'Більше власних груп і кімнат',
          es: 'Más grupos y salas propios',
          pt: 'Mais grupos e salas próprios',
          ptBr: 'Mais grupos e salas próprios',
          fr: 'Plus de groupes et salons à vous',
          de: 'Mehr eigene Gruppen und Räume',
        ),
        wave1Text(
          context,
          ru: 'до 100 вместо 5',
          en: 'up to 100 instead of 5',
          uk: 'до 100 замість 5',
          es: 'hasta 100 en lugar de 5',
          pt: 'até 100 em vez de 5',
          ptBr: 'até 100 em vez de 5',
          fr: 'jusqu’à 100 au lieu de 5',
          de: 'bis zu 100 statt 5',
        ),
      ),
      // "Custom Secretly ID" is deliberately absent from this list: the
      // entitlement carries a custom_id flag, but nothing in the app or the
      // server can actually change a Secretly ID, so listing it sold a feature
      // that does not exist. Restore it here only once the feature ships — and
      // it must ship as an alias over a stable profile_id, never as a new one:
      // the ID anchors contacts, ratchet sessions and the entitlement itself,
      // so minting a fresh one would break all three at once.
      (
        Icons.record_voice_over_rounded,
        wave1Text(
          context,
          ru: 'ИИ: голосовые сообщения в текст',
          en: 'AI: voice messages to text',
          uk: 'ШІ: голосові повідомлення в текст',
          es: 'IA: mensajes de voz a texto',
          pt: 'IA: mensagens de voz em texto',
          ptBr: 'IA: mensagens de voz em texto',
          fr: 'IA : messages vocaux en texte',
          de: 'KI: Sprachnachrichten in Text',
        ),
        null,
      ),
      (
        Icons.palette_rounded,
        wave1Text(
          context,
          ru: 'Премиум-косметика: иконки, обои, рингтоны, рамки и обложки профиля',
          en: 'Premium cosmetics: icons, wallpapers, ringtones, frames and profile covers',
          uk: 'Преміум-косметика: іконки, шпалери, рингтони, рамки та обкладинки профілю',
          es: 'Cosmética premium: iconos, fondos, tonos, marcos y portadas de perfil',
          pt: 'Cosméticos premium: ícones, fundos, toques, molduras e capas de perfil',
          ptBr:
              'Cosméticos premium: ícones, papéis de parede, toques, molduras e capas de perfil',
          fr: 'Cosmétiques premium : icônes, fonds d’écran, sonneries, cadres et couvertures de profil',
          de: 'Premium-Kosmetik: Icons, Hintergründe, Klingeltöne, Rahmen und Profil-Cover',
        ),
        null,
      ),
      (
        Icons.auto_awesome_rounded,
        wave1Text(
          context,
          ru: 'Премиум-стикеры и эмодзи-статусы',
          en: 'Premium stickers and emoji statuses',
          uk: 'Преміум-стикери та емодзі-статуси',
          es: 'Stickers premium y estados con emoji',
          pt: 'Stickers premium e estados com emoji',
          ptBr: 'Figurinhas premium e status com emoji',
          fr: 'Stickers premium et statuts emoji',
          de: 'Premium-Sticker und Emoji-Status',
        ),
        null,
      ),
      (
        Icons.verified_user_rounded,
        wave1Text(
          context,
          ru: 'Без рекламы и трекеров слежки',
          en: 'No ads, no tracking',
          uk: 'Без реклами та трекерів стеження',
          es: 'Sin anuncios ni rastreadores',
          pt: 'Sem anúncios nem rastreadores',
          ptBr: 'Sem anúncios nem rastreadores',
          fr: 'Sans publicité ni traqueurs',
          de: 'Keine Werbung, keine Tracker',
        ),
        null,
      ),
      (
        Icons.folder_special_rounded,
        wave1Text(
          context,
          ru: 'Папки и умная сортировка чатов',
          en: 'Chat folders and smart sorting',
          uk: 'Папки та розумне сортування чатів',
          es: 'Carpetas y orden inteligente de chats',
          pt: 'Pastas e ordenação inteligente de conversas',
          ptBr: 'Pastas e ordenação inteligente de conversas',
          fr: 'Dossiers et tri intelligent des discussions',
          de: 'Chat-Ordner und intelligente Sortierung',
        ),
        null,
      ),
      (
        Icons.translate_rounded,
        wave1Text(
          context,
          ru: 'ИИ-перевод сообщений на лету',
          en: 'On-the-fly AI message translation',
          uk: 'ШІ-переклад повідомлень на льоту',
          es: 'Traducción de mensajes con IA al instante',
          pt: 'Tradução de mensagens com IA em tempo real',
          ptBr: 'Tradução de mensagens com IA em tempo real',
          fr: 'Traduction des messages par IA à la volée',
          de: 'KI-Nachrichtenübersetzung in Echtzeit',
        ),
        null,
      ),
      (
        Icons.cloud_done_rounded,
        wave1Text(
          context,
          ru: 'Зашифрованный облачный бэкап',
          en: 'Encrypted cloud backup',
          uk: 'Зашифрований хмарний бекап',
          es: 'Copia de seguridad cifrada en la nube',
          pt: 'Cópia de segurança cifrada na nuvem',
          ptBr: 'Backup criptografado na nuvem',
          fr: 'Sauvegarde chiffrée dans le cloud',
          de: 'Verschlüsseltes Cloud-Backup',
        ),
        null,
      ),
      (
        Icons.schedule_send_rounded,
        wave1Text(
          context,
          ru: 'Запланированные сообщения',
          en: 'Scheduled messages',
          uk: 'Заплановані повідомлення',
          es: 'Mensajes programados',
          pt: 'Mensagens agendadas',
          ptBr: 'Mensagens agendadas',
          fr: 'Messages programmés',
          de: 'Geplante Nachrichten',
        ),
        null,
      ),
    ];
  }

  /// Upcoming perks — honestly tagged «Скоро». Genuinely-future features that
  /// are not yet implemented. (icon, title)
  List<(IconData, String)> _comingPerks(BuildContext context) {
    return [
      (
        Icons.workspaces_rounded,
        wave1Text(
          context,
          ru: 'Spaces — каналы и сообщества',
          en: 'Spaces — channels and communities',
          uk: 'Spaces — канали та спільноти',
          es: 'Spaces: canales y comunidades',
          pt: 'Spaces: canais e comunidades',
          ptBr: 'Spaces: canais e comunidades',
          fr: 'Spaces — chaînes et communautés',
          de: 'Spaces — Kanäle und Communitys',
        ),
      ),
      (
        Icons.emoji_emotions_rounded,
        wave1Text(
          context,
          ru: 'Свои стикерпаки и создание стикеров',
          en: 'Custom sticker packs and sticker maker',
          uk: 'Власні стікерпаки та створення стікерів',
          es: 'Packs de stickers propios y creador',
          pt: 'Pacotes de stickers próprios e criador',
          ptBr: 'Pacotes de figurinhas próprios e criador',
          fr: 'Packs de stickers personnalisés et éditeur',
          de: 'Eigene Sticker-Packs und Sticker-Editor',
        ),
      ),
      (
        Icons.auto_stories_rounded,
        wave1Text(
          context,
          ru: 'Истории, которые исчезают',
          en: 'Disappearing stories',
          uk: 'Історії, що зникають',
          es: 'Historias que desaparecen',
          pt: 'Histórias que desaparecem',
          ptBr: 'Histórias que desaparecem',
          fr: 'Stories éphémères',
          de: 'Verschwindende Stories',
        ),
      ),
      (
        Icons.smart_display_rounded,
        wave1Text(
          context,
          ru: 'Совместный просмотр видео в звонках',
          en: 'Watch videos together on calls',
          uk: 'Спільний перегляд відео у дзвінках',
          es: 'Ver vídeos juntos en llamadas',
          pt: 'Assistir a vídeos juntos em chamadas',
          ptBr: 'Assistir a vídeos juntos em chamadas',
          fr: 'Regarder des vidéos ensemble en appel',
          de: 'Gemeinsam Videos in Anrufen ansehen',
        ),
      ),
      (
        Icons.videocam_rounded,
        wave1Text(
          context,
          ru: 'HD-видеозвонки и шумоподавление',
          en: 'HD video calls with noise suppression',
          uk: 'HD-відеодзвінки та придушення шуму',
          es: 'Videollamadas HD con supresión de ruido',
          pt: 'Videochamadas HD com supressão de ruído',
          ptBr: 'Chamadas de vídeo HD com supressão de ruído',
          fr: 'Appels vidéo HD avec suppression du bruit',
          de: 'HD-Videoanrufe mit Rauschunterdrückung',
        ),
      ),
    ];
  }

  /// Auto-renewal disclosure (Apple 3.1.2 / Google), refined wording.
  String _renewalDisclosure(BuildContext context) {
    final apple =
        debugPaywallForceAppleStore ?? (Platform.isIOS || Platform.isMacOS);
    final acc = apple
        ? wave1Text(
            context,
            ru: 'аккаунта Apple',
            en: 'your Apple Account',
            uk: 'облікового запису Apple',
            es: 'tu cuenta de Apple',
            pt: 'da sua conta Apple',
            ptBr: 'da sua conta Apple',
            fr: 'votre compte Apple',
            de: 'deinem Apple-Konto',
          )
        : wave1Text(
            context,
            ru: 'аккаунта Google Play',
            en: 'your Google Play account',
            uk: 'облікового запису Google Play',
            es: 'tu cuenta de Google Play',
            pt: 'da sua conta Google Play',
            ptBr: 'da sua conta Google Play',
            fr: 'votre compte Google Play',
            de: 'deinem Google-Play-Konto',
          );
    return wave1Text(
      context,
      ru:
          'Подписка продлевается автоматически. Оплата спишется с $acc при '
          'подтверждении покупки и далее автоматически перед началом каждого '
          'периода, если её не отменить минимум за 24 часа до окончания текущего '
          'срока. Управлять подпиской и отменять её можно в настройках аккаунта. '
          '«Навсегда» — разовый платёж без автопродления.',
      en:
          'Subscriptions renew automatically. Payment is charged to $acc at '
          'confirmation of purchase and automatically before the start of each '
          'period, unless canceled at least 24 hours before the end of the current '
          'term. Manage or cancel your subscription in your account settings. '
          'Lifetime is a one-time purchase with no renewal.',
      uk:
          'Підписка продовжується автоматично. Оплата спишеться з $acc під час '
          'підтвердження покупки й надалі автоматично перед початком кожного '
          'періоду, якщо її не скасувати щонайменше за 24 години до завершення '
          'поточного терміну. Керувати підпискою та скасовувати її можна в '
          'налаштуваннях облікового запису. «Назавжди» — разовий платіж без '
          'автопродовження.',
      es:
          'Las suscripciones se renuevan automáticamente. El cargo se realiza a '
          '$acc al confirmar la compra y, después, automáticamente antes del '
          'inicio de cada período, salvo que se cancele al menos 24 horas antes '
          'del final del período actual. Gestiona o cancela tu suscripción en los '
          'ajustes de tu cuenta. «Para siempre» es un pago único sin renovación.',
      pt:
          'As subscrições renovam-se automaticamente. O pagamento é cobrado $acc '
          'ao confirmar a compra e, depois, automaticamente antes do início de '
          'cada período, salvo se for cancelado pelo menos 24 horas antes do fim '
          'do período atual. Faça a gestão ou cancele a subscrição nas definições '
          'da conta. «Para sempre» é um pagamento único sem renovação.',
      ptBr:
          'As assinaturas são renovadas automaticamente. A cobrança é feita '
          '$acc ao confirmar a compra e, depois, automaticamente antes do início '
          'de cada período, a menos que seja cancelada pelo menos 24 horas antes '
          'do fim do período atual. Gerencie ou cancele sua assinatura nas '
          'configurações da conta. «Para sempre» é um pagamento único, sem '
          'renovação.',
      fr:
          'Les abonnements se renouvellent automatiquement. Le paiement est '
          'prélevé sur $acc à la confirmation de l’achat, puis automatiquement '
          'avant le début de chaque période, sauf annulation au moins 24 heures '
          'avant la fin de la période en cours. Gérez ou annulez votre abonnement '
          'dans les réglages de votre compte. « À vie » est un paiement unique '
          'sans renouvellement.',
      de:
          'Abonnements verlängern sich automatisch. Die Zahlung wird bei '
          'Kaufbestätigung von $acc abgebucht und danach automatisch vor Beginn '
          'jedes Zeitraums, sofern nicht mindestens 24 Stunden vor Ende des '
          'aktuellen Zeitraums gekündigt wird. Verwalte oder kündige dein '
          'Abonnement in den Kontoeinstellungen. „Für immer“ ist eine einmalige '
          'Zahlung ohne Verlängerung.',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Telegram-style premium canvas, theme-aware:
    //  • DARK  → the app's bluish accent over a near-black base (as before).
    //  • LIGHT → a vibrant PURPLE gradient with frosted-white cards.
    // Cosmic dust + glow read well on both.
    final appIsDark = Theme.of(context).brightness == Brightness.dark;
    const purpleSeed = Color(0xFF8B4DFF);
    final paneTheme = ThemeData(
      useMaterial3: true,
      brightness: appIsDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appIsDark
            ? Theme.of(context).colorScheme.primary
            : purpleSeed,
        brightness: appIsDark ? Brightness.dark : Brightness.light,
      ),
    );
    return Theme(
      data: paneTheme,
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF0C0D11) : const Color(0xFF8A46DA);
    // Text/icons that sit OVER the gradient (hero subtitle, disclosures, terms)
    // — white in BOTH themes (the canvas is dark navy or vibrant purple).
    final onCanvas = Colors.white.withValues(alpha: 0.92);
    final onCanvasDim = Colors.white.withValues(alpha: 0.72);

    return Scaffold(
      backgroundColor: base,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isDark
                    ? RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.15,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.20),
                          base,
                        ],
                        stops: const [0.0, 0.6],
                      )
                    : const LinearGradient(
                        // Vibrant purple → violet → magenta (the reference look).
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF7C5BF2),
                          Color(0xFFA64CE2),
                          Color(0xFFCF5FCB),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
              ),
            ),
          ),
          // Fixed full-screen cosmic dust — stays put while content scrolls and
          // sits BEHIND the top bar (no opaque panel covering it).
          const Positioned.fill(
            child: IgnorePointer(child: CosmicDustField(count: 140)),
          ),
          // Content scrolls full-height over the fixed dust — nothing is
          // reserved at the top, so no panel can cover it on scroll.
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              children: [
                _hero(context, theme),
                const SizedBox(height: 18),
                // Плашка ожидания стоит ВЫШЕ тарифов намеренно: если заказ уже
                // ждёт доплаты, человек должен узнать об этом ДО того, как
                // начнёт покупать во второй раз.
                if (widget.pendingPayment)
                  _pendingPaymentIsland(context, theme),
                ..._planCards(),
                const SizedBox(height: 18),
                _perksIsland(context, theme),
                const SizedBox(height: 14),
                Text(
                  _renewalDisclosure(context),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onCanvasDim,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: widget.onOpenTerms,
                      style: TextButton.styleFrom(foregroundColor: onCanvas),
                      child: Text(
                        wave1Text(
                          context,
                          ru: 'Условия',
                          en: 'Terms',
                          uk: 'Умови',
                          es: 'Términos',
                          pt: 'Termos',
                          ptBr: 'Termos',
                          fr: 'Conditions',
                          de: 'Bedingungen',
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onCanvasDim,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenPrivacy,
                      style: TextButton.styleFrom(foregroundColor: onCanvas),
                      child: Text(
                        wave1Text(
                          context,
                          ru: 'Конфиденциальность',
                          en: 'Privacy',
                          uk: 'Конфіденційність',
                          es: 'Privacidad',
                          pt: 'Privacidade',
                          ptBr: 'Privacidade',
                          fr: 'Confidentialité',
                          de: 'Datenschutz',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Floating controls — transparent (NOT a panel). Gaps pass touches
          // through, so the list scrolls under them.
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: wave1Text(
                        context,
                        ru: 'Закрыть',
                        en: 'Close',
                        uk: 'Закрити',
                        es: 'Cerrar',
                        pt: 'Fechar',
                        ptBr: 'Fechar',
                        fr: 'Fermer',
                        de: 'Schließen',
                      ),
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    PremiumGlassCard(
                      radius: 20,
                      opaqueLight: true,
                      onTap: _restoreInFlight ? null : _handleRestore,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Text(
                          wave1Text(
                            context,
                            ru: 'Восстановить',
                            en: 'Restore',
                            uk: 'Відновити',
                            es: 'Restaurar',
                            pt: 'Restaurar',
                            ptBr: 'Restaurar',
                            fr: 'Restaurer',
                            de: 'Wiederherstellen',
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, ThemeData theme) {
    // Cosmic dust is a fixed background layer (see _buildContent); the hero —
    // mark, wordmark and subtitle — scrolls normally over it.
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Column(
        children: [
          const _AnimatedHeroIcon(),
          const SizedBox(height: 18),
          ShimmerGoldText(
            'Secretly Premium',
            // Harmonious with the cosmic page: white with a faint periwinkle sheen
            // (matches the blue dust), not gold.
            colors: const [
              Color(0xFF9FB0FF),
              Colors.white,
              Colors.white,
              Colors.white,
              Color(0xFF9FB0FF),
            ],
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              _heroSubtitle(context),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                // Over the canvas → white in both themes (dark navy / purple).
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _planCards() {
    return [
      for (final s in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PlanRow(
            sku: s,
            highlighted: s.highlighted,
            onTap: () => _handlePurchase(s),
          ),
        ),
    ];
  }

  /// Тихая полоска «ожидаем оплату».
  ///
  /// 🔴 ГДЕ И ПОЧЕМУ ИМЕННО ТАК. Магазин умеет отложенную оплату — наличными в
  /// магазине, через оператора. Заказ создан, премиум правильно НЕ выдан, но
  /// раньше покупателю не говорили ничего: прод-заказ от 24.07.2026 так и висел
  /// неоплаченным, потому что человек не знал, что от него ждут.
  ///
  /// Не надоедает по построению: живёт ТОЛЬКО на этом экране — там, где человек
  /// сам ищет ответ про подписку, — а всплывающая подсказка полагается ровно
  /// один раз на заказ. Сама отметка истекает через неделю, поэтому полоска не
  /// может остаться навсегда.
  Widget _pendingPaymentIsland(BuildContext context, ThemeData theme) {
    final localeTag = wave1LocaleTagFromContext(context);
    final onGlass = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumGlassCard(
        radius: 22,
        opaqueLight: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: onGlass),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pendingPaymentTitle(localeTag),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onGlass,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pendingPaymentBody(localeTag),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onGlass.withValues(alpha: 0.72),
                        height: 1.35,
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

  Widget _perksIsland(BuildContext context, ThemeData theme) {
    return PremiumGlassCard(
      radius: 22,
      opaqueLight: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in _currentPerks(context))
              _FeatureRow(icon: p.$1, title: p.$2, subtitle: p.$3),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  wave1Text(
                    context,
                    ru: 'Скоро',
                    en: 'Coming soon',
                    uk: 'Незабаром',
                    es: 'Próximamente',
                    pt: 'Em breve',
                    ptBr: 'Em breve',
                    fr: 'Bientôt',
                    de: 'Demnächst',
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final p in _comingPerks(context))
              _FeatureRow(icon: p.$1, title: p.$2, dim: true),
          ],
        ),
      ),
    );
  }
}

/// The Secretly mark with a gentle "light 3D" idle animation: float, perspective
/// tilt and a pulsing brand glow halo. The icon drops straight into the hero.
class _AnimatedHeroIcon extends StatefulWidget {
  const _AnimatedHeroIcon();

  @override
  State<_AnimatedHeroIcon> createState() => _AnimatedHeroIconState();
}

class _AnimatedHeroIconState extends State<_AnimatedHeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final a = _c.value * 2 * math.pi;
        final float = math.sin(a) * 5.0;
        final tiltY = math.sin(a) * 0.13;
        final tiltX = math.cos(a * 0.8) * 0.07;
        final glow = 0.32 + 0.24 * (0.5 + 0.5 * math.sin(a));
        return Transform.translate(
          offset: Offset(0, float),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(tiltX)
              ..rotateY(tiltY),
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: glow),
                    blurRadius: 42,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(
                      0xFF8E5BFF,
                    ).withValues(alpha: glow * 0.6),
                    blurRadius: 60,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Image(
          image: AssetImage('assets/app_ui/icons/png/premium_logo.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.dim = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Feature icon plate: a clear VIOLET in light theme, the bluish accent in
    // dark — both with a white glyph.
    final accent = theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : const Color(0xFF7C3AED);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              // Telegram-style: a solid accent squircle (purple in light theme,
              // bluish in dark) with a WHITE glyph — prominent, not a faint tint.
              color: dim ? accent.withValues(alpha: 0.42) : accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dim
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plan card. Tapping it starts the purchase directly (no confirm button).
/// The best-value plan is [highlighted] with a brand-colour rim + glow.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.sku,
    required this.highlighted,
    required this.onTap,
  });

  final PaywallSku sku;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onVariant = theme.colorScheme.onSurfaceVariant;
    // Layout (Telegram-style, comparable per-month on every card):
    //   LEFT  — title + discount badge; for the YEARLY plan also the struck
    //           original next to the actual billed price; for LIFETIME the
    //           one-time note.
    //   RIGHT — the per-month figure (with currency + «в месяц») for the
    //           monthly & yearly plans so users can compare them at a glance,
    //           or the one-time price for lifetime — then the chevron.
    final bool isLifetime = sku.perMonthLabel == null && sku.subtitle != null;
    final bool hasBilledPriceLine = sku.originalPriceLabel != null; // yearly
    final String? trailingText = sku.perMonthLabel ?? (isLifetime ? sku.priceLabel : null);
    final bool trailingIsPerMonth = sku.perMonthLabel != null;
    return PremiumGlassCard(
      radius: 16,
      highlighted: highlighted,
      accentColor: accent,
      onTap: onTap,
      opaqueLight: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sku.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (sku.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            // Darker, more saturated accent so the WHITE «-37%»
                            // never blends into the card / lighter accent.
                            color: Color.alphaBlend(
                              Colors.black.withValues(alpha: 0.26),
                              accent,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sku.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // YEARLY: struck-through original next to the billed annual
                  // price. LIFETIME: the one-time note. MONTHLY: nothing (the
                  // per-month figure on the right is the price).
                  if (hasBilledPriceLine) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            sku.originalPriceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            sku.priceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isLifetime && sku.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      sku.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Natural width, right-aligned, single line — pins to the same right
            // edge on every card and never wraps (the left column gives way).
            if (trailingText != null)
              _trailingPrice(
                theme: theme,
                text: trailingText,
                isPerMonth: trailingIsPerMonth,
                accent: accent,
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: onVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Right-aligned, single-line price for a plan card's trailing slot. A per-month
/// figure ("2,99 $/мес") renders the price bold-accent with a lighter slash
/// period; a one-time price (lifetime) is bold onSurface. Kept to ONE line so
/// every card's price pins to the same right edge (no ragged "/в месяц" wrap).
Widget _trailingPrice({
  required ThemeData theme,
  required String text,
  required bool isPerMonth,
  required Color accent,
}) {
  final priceStyle = theme.textTheme.titleSmall?.copyWith(
    fontWeight: FontWeight.w800,
    height: 1.1,
  );
  if (!isPerMonth) {
    return Text(
      text,
      textAlign: TextAlign.end,
      maxLines: 1,
      style: priceStyle?.copyWith(color: theme.colorScheme.onSurface),
    );
  }
  final i = text.lastIndexOf('/');
  final price = i > 0 ? text.substring(0, i) : text;
  final period = i > 0 ? text.substring(i) : '';
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: price, style: priceStyle?.copyWith(color: accent)),
        if (period.isNotEmpty)
          TextSpan(
            text: period,
            style: priceStyle?.copyWith(
              color: accent.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
    textAlign: TextAlign.end,
    maxLines: 1,
  );
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = PremiumGlassCard(
      radius: 19,
      onTap: onTap,
      opaqueLight: true,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
