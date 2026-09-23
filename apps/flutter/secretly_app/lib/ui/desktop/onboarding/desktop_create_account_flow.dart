// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../app/desktop_app_view_model.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_text_field.dart';
import 'desktop_account_setup.dart';
import 'desktop_auth_scaffold.dart';

/// Создание нового аккаунта прямо на компьютере.
///
/// Низ уже был написан и проверен телефоном:
/// [AppController.createNewServerProfileForCurrentDevice] заводит серверный
/// профиль и снимает запрет входа. Здесь — только два человеческих шага
/// вокруг него: имя и обещание про набор восстановления.
///
/// 🔴 ШАГ «СОХРАНИТЕ НАБОР» ЖИВЁТ НЕ ЗДЕСЬ. Создание профиля снимает запрет
/// входа в тот же кадр, и корень окна меняет этот экран на оболочку — шаг,
/// живущий внутри него, исчез бы вместе с ним. Поэтому перед созданием
/// взводится флаг [DesktopAccountSetup.markKitPending], а показывает шаг
/// корень, поверх оболочки. Заодно это переживает закрытие окна посреди
/// создания.
class DesktopCreateAccountFlow extends StatefulWidget {
  const DesktopCreateAccountFlow({
    super.key,
    required this.vm,
    required this.onBack,
  });

  final DesktopAppViewModel vm;
  final VoidCallback onBack;

  @override
  State<DesktopCreateAccountFlow> createState() =>
      _DesktopCreateAccountFlowState();
}

class _DesktopCreateAccountFlowState extends State<DesktopCreateAccountFlow> {
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Флаг взводится ДО создания, а не после: создание снимает запрет входа
      // и уводит этот экран со сцены. Успеть взвести его «потом» нельзя.
      await DesktopAccountSetup.markKitPending();
      await widget.vm.controller.createNewServerProfileForCurrentDevice();
      // Имя — уже по существующему профилю. Отказ здесь не отменяет аккаунт:
      // имя правится в любой момент, а второй попытки создания не будет.
      try {
        await widget.vm.controller.setMyNickname(name);
      } catch (_) {
        // Имя можно задать позже в профиле.
      }
      // Дальше экран сменит корень: запрет входа снят.
    } catch (e) {
      // Аккаунт не создан — флаг снимаем, иначе шаг «сохраните набор» повис
      // бы над оболочкой, которой ещё нет.
      await DesktopAccountSetup.clearKitPending();
      if (!mounted) return;
      var text = e.toString();
      for (final prefix in const ['Bad state: ', 'StateError: ']) {
        if (text.startsWith(prefix)) text = text.substring(prefix.length);
      }
      setState(() {
        _busy = false;
        _error = l10n.desktopAuthCreateFailed(text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return DesktopAuthScaffold(
      onBack: _busy ? null : widget.onBack,
      title: l10n.desktopAuthNameTitle,
      subtitle: l10n.desktopAuthNameBody,
      children: [
        DesktopTextField(
          controller: _name,
          autofocus: true,
          hintText: l10n.desktopProfileName,
          prefixIcon: FluentIcons.person_24_regular,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _create(),
        ),
        if (_error != null) ...[
          const SizedBox(height: DSpace.m),
          Text(
            _error!,
            style: DType.label.copyWith(color: c.danger, height: 1.45),
          ),
          const SizedBox(height: DSpace.xs),
          // Сбитые часы — самая частая и самая непонятная причина отказа:
          // сервер отвергает подпись, а человек видит только «не удалось».
          Text(
            l10n.desktopAuthCheckClock,
            style: DType.caption.copyWith(color: c.textSecondary, height: 1.45),
          ),
        ],
        const SizedBox(height: DSpace.xl),
        DesktopButton(
          label: _busy ? l10n.desktopAuthCreating : l10n.desktopAuthContinue,
          kind: DButtonKind.filled,
          expand: true,
          // Пустое имя не пропускаем: без него собеседники увидят сырой
          // идентификатор вместо человека.
          onPressed: (_busy || _name.text.trim().isEmpty) ? null : _create,
        ),
      ],
    );
  }
}
