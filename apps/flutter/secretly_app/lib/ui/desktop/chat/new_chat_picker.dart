// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/hover_listener.dart';

/// Выбор человека для нового чата.
///
/// 🔴 Почему выбор свой, а создание комнаты — мобильное.
///
/// Комнату заводит `NewGroupScreen` с телефона, целиком и без правок: это
/// многошаговая форма (название, участники, автоудаление), и вторая её
/// реализация разошлась бы с первой на первой же правке.
///
/// А выбор человека — это один список. Мобильный показывает его экраном на весь
/// телефон; на столе такой экран перекрыл бы окно целиком ради одного нажатия.
/// Поэтому здесь окно, а ДЕЙСТВИЕ под ним то же самое, что у кнопки «Написать
/// сообщение» в разделе «Контакты»: `prepareSharedProfileConversation`.
///
/// 🔴 Контроллер сюда НЕ приходит.
///
/// Десктопные окна ходят к приложению через один шов
/// (`desktop_app_view_model.dart`), и сторожевой тест считает каждый файл,
/// который импортирует контроллер напрямую. Причина не в чистоте: виджет с
/// контроллером на руках дотягивается до любого из его полутора сотен методов
/// и заводит свою подписку — именно так десктоп однажды набрал восемнадцать
/// независимых подписок и 23 % процессора на холостом ходу.
///
/// Поэтому окно принимает ГОТОВЫЙ список: кто его собрал, оно не знает.
///
/// Возвращает `profileId` выбранного человека или `null`, если закрыли.
Future<String?> showNewChatPicker(
  BuildContext context, {
  required Future<List<NewChatCandidate>> Function() loadContacts,
}) {
  return DesktopDialog.show<String>(
    context,
    title: 'Новый чат',
    size: DDialogSize.small,
    body: _NewChatPickerBody(loadContacts: loadContacts),
  );
}

/// Человек, с которым можно начать переписку. Ровно то, что нужно строке
/// списка, и ничего больше.
class NewChatCandidate {
  const NewChatCandidate({
    required this.profileId,
    required this.name,
    this.avatarPath,
  });

  final String profileId;
  final String name;
  final String? avatarPath;
}

class _NewChatPickerBody extends StatefulWidget {
  const _NewChatPickerBody({required this.loadContacts});

  final Future<List<NewChatCandidate>> Function() loadContacts;

  @override
  State<_NewChatPickerBody> createState() => _NewChatPickerBodyState();
}

class _NewChatPickerBodyState extends State<_NewChatPickerBody> {
  final TextEditingController _search = TextEditingController();
  List<NewChatCandidate>? _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.loadContacts();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _all = const <NewChatCandidate>[]);
    }
  }

  List<NewChatCandidate> get _visible {
    final all = _all ?? const <NewChatCandidate>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.profileId.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final all = _all;
    final visible = _visible;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopTextField(
          controller: _search,
          hintText: 'Поиск по контактам',
          prefixIcon: FluentIcons.search_24_regular,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: DSpace.m),
        // Высота фиксированная: список в диалоге, который растёт под число
        // контактов, прыгает при каждом набранном символе.
        SizedBox(
          height: 300,
          child: all == null
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                    ),
                  ),
                )
              : visible.isEmpty
              ? Center(
                  child: Text(
                    all.isEmpty ? 'Контактов пока нет' : 'Никого не нашлось',
                    style: DType.body.copyWith(color: c.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  itemBuilder: (ctx, i) {
                    final contact = visible[i];
                    return _ContactRow(
                      name: contact.name,
                      profileId: contact.profileId,
                      avatarPath: contact.avatarPath,
                      onTap: () =>
                          Navigator.of(context).maybePop(contact.profileId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.profileId,
    required this.avatarPath,
    required this.onTap,
  });

  final String name;
  final String profileId;
  final String? avatarPath;
  final VoidCallback onTap;

  ImageProvider? get _image {
    final p = avatarPath;
    if (p == null || p.trim().isEmpty) return null;
    try {
      final f = File(p);
      return f.existsSync() ? FileImage(f) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.s,
          vertical: DSpace.s,
        ),
        decoration: BoxDecoration(
          color: pressed ? c.pressed : (hovered ? c.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(DRadii.sm),
        ),
        child: Row(
          children: [
            // Контакт это всегда человек — круг. Комнату из этого окна не
            // создают, для неё отдельный пункт меню.
            Avatar(name: name, image: _image, size: 34),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.bodyStrong.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    profileId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.tiny.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
