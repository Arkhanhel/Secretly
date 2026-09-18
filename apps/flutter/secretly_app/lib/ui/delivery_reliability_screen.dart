// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../reliability/delivery_reliability_service.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';

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
  const DeliveryReliabilityScreen({super.key, this.service, this.healthLoader});

  /// Injectable for tests; defaults to the real platform channels.
  final DeliveryReliabilityService? service;

  /// Supplies `AppDb.deliveryHealthCounters()`. Optional so the screen still
  /// renders (without the health block) in tests and on the settings route
  /// before the controller is ready.
  final Future<Map<String, int>> Function()? healthLoader;

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
          ? Icons.verified_rounded
          : (unreported > 0
                ? Icons.error_outline_rounded
                : Icons.autorenew_rounded),
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
        fr: 'Etat de la livraison',
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
              fr: 'Tout est livre, rien de bloque.',
              de: 'Alles zugestellt, nichts haengt fest.',
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
                  'Pendientes de envio: $outbox',
              pt: 'Ilegiveis: $stuck (remetente avisado: $reported)\n'
                  'Recibos na fila: $receipts\n'
                  'Aguardando envio: $outbox',
              ptBr: 'Ilegiveis: $stuck (remetente avisado: $reported)\n'
                  'Recibos na fila: $receipts\n'
                  'Aguardando envio: $outbox',
              fr: 'Illisibles: $stuck (expediteur averti: $reported)\n'
                  'Accuses en attente: $receipts\n'
                  'En attente d envoi: $outbox',
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

    return Scaffold(
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
            fr: 'Fiabilite de livraison',
            de: 'Zustellsicherheit',
          ),
        ),
        actions: [
          IconButton(
            tooltip: _rl(
              context,
              ru: 'Проверить снова',
              uk: 'Перевірити знову',
              en: 'Re-check',
              es: 'Volver a comprobar',
              pt: 'Verificar novamente',
              ptBr: 'Verificar novamente',
              fr: 'Reverifier',
              de: 'Erneut pruefen',
            ),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: [
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
              child: Center(child: CircularProgressIndicator()),
            )
          else if (status == null)
            _InfoCard(
              icon: Icons.desktop_windows_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: _rl(
                context,
                ru: 'Здесь всё просто',
                uk: 'Тут усе просто',
                en: 'Nothing to tune here',
                es: 'Nada que ajustar aqui',
                pt: 'Nada para ajustar aqui',
                ptBr: 'Nada para ajustar aqui',
                fr: 'Rien a regler ici',
                de: 'Hier gibt es nichts einzustellen',
              ),
              body: _rl(
                context,
                ru: 'На этой платформе система не ограничивает доставку сообщений в фоне.',
                uk: 'На цій платформі система не обмежує доставлення повідомлень у фоні.',
                en: 'On this platform the OS does not restrict background message delivery.',
                es: 'En esta plataforma el sistema no restringe la entrega de mensajes en segundo plano.',
                pt: 'Nesta plataforma o sistema nao restringe a entrega de mensagens em segundo plano.',
                ptBr: 'Nesta plataforma o sistema nao restringe a entrega de mensagens em segundo plano.',
                fr: 'Sur cette plateforme le systeme ne limite pas la livraison des messages en arriere-plan.',
                de: 'Auf dieser Plattform schraenkt das System die Zustellung im Hintergrund nicht ein.',
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
                es: 'Estos ajustes viven en la configuracion del sistema: la app no puede cambiarlos, solo llevarte alli.',
                pt: 'Estes ajustes vivem nas definicoes do sistema — a app nao pode alterar-los, apenas levar-te ate la.',
                ptBr: 'Esses ajustes ficam nas configuracoes do sistema — o app nao pode alterar-los, apenas levar voce ate la.',
                fr: 'Ces reglages vivent dans les parametres du systeme — l\'app ne peut pas les changer, seulement vous y conduire.',
                de: 'Diese Schalter liegen in den Systemeinstellungen — die App kann sie nicht selbst umlegen, nur dorthin fuehren.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _rowsFor(
    BuildContext context,
    DeliveryReliabilityStatus status,
  ) {
    final rows = <Widget>[];

    // Notifications — both platforms.
    rows.add(
      _ReliabilityRow(
        icon: Icons.notifications_active_rounded,
        title: _rl(
          context,
          ru: 'Уведомления',
          uk: 'Сповіщення',
          en: 'Notifications',
          es: 'Notificaciones',
          pt: 'Notificacoes',
          ptBr: 'Notificacoes',
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
          fr: 'Activees',
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
          fr: 'Desactivees',
          de: 'Deaktiviert',
        ),
        description: status.notificationsEnabled != false
            ? _rl(
                context,
                ru: 'Баннеры о новых сообщениях показываются.',
                uk: 'Банери про нові повідомлення показуються.',
                en: 'New-message banners are shown.',
                es: 'Se muestran los avisos de mensajes nuevos.',
                pt: 'Os avisos de novas mensagens sao mostrados.',
                ptBr: 'Os avisos de novas mensagens sao mostrados.',
                fr: 'Les bannieres de nouveaux messages s\'affichent.',
                de: 'Banner fuer neue Nachrichten werden angezeigt.',
              )
            : _rl(
                context,
                ru: 'Система блокирует все уведомления Secretly — вы не увидите новых сообщений, пока не откроете приложение.',
                uk: 'Система блокує всі сповіщення Secretly — ви не побачите нових повідомлень, доки не відкриєте застосунок.',
                en: 'The OS blocks all Secretly notifications — you will not see new messages until you open the app.',
                es: 'El sistema bloquea todas las notificaciones de Secretly: no veras mensajes nuevos hasta abrir la app.',
                pt: 'O sistema bloqueia todas as notificacoes do Secretly — nao veras novas mensagens ate abrires a app.',
                ptBr: 'O sistema bloqueia todas as notificacoes do Secretly — voce nao vera novas mensagens ate abrir o app.',
                fr: 'Le systeme bloque toutes les notifications de Secretly — vous ne verrez pas les nouveaux messages avant d\'ouvrir l\'app.',
                de: 'Das System blockiert alle Secretly-Benachrichtigungen — neue Nachrichten sehen Sie erst beim Oeffnen der App.',
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
          icon: Icons.battery_charging_full_rounded,
          title: _rl(
            context,
            ru: 'Батарея',
            uk: 'Батарея',
            en: 'Battery',
            es: 'Bateria',
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
            pt: 'Sem restricoes',
            ptBr: 'Sem restricoes',
            fr: 'Sans restrictions',
            de: 'Ohne Einschraenkungen',
          ),
          warnLabel: _rl(
            context,
            ru: 'Оптимизируется',
            uk: 'Оптимізується',
            en: 'Optimized',
            es: 'Optimizada',
            pt: 'Otimizada',
            ptBr: 'Otimizada',
            fr: 'Optimisee',
            de: 'Optimiert',
          ),
          description: status.batteryUnrestricted != false
              ? _rl(
                  context,
                  ru: 'Система не усыпляет Secretly — пуши будят приложение вовремя.',
                  uk: 'Система не присипляє Secretly — пуші будять застосунок вчасно.',
                  en: 'The OS does not put Secretly to sleep — pushes wake the app on time.',
                  es: 'El sistema no duerme a Secretly: las notificaciones despiertan la app a tiempo.',
                  pt: 'O sistema nao adormece o Secretly — as notificacoes acordam a app a tempo.',
                  ptBr: 'O sistema nao adormece o Secretly — as notificacoes acordam o app a tempo.',
                  fr: 'Le systeme n\'endort pas Secretly — les notifications reveillent l\'app a temps.',
                  de: 'Das System legt Secretly nicht schlafen — Pushes wecken die App rechtzeitig.',
                )
              : _rl(
                  context,
                  ru: 'В глубоком сне система может замораживать Secretly, и сообщения будут приходить с опозданием. Разрешите работу без ограничений.',
                  uk: 'У глибокому сні система може заморожувати Secretly, і повідомлення надходитимуть із запізненням. Дозвольте роботу без обмежень.',
                  en: 'In deep sleep the OS may freeze Secretly and messages will arrive late. Allow unrestricted background use.',
                  es: 'En reposo profundo el sistema puede congelar Secretly y los mensajes llegaran tarde. Permite el uso sin restricciones.',
                  pt: 'Em suspensao profunda o sistema pode congelar o Secretly e as mensagens chegarao atrasadas. Permite o uso sem restricoes.',
                  ptBr: 'Em suspensao profunda o sistema pode congelar o Secretly e as mensagens chegarao atrasadas. Permita o uso sem restricoes.',
                  fr: 'En veille profonde le systeme peut geler Secretly et les messages arriveront en retard. Autorisez l\'usage sans restrictions.',
                  de: 'Im Tiefschlaf kann das System Secretly einfrieren, Nachrichten kommen verspaetet an. Erlauben Sie die uneingeschraenkte Nutzung.',
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
          icon: Icons.data_saver_on_rounded,
          title: _rl(
            context,
            ru: 'Фоновые данные',
            uk: 'Фонові дані',
            en: 'Background data',
            es: 'Datos en segundo plano',
            pt: 'Dados em segundo plano',
            ptBr: 'Dados em segundo plano',
            fr: 'Donnees en arriere-plan',
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
            fr: 'Autorisees',
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
            fr: 'Bloquees',
            de: 'Blockiert',
          ),
          description: !dataBlocked
              ? _rl(
                  context,
                  ru: 'Secretly может забирать сообщения в фоне на мобильном интернете.',
                  uk: 'Secretly може забирати повідомлення у фоні на мобільному інтернеті.',
                  en: 'Secretly can fetch messages in the background on mobile data.',
                  es: 'Secretly puede recibir mensajes en segundo plano con datos moviles.',
                  pt: 'O Secretly pode receber mensagens em segundo plano com dados moveis.',
                  ptBr: 'O Secretly pode receber mensagens em segundo plano com dados moveis.',
                  fr: 'Secretly peut recuperer les messages en arriere-plan via les donnees mobiles.',
                  de: 'Secretly kann Nachrichten im Hintergrund ueber mobile Daten abrufen.',
                )
              : _rl(
                  context,
                  ru: 'Включён «Экономия трафика», и Secretly не в списке исключений: на мобильном интернете сообщения не загрузятся, пока вы не откроете приложение.',
                  uk: 'Увімкнено «Заощадження трафіку», і Secretly не у винятках: на мобільному інтернеті повідомлення не завантажаться, доки ви не відкриєте застосунок.',
                  en: 'Data Saver is on and Secretly is not exempted: on mobile data messages will not load until you open the app.',
                  es: 'El ahorro de datos esta activado y Secretly no esta exento: con datos moviles los mensajes no cargaran hasta abrir la app.',
                  pt: 'A poupanca de dados esta ativa e o Secretly nao esta isento: com dados moveis as mensagens nao carregam ate abrires a app.',
                  ptBr: 'A economia de dados esta ativa e o Secretly nao esta isento: com dados moveis as mensagens nao carregam ate voce abrir o app.',
                  fr: 'L\'economiseur de donnees est actif et Secretly n\'est pas exempte : en donnees mobiles les messages ne chargeront pas avant l\'ouverture de l\'app.',
                  de: 'Der Datensparmodus ist aktiv und Secretly nicht ausgenommen: ueber mobile Daten laden Nachrichten erst beim Oeffnen der App.',
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
            icon: Icons.rocket_launch_rounded,
            title: _rl(
              context,
              ru: 'Автозапуск',
              uk: 'Автозапуск',
              en: 'Autostart',
              es: 'Inicio automatico',
              pt: 'Inicio automatico',
              ptBr: 'Inicio automatico',
              fr: 'Demarrage automatique',
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
              fr: 'Verifier manuellement',
              de: 'Manuell pruefen',
            ),
            description: _rl(
              context,
              ru: 'На этой прошивке система может полностью останавливать приложения. Убедитесь, что Secretly разрешён автозапуск / не находится в «спящих» — иначе пуши не доходят вовсе.',
              uk: 'На цій прошивці система може повністю зупиняти застосунки. Переконайтеся, що Secretly дозволено автозапуск / він не серед «сплячих» — інакше пуші не доходять узагалі.',
              en: 'This firmware can force-stop apps entirely. Make sure Secretly is allowed to auto-start / is not among “sleeping apps” — otherwise pushes never arrive.',
              es: 'Este firmware puede detener apps por completo. Asegurate de que Secretly tenga inicio automatico y no este entre las apps dormidas; si no, las notificaciones nunca llegan.',
              pt: 'Este firmware pode parar apps por completo. Garante que o Secretly tem inicio automatico e nao esta entre as apps adormecidas — senao as notificacoes nunca chegam.',
              ptBr: 'Este firmware pode parar apps por completo. Garanta que o Secretly tenha inicio automatico e nao esteja entre os apps adormecidos — senao as notificacoes nunca chegam.',
              fr: 'Ce firmware peut arreter completement les apps. Verifiez que Secretly a le demarrage automatique et n\'est pas parmi les apps endormies — sinon les notifications n\'arrivent jamais.',
              de: 'Diese Firmware kann Apps komplett stoppen. Stellen Sie sicher, dass Secretly Autostart hat und nicht zu den schlafenden Apps gehoert — sonst kommen Pushes nie an.',
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
              de: 'Oeffnen',
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
          icon: Icons.autorenew_rounded,
          title: _rl(
            context,
            ru: 'Обновление в фоне',
            uk: 'Оновлення у фоні',
            en: 'Background App Refresh',
            es: 'Actualizacion en segundo plano',
            pt: 'Atualizacao em segundo plano',
            ptBr: 'Atualizacao em segundo plano',
            fr: 'Actualisation en arriere-plan',
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
            fr: 'Activee',
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
            fr: 'Desactivee',
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
                  fr: 'iOS laisse Secretly recuperer les messages en arriere-plan.',
                  de: 'iOS laesst Secretly Nachrichten im Hintergrund abrufen.',
                )
              : _rl(
                  context,
                  ru: 'Без «Обновления контента» iOS не будит Secretly в фоне — сообщения загрузятся только при открытии.',
                  uk: 'Без «Оновлення контенту» iOS не будить Secretly у фоні — повідомлення завантажаться лише під час відкриття.',
                  en: 'Without Background App Refresh iOS never wakes Secretly in the background — messages load only when you open the app.',
                  es: 'Sin la actualizacion en segundo plano iOS no despierta a Secretly: los mensajes cargan solo al abrir la app.',
                  pt: 'Sem a atualizacao em segundo plano o iOS nao acorda o Secretly — as mensagens carregam so ao abrir a app.',
                  ptBr: 'Sem a atualizacao em segundo plano o iOS nao acorda o Secretly — as mensagens carregam so ao abrir o app.',
                  fr: 'Sans l\'actualisation en arriere-plan iOS ne reveille jamais Secretly — les messages chargent seulement a l\'ouverture.',
                  de: 'Ohne Hintergrundaktualisierung weckt iOS Secretly nie im Hintergrund — Nachrichten laden erst beim Oeffnen.',
                ),
          onFix: barOff ? () => _act(_service.openAppSettings) : null,
          fixLabel: _fixLabel(context),
        ),
      );

      // Low Power Mode — informational (temporary by nature).
      if (status.lowPowerMode == true) {
        rows.add(
          _ReliabilityRow(
            icon: Icons.battery_saver_rounded,
            title: _rl(
              context,
              ru: 'Энергосбережение',
              uk: 'Енергозбереження',
              en: 'Low Power Mode',
              es: 'Modo de bajo consumo',
              pt: 'Modo de poupanca de energia',
              ptBr: 'Modo de economia de energia',
              fr: 'Mode economie d\'energie',
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
              fr: 'Active',
              de: 'Aktiv',
            ),
            description: _rl(
              context,
              ru: 'В режиме энергосбережения iOS придерживает фоновые загрузки — сообщения могут приходить с задержкой, пока режим включён.',
              uk: 'У режимі енергозбереження iOS притримує фонові завантаження — повідомлення можуть надходити із затримкою, доки режим увімкнено.',
              en: 'In Low Power Mode iOS defers background fetches — messages may lag until the mode is off.',
              es: 'En bajo consumo iOS pospone las descargas en segundo plano: los mensajes pueden retrasarse hasta desactivarlo.',
              pt: 'Em poupanca de energia o iOS adia as transferencias em segundo plano — as mensagens podem atrasar ate desligares o modo.',
              ptBr: 'Em economia de energia o iOS adia os downloads em segundo plano — as mensagens podem atrasar ate desligar o modo.',
              fr: 'En economie d\'energie iOS reporte les telechargements en arriere-plan — les messages peuvent tarder tant que le mode est actif.',
              de: 'Im Stromsparmodus verschiebt iOS Hintergrundabrufe — Nachrichten koennen sich verzoegern, bis der Modus aus ist.',
            ),
            onFix: null,
            fixLabel: _fixLabel(context),
          ),
        );
      }
    }

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
      icon: ok ? Icons.verified_rounded : Icons.error_outline_rounded,
      color: color,
      title: ok
          ? _rl(
              context,
              ru: 'Всё настроено идеально',
              uk: 'Усе налаштовано ідеально',
              en: 'Everything is set up perfectly',
              es: 'Todo esta configurado perfectamente',
              pt: 'Tudo esta configurado na perfeicao',
              ptBr: 'Tudo esta configurado perfeitamente',
              fr: 'Tout est parfaitement configure',
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
              fr: 'La livraison peut etre retardee',
              de: 'Die Zustellung kann sich verzoegern',
            ),
      body: ok
          ? _rl(
              context,
              ru: 'Система не ограничивает Secretly — сообщения будут приходить мгновенно.',
              uk: 'Система не обмежує Secretly — повідомлення надходитимуть миттєво.',
              en: 'The OS does not restrict Secretly — messages will arrive instantly.',
              es: 'El sistema no restringe a Secretly: los mensajes llegaran al instante.',
              pt: 'O sistema nao restringe o Secretly — as mensagens chegarao de imediato.',
              ptBr: 'O sistema nao restringe o Secretly — as mensagens chegarao na hora.',
              fr: 'Le systeme ne limite pas Secretly — les messages arriveront instantanement.',
              de: 'Das System schraenkt Secretly nicht ein — Nachrichten kommen sofort an.',
            )
          : _rl(
              context,
              ru: 'Ниже отмечено, что именно мешает. Каждый пункт исправляется одним нажатием.',
              uk: 'Нижче позначено, що саме заважає. Кожен пункт виправляється одним натисканням.',
              en: 'The blockers are marked below. Each one is a one-tap fix.',
              es: 'Abajo se marca lo que estorba. Cada punto se corrige con un toque.',
              pt: 'Abaixo esta marcado o que atrapalha. Cada ponto corrige-se com um toque.',
              ptBr: 'Abaixo esta marcado o que atrapalha. Cada ponto se corrige com um toque.',
              fr: 'Les blocages sont indiques ci-dessous. Chacun se corrige d\'un geste.',
              de: 'Unten ist markiert, was stoert. Jeder Punkt laesst sich mit einem Tipp beheben.',
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
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
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
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
              child: FilledButton.tonal(
                onPressed: onFix,
                child: Text(fixLabel),
              ),
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
