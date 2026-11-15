// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../transport/response_signature.dart';

/// Б3 Э2 (25.10.2026): ответ сервера с ключами или составом не прошёл
/// проверку подписи, а отказ на этом устройстве включён
/// (docs/TZ_SERVER_AUTH_B3_2026-10-25.md §5).
///
/// Пусто, пока отказа не было: при доле 0 его не видит никто. Сказать надо
/// три вещи — что случилось, что по-прежнему безопасно (открытые чаты), что
/// делать (другая сеть или прокси). «Понятно» прячет баннер до следующего
/// отказа.
class ServerAuthAlertBanner extends StatelessWidget {
  const ServerAuthAlertBanner({super.key, this.compact = false});

  /// Плотнее — для подвала списка на компьютере.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ServerUnauthenticatedException?>(
      valueListenable: ServerAuthEnforcement.lastRejection,
      builder: (context, rejection, _) {
        final l10n = AppLocalizations.of(context);
        if (rejection == null || l10n == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final fg = scheme.onErrorContainer;
        return Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(8, 4, 8, 4)
              : const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Material(
              color: scheme.errorContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(compact ? 10 : 14),
              child: Padding(
                padding: EdgeInsets.all(compact ? 10 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gpp_maybe_rounded, color: fg, size: compact ? 18 : 24),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.serverAuthAlertTitle,
                            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.serverAuthAlertBody,
                            style: TextStyle(color: fg, fontSize: compact ? 12 : null),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () =>
                                  ServerAuthEnforcement.lastRejection.value = null,
                              style: TextButton.styleFrom(foregroundColor: fg),
                              child: Text(l10n.serverAuthAlertDismiss),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
