// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'wave1_l10n.dart';

/// У-1 (17.09.2026): регистрацию этого устройства сняли на сервере.
///
/// Сообщения сюда больше не приходят; данные на устройстве не тронуты —
/// что с ними делать, решает человек.
class OwnDeviceRemovedBanner extends StatelessWidget {
  const OwnDeviceRemovedBanner({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) {
        if (!controller.ownDeviceRemoved) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final text = wave1TextForLocale(
          Localizations.localeOf(context).toLanguageTag(),
          ru: 'Это устройство отключено от вашего аккаунта. Новые сообщения сюда не приходят. Переписка на устройстве сохранена.',
          en: 'This device was disconnected from your account. New messages no longer arrive here. Chats on this device are kept.',
          uk: 'Цей пристрій відключено від вашого акаунта. Нові повідомлення сюди не надходять. Листування на пристрої збережено.',
          es: 'Este dispositivo se desconecto de tu cuenta. Aqui ya no llegan mensajes nuevos. Los chats del dispositivo se conservan.',
          pt: 'Este dispositivo foi desligado da sua conta. Novas mensagens ja nao chegam aqui. As conversas no dispositivo foram mantidas.',
          ptBr: 'Este dispositivo foi desconectado da sua conta. Novas mensagens nao chegam mais aqui. As conversas no dispositivo foram mantidas.',
          fr: 'Cet appareil a ete deconnecte de votre compte. Les nouveaux messages n arrivent plus ici. Les conversations sur l appareil sont conservees.',
          de: 'Dieses Gerat wurde von deinem Konto getrennt. Neue Nachrichten kommen hier nicht mehr an. Die Chats auf dem Gerat bleiben erhalten.',
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Material(
            color: scheme.errorContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.link_off_rounded, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
