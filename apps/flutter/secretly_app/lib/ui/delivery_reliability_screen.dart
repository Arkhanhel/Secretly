// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../reliability/delivery_reliability_service.dart';
import 'motion/press_feedback.dart';
import 'settings_group.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:secretly_app/ui/apple_glass.dart';
import 'package:secretly_app/ui/apple_settings_row.dart';

/// DELIVERY RELIABILITY SCREEN (2026-07-16, delivery-wake audit).
///
/// Shows the OS-level switches that silently break message delivery and deep
/// links the user straight to the right settings page. This is the class of
/// problems no server or app code can fix — battery optimization, Data Saver,
/// disabled notifications, OEM autostart killers (MIUI/Samsung/...), iOS
/// Background App Refresh / Low Power Mode — the industry-standard answer is
/// to surface them in-app (WhatsApp's battery prompt, Telegram's "background
/// activity restricted" warning); this screen is our equivalent.
///
/// Read-only + user-driven: the app never toggles anything itself. Statuses
/// re-check automatically when the user comes back from system settings
/// (lifecycle resume).
class DeliveryReliabilityScreen extends StatefulWidget {
  const DeliveryReliabilityScreen({
    super.key,
    this.service,
    this.healthLoader,
    this.connectionSection,
  });

  /// Injectable for tests; defaults to the real platform channels.
  final DeliveryReliabilityService? service;

  /// Supplies `AppDb.deliveryHealthCounters()`. Optional so the screen still
  /// renders (without the health block) in tests and on the settings route
  /// before the controller is ready.
  final Future<Map<String, int>> Function()? healthLoader;

  /// Переключатель «Фоновое соединение» (перенесён из «Уведомлений» по
  /// макету владельца, 11.2026). Его хранение живёт в экране настроек,
  /// поэтому сюда он приходит готовым; с баннера доставки — не передаётся.
  final Widget? connectionSection;

  @override
  State<DeliveryReliabilityScreen> createState() =>
      _DeliveryReliabilityScreenState();
}

class _DeliveryReliabilityScreenState extends State<DeliveryReliabilityScreen>
    with WidgetsBindingObserver {
  late final DeliveryReliabilityService _service =
      widget.service ?? DeliveryReliabilityService();

  DeliveryReliabilityStatus? _status;
  Map<String, int>? _health;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user typically leaves for the system settings page we deep-linked
    // to and comes right back — re-check so the row flips to green instantly.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final status = await _service.getStatus();
    Map<String, int>? health;
    final loader = widget.healthLoader;
    if (loader != null) {
      try {
        health = await loader();
      } catch (_) {
        health = null; // diagnostics must never fail the screen
      }
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _health = health;
      _loading = false;
    });
  }

  Widget _buildHealthCard(BuildContext context, Map<String, int> h) {
    final stuck = h['quarantined'] ?? 0;
    final reported = h['nacked'] ?? 0;
    final receipts = h['receipts_queued'] ?? 0;
    final outbox = h['outbox_pending'] ?? 0;
    // Undecryptable wires the sender has NOT been told about are the state
    // that used to stall forever without anyone noticing.
    final unreported = stuck - reported;
    final healthy = stuck == 0 && outbox == 0;
    final scheme = Theme.of(context).colorScheme;
    return _InfoCard(
      icon: healthy
          ? AdaptiveIcons.verified_rounded
          : (unreported > 0
                ? AdaptiveIcons.error_outline_rounded
                : AdaptiveIcons.autorenew_rounded),
      color: healthy
          ? scheme.primary
          : (unreported > 0 ? scheme.error : scheme.tertiary),
      title: _rl(
        context,
        ru: 'Состояние доставки',
        uk: 'Стан доставки',
        en: 'Delivery health',
        es: 'Estado de entrega',
        pt: 'Estado da entrega',
        ptBr: 'Estado da entrega',
        fr: 'État de la livraison',
        de: 'Zustellungsstatus',
      ),
      body: healthy
          ? _rl(
              context,
              ru: 'Всё доставлено, ничего не застряло.',
              uk: 'Усе доставлено, нічого не застрягло.',
              en: 'Everything delivered, nothing stuck.',
              es: 'Todo entregado, nada atascado.',
              pt: 'Tudo entregue, nada preso.',
              ptBr: 'Tudo entregue, nada preso.',
              fr: 'Tout est livré, rien de bloqué.',
              de: 'Alles zugestellt, nichts hängt fest.',
            )
          : _rl(
              context,
              ru: 'Не удалось прочитать: $stuck (сообщено отправителю: $reported)\n'
                  'Квитанции в очереди: $receipts\n'
                  'Ждут отправки: $outbox',
              uk: 'Не вдалося прочитати: $stuck (повідомлено відправнику: $reported)\n'
                  'Квитанції в черзі: $receipts\n'
                  'Чекають надсилання: $outbox',
              en: 'Unreadable: $stuck (sender told: $reported)\n'
                  'Receipts queued: $receipts\n'
                  'Waiting to send: $outbox',
              es: 'Ilegibles: $stuck (remitente avisado: $reported)\n'
                  'Recibos en cola: $receipts\n'
                  'Pendientes de envío: $outbox',
              pt: 'Ilegíveis: $stuck (remetente avisado: $reported)\n'
                  'Recibos na fila: $receipts\n'
                  'Aguardando envio: $outbox',
              ptBr: 'Ilegíveis: $stuck (remetente avisado: $reported)\n'
                  'Recibos na fila: $receipts\n'
                  'Aguardando envio: $outbox',
              fr: 'Illisibles: $stuck (expéditeur averti: $reported)\n'
                  'Accusés en attente: $receipts\n'
                  'En attente d’envoi: $outbox',
              de: 'Unlesbar: $stuck (Absender informiert: $reported)\n'
                  'Quittungen in Warteschlange: $receipts\n'
                  'Wartet auf Versand: $outbox',
            ),
    );
  }

  Future<void> _act(Future<bool> Function() action) async {
    await action();
    // Some actions (battery dialog) resolve without a lifecycle change —
    // schedule a short delayed re-check as well.
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;
    final status = _status;
    final l10n = AppLocalizations.of(context);

    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          _rl(
            context,
            ru: 'Надёжность доставки',
            uk: 'Надійність доставлення',
            en: 'Delivery reliability',
            es: 'Fiabilidad de entrega',
            pt: 'Fiabilidade de entrega',
            ptBr: 'Confiabilidade de entrega',
            fr: 'Fiabilité de livraison',
            de: 'Zustellsicherheit',
          ),
        ),
        actions: [
          PressFeedback(child: IconButton(
            tooltip: _rl(
              context,
              ru: 'Проверить снова',
              uk: 'Перевірити знову',
              en: 'Re-check',
              es: 'Volver a comprobar',
              pt: 'Verificar novamente',
              ptBr: 'Verificar novamente',
              fr: 'Revérifier',
              de: 'Erneut prüfen',
            ),
            onPressed: _refresh,
            icon: const Icon(AdaptiveIcons.refresh_rounded),
          )),
        ],
      ),
      body: settingsAndroidPanels
          ? _buildAndroidList(context, status, l10n, topPad, bottomPad)
          : ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: [
          // Без локализаций (тесты, ранний старт) вступления просто нет.
          if (l10n != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SettingsPageIntro(
              icon: const Icon(
                AdaptiveIcons.network_check_rounded,
                color: Color(0xFF35B86B),
                size: 28,
              ),
              color: const Color(0xFF35B86B),
              text: l10n.settingsIntroReliability,
              inset: 4,
            ),
          ),
          // Delivery health. Shown above the OS-permission rows because it
          // answers a different question: not "can the system wake us" but
          // "is anything actually stuck right now". Quarantined wires with
          // nothing reported to the sender is the silent-stall signature.
          if (!_loading && _health != null && _health!.isNotEmpty) ...[
            _buildHealthCard(context, _health!),
            const SizedBox(height: 14),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: SecretlySpinner()),
            )
          else if (status == null)
            _InfoCard(
              icon: AdaptiveIcons.desktop_windows_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: _rl(
                context,
                ru: 'Здесь всё просто',
                uk: 'Тут усе просто',
                en: 'Nothing to tune here',
                es: 'Nada que ajustar aquí',
                pt: 'Nada para ajustar aqui',
                ptBr: 'Nada para ajustar aqui',
                fr: 'Rien à régler ici',
                de: 'Hier gibt es nichts einzustellen',
              ),
              body: _rl(
                context,
                ru: 'На этой платформе система не ограничивает доставку сообщений в фоне.',
                uk: 'На цій платформі система не обмежує доставлення повідомлень у фоні.',
                en: 'On this platform the OS does not restrict background message delivery.',
                es: 'En esta plataforma el sistema no restringe la entrega de mensajes en segundo plano.',
                pt: 'Nesta plataforma o sistema não restringe a entrega de mensagens em segundo plano.',
                ptBr: 'Nesta plataforma o sistema não restringe a entrega de mensagens em segundo plano.',
                fr: 'Sur cette plateforme le système ne limite pas la livraison des messages en arrière-plan.',
                de: 'Auf dieser Plattform schränkt das System die Zustellung im Hintergrund nicht ein.',
              ),
            )
          else ...[
            _SummaryCard(status: status),
            const SizedBox(height: 14),
            ..._rowsFor(context, status),
            const SizedBox(height: 20),
            Text(
              _rl(
                context,
                ru: 'Эти переключатели живут в настройках системы — приложение не может менять их само, только показать дорогу.',
                uk: 'Ці перемикачі живуть у налаштуваннях системи — застосунок не може змінювати їх сам, лише показати шлях.',
                en: 'These switches live in system settings — the app cannot flip them itself, only take you there.',
                es: 'Estos ajustes viven en la configuración del sistema: la app no puede cambiarlos, solo llevarte allí.',
                pt: 'Estes ajustes vivem nas definições do sistema — a app não pode alterá-los, apenas levar-te até lá.',
                ptBr: 'Esses ajustes ficam nas configurações do sistema — o app não pode alterá-los, apenas levar você até lá.',
                fr: 'Ces réglages vivent dans les paramètres du système — l’app ne peut pas les changer, seulement vous y conduire.',
                de: 'Diese Schalter liegen in den Systemeinstellungen — die App kann sie nicht selbst umlegen, nur dorthin führen.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (widget.connectionSection != null) ...[
            SettingsGroupHeader(
              l10n?.settingsGroupConnection ?? 'Connection',
              inset: 16,
            ),
            widget.connectionSection!,
          ],
        ],
      ),
    ),
    );
  }

  /// Android (23.11.2026, владелец: «доделай все категории, половина на
  /// старом стиле»): состояние и проверки — строками двух групп (значок
  /// цвета состояния, название, серое пояснение, состояние справа) вместо
  /// отдельных карточек с плашками. Сведения и действия те же.
  Widget _buildAndroidList(
    BuildContext context,
    DeliveryReliabilityStatus? status,
    AppLocalizations? l10n,
    double topPad,
    double bottomPad,
  ) {
    final showHealth = !_loading && _health != null && _health!.isNotEmpty;
    return ListView(
      padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
      children: [
        if (l10n != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SettingsPageIntro(
              icon: const Icon(
                AdaptiveIcons.network_check_rounded,
                color: Color(0xFF35B86B),
                size: 28,
              ),
              color: const Color(0xFF35B86B),
              text: l10n.settingsIntroReliability,
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: SecretlySpinner()),
          )
        else if (status == null) ...[
          if (showHealth) ...[
            settingsRowsGroup([_buildHealthCard(context, _health!)]),
            const SizedBox(height: 12),
          ],
          settingsRowsGroup([
            _InfoCard(
              icon: AdaptiveIcons.desktop_windows_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: _rl(
                context,
                ru: 'Здесь всё просто',
                uk: 'Тут усе просто',
                en: 'Nothing to tune here',
                es: 'Nada que ajustar aquí',
                pt: 'Nada para ajustar aqui',
                ptBr: 'Nada para ajustar aqui',
                fr: 'Rien à régler ici',
                de: 'Hier gibt es nichts einzustellen',
              ),
              body: _rl(
                context,
                ru: 'На этой платформе система не ограничивает доставку сообщений в фоне.',
                uk: 'На цій платформі система не обмежує доставлення повідомлень у фоні.',
                en: 'On this platform the OS does not restrict background message delivery.',
                es: 'En esta plataforma el sistema no restringe la entrega de mensajes en segundo plano.',
                pt: 'Nesta plataforma o sistema não restringe a entrega de mensagens em segundo plano.',
                ptBr: 'Nesta plataforma o sistema não restringe a entrega de mensagens em segundo plano.',
                fr: 'Sur cette plateforme le système ne limite pas la livraison des messages en arrière-plan.',
                de: 'Auf dieser Plattform schränkt das System die Zustellung im Hintergrund nicht ein.',
              ),
            ),
          ]),
        ] else ...[
          // Сводка и «Состояние доставки» — одна группа.
          settingsRowsGroup([
            _SummaryCard(status: status),
            if (showHealth) _buildHealthCard(context, _health!),
          ]),
          const SizedBox(height: 12),
          settingsRowsGroup(_rowsFor(context, status, spaced: false)),
          SettingsGroupCaption(
            _rl(
              context,
              ru: 'Эти переключатели живут в настройках системы — приложение не может менять их само, только показать дорогу.',
              uk: 'Ці перемикачі живуть у налаштуваннях системи — застосунок не може змінювати їх сам, лише показати шлях.',
              en: 'These switches live in system settings — the app cannot flip them itself, only take you there.',
              es: 'Estos ajustes viven en la configuración del sistema: la app no puede cambiarlos, solo llevarte allí.',
              pt: 'Estes ajustes vivem nas definições do sistema — a app não pode alterá-los, apenas levar-te até lá.',
              ptBr: 'Esses ajustes ficam nas configurações do sistema — o app não pode alterá-los, apenas levar você até lá.',
              fr: 'Ces réglages vivent dans les paramètres du système — l’app ne peut pas les changer, seulement vous y conduire.',
              de: 'Diese Schalter liegen in den Systemeinstellungen — die App kann sie nicht selbst umlegen, nur dorthin führen.',
            ),
          ),
        ],
        if (widget.connectionSection != null) ...[
          SettingsGroupHeader(l10n?.settingsGroupConnection ?? 'Connection'),
          widget.connectionSection!,
        ],
      ],
    );
  }

  List<Widget> _rowsFor(
    BuildContext context,
    DeliveryReliabilityStatus status, {
    bool spaced = true,
  }) {
    final rows = <Widget>[];

    // Notifications — both platforms.
    rows.add(
      _ReliabilityRow(
        icon: AdaptiveIcons.notifications_active_rounded,
        title: _rl(
          context,
          ru: 'Уведомления',
          uk: 'Сповіщення',
          en: 'Notifications',
          es: 'Notificaciones',
          pt: 'Notificações',
          ptBr: 'Notificações',
          fr: 'Notifications',
          de: 'Benachrichtigungen',
        ),
        ok: status.notificationsEnabled != false,
        okLabel: _rl(
          context,
          ru: 'Включены',
          uk: 'Увімкнені',
          en: 'Enabled',
          es: 'Activadas',
          pt: 'Ativadas',
          ptBr: 'Ativadas',
          fr: 'Activées',
          de: 'Aktiviert',
        ),
        warnLabel: _rl(
          context,
          ru: 'Выключены',
          uk: 'Вимкнені',
          en: 'Disabled',
          es: 'Desactivadas',
          pt: 'Desativadas',
          ptBr: 'Desativadas',
          fr: 'Désactivées',
          de: 'Deaktiviert',
        ),
        description: status.notificationsEnabled != false
            ? _rl(
                context,
                ru: 'Баннеры о новых сообщениях показываются.',
                uk: 'Банери про нові повідомлення показуються.',
                en: 'New-message banners are shown.',
                es: 'Se muestran los avisos de mensajes nuevos.',
                pt: 'Os avisos de novas mensagens são mostrados.',
                ptBr: 'Os avisos de novas mensagens são mostrados.',
                fr: 'Les bannières de nouveaux messages s’affichent.',
                de: 'Banner für neue Nachrichten werden angezeigt.',
              )
            : _rl(
                context,
                ru: 'Система блокирует все уведомления Secretly — вы не увидите новых сообщений, пока не откроете приложение.',
                uk: 'Система блокує всі сповіщення Secretly — ви не побачите нових повідомлень, доки не відкриєте застосунок.',
                en: 'The OS blocks all Secretly notifications — you will not see new messages until you open the app.',
                es: 'El sistema bloquea todas las notificaciones de Secretly: no verás mensajes nuevos hasta abrir la app.',
                pt: 'O sistema bloqueia todas as notificações do Secretly — não verás novas mensagens até abrires a app.',
                ptBr: 'O sistema bloqueia todas as notificações do Secretly — você não verá novas mensagens até abrir o app.',
                fr: 'Le système bloque toutes les notifications de Secretly — vous ne verrez pas les nouveaux messages avant d’ouvrir l’app.',
                de: 'Das System blockiert alle Secretly-Benachrichtigungen — neue Nachrichten sehen Sie erst beim Öffnen der App.',
              ),
        onFix: status.notificationsEnabled != false
            ? null
            : () => _act(
                status.isAndroid
                    ? _service.openNotificationSettings
                    : _service.openAppSettings,
              ),
        fixLabel: _fixLabel(context),
      ),
    );

    if (status.isAndroid) {
      // Battery optimization.
      rows.add(
        _ReliabilityRow(
          icon: AdaptiveIcons.battery_charging_full_rounded,
          title: _rl(
            context,
            ru: 'Батарея',
            uk: 'Батарея',
            en: 'Battery',
            es: 'Batería',
            pt: 'Bateria',
            ptBr: 'Bateria',
            fr: 'Batterie',
            de: 'Akku',
          ),
          ok: status.batteryUnrestricted != false,
          okLabel: _rl(
            context,
            ru: 'Без ограничений',
            uk: 'Без обмежень',
            en: 'Unrestricted',
            es: 'Sin restricciones',
            pt: 'Sem restrições',
            ptBr: 'Sem restrições',
            fr: 'Sans restrictions',
            de: 'Ohne Einschränkungen',
          ),
          warnLabel: _rl(
            context,
            ru: 'Оптимизируется',
            uk: 'Оптимізується',
            en: 'Optimized',
            es: 'Optimizada',
            pt: 'Otimizada',
            ptBr: 'Otimizada',
            fr: 'Optimisée',
            de: 'Optimiert',
          ),
          description: status.batteryUnrestricted != false
              ? _rl(
                  context,
                  ru: 'Система не усыпляет Secretly — пуши будят приложение вовремя.',
                  uk: 'Система не присипляє Secretly — пуші будять застосунок вчасно.',
                  en: 'The OS does not put Secretly to sleep — pushes wake the app on time.',
                  es: 'El sistema no duerme a Secretly: las notificaciones despiertan la app a tiempo.',
                  pt: 'O sistema não adormece o Secretly — as notificações acordam a app a tempo.',
                  ptBr: 'O sistema não adormece o Secretly — as notificações acordam o app a tempo.',
                  fr: 'Le système n’endort pas Secretly — les notifications réveillent l’app à temps.',
                  de: 'Das System legt Secretly nicht schlafen — Pushes wecken die App rechtzeitig.',
                )
              : _rl(
                  context,
                  ru: 'В глубоком сне система может замораживать Secretly, и сообщения будут приходить с опозданием. Разрешите работу без ограничений.',
                  uk: 'У глибокому сні система може заморожувати Secretly, і повідомлення надходитимуть із запізненням. Дозвольте роботу без обмежень.',
                  en: 'In deep sleep the OS may freeze Secretly and messages will arrive late. Allow unrestricted background use.',
                  es: 'En reposo profundo el sistema puede congelar Secretly y los mensajes llegarán tarde. Permite el uso sin restricciones.',
                  pt: 'Em suspensão profunda o sistema pode congelar o Secretly e as mensagens chegarão atrasadas. Permite o uso sem restrições.',
                  ptBr: 'Em suspensão profunda o sistema pode congelar o Secretly e as mensagens chegarão atrasadas. Permita o uso sem restrições.',
                  fr: 'En veille profonde le système peut geler Secretly et les messages arriveront en retard. Autorisez l’usage sans restrictions.',
                  de: 'Im Tiefschlaf kann das System Secretly einfrieren, Nachrichten kommen verspätet an. Erlauben Sie die uneingeschränkte Nutzung.',
                ),
          onFix: status.batteryUnrestricted != false
              ? null
              : () => _act(_service.requestBatteryExemption),
          fixLabel: _fixLabel(context),
        ),
      );

      // Data Saver / background data.
      final dataBlocked = status.dataSaver == 'enabled';
      rows.add(
        _ReliabilityRow(
          icon: AdaptiveIcons.data_saver_on_rounded,
          title: _rl(
            context,
            ru: 'Фоновые данные',
            uk: 'Фонові дані',
            en: 'Background data',
            es: 'Datos en segundo plano',
            pt: 'Dados em segundo plano',
            ptBr: 'Dados em segundo plano',
            fr: 'Données en arrière-plan',
            de: 'Hintergrunddaten',
          ),
          ok: !dataBlocked,
          okLabel: _rl(
            context,
            ru: 'Разрешены',
            uk: 'Дозволені',
            en: 'Allowed',
            es: 'Permitidos',
            pt: 'Permitidos',
            ptBr: 'Permitidos',
            fr: 'Autorisées',
            de: 'Erlaubt',
          ),
          warnLabel: _rl(
            context,
            ru: 'Заблокированы',
            uk: 'Заблоковані',
            en: 'Blocked',
            es: 'Bloqueados',
            pt: 'Bloqueados',
            ptBr: 'Bloqueados',
            fr: 'Bloquées',
            de: 'Blockiert',
          ),
          description: !dataBlocked
              ? _rl(
                  context,
                  ru: 'Secretly может забирать сообщения в фоне на мобильном интернете.',
                  uk: 'Secretly може забирати повідомлення у фоні на мобільному інтернеті.',
                  en: 'Secretly can fetch messages in the background on mobile data.',
                  es: 'Secretly puede recibir mensajes en segundo plano con datos móviles.',
                  pt: 'O Secretly pode receber mensagens em segundo plano com dados móveis.',
                  ptBr: 'O Secretly pode receber mensagens em segundo plano com dados móveis.',
                  fr: 'Secretly peut récupérer les messages en arrière-plan via les données mobiles.',
                  de: 'Secretly kann Nachrichten im Hintergrund über mobile Daten abrufen.',
                )
              : _rl(
                  context,
                  ru: 'Включён «Экономия трафика», и Secretly не в списке исключений: на мобильном интернете сообщения не загрузятся, пока вы не откроете приложение.',
                  uk: 'Увімкнено «Заощадження трафіку», і Secretly не у винятках: на мобільному інтернеті повідомлення не завантажаться, доки ви не відкриєте застосунок.',
                  en: 'Data Saver is on and Secretly is not exempted: on mobile data messages will not load until you open the app.',
                  es: 'El ahorro de datos está activado y Secretly no está exento: con datos móviles los mensajes no cargarán hasta abrir la app.',
                  pt: 'A poupança de dados está ativa e o Secretly não está isento: com dados móveis as mensagens não carregam até abrires a app.',
                  ptBr: 'A economia de dados está ativa e o Secretly não está isento: com dados móveis as mensagens não carregam até você abrir o app.',
                  fr: 'L’économiseur de données est actif et Secretly n’est pas exempté : en données mobiles les messages ne chargeront pas avant l’ouverture de l’app.',
                  de: 'Der Datensparmodus ist aktiv und Secretly nicht ausgenommen: über mobile Daten laden Nachrichten erst beim Öffnen der App.',
                ),
          onFix: dataBlocked
              ? () => _act(_service.openDataUsageSettings)
              : null,
          fixLabel: _fixLabel(context),
        ),
      );

      // OEM autostart advisory — status is unknowable, so it is neutral.
      if (status.showAutostartAdvisory) {
        rows.add(
          _ReliabilityRow(
            icon: AdaptiveIcons.rocket_launch_rounded,
            title: _rl(
              context,
              ru: 'Автозапуск',
              uk: 'Автозапуск',
              en: 'Autostart',
              es: 'Inicio automático',
              pt: 'Início automático',
              ptBr: 'Início automático',
              fr: 'Démarrage automatique',
              de: 'Autostart',
            ),
            ok: null,
            okLabel: '',
            warnLabel: _rl(
              context,
              ru: 'Проверьте вручную',
              uk: 'Перевірте вручну',
              en: 'Check manually',
              es: 'Comprobar a mano',
              pt: 'Verificar manualmente',
              ptBr: 'Verificar manualmente',
              fr: 'Vérifier manuellement',
              de: 'Manuell prüfen',
            ),
            description: _rl(
              context,
              ru: 'На этой прошивке система может полностью останавливать приложения. Убедитесь, что Secretly разрешён автозапуск / не находится в «спящих» — иначе пуши не доходят вовсе.',
              uk: 'На цій прошивці система може повністю зупиняти застосунки. Переконайтеся, що Secretly дозволено автозапуск / він не серед «сплячих» — інакше пуші не доходять узагалі.',
              en: 'This firmware can force-stop apps entirely. Make sure Secretly is allowed to auto-start / is not among “sleeping apps” — otherwise pushes never arrive.',
              es: 'Este firmware puede detener apps por completo. Asegúrate de que Secretly tenga inicio automático y no esté entre las apps dormidas; si no, las notificaciones nunca llegan.',
              pt: 'Este firmware pode parar apps por completo. Garante que o Secretly tem início automático e não está entre as apps adormecidas — senão as notificações nunca chegam.',
              ptBr: 'Este firmware pode parar apps por completo. Garanta que o Secretly tenha início automático e não esteja entre os apps adormecidos — senão as notificações nunca chegam.',
              fr: 'Ce firmware peut arrêter complètement les apps. Vérifiez que Secretly a le démarrage automatique et n’est pas parmi les apps endormies — sinon les notifications n’arrivent jamais.',
              de: 'Diese Firmware kann Apps komplett stoppen. Stellen Sie sicher, dass Secretly Autostart hat und nicht zu den schlafenden Apps gehört — sonst kommen Pushes nie an.',
            ),
            onFix: () => _act(_service.openAutostartSettings),
            fixLabel: _rl(
              context,
              ru: 'Открыть',
              uk: 'Відкрити',
              en: 'Open',
              es: 'Abrir',
              pt: 'Abrir',
              ptBr: 'Abrir',
              fr: 'Ouvrir',
              de: 'Öffnen',
            ),
          ),
        );
      }
    } else {
      // iOS: Background App Refresh.
      final barOff =
          status.backgroundRefresh == 'denied' ||
          status.backgroundRefresh == 'restricted';
      rows.add(
        _ReliabilityRow(
          icon: AdaptiveIcons.autorenew_rounded,
          title: _rl(
            context,
            ru: 'Обновление в фоне',
            uk: 'Оновлення у фоні',
            en: 'Background App Refresh',
            es: 'Actualización en segundo plano',
            pt: 'Atualização em segundo plano',
            ptBr: 'Atualização em segundo plano',
            fr: 'Actualisation en arrière-plan',
            de: 'Hintergrundaktualisierung',
          ),
          ok: !barOff,
          okLabel: _rl(
            context,
            ru: 'Включено',
            uk: 'Увімкнено',
            en: 'On',
            es: 'Activada',
            pt: 'Ativada',
            ptBr: 'Ativada',
            fr: 'Activée',
            de: 'Aktiviert',
          ),
          warnLabel: _rl(
            context,
            ru: 'Выключено',
            uk: 'Вимкнено',
            en: 'Off',
            es: 'Desactivada',
            pt: 'Desativada',
            ptBr: 'Desativada',
            fr: 'Désactivée',
            de: 'Deaktiviert',
          ),
          description: !barOff
              ? _rl(
                  context,
                  ru: 'iOS позволяет Secretly забирать сообщения в фоне.',
                  uk: 'iOS дозволяє Secretly забирати повідомлення у фоні.',
                  en: 'iOS lets Secretly fetch messages in the background.',
                  es: 'iOS permite a Secretly recibir mensajes en segundo plano.',
                  pt: 'O iOS permite ao Secretly receber mensagens em segundo plano.',
                  ptBr: 'O iOS permite ao Secretly receber mensagens em segundo plano.',
                  fr: 'iOS laisse Secretly récupérer les messages en arrière-plan.',
                  de: 'iOS lässt Secretly Nachrichten im Hintergrund abrufen.',
                )
              : _rl(
                  context,
                  ru: 'Без «Обновления контента» iOS не будит Secretly в фоне — сообщения загрузятся только при открытии.',
                  uk: 'Без «Оновлення контенту» iOS не будить Secretly у фоні — повідомлення завантажаться лише під час відкриття.',
                  en: 'Without Background App Refresh iOS never wakes Secretly in the background — messages load only when you open the app.',
                  es: 'Sin la actualización en segundo plano iOS no despierta a Secretly: los mensajes cargan solo al abrir la app.',
                  pt: 'Sem a atualização em segundo plano o iOS não acorda o Secretly — as mensagens carregam só ao abrir a app.',
                  ptBr: 'Sem a atualização em segundo plano o iOS não acorda o Secretly — as mensagens carregam só ao abrir o app.',
                  fr: 'Sans l’actualisation en arrière-plan iOS ne réveille jamais Secretly — les messages chargent seulement à l’ouverture.',
                  de: 'Ohne Hintergrundaktualisierung weckt iOS Secretly nie im Hintergrund — Nachrichten laden erst beim Öffnen.',
                ),
          onFix: barOff ? () => _act(_service.openAppSettings) : null,
          fixLabel: _fixLabel(context),
        ),
      );

      // Low Power Mode — informational (temporary by nature).
      if (status.lowPowerMode == true) {
        rows.add(
          _ReliabilityRow(
            icon: AdaptiveIcons.battery_saver_rounded,
            title: _rl(
              context,
              ru: 'Энергосбережение',
              uk: 'Енергозбереження',
              en: 'Low Power Mode',
              es: 'Modo de bajo consumo',
              pt: 'Modo de poupança de energia',
              ptBr: 'Modo de economia de energia',
              fr: 'Mode économie d’énergie',
              de: 'Stromsparmodus',
            ),
            ok: false,
            okLabel: '',
            warnLabel: _rl(
              context,
              ru: 'Включено',
              uk: 'Увімкнено',
              en: 'On',
              es: 'Activado',
              pt: 'Ativado',
              ptBr: 'Ativado',
              fr: 'Activé',
              de: 'Aktiv',
            ),
            description: _rl(
              context,
              ru: 'В режиме энергосбережения iOS придерживает фоновые загрузки — сообщения могут приходить с задержкой, пока режим включён.',
              uk: 'У режимі енергозбереження iOS притримує фонові завантаження — повідомлення можуть надходити із затримкою, доки режим увімкнено.',
              en: 'In Low Power Mode iOS defers background fetches — messages may lag until the mode is off.',
              es: 'En bajo consumo iOS pospone las descargas en segundo plano: los mensajes pueden retrasarse hasta desactivarlo.',
              pt: 'Em poupança de energia o iOS adia as transferências em segundo plano — as mensagens podem atrasar até desligares o modo.',
              ptBr: 'Em economia de energia o iOS adia os downloads em segundo plano — as mensagens podem atrasar até desligar o modo.',
              fr: 'En économie d’énergie iOS reporte les téléchargements en arrière-plan — les messages peuvent tarder tant que le mode est actif.',
              de: 'Im Stromsparmodus verschiebt iOS Hintergrundabrufe — Nachrichten können sich verzögern, bis der Modus aus ist.',
            ),
            onFix: null,
            fixLabel: _fixLabel(context),
          ),
        );
      }
    }

    if (!spaced) return rows;
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        rows[i],
      ],
    ];
  }

  String _fixLabel(BuildContext context) => _rl(
    context,
    ru: 'Исправить',
    uk: 'Виправити',
    en: 'Fix',
    es: 'Corregir',
    pt: 'Corrigir',
    ptBr: 'Corrigir',
    fr: 'Corriger',
    de: 'Beheben',
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status});

  final DeliveryReliabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final ok = !status.hasIssues;
    final color = ok ? Colors.green : Colors.orange;
    return _InfoCard(
      icon: ok ? AdaptiveIcons.verified_rounded : AdaptiveIcons.error_outline_rounded,
      color: color,
      title: ok
          ? _rl(
              context,
              ru: 'Всё настроено идеально',
              uk: 'Усе налаштовано ідеально',
              en: 'Everything is set up perfectly',
              es: 'Todo está configurado perfectamente',
              pt: 'Tudo está configurado na perfeição',
              ptBr: 'Tudo está configurado perfeitamente',
              fr: 'Tout est parfaitement configuré',
              de: 'Alles ist perfekt eingerichtet',
            )
          : _rl(
              context,
              ru: 'Доставка может задерживаться',
              uk: 'Доставлення може затримуватися',
              en: 'Delivery may be delayed',
              es: 'La entrega puede retrasarse',
              pt: 'A entrega pode atrasar',
              ptBr: 'A entrega pode atrasar',
              fr: 'La livraison peut être retardée',
              de: 'Die Zustellung kann sich verzögern',
            ),
      body: ok
          ? _rl(
              context,
              ru: 'Система не ограничивает Secretly — сообщения будут приходить мгновенно.',
              uk: 'Система не обмежує Secretly — повідомлення надходитимуть миттєво.',
              en: 'The OS does not restrict Secretly — messages will arrive instantly.',
              es: 'El sistema no restringe a Secretly: los mensajes llegarán al instante.',
              pt: 'O sistema não restringe o Secretly — as mensagens chegarão de imediato.',
              ptBr: 'O sistema não restringe o Secretly — as mensagens chegarão na hora.',
              fr: 'Le système ne limite pas Secretly — les messages arriveront instantanément.',
              de: 'Das System schränkt Secretly nicht ein — Nachrichten kommen sofort an.',
            )
          : _rl(
              context,
              ru: 'Ниже отмечено, что именно мешает. Каждый пункт исправляется одним нажатием.',
              uk: 'Нижче позначено, що саме заважає. Кожен пункт виправляється одним натисканням.',
              en: 'The blockers are marked below. Each one is a one-tap fix.',
              es: 'Abajo se marca lo que estorba. Cada punto se corrige con un toque.',
              pt: 'Abaixo está marcado o que atrapalha. Cada ponto corrige-se com um toque.',
              ptBr: 'Abaixo está marcado o que atrapalha. Cada ponto se corrige com um toque.',
              fr: 'Les blocages sont indiques ci-dessous. Chacun se corrige d’un geste.',
              de: 'Unten ist markiert, was stört. Jeder Punkt lässt sich mit einem Tipp beheben.',
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Android: строка группы со значком цвета состояния.
    if (settingsAndroidPanels) {
      return AppleSettingsRow(
        leading: AppleRowIcon(tint: color, icon: icon),
        title: title,
        subtitle: body,
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
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

class _ReliabilityRow extends StatelessWidget {
  const _ReliabilityRow({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okLabel,
    required this.warnLabel,
    required this.description,
    required this.onFix,
    required this.fixLabel,
  });

  final IconData icon;
  final String title;

  /// true = green, false = orange warning, null = neutral advisory (grey).
  final bool? ok;
  final String okLabel;
  final String warnLabel;
  final String description;
  final VoidCallback? onFix;
  final String fixLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color stateColor = switch (ok) {
      true => Colors.green,
      false => Colors.orange,
      null => cs.onSurface.withValues(alpha: 0.5),
    };
    final String stateLabel = ok == true ? okLabel : warnLabel;

    // Android (23.11.2026): строка группы — значок цвета состояния, серое
    // пояснение, справа состояние и действие («Исправить» / «Открыть»);
    // нажатие по строке делает то же, что кнопка.
    if (settingsAndroidPanels) {
      final Color tint = switch (ok) {
        true => const Color(0xFF34C759),
        false => const Color(0xFFFF9500),
        null => const Color(0xFF8E8E93),
      };
      final fix = onFix;
      return AppleSettingsRow(
        leading: AppleRowIcon(tint: tint, icon: icon),
        title: title,
        subtitle: description,
        onTap: fix,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (stateLabel.isNotEmpty)
                Text(
                  stateLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ok == null ? cs.onSurfaceVariant : tint,
                  ),
                ),
              if (fix != null) ...[
                const SizedBox(height: 2),
                Text(
                  fixLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: appleGlassDecorationOr(
        context,
        BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: cs.onSurface.withValues(alpha: 0.8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ok == true
                          ? AdaptiveIcons.check_circle_rounded
                          : AdaptiveIcons.info_rounded,
                      size: 14,
                      color: stateColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stateLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: stateColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (onFix != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: PressFeedback(child: FilledButton.tonal(
                onPressed: onFix,
                child: Text(fixLabel),
              )),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-locale label resolver for this screen (L10N FIX 2026-07-17: was
/// ru/uk/en only — every other locale saw English). Delegates to the shared
/// wave1 resolver so locale-tag semantics (pt vs pt_BR etc.) stay consistent
/// with the rest of the app.
String _rl(
  BuildContext context, {
  required String ru,
  required String uk,
  required String en,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: ptBr,
    fr: fr,
    de: de,
  );
}
