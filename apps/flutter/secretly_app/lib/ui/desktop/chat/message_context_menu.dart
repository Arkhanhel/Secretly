// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../primitives/context_menu.dart';

/// Builds the standard message right-click menu sections.
class MessageContextMenu {
  MessageContextMenu._();

  /// Builds the message right-click menu.
  ///
  /// **No dead affordances:** any action whose handler is `null` is omitted
  /// entirely rather than rendered as a clickable-but-inert row. Unimplemented
  /// actions (forward / pin / select) therefore simply don't appear until they
  /// are wired, instead of looking available and doing nothing.
  static List<List<CtxMenuItem>> sections({
    required bool isSelf,
    required bool canEdit,
    required bool canDelete,
    required bool canPin,
    VoidCallback? onReply,
    VoidCallback? onForward,
    VoidCallback? onSave,
    VoidCallback? onSaveAs,
    VoidCallback? onContinueInTopic,
    VoidCallback? onCopySelection,
    VoidCallback? onCopy,
    VoidCallback? onEdit,
    VoidCallback? onPin,
    VoidCallback? onSelect,
    VoidCallback? onReact,
    VoidCallback? onCopyLink,
    VoidCallback? onDelete,
    VoidCallback? onTranslate,
    bool translationShown = false,
  }) {
    final raw = <List<CtxMenuItem>>[
      [
        if (onReply != null)
          CtxMenuItem(
            label: 'Ответить',
            icon: FluentIcons.arrow_reply_24_regular,
            shortcut: 'Cmd R',
            onTap: onReply,
          ),
        if (onReact != null)
          CtxMenuItem(
            label: 'Реакция',
            icon: FluentIcons.emoji_add_24_regular,
            onTap: onReact,
          ),
        if (onForward != null)
          CtxMenuItem(
            label: 'Переслать',
            icon: FluentIcons.share_24_regular,
            onTap: onForward,
          ),
        // 🔴 «Сохранить» — это пересылка САМОМУ СЕБЕ, и ничего больше.
        //
        // В макете четвёртым разделом рейки стоит закладка, и первым ответом
        // на неё напрашивается «завести хранилище сохранённых сообщений». Оно
        // не нужно: переписка с самим собой в приложении уже есть
        // («Избранное»), она синхронизируется с телефоном и умеет всё, что
        // умеет обычный чат — поиск, вложения, закрепление.
        //
        // Пункт избавляет от трёх действий: «Переслать» → найти себя в списке
        // → нажать. Туда же и попадёт.
        if (onSave != null)
          CtxMenuItem(
            label: 'Сохранить',
            icon: FluentIcons.bookmark_24_regular,
            onTap: onSave,
          ),
        // 🔴 «Продолжить в теме» — и здесь, а не только в строке наведения
        // (указание владельца 16.09.2026: «очень полезная кнопка»). Строку
        // наведения теперь можно выключить в настройках — без этого пункта до
        // действия было бы не добраться вовсе.
        if (onContinueInTopic != null)
          CtxMenuItem(
            label: 'Продолжить в теме',
            icon: FluentIcons.comment_multiple_24_regular,
            onTap: onContinueInTopic,
          ),
      ],
      [
        // Мышью выделен кусок текста — первым пунктом копируется ОН, как в
        // любом текстовом окне; весь текст — пунктом ниже.
        if (onCopySelection != null)
          CtxMenuItem(
            label: 'Копировать выделенное',
            icon: FluentIcons.copy_select_20_regular,
            shortcut: 'Cmd C',
            onTap: onCopySelection,
          ),
        if (onCopy != null)
          CtxMenuItem(
            label: 'Копировать текст',
            icon: FluentIcons.copy_24_regular,
            shortcut: onCopySelection == null ? 'Cmd C' : null,
            onTap: onCopy,
          ),
        if (onSaveAs != null)
          CtxMenuItem(
            label: 'Сохранить как…',
            icon: FluentIcons.arrow_download_24_regular,
            onTap: onSaveAs,
          ),
        if (onCopyLink != null)
          CtxMenuItem(
            label: 'Копировать ссылку',
            icon: FluentIcons.link_24_regular,
            onTap: onCopyLink,
          ),
        // 🔴 Перевод считает САМ КОМПЬЮТЕР — системным переводчиком macOS.
        // Текст сообщения никуда не уходит; облачный переводчик исключён, см.
        // `desktop_translation_service.dart`. Пункта нет вовсе там, где
        // переводить нечего или нечем.
        if (onTranslate != null)
          CtxMenuItem(
            label: translationShown ? 'Скрыть перевод' : 'Перевести',
            icon: FluentIcons.translate_24_regular,
            onTap: onTranslate,
          ),
        if (onPin != null)
          CtxMenuItem(
            label: canPin ? 'Закрепить' : 'Открепить',
            icon: FluentIcons.pin_24_regular,
            onTap: onPin,
          ),
        if (onSelect != null)
          CtxMenuItem(
            label: 'Выделить',
            icon: FluentIcons.select_object_24_regular,
            onTap: onSelect,
          ),
      ],
      if (isSelf && canEdit && onEdit != null)
        [
          CtxMenuItem(
            label: 'Редактировать',
            icon: FluentIcons.edit_24_regular,
            shortcut: 'Cmd E',
            onTap: onEdit,
          ),
        ],
      if (canDelete && onDelete != null)
        [
          CtxMenuItem(
            label: 'Удалить',
            icon: FluentIcons.delete_24_regular,
            isDanger: true,
            onTap: onDelete,
          ),
        ],
    ];
    // Drop any section left empty after null-handler filtering so we never
    // render a stray divider with nothing under it.
    return raw.where((section) => section.isNotEmpty).toList(growable: false);
  }

  /// Attach (+) menu. Same no-dead-affordances rule: items whose handler is
  /// null are omitted (contact / location / poll stay hidden until wired).
  static List<List<CtxMenuItem>> attachSections({
    VoidCallback? onPhoto,
    VoidCallback? onFile,
    VoidCallback? onContact,
    VoidCallback? onLocation,
    VoidCallback? onPoll,
    VoidCallback? onEvent,

    /// Подпись пункта «Событие» — из языковых файлов: подписи в этом файле
    /// зашиты в код, и новым там уже не место.
    String? eventLabel,
  }) {
    final raw = <List<CtxMenuItem>>[
      [
        if (onPhoto != null)
          CtxMenuItem(
            label: 'Фото или видео',
            icon: FluentIcons.image_24_regular,
            onTap: onPhoto,
          ),
        if (onFile != null)
          CtxMenuItem(
            label: 'Файл',
            icon: FluentIcons.document_24_regular,
            onTap: onFile,
          ),
        if (onContact != null)
          CtxMenuItem(
            label: 'Контакт',
            icon: FluentIcons.person_24_regular,
            onTap: onContact,
          ),
        if (onLocation != null)
          CtxMenuItem(
            label: 'Геопозиция',
            icon: FluentIcons.location_24_regular,
            onTap: onLocation,
          ),
        if (onPoll != null)
          CtxMenuItem(
            label: 'Опрос',
            icon: FluentIcons.poll_24_regular,
            onTap: onPoll,
          ),
        if (onEvent != null && (eventLabel ?? '').trim().isNotEmpty)
          CtxMenuItem(
            label: eventLabel!,
            icon: FluentIcons.calendar_24_regular,
            onTap: onEvent,
          ),
      ],
    ];
    return raw.where((section) => section.isNotEmpty).toList(growable: false);
  }
}
