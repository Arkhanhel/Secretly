// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Знак «важного пользователя» рядом с именем (21.11.2026): там, где раньше
/// стояла звёздочка премиума (владелец: «звёздочки не нужны — у них есть
/// платные эмодзи-статусы»). Рисуется, только если оператор выдал знак
/// этому профилю ([EliteBadges]); иначе — ничего, места не занимает.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/elite_badges.dart';
import '../../l10n/app_localizations.dart';
import '../chat_screen_l10n.dart';
import '../motion/app_dialogs.dart' show appSheetAnimationStyle;
import 'secretly_glass_sheet.dart';
import 'verified_badges.dart';

/// Роль в команде Secretly у профилей со знаком (слово владельца
/// 22.11.2026). Окно «это команда разработчиков» открывается ТОЛЬКО у этих
/// профилей: знак выдаёт оператор, и у будущих владельцев знака может быть
/// другой смысл — им окна нет, пока владелец не скажет, что в нём писать.
enum SecretlyTeamRole { founder, tester }

const Map<String, SecretlyTeamRole> _kTeamRoles = <String, SecretlyTeamRole>{
  'Z75LTCBZ437IUDXT6XPY': SecretlyTeamRole.founder,
  'OD3SWHK6CHBMUFH54HXA': SecretlyTeamRole.founder,
  'UT5ZUIO2TG6HYY7UG3DA': SecretlyTeamRole.tester,
  'TMZHBYEIGROG6ZNHLJIQ': SecretlyTeamRole.tester,
};

/// Роль профиля в команде или `null`. Id сравниваются без дефисов и регистра.
SecretlyTeamRole? secretlyTeamRoleOf(String? profileId) {
  final id = (profileId ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (id.isEmpty) return null;
  return _kTeamRoles[id];
}

/// Окно по касанию знака у участника команды: что значит галочка и статус.
Future<void> showSecretlyTeamBadgeSheet(
  BuildContext context, {
  required SecretlyTeamRole role,
  required VerifiedBadgeStyle style,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    sheetAnimationStyle: appSheetAnimationStyle,
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final l10n = AppLocalizations.of(sheetCtx)!;
      final theme = Theme.of(sheetCtx);
      final cs = theme.colorScheme;
      final safeBottom = MediaQuery.paddingOf(sheetCtx).bottom;
      final roleLabel = switch (role) {
        SecretlyTeamRole.founder => l10n.eliteBadgeRoleFounder,
        SecretlyTeamRole.tester => l10n.eliteBadgeRoleTester,
      };
      return SecretlyGlassSheetSurface(
        flushToEdges: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SecretlyGlassSheetHandle(),
              const SizedBox(height: 22),
              VerifiedBadge(style: style, size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.eliteBadgeTeamTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.eliteBadgeTeamBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: .78),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.eliteBadgeStatusLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: .62),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        roleLabel,
                        key: const ValueKey('team-badge:role'),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class EliteBadgeMark extends StatefulWidget {
  const EliteBadgeMark({
    super.key,
    required this.profileId,
    this.size = 18,
    this.gap = 6,
    this.interactive = true,
  });

  final String? profileId;
  final double size;

  /// Касание знака открывает окно «команда Secretly» (у участников
  /// команды). В строках списков — `false`: там касание открывает чат.
  final bool interactive;

  /// Отступ слева от имени — только когда знак есть.
  final double gap;

  @override
  State<EliteBadgeMark> createState() => _EliteBadgeMarkState();
}

class _EliteBadgeMarkState extends State<EliteBadgeMark> {
  @override
  void initState() {
    super.initState();
    EliteBadges.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: EliteBadges.instance.badges,
      builder: (context, _, _) {
        final style = verifiedBadgeStyleFromSlug(
          EliteBadges.instance.badgeOf(widget.profileId),
        );
        if (style == null) return const SizedBox.shrink();
        final role = widget.interactive
            ? secretlyTeamRoleOf(widget.profileId)
            : null;
        Widget mark = VerifiedBadge(
            style: style,
            size: widget.size,
            semanticLabel: chatText(
              context,
              ru: 'Важный пользователь',
              en: 'Notable user',
              uk: 'Важливий користувач',
              es: 'Usuario destacado',
              pt: 'Usuário notável',
              fr: 'Utilisateur notable',
              de: 'Bekannter Nutzer',
            ),
          );
        if (role != null) {
          // Касание — окно «команда Secretly» со статусом.
          mark = Semantics(
            button: true,
            child: GestureDetector(
              key: const ValueKey('elite-badge:tap'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showSecretlyTeamBadgeSheet(
                context,
                role: role,
                style: style,
              ),
              child: mark,
            ),
          );
        }
        return Padding(
          padding: EdgeInsetsDirectional.only(start: widget.gap),
          child: mark,
        );
      },
    );
  }
}
