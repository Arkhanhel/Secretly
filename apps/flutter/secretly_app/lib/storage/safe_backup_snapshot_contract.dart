// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
const Map<String, Set<String>> kSafeBackupSnapshotColumnsByTable =
    <String, Set<String>>{
      'conversations': <String>{
        'convo_id',
        'kind',
        'peer_profile_id',
        'title',
        'pinned_at_ms',
        'muted',
        'muted_until_ms',
        'muted_mentions_only',
        'archived_at_ms',
        'auto_delete_seconds',
        'last_event_at_ms',
        'created_at_ms',
        'updated_at_ms',
      },
      'contacts': <String>{
        'contact_profile_id',
        'display_name',
        'display_name_is_custom',
        'avatar_path',
        'contact_emoji',
        'created_at_ms',
        'updated_at_ms',
      },
      'events': <String>{
        'event_id',
        'convo_id',
        'type',
        'sender_device_id',
        'ciphertext_b64',
        'local_ciphertext_b64',
        'created_at_ms',
        'local_state',
        'payload_event_id',
        'read_at_ms',
        'scheduled_at_ms',
      },
      'requests': <String>{
        'contact_profile_id',
        'status',
        'created_at_ms',
        'updated_at_ms',
      },
      'blocked_profiles': <String>{'blocked_profile_id', 'created_at_ms'},
      'profile_meta': <String>{
        'profile_id',
        'nickname',
        'avatar_path',
        'bio',
        'privacy_audience_json',
        'frame_id',
        'cover_id',
        'cover_path',
        'emoji_status',
        'premium_badge',
        'last_seen_at_ms',
        'updated_at_ms',
      },
      'message_reactions': <String>{
        'event_id',
        'convo_id',
        'profile_id',
        'actor_name',
        'actor_avatar_path',
        'emoji',
        'created_at_ms',
        'updated_at_ms',
      },
      'group_members': <String>{
        'group_id',
        'member_profile_id',
        'created_at_ms',
      },
      'group_settings': <String>{
        'group_id',
        'owner_profile_id',
        'description',
        'avatar_path',
        'avatar_hash',
        'cover_id',
        'frame_id',
        'name_emoji',
        'reactions_mode',
        'allow_text',
        'allow_media',
        'allow_add_members',
        'allow_pin_messages',
        'allow_change_group_info',
        'allow_change_tag',
        'join_approval_required',
        'slow_mode_seconds',
        'chat_history_visible',
        'pinned_message_event_id',
        'state_version',
        'membership_version',
        'created_at_ms',
        'updated_at_ms',
      },
      'group_memberships': <String>{
        'group_id',
        'profile_id',
        'status',
        'role',
        'source_link_id',
        'tag',
        'created_at_ms',
        'updated_at_ms',
      },
      'group_admins': <String>{'group_id', 'profile_id', 'created_at_ms'},
      'group_invite_links': <String>{
        'link_id',
        'group_id',
        'slug',
        'created_by_profile_id',
        'expires_at_ms',
        'max_uses',
        'use_count',
        'requires_approval',
        'allowed_role',
        'is_revoked',
        'created_at_ms',
        'updated_at_ms',
      },
      'room_message_receipts': <String>{
        'payload_event_id',
        'reader_profile_id',
        'reader_device_id',
        'status',
        'updated_at_ms',
      },
      'group_posting_state': <String>{
        'group_id',
        'profile_id',
        'last_admitted_at_ms',
        'next_allowed_at_ms',
        'updated_at_ms',
      },
      'attachments': <String>{
        'blob_id',
        'file_key_b64',
        'access_token_b64',
        'mime',
        'plaintext_size_bytes',
        'ciphertext_size_bytes',
        'expires_at_ms',
        'created_at_ms',
      },
      // 🔴 Стикеры (08.08.2026, поле: «после восстановления папка стикеров
      // пустая»). Ни таблиц, ни файлов копия не несла вовсе — то есть свои
      // наборы терялись безвозвратно, а сделать их заново из ничего нельзя.
      //
      // `local_path` переносится НАМЕРЕННО, хотя путь абсолютный и на новом
      // устройстве недействителен: восстановление перепривязывает его по имени
      // файла (`_rebaseStickerLocalPaths`). Выбросить столбец было бы хуже —
      // тогда нечего перепривязывать, и наборы остались бы пустыми.
      'sticker_packs': <String>{
        'pack_id',
        'pack_version',
        'title',
        'description',
        'icon_sticker_id',
        'icon_emoji_hint',
        'featured_rank',
        'tags_json',
        'installed',
        'sticker_count',
        'updated_at_ms',
        'installed_at_ms',
        // Режим доступа обязан переживать восстановление: иначе человек, назвавший
        // набор личным, получил бы его обратно в режиме по умолчанию — то есть
        // копия молча расширила бы доступ к его картинкам.
        'share_mode',
      },
      'sticker_pack_stickers': <String>{
        'pack_id',
        'pack_version',
        'sticker_id',
        'file_name',
        'local_path',
        'format',
        'animated',
        'emoji_hint',
        'label',
        'keywords_json',
        'sha256_b64',
        'size_bytes',
        'downloaded_at_ms',
        'last_accessed_at_ms',
      },
    };

const List<String> kSafeBackupSnapshotTables = <String>[
  'conversations',
  'contacts',
  'events',
  'requests',
  'blocked_profiles',
  'profile_meta',
  'message_reactions',
  'group_members',
  'group_settings',
  'group_memberships',
  'group_admins',
  'group_invite_links',
  'room_message_receipts',
  'group_posting_state',
  'attachments',
  'sticker_packs',
  'sticker_pack_stickers',
];

/// Столбцы, которые ОСОЗНАННО не едут в копию.
///
/// 🔴 ЗАЧЕМ ОТДЕЛЬНЫЙ СПИСОК, А НЕ ПРОСТО ОТСУТСТВИЕ В КОНТРАКТЕ (09.08.2026).
/// Экспорт делает `SELECT *` и падает на столбце, которого нет в контракте — это
/// защита, и терять её нельзя: она заставляет человека РЕШИТЬ про каждый новый
/// столбец, вместо того чтобы тот молча уехал в копию.
///
/// Но у решения «не переносить» до сих пор не было способа выразиться: столбец,
/// про который решили «не надо», выглядел точно как забытый — и валил создание
/// копии целиком. Именно это и случилось со кэшем блоба стикеров (схема v66):
/// столбцы добавили, в контракт осознанно не внесли, и копия перестала
/// создаваться.
///
/// Теперь различие явное: **нет ни в одном списке — ошибка; здесь — не едет.**
const Map<String, Set<String>> kSafeBackupSnapshotExcludedColumnsByTable =
    <String, Set<String>>{
      // Кэш выгруженного блоба стикера. Это состояние СЕРВЕРА со сроком жизни и
      // токеном доступа: перенос на другую установку дал бы указатели на,
      // возможно, истёкшие объекты. Сам файл стикера в копии есть, а блоб
      // выгрузится заново по требованию.
      'sticker_pack_stickers': <String>{
        'blob_id',
        'blob_file_key_b64',
        'blob_access_token_b64',
        'blob_expires_at_ms',
      },
    };

bool isValidSafeBackupSnapshotScalar(Object? value) {
  return value == null || value is String || value is num || value is bool;
}
