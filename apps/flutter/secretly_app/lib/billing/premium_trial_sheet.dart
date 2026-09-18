// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Premium trial teaser (TZ-MONETIZE-01 §C-4).
//
// A light, attractive "7 days free" announcement that leads to the full plan
// picker (PaywallScreen) — it does NOT itself charge or start a trial. The
// trial is a store-side intro offer attached to the subscription products; the
// user actually starts it by choosing a plan on the paywall. See
// docs/PREMIUM_TRIAL_SETUP.md for the App Store / Play configuration.
//
// Ethics (§C-4): always a visible close + «Не сейчас», honest pricing
// ("от 1,25 $/мес" — the cheapest plan's effective monthly), cancel-anytime
// line, no countdown timers, no gold. Shown
// ONLY when monetization is enabled AND the user is not already paid — never on
// first launch, capped and cooled-down (see maybeShowPremiumTrialAnnouncement).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../entitlements/entitlement_models.dart';
import '../ui/paywall_screen.dart';
import '../ui/wave1_l10n.dart';
import 'billing_service.dart';
import 'show_paywall.dart';

const String _kTrialFirstSeenMs = 'premium_trial_first_seen_ms';
const String _kTrialLastShownMs = 'premium_trial_last_shown_ms';
const String _kTrialShownCount = 'premium_trial_shown_count';

// Canonical legal URLs (must match show_paywall.dart + Settings/About).
const String _kTrialTermsUrl = 'https://www.secretlyapp.com/terms-of-service';
const String _kTrialPrivacyUrl = 'https://www.secretlyapp.com/privacy-policy';

Future<void> _openTrialUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {/* best-effort — legal links must never crash the teaser */}
}

/// How many times the auto-announcement may appear before we stop nagging.
const int kTrialAnnounceMaxShows = 4;

/// Quiet period after each auto-announcement (and after «Не сейчас»).
const Duration kTrialAnnounceCooldown = Duration(days: 5);

/// Auto-announcement entry point — safe to call on every app open. Shows the
/// teaser only when ALL hold: monetization on, not already paid, not the very
/// first launch, under the show cap, and past the cooldown. Records bookkeeping
/// and is a no-op otherwise. Never throws into the caller.
Future<void> maybeShowPremiumTrialAnnouncement(
  BuildContext context,
  AppController controller,
) async {
  try {
    final ent = controller.entitlementStateNow;
    // Fail-open / security stays free: nothing to upsell when monetization is
    // off, and never upsell someone who already paid. Crucially, also skip
    // anyone who has EVER had a subscription (lapsed subscribers look like
    // `free` again) — the auto-announcement is for never-subscribed users only.
    if (!ent.monetizationEnabled ||
        ent.tier.isPaid ||
        controller.everHadEntitlement) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Let people explore on their first ever launch — only stamp it now.
    final firstSeen = prefs.getInt(_kTrialFirstSeenMs);
    if (firstSeen == null) {
      await prefs.setInt(_kTrialFirstSeenMs, nowMs);
      return;
    }

    final count = prefs.getInt(_kTrialShownCount) ?? 0;
    if (count >= kTrialAnnounceMaxShows) return;

    final lastShown = prefs.getInt(_kTrialLastShownMs) ?? 0;
    if (nowMs - lastShown < kTrialAnnounceCooldown.inMilliseconds) return;

    await prefs.setInt(_kTrialLastShownMs, nowMs);
    await prefs.setInt(_kTrialShownCount, count + 1);
    // Make sure store prices are loaded so the teaser shows the REAL per-month
    // (in the user's currency), not the reference fallback. Best-effort.
    try {
      await BillingService.instance.loadProducts();
    } catch (_) {}
    if (!context.mounted) return;
    await showPremiumTrialSheet(context);
  } catch (_) {
    // Best-effort: an upsell must never break app launch.
  }
}

/// Shows the trial teaser as a centered dialog. «Попробовать бесплатно» closes
/// it and opens the full plan picker ([PaywallScreen]). Safe to call manually
/// (e.g. from the Settings → Premium row).
Future<void> showPremiumTrialSheet(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (ctx) => const _PremiumTrialCard(),
  );
}

class _PremiumTrialCard extends StatelessWidget {
  const _PremiumTrialCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final card = cs.surface;

    return Dialog(
      backgroundColor: card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Close.
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              // Logo (our app mark — not a crown).
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: accent.withValues(alpha: 0.12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/app_ui/icons/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.bolt_rounded, color: accent, size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'SECRETLY PREMIUM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kFreeTrialEnabled
                    ? wave1Text(
                        context,
                        ru: '7 дней бесплатно',
                        en: '7 days free',
                        uk: '7 днів безкоштовно',
                        es: '7 días gratis',
                        pt: '7 dias grátis',
                        ptBr: '7 dias grátis',
                        fr: '7 jours gratuits',
                        de: '7 Tage gratis',
                      )
                    : wave1Text(
                        context,
                        ru: 'Всё без ограничений',
                        en: 'Everything unlocked',
                        uk: 'Усе без обмежень',
                        es: 'Todo sin límites',
                        pt: 'Tudo sem limites',
                        ptBr: 'Tudo sem limites',
                        fr: 'Tout sans limites',
                        de: 'Alles ohne Limits',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                wave1Text(
                  context,
                  ru: 'Полный Secretly без ограничений.\nНи рекламы, ни компромиссов.',
                  en: 'The full Secretly, no limits.\nNo ads, no compromises.',
                  uk: 'Повний Secretly без обмежень.\nЖодної реклами, жодних компромісів.',
                  es: 'Secretly completo, sin límites.\nSin anuncios, sin concesiones.',
                  pt: 'O Secretly completo, sem limites.\nSem anúncios, sem concessões.',
                  ptBr:
                      'O Secretly completo, sem limites.\nSem anúncios, sem concessões.',
                  fr: 'Tout Secretly, sans limites.\nSans publicité, sans compromis.',
                  de: 'Das volle Secretly, ohne Limits.\nKeine Werbung, keine Kompromisse.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              // Benefits — the strongest features, then "and much more".
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _benefit(
                      context,
                      Icons.folder_rounded,
                      accent,
                      ru: 'Файлы до 1 ГБ',
                      en: 'Files up to 1 GB',
                    ),
                    _benefit(
                      context,
                      Icons.groups_rounded,
                      accent,
                      ru: 'Группы до 500 и звонки до 50',
                      en: 'Groups up to 500, calls up to 50',
                    ),
                    _benefit(
                      context,
                      Icons.graphic_eq_rounded,
                      accent,
                      ru: 'ИИ: голосовые в текст и аудиофункции',
                      en: 'AI voice-to-text and audio tools',
                    ),
                    _benefit(
                      context,
                      Icons.palette_rounded,
                      accent,
                      ru: 'Персонализация профиля и авторские эмодзи',
                      en: 'Profile personalization and custom emoji',
                    ),
                    _benefit(
                      context,
                      Icons.verified_user_rounded,
                      accent,
                      ru: 'Без рекламы и трекеров + свой Secretly ID',
                      en: 'No ads or trackers + custom Secretly ID',
                    ),
                    _benefit(
                      context,
                      Icons.auto_awesome_rounded,
                      accent,
                      ru: 'И многое другое',
                      en: 'And much more',
                      emphasised: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Honest pricing — real localized prices live on the plan picker.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: kFreeTrialEnabled
                          ? wave1Text(
                              context,
                              ru: 'Сегодня бесплатно',
                              en: 'Free today',
                              uk: 'Сьогодні безкоштовно',
                              es: 'Hoy gratis',
                              pt: 'Hoje grátis',
                              ptBr: 'Hoje grátis',
                              fr: 'Gratuit aujourd’hui',
                              de: 'Heute gratis',
                            )
                          : wave1Text(
                              context,
                              ru: 'Премиум',
                              en: 'Premium',
                              uk: 'Преміум',
                              es: 'Premium',
                              pt: 'Premium',
                              ptBr: 'Premium',
                              fr: 'Premium',
                              de: 'Premium',
                            ),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    TextSpan(
                      // Real store per-month (e.g. "далее от 82 ₴ в месяц") when
                      // products are loaded; reference fallback otherwise. Never
                      // a hardcoded "$1.25/mo" in the wrong currency.
                      text: () {
                        final lowest = BillingService.instance.lowestPerMonthLabel(
                          localeTag: wave1LocaleTagFromContext(context),
                        );
                        if (lowest != null) {
                          final prefix = kFreeTrialEnabled
                              ? wave1Text(context, ru: '  ·  далее от ', en: '  ·  then from ', uk: '  ·  далі від ', es: '  ·  luego desde ', pt: '  ·  depois a partir de ', ptBr: '  ·  depois a partir de ', fr: '  ·  puis à partir de ', de: '  ·  danach ab ')
                              : wave1Text(context, ru: '  ·  от ', en: '  ·  from ', uk: '  ·  від ', es: '  ·  desde ', pt: '  ·  a partir de ', ptBr: '  ·  a partir de ', fr: '  ·  à partir de ', de: '  ·  ab ');
                          return '$prefix$lowest';
                        }
                        return wave1Text(
                          context,
                          ru: '  ·  далее от 1,25 \$/мес',
                          en: r'  ·  then from $1.25/mo',
                          uk: '  ·  далі від 1,25 \$/міс',
                          es: r'  ·  luego desde $1.25/mes',
                          pt: r'  ·  depois a partir de $1.25/mês',
                          ptBr: r'  ·  depois a partir de $1.25/mês',
                          fr: '  ·  puis à partir de 1,25 \$/mois',
                          de: '  ·  danach ab 1,25 \$/Mon.',
                        );
                      }(),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                wave1Text(
                  context,
                  ru: 'Отмена в любой момент в App Store / Google Play',
                  en: 'Cancel anytime in App Store / Google Play',
                  uk: 'Скасування будь-коли в App Store / Google Play',
                  es: 'Cancela cuando quieras en App Store / Google Play',
                  pt: 'Cancele quando quiser na App Store / Google Play',
                  ptBr: 'Cancele quando quiser na App Store / Google Play',
                  fr: 'Annulez à tout moment dans l’App Store / Google Play',
                  de: 'Jederzeit kündbar im App Store / Google Play',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              // Primary CTA → the full plan picker (3 plans), where the trial
              // actually starts on the chosen subscription.
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: cs.onPrimary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).maybePop();
                  showPaywall(context, PaywallTrigger.general);
                },
                child: Text(
                  kFreeTrialEnabled
                      ? wave1Text(
                          context,
                          ru: 'Попробовать бесплатно',
                          en: 'Try for free',
                          uk: 'Спробувати безкоштовно',
                          es: 'Probar gratis',
                          pt: 'Experimentar grátis',
                          ptBr: 'Experimentar grátis',
                          fr: 'Essayer gratuitement',
                          de: 'Kostenlos testen',
                        )
                      : wave1Text(
                          context,
                          ru: 'Оформить Премиум',
                          en: 'Get Premium',
                          uk: 'Оформити Преміум',
                          es: 'Obtener Premium',
                          pt: 'Obter Premium',
                          ptBr: 'Assinar Premium',
                          fr: 'Passer à Premium',
                          de: 'Premium holen',
                        ),
                ),
              ),
              // Trial-only reminder — hidden when the trial is off (nothing to
              // remind about; the price is charged immediately on purchase).
              if (kFreeTrialEnabled) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        wave1Text(
                          context,
                          ru: 'Напомним заранее перед окончанием пробного периода',
                          en: 'We’ll remind you before the trial ends',
                          uk: 'Нагадаємо заздалегідь перед завершенням пробного періоду',
                          es: 'Te avisaremos antes de que termine la prueba',
                          pt: 'Avisaremos antes de a avaliação terminar',
                          ptBr: 'Avisaremos antes de o teste terminar',
                          fr: 'Nous vous préviendrons avant la fin de l’essai',
                          de: 'Wir erinnern dich vor Ablauf der Testphase',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Divider(color: cs.onSurface.withValues(alpha: 0.08), height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => BillingService.instance.restore(),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Восстановить покупки',
                        en: 'Restore purchases',
                        uk: 'Відновити покупки',
                        es: 'Restaurar compras',
                        pt: 'Restaurar compras',
                        ptBr: 'Restaurar compras',
                        fr: 'Restaurer les achats',
                        de: 'Käufe wiederherstellen',
                      ),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  Text('·', style: TextStyle(color: cs.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Не сейчас',
                        en: 'Not now',
                        uk: 'Не зараз',
                        es: 'Ahora no',
                        pt: 'Agora não',
                        ptBr: 'Agora não',
                        fr: 'Plus tard',
                        de: 'Nicht jetzt',
                      ),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              // App Store requirement (Guideline 3.1.2(c)): every subscription
              // purchase surface must carry functional Terms of Use (EULA) +
              // Privacy Policy links. The full paywall has them too; this teaser
              // can be shown standalone, so it must as well.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _openTrialUrl(_kTrialTermsUrl),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Условия использования',
                        en: 'Terms of Use',
                        uk: 'Умови використання',
                        es: 'Términos de uso',
                        pt: 'Termos de uso',
                        ptBr: 'Termos de uso',
                        fr: "Conditions d'utilisation",
                        de: 'Nutzungsbedingungen',
                      ),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text('·', style: TextStyle(color: cs.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => _openTrialUrl(_kTrialPrivacyUrl),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Политика конфиденциальности',
                        en: 'Privacy Policy',
                        uk: 'Політика конфіденційності',
                        es: 'Privacidad',
                        pt: 'Privacidade',
                        ptBr: 'Privacidade',
                        fr: 'Confidentialité',
                        de: 'Datenschutz',
                      ),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(
    BuildContext context,
    IconData icon,
    Color accent, {
    required String ru,
    required String en,
    bool emphasised = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              wave1Text(context, ru: ru, en: en),
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                color: emphasised ? accent : cs.onSurface,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
