// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../reliability/delivery_reliability_service.dart';
import 'delivery_reliability_screen.dart';
import 'haptics.dart';
import 'animations/page_transitions.dart';
import 'wave1_l10n.dart';

/// Полоса-предупреждение над списком чатов: система мешает доставке.
///
/// 🔴 ЗАЧЕМ ОНА, ЕСЛИ ЭКРАН ПРОВЕРОК УЖЕ ЕСТЬ (23.08.2026).
///
/// Проверки и кнопки «Исправить» живут в [DeliveryReliabilityScreen] с июля, и
/// в настройках рядом с пунктом даже горит оранжевый значок. Но попадает туда
/// только тот, кто уже пошёл искать причину — а причина проявляется как
/// «звонков нет вообще», то есть человек скорее решит, что сломано приложение.
///
/// Поле 22.08: звонок на закрытый Android (Xiaomi HyperOS) не показал
/// уведомления совсем. Реле отправило приглашение, FCM подтвердил приём, а
/// телефон получил его тремя минутами позже — в секунду, когда приложение
/// открыли руками; рядом система раз за разом убивала push-сервис. Приложение
/// в белый список энергосбережения не входило, и узнать об этом было неоткуда.
///
/// Поэтому предупреждение поднимается туда, где его увидят, и ровно тогда,
/// когда проблема есть: пустой виджет в здоровом случае.
class DeliveryHealthBanner extends StatefulWidget {
  const DeliveryHealthBanner({super.key, this.service});

  /// Подменяется в тестах.
  final DeliveryReliabilityService? service;

  @override
  State<DeliveryHealthBanner> createState() => _DeliveryHealthBannerState();
}

class _DeliveryHealthBannerState extends State<DeliveryHealthBanner>
    with WidgetsBindingObserver {
  late final DeliveryReliabilityService _service =
      widget.service ?? DeliveryReliabilityService();
  DeliveryReliabilityStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Человек мог уйти в системные настройки и вернуться — перепроверяем, иначе
    // полоса висела бы после того, как разрешение уже выдано.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || !status.hasIssues) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            Haptics.tap();
            await Navigator.of(context).push(
              SecretlyPageRoute(
                builder: (_) => const DeliveryReliabilityScreen(),
              ),
            );
            await _refresh();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wave1Text(
                          context,
                          ru: 'Звонки и сообщения могут не приходить',
                          en: 'Calls and messages may not arrive',
                          uk: 'Дзвінки та повідомлення можуть не надходити',
                          es: 'Las llamadas y mensajes pueden no llegar',
                          pt: 'Chamadas e mensagens podem não chegar',
                          ptBr: 'Chamadas e mensagens podem não chegar',
                          fr: 'Appels et messages peuvent ne pas arriver',
                          de: 'Anrufe und Nachrichten kommen evtl. nicht an',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wave1Text(
                          context,
                          ru: 'Система ограничивает приложение. Нажмите, чтобы исправить',
                          en: 'The system is restricting the app. Tap to fix',
                          uk: 'Система обмежує застосунок. Натисніть, щоб виправити',
                          es: 'El sistema restringe la app. Toca para solucionarlo',
                          pt: 'O sistema restringe o app. Toque para corrigir',
                          ptBr: 'O sistema restringe o app. Toque para corrigir',
                          fr: 'Le système limite l\'app. Touchez pour corriger',
                          de: 'Das System schränkt die App ein. Zum Beheben tippen',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onErrorContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onErrorContainer.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
