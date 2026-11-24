// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ignore_for_file: constant_identifier_names

/// Значки, которые на iPhone рисуются в стиле iOS (SF Symbols через
/// `CupertinoIcons`), а на Android и компьютере — прежними Material.
///
/// 🔴 ЗАЧЕМ ОТДЕЛЬНЫЙ КЛАСС (20.11.2026). В мобильной части ~540 мест брали
/// значки Material напрямую (`Icons.lock_rounded`), и на iPhone они выглядели
/// по-андроидному рядом со значками iOS из [AppIcons]. Переписать каждое место
/// на «если iPhone — одно, иначе другое» значило бы потерять `const` и
/// размножить ветвления. Здесь каждое имя — ТО ЖЕ, что в `Icons`, а значение —
/// [AdaptiveIconData]: константа, которая при отрисовке отдаёт знак своей
/// платформы. Экраны меняются одной заменой `Icons.` → `AdaptiveIcons.`.
///
/// Соответствия подобраны по смыслу, а не по имени: заполненный значок
/// Material — заполненный знак iOS, контурный — контурный. Анимированные
/// значки (Lottie, AnimatedIcon) здесь не участвуют.
///
/// Сокращение шрифтов при сборке (icon tree-shaking) работает: обе константы
/// внутри каждой записи — обычные `IconData` из `Icons` и `CupertinoIcons`.
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// Значки iOS на iPhone. Выключатель — мгновенный откат к Material.
const bool kAppleSystemIcons = true;

bool get appleSystemIconsEnabled =>
    kAppleSystemIcons && defaultTargetPlatform == TargetPlatform.iOS;

/// Значок с двумя знаками: Material и iOS. Какой рисовать, решается при
/// отрисовке по платформе ([appleSystemIconsEnabled]).
@immutable
class AdaptiveIconData extends IconData {
  const AdaptiveIconData(this.material, this.cupertino) : super(0);

  final IconData material;
  final IconData cupertino;

  IconData get _active => appleSystemIconsEnabled ? cupertino : material;

  @override
  int get codePoint => _active.codePoint;

  @override
  String? get fontFamily => _active.fontFamily;

  @override
  String? get fontPackage => _active.fontPackage;

  @override
  bool get matchTextDirection => _active.matchTextDirection;

  @override
  List<String>? get fontFamilyFallback => _active.fontFamilyFallback;

  /// 🔴 Равенство — по знаку, который реально рисуется, а не по типу.
  /// Обычный `IconData.==` требует совпадения `runtimeType`, и тогда
  /// `AdaptiveIcons.lock_rounded == Icons.lock_rounded` было бы ложью даже на
  /// Android, где рисуется тот же знак: сломались бы сравнения в коде и поиск
  /// значка в тестах (`find.byIcon`).
  @override
  bool operator ==(Object other) =>
      other is IconData &&
      other.codePoint == codePoint &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage &&
      other.matchTextDirection == matchTextDirection &&
      listEquals(other.fontFamilyFallback, fontFamilyFallback);

  @override
  int get hashCode => Object.hash(
    codePoint,
    fontFamily,
    fontPackage,
    matchTextDirection,
    Object.hashAll(fontFamilyFallback ?? const <String>[]),
  );
}

abstract final class AdaptiveIcons {

  static const AdaptiveIconData account_circle_rounded = AdaptiveIconData(
    Icons.account_circle_rounded,
    CupertinoIcons.person_crop_circle_fill,
  );
  static const AdaptiveIconData add = AdaptiveIconData(
    Icons.add,
    CupertinoIcons.add,
  );
  static const AdaptiveIconData add_circle_outline_rounded = AdaptiveIconData(
    Icons.add_circle_outline_rounded,
    CupertinoIcons.plus_circle,
  );
  static const AdaptiveIconData add_circle_rounded = AdaptiveIconData(
    Icons.add_circle_rounded,
    CupertinoIcons.plus_circle_fill,
  );
  static const AdaptiveIconData add_photo_alternate_outlined = AdaptiveIconData(
    Icons.add_photo_alternate_outlined,
    CupertinoIcons.photo_on_rectangle,
  );
  static const AdaptiveIconData add_photo_alternate_rounded = AdaptiveIconData(
    Icons.add_photo_alternate_rounded,
    CupertinoIcons.photo_fill_on_rectangle_fill,
  );
  static const AdaptiveIconData add_reaction_outlined = AdaptiveIconData(
    Icons.add_reaction_outlined,
    CupertinoIcons.smiley,
  );
  static const AdaptiveIconData add_rounded = AdaptiveIconData(
    Icons.add_rounded,
    CupertinoIcons.add,
  );
  static const AdaptiveIconData admin_panel_settings_outlined = AdaptiveIconData(
    Icons.admin_panel_settings_outlined,
    CupertinoIcons.person_crop_circle_badge_checkmark,
  );
  static const AdaptiveIconData all_inclusive = AdaptiveIconData(
    Icons.all_inclusive,
    CupertinoIcons.infinite,
  );
  static const AdaptiveIconData alternate_email_rounded = AdaptiveIconData(
    Icons.alternate_email_rounded,
    CupertinoIcons.at,
  );
  static const AdaptiveIconData apps_rounded = AdaptiveIconData(
    Icons.apps_rounded,
    CupertinoIcons.square_grid_2x2,
  );
  static const AdaptiveIconData archive_outlined = AdaptiveIconData(
    Icons.archive_outlined,
    CupertinoIcons.archivebox,
  );
  static const AdaptiveIconData archive_rounded = AdaptiveIconData(
    Icons.archive_rounded,
    CupertinoIcons.archivebox_fill,
  );
  static const AdaptiveIconData arrow_back = AdaptiveIconData(
    Icons.arrow_back,
    CupertinoIcons.chevron_back,
  );
  static const AdaptiveIconData arrow_back_ios_new = AdaptiveIconData(
    Icons.arrow_back_ios_new,
    CupertinoIcons.chevron_back,
  );
  static const AdaptiveIconData arrow_back_ios_new_rounded = AdaptiveIconData(
    Icons.arrow_back_ios_new_rounded,
    CupertinoIcons.chevron_back,
  );
  static const AdaptiveIconData arrow_back_rounded = AdaptiveIconData(
    Icons.arrow_back_rounded,
    CupertinoIcons.chevron_back,
  );
  static const AdaptiveIconData arrow_upward_rounded = AdaptiveIconData(
    Icons.arrow_upward_rounded,
    CupertinoIcons.arrow_up,
  );
  static const AdaptiveIconData attach_file_rounded = AdaptiveIconData(
    Icons.attach_file_rounded,
    CupertinoIcons.paperclip,
  );
  static const AdaptiveIconData auto_awesome = AdaptiveIconData(
    Icons.auto_awesome,
    CupertinoIcons.sparkles,
  );
  static const AdaptiveIconData auto_awesome_outlined = AdaptiveIconData(
    Icons.auto_awesome_outlined,
    CupertinoIcons.sparkles,
  );
  static const AdaptiveIconData auto_awesome_rounded = AdaptiveIconData(
    Icons.auto_awesome_rounded,
    CupertinoIcons.sparkles,
  );
  static const AdaptiveIconData auto_fix_high_rounded = AdaptiveIconData(
    Icons.auto_fix_high_rounded,
    CupertinoIcons.wand_stars,
  );
  static const AdaptiveIconData auto_stories_rounded = AdaptiveIconData(
    Icons.auto_stories_rounded,
    CupertinoIcons.book_fill,
  );
  static const AdaptiveIconData autorenew_rounded = AdaptiveIconData(
    Icons.autorenew_rounded,
    CupertinoIcons.arrow_2_circlepath,
  );
  static const AdaptiveIconData battery_charging_full_rounded = AdaptiveIconData(
    Icons.battery_charging_full_rounded,
    CupertinoIcons.battery_charging,
  );
  static const AdaptiveIconData battery_saver_rounded = AdaptiveIconData(
    Icons.battery_saver_rounded,
    CupertinoIcons.battery_25,
  );
  static const AdaptiveIconData block = AdaptiveIconData(
    Icons.block,
    CupertinoIcons.nosign,
  );
  static const AdaptiveIconData block_rounded = AdaptiveIconData(
    Icons.block_rounded,
    CupertinoIcons.nosign,
  );
  static const AdaptiveIconData bluetooth_audio_rounded = AdaptiveIconData(
    Icons.bluetooth_audio_rounded,
    CupertinoIcons.bluetooth,
  );
  static const AdaptiveIconData bolt_rounded = AdaptiveIconData(
    Icons.bolt_rounded,
    CupertinoIcons.bolt_fill,
  );
  static const AdaptiveIconData border_outer_rounded = AdaptiveIconData(
    Icons.border_outer_rounded,
    CupertinoIcons.square,
  );
  static const AdaptiveIconData broken_image_outlined = AdaptiveIconData(
    Icons.broken_image_outlined,
    CupertinoIcons.photo,
  );
  static const AdaptiveIconData brush_rounded = AdaptiveIconData(
    Icons.brush_rounded,
    CupertinoIcons.paintbrush_fill,
  );
  static const AdaptiveIconData call_end_rounded = AdaptiveIconData(
    Icons.call_end_rounded,
    CupertinoIcons.phone_down_fill,
  );
  static const AdaptiveIconData call_made_rounded = AdaptiveIconData(
    Icons.call_made_rounded,
    CupertinoIcons.phone_arrow_up_right,
  );
  static const AdaptiveIconData call_received_rounded = AdaptiveIconData(
    Icons.call_received_rounded,
    CupertinoIcons.phone_arrow_down_left,
  );
  static const AdaptiveIconData call_rounded = AdaptiveIconData(
    Icons.call_rounded,
    CupertinoIcons.phone_fill,
  );
  static const AdaptiveIconData cameraswitch_outlined = AdaptiveIconData(
    Icons.cameraswitch_outlined,
    CupertinoIcons.camera_rotate,
  );
  static const AdaptiveIconData cameraswitch_rounded = AdaptiveIconData(
    Icons.cameraswitch_rounded,
    CupertinoIcons.camera_rotate_fill,
  );
  static const AdaptiveIconData cancel = AdaptiveIconData(
    Icons.cancel,
    CupertinoIcons.xmark_circle_fill,
  );
  static const AdaptiveIconData cancel_presentation = AdaptiveIconData(
    Icons.cancel_presentation,
    CupertinoIcons.xmark_rectangle,
  );
  static const AdaptiveIconData chat_bubble_outline_rounded = AdaptiveIconData(
    Icons.chat_bubble_outline_rounded,
    CupertinoIcons.chat_bubble,
  );
  static const AdaptiveIconData chat_bubble_rounded = AdaptiveIconData(
    Icons.chat_bubble_rounded,
    CupertinoIcons.chat_bubble_fill,
  );
  static const AdaptiveIconData check = AdaptiveIconData(
    Icons.check,
    CupertinoIcons.checkmark_alt,
  );
  static const AdaptiveIconData check_circle_outline_rounded = AdaptiveIconData(
    Icons.check_circle_outline_rounded,
    CupertinoIcons.checkmark_circle,
  );
  static const AdaptiveIconData check_circle_rounded = AdaptiveIconData(
    Icons.check_circle_rounded,
    CupertinoIcons.checkmark_circle_fill,
  );
  static const AdaptiveIconData check_rounded = AdaptiveIconData(
    Icons.check_rounded,
    CupertinoIcons.checkmark_alt,
  );
  static const AdaptiveIconData chevron_left_rounded = AdaptiveIconData(
    Icons.chevron_left_rounded,
    CupertinoIcons.chevron_left,
  );
  static const AdaptiveIconData chevron_right = AdaptiveIconData(
    Icons.chevron_right,
    CupertinoIcons.chevron_right,
  );
  static const AdaptiveIconData chevron_right_rounded = AdaptiveIconData(
    Icons.chevron_right_rounded,
    CupertinoIcons.chevron_right,
  );
  static const AdaptiveIconData circle = AdaptiveIconData(
    Icons.circle,
    CupertinoIcons.circle_fill,
  );
  static const AdaptiveIconData cleaning_services_rounded = AdaptiveIconData(
    Icons.cleaning_services_rounded,
    CupertinoIcons.trash,
  );
  static const AdaptiveIconData close = AdaptiveIconData(
    Icons.close,
    CupertinoIcons.xmark,
  );
  static const AdaptiveIconData close_rounded = AdaptiveIconData(
    Icons.close_rounded,
    CupertinoIcons.xmark,
  );
  static const AdaptiveIconData cloud_done_rounded = AdaptiveIconData(
    Icons.cloud_done_rounded,
    CupertinoIcons.cloud_fill,
  );
  static const AdaptiveIconData cloud_off_rounded = AdaptiveIconData(
    Icons.cloud_off_rounded,
    CupertinoIcons.cloud,
  );
  static const AdaptiveIconData cloud_queue_rounded = AdaptiveIconData(
    Icons.cloud_queue_rounded,
    CupertinoIcons.cloud,
  );
  static const AdaptiveIconData cloud_upload_rounded = AdaptiveIconData(
    Icons.cloud_upload_rounded,
    CupertinoIcons.cloud_upload_fill,
  );
  static const AdaptiveIconData contacts_rounded = AdaptiveIconData(
    Icons.contacts_rounded,
    CupertinoIcons.person_2_square_stack_fill,
  );
  static const AdaptiveIconData content_cut_rounded = AdaptiveIconData(
    Icons.content_cut_rounded,
    CupertinoIcons.scissors,
  );
  static const AdaptiveIconData content_paste_rounded = AdaptiveIconData(
    Icons.content_paste_rounded,
    CupertinoIcons.doc_on_clipboard,
  );
  static const AdaptiveIconData copy_all_rounded = AdaptiveIconData(
    Icons.copy_all_rounded,
    CupertinoIcons.doc_on_doc,
  );
  static const AdaptiveIconData copy_rounded = AdaptiveIconData(
    Icons.copy_rounded,
    CupertinoIcons.doc_on_doc,
  );
  static const AdaptiveIconData create_new_folder_outlined = AdaptiveIconData(
    Icons.create_new_folder_outlined,
    CupertinoIcons.folder_badge_plus,
  );
  static const AdaptiveIconData crop = AdaptiveIconData(
    Icons.crop,
    CupertinoIcons.crop,
  );
  static const AdaptiveIconData crop_rounded = AdaptiveIconData(
    Icons.crop_rounded,
    CupertinoIcons.crop,
  );
  static const AdaptiveIconData data_saver_on_rounded = AdaptiveIconData(
    Icons.data_saver_on_rounded,
    CupertinoIcons.gauge,
  );
  static const AdaptiveIconData delete_forever_rounded = AdaptiveIconData(
    Icons.delete_forever_rounded,
    CupertinoIcons.trash_fill,
  );
  static const AdaptiveIconData delete_outline_rounded = AdaptiveIconData(
    Icons.delete_outline_rounded,
    CupertinoIcons.trash,
  );
  static const AdaptiveIconData delete_sweep_rounded = AdaptiveIconData(
    Icons.delete_sweep_rounded,
    CupertinoIcons.trash,
  );
  static const AdaptiveIconData desktop_windows_rounded = AdaptiveIconData(
    Icons.desktop_windows_rounded,
    CupertinoIcons.device_desktop,
  );
  static const AdaptiveIconData devices_other_rounded = AdaptiveIconData(
    Icons.devices_other_rounded,
    CupertinoIcons.device_laptop,
  );
  static const AdaptiveIconData devices_rounded = AdaptiveIconData(
    Icons.devices_rounded,
    CupertinoIcons.device_laptop,
  );
  static const AdaptiveIconData diversity_3_rounded = AdaptiveIconData(
    Icons.diversity_3_rounded,
    CupertinoIcons.person_3_fill,
  );
  static const AdaptiveIconData done_all = AdaptiveIconData(
    Icons.done_all,
    CupertinoIcons.checkmark_alt,
  );
  static const AdaptiveIconData download_rounded = AdaptiveIconData(
    Icons.download_rounded,
    CupertinoIcons.arrow_down_to_line,
  );
  static const AdaptiveIconData drag_indicator = AdaptiveIconData(
    Icons.drag_indicator,
    CupertinoIcons.line_horizontal_3,
  );
  static const AdaptiveIconData edit_off_outlined = AdaptiveIconData(
    Icons.edit_off_outlined,
    CupertinoIcons.pencil_slash,
  );
  static const AdaptiveIconData edit_outlined = AdaptiveIconData(
    Icons.edit_outlined,
    CupertinoIcons.pencil,
  );
  static const AdaptiveIconData edit_rounded = AdaptiveIconData(
    Icons.edit_rounded,
    CupertinoIcons.pencil,
  );
  static const AdaptiveIconData electric_bolt = AdaptiveIconData(
    Icons.electric_bolt,
    CupertinoIcons.bolt_fill,
  );
  static const AdaptiveIconData emoji_emotions_outlined = AdaptiveIconData(
    Icons.emoji_emotions_outlined,
    CupertinoIcons.smiley,
  );
  static const AdaptiveIconData emoji_emotions_rounded = AdaptiveIconData(
    Icons.emoji_emotions_rounded,
    CupertinoIcons.smiley_fill,
  );
  static const AdaptiveIconData error_outline_rounded = AdaptiveIconData(
    Icons.error_outline_rounded,
    CupertinoIcons.exclamationmark_circle,
  );
  static const AdaptiveIconData expand_less_rounded = AdaptiveIconData(
    Icons.expand_less_rounded,
    CupertinoIcons.chevron_up,
  );
  static const AdaptiveIconData expand_more_rounded = AdaptiveIconData(
    Icons.expand_more_rounded,
    CupertinoIcons.chevron_down,
  );
  static const AdaptiveIconData face_retouching_natural = AdaptiveIconData(
    Icons.face_retouching_natural,
    CupertinoIcons.wand_stars,
  );
  static const AdaptiveIconData face_retouching_natural_rounded = AdaptiveIconData(
    Icons.face_retouching_natural_rounded,
    CupertinoIcons.wand_stars,
  );
  static const AdaptiveIconData fiber_manual_record_rounded = AdaptiveIconData(
    Icons.fiber_manual_record_rounded,
    CupertinoIcons.circle_fill,
  );
  static const AdaptiveIconData filter_frames_rounded = AdaptiveIconData(
    Icons.filter_frames_rounded,
    CupertinoIcons.square_on_square,
  );
  static const AdaptiveIconData fingerprint = AdaptiveIconData(
    Icons.fingerprint,
    CupertinoIcons.lock_shield,
  );
  static const AdaptiveIconData fingerprint_rounded = AdaptiveIconData(
    Icons.fingerprint_rounded,
    CupertinoIcons.lock_shield,
  );
  static const AdaptiveIconData flag_rounded = AdaptiveIconData(
    Icons.flag_rounded,
    CupertinoIcons.flag_fill,
  );
  static const AdaptiveIconData flash_off_rounded = AdaptiveIconData(
    Icons.flash_off_rounded,
    CupertinoIcons.bolt_slash_fill,
  );
  static const AdaptiveIconData flash_on_rounded = AdaptiveIconData(
    Icons.flash_on_rounded,
    CupertinoIcons.bolt_fill,
  );
  static const AdaptiveIconData folder_rounded = AdaptiveIconData(
    Icons.folder_rounded,
    CupertinoIcons.folder_fill,
  );
  static const AdaptiveIconData folder_special_rounded = AdaptiveIconData(
    Icons.folder_special_rounded,
    CupertinoIcons.folder_fill,
  );
  static const AdaptiveIconData format_color_fill_rounded = AdaptiveIconData(
    Icons.format_color_fill_rounded,
    CupertinoIcons.drop_fill,
  );
  static const AdaptiveIconData forum_rounded = AdaptiveIconData(
    Icons.forum_rounded,
    CupertinoIcons.bubble_left_bubble_right_fill,
  );
  static const AdaptiveIconData forward_rounded = AdaptiveIconData(
    Icons.forward_rounded,
    CupertinoIcons.arrowshape_turn_up_right_fill,
  );
  static const AdaptiveIconData g_translate = AdaptiveIconData(
    Icons.g_translate,
    CupertinoIcons.globe,
  );
  static const AdaptiveIconData gpp_maybe_rounded = AdaptiveIconData(
    Icons.gpp_maybe_rounded,
    CupertinoIcons.exclamationmark_shield,
  );
  static const AdaptiveIconData grid_view_rounded = AdaptiveIconData(
    Icons.grid_view_rounded,
    CupertinoIcons.square_grid_2x2,
  );
  static const AdaptiveIconData group_off_rounded = AdaptiveIconData(
    Icons.group_off_rounded,
    CupertinoIcons.person_2,
  );
  static const AdaptiveIconData group_outlined = AdaptiveIconData(
    Icons.group_outlined,
    CupertinoIcons.person_2,
  );
  static const AdaptiveIconData group_rounded = AdaptiveIconData(
    Icons.group_rounded,
    CupertinoIcons.person_2_fill,
  );
  static const AdaptiveIconData groups_rounded = AdaptiveIconData(
    Icons.groups_rounded,
    CupertinoIcons.person_3_fill,
  );
  static const AdaptiveIconData headphones_rounded = AdaptiveIconData(
    Icons.headphones_rounded,
    CupertinoIcons.headphones,
  );
  static const AdaptiveIconData health_and_safety_outlined = AdaptiveIconData(
    Icons.health_and_safety_outlined,
    CupertinoIcons.shield,
  );
  static const AdaptiveIconData help_outline_rounded = AdaptiveIconData(
    Icons.help_outline_rounded,
    CupertinoIcons.question_circle,
  );
  static const AdaptiveIconData highlight_rounded = AdaptiveIconData(
    Icons.highlight_rounded,
    CupertinoIcons.pencil_outline,
  );
  static const AdaptiveIconData history_rounded = AdaptiveIconData(
    Icons.history_rounded,
    CupertinoIcons.clock_fill,
  );
  static const AdaptiveIconData history_toggle_off_rounded = AdaptiveIconData(
    Icons.history_toggle_off_rounded,
    CupertinoIcons.clock,
  );
  static const AdaptiveIconData hourglass_top_rounded = AdaptiveIconData(
    Icons.hourglass_top_rounded,
    CupertinoIcons.hourglass_tophalf_fill,
  );
  static const AdaptiveIconData image_not_supported_outlined = AdaptiveIconData(
    Icons.image_not_supported_outlined,
    CupertinoIcons.photo,
  );
  static const AdaptiveIconData image_outlined = AdaptiveIconData(
    Icons.image_outlined,
    CupertinoIcons.photo,
  );
  static const AdaptiveIconData info_outline = AdaptiveIconData(
    Icons.info_outline,
    CupertinoIcons.info_circle,
  );
  static const AdaptiveIconData info_outline_rounded = AdaptiveIconData(
    Icons.info_outline_rounded,
    CupertinoIcons.info_circle,
  );
  static const AdaptiveIconData info_rounded = AdaptiveIconData(
    Icons.info_rounded,
    CupertinoIcons.info_circle_fill,
  );
  static const AdaptiveIconData insert_drive_file_rounded = AdaptiveIconData(
    Icons.insert_drive_file_rounded,
    CupertinoIcons.doc_fill,
  );
  static const AdaptiveIconData insights_rounded = AdaptiveIconData(
    Icons.insights_rounded,
    CupertinoIcons.chart_bar_alt_fill,
  );
  static const AdaptiveIconData ios_share_rounded = AdaptiveIconData(
    Icons.ios_share_rounded,
    CupertinoIcons.square_arrow_up,
  );
  static const AdaptiveIconData key_rounded = AdaptiveIconData(
    Icons.key_rounded,
    CupertinoIcons.lock_rotation,
  );
  static const AdaptiveIconData keyboard_arrow_down = AdaptiveIconData(
    Icons.keyboard_arrow_down,
    CupertinoIcons.chevron_down,
  );
  static const AdaptiveIconData keyboard_arrow_down_rounded = AdaptiveIconData(
    Icons.keyboard_arrow_down_rounded,
    CupertinoIcons.chevron_down,
  );
  static const AdaptiveIconData keyboard_arrow_up_rounded = AdaptiveIconData(
    Icons.keyboard_arrow_up_rounded,
    CupertinoIcons.chevron_up,
  );
  static const AdaptiveIconData keyboard_voice_rounded = AdaptiveIconData(
    Icons.keyboard_voice_rounded,
    CupertinoIcons.mic_fill,
  );
  static const AdaptiveIconData language = AdaptiveIconData(
    Icons.language,
    CupertinoIcons.globe,
  );
  static const AdaptiveIconData language_rounded = AdaptiveIconData(
    Icons.language_rounded,
    CupertinoIcons.globe,
  );
  static const AdaptiveIconData laptop_rounded = AdaptiveIconData(
    Icons.laptop_rounded,
    CupertinoIcons.device_laptop,
  );
  static const AdaptiveIconData lightbulb_outline_rounded = AdaptiveIconData(
    Icons.lightbulb_outline_rounded,
    CupertinoIcons.lightbulb,
  );
  static const AdaptiveIconData lightbulb_rounded = AdaptiveIconData(
    Icons.lightbulb_rounded,
    CupertinoIcons.lightbulb_fill,
  );
  static const AdaptiveIconData link_off_rounded = AdaptiveIconData(
    Icons.link_off_rounded,
    CupertinoIcons.link,
  );
  static const AdaptiveIconData link_rounded = AdaptiveIconData(
    Icons.link_rounded,
    CupertinoIcons.link,
  );
  static const AdaptiveIconData lock = AdaptiveIconData(
    Icons.lock,
    CupertinoIcons.lock_fill,
  );
  static const AdaptiveIconData lock_clock_rounded = AdaptiveIconData(
    Icons.lock_clock_rounded,
    CupertinoIcons.lock,
  );
  static const AdaptiveIconData lock_open_rounded = AdaptiveIconData(
    Icons.lock_open_rounded,
    CupertinoIcons.lock_open_fill,
  );
  static const AdaptiveIconData lock_outline = AdaptiveIconData(
    Icons.lock_outline,
    CupertinoIcons.lock,
  );
  static const AdaptiveIconData lock_outline_rounded = AdaptiveIconData(
    Icons.lock_outline_rounded,
    CupertinoIcons.lock,
  );
  static const AdaptiveIconData lock_reset_rounded = AdaptiveIconData(
    Icons.lock_reset_rounded,
    CupertinoIcons.lock_rotation,
  );
  static const AdaptiveIconData lock_rounded = AdaptiveIconData(
    Icons.lock_rounded,
    CupertinoIcons.lock_fill,
  );
  static const AdaptiveIconData login = AdaptiveIconData(
    Icons.login,
    CupertinoIcons.square_arrow_left,
  );
  static const AdaptiveIconData login_rounded = AdaptiveIconData(
    Icons.login_rounded,
    CupertinoIcons.square_arrow_left,
  );
  static const AdaptiveIconData logout_rounded = AdaptiveIconData(
    Icons.logout_rounded,
    CupertinoIcons.square_arrow_right,
  );
  static const AdaptiveIconData manage_search_rounded = AdaptiveIconData(
    Icons.manage_search_rounded,
    CupertinoIcons.doc_text_search,
  );
  static const AdaptiveIconData mark_chat_unread_rounded = AdaptiveIconData(
    Icons.mark_chat_unread_rounded,
    CupertinoIcons.chat_bubble_text_fill,
  );
  static const AdaptiveIconData message_rounded = AdaptiveIconData(
    Icons.message_rounded,
    CupertinoIcons.chat_bubble_text_fill,
  );
  static const AdaptiveIconData mic_none_rounded = AdaptiveIconData(
    Icons.mic_none_rounded,
    CupertinoIcons.mic,
  );
  static const AdaptiveIconData mic_off_rounded = AdaptiveIconData(
    Icons.mic_off_rounded,
    CupertinoIcons.mic_slash_fill,
  );
  static const AdaptiveIconData mic_rounded = AdaptiveIconData(
    Icons.mic_rounded,
    CupertinoIcons.mic_fill,
  );
  static const AdaptiveIconData more_horiz_rounded = AdaptiveIconData(
    Icons.more_horiz_rounded,
    CupertinoIcons.ellipsis,
  );
  static const AdaptiveIconData more_vert_rounded = AdaptiveIconData(
    Icons.more_vert_rounded,
    CupertinoIcons.ellipsis_vertical,
  );
  static const AdaptiveIconData motion_photos_on = AdaptiveIconData(
    Icons.motion_photos_on,
    CupertinoIcons.smallcircle_circle,
  );
  static const AdaptiveIconData move_to_inbox_rounded = AdaptiveIconData(
    Icons.move_to_inbox_rounded,
    CupertinoIcons.tray_arrow_down,
  );
  static const AdaptiveIconData movie_creation_rounded = AdaptiveIconData(
    Icons.movie_creation_rounded,
    CupertinoIcons.film,
  );
  static const AdaptiveIconData music_note_rounded = AdaptiveIconData(
    Icons.music_note_rounded,
    CupertinoIcons.music_note,
  );
  static const AdaptiveIconData network_check_rounded = AdaptiveIconData(
    Icons.network_check_rounded,
    CupertinoIcons.speedometer,
  );
  static const AdaptiveIconData no_encryption_gmailerrorred_rounded = AdaptiveIconData(
    Icons.no_encryption_gmailerrorred_rounded,
    CupertinoIcons.lock_slash,
  );
  static const AdaptiveIconData north_east_rounded = AdaptiveIconData(
    Icons.north_east_rounded,
    CupertinoIcons.arrow_up_right,
  );
  static const AdaptiveIconData notes_rounded = AdaptiveIconData(
    Icons.notes_rounded,
    CupertinoIcons.text_alignleft,
  );
  static const AdaptiveIconData notification_important_rounded = AdaptiveIconData(
    Icons.notification_important_rounded,
    CupertinoIcons.bell_fill,
  );
  static const AdaptiveIconData notifications_active_rounded = AdaptiveIconData(
    Icons.notifications_active_rounded,
    CupertinoIcons.bell_fill,
  );
  static const AdaptiveIconData notifications_off_outlined = AdaptiveIconData(
    Icons.notifications_off_outlined,
    CupertinoIcons.bell_slash,
  );
  static const AdaptiveIconData notifications_off_rounded = AdaptiveIconData(
    Icons.notifications_off_rounded,
    CupertinoIcons.bell_slash_fill,
  );
  static const AdaptiveIconData notifications_outlined = AdaptiveIconData(
    Icons.notifications_outlined,
    CupertinoIcons.bell,
  );
  static const AdaptiveIconData notifications_rounded = AdaptiveIconData(
    Icons.notifications_rounded,
    CupertinoIcons.bell_fill,
  );
  static const AdaptiveIconData open_in_full_rounded = AdaptiveIconData(
    Icons.open_in_full_rounded,
    CupertinoIcons.arrow_up_left_arrow_down_right,
  );
  static const AdaptiveIconData open_in_new_rounded = AdaptiveIconData(
    Icons.open_in_new_rounded,
    CupertinoIcons.arrow_up_right_square,
  );
  static const AdaptiveIconData outbox_rounded = AdaptiveIconData(
    Icons.outbox_rounded,
    CupertinoIcons.tray_arrow_up,
  );
  static const AdaptiveIconData palette_rounded = AdaptiveIconData(
    Icons.palette_rounded,
    CupertinoIcons.paintbrush,
  );
  static const AdaptiveIconData password_rounded = AdaptiveIconData(
    Icons.password_rounded,
    CupertinoIcons.lock_rotation,
  );
  static const AdaptiveIconData pause = AdaptiveIconData(
    Icons.pause,
    CupertinoIcons.pause_fill,
  );
  static const AdaptiveIconData pause_rounded = AdaptiveIconData(
    Icons.pause_rounded,
    CupertinoIcons.pause_fill,
  );
  static const AdaptiveIconData pending_actions_rounded = AdaptiveIconData(
    Icons.pending_actions_rounded,
    CupertinoIcons.hourglass,
  );
  static const AdaptiveIconData person_add_alt_1_rounded = AdaptiveIconData(
    Icons.person_add_alt_1_rounded,
    CupertinoIcons.person_badge_plus_fill,
  );
  static const AdaptiveIconData person_add_outlined = AdaptiveIconData(
    Icons.person_add_outlined,
    CupertinoIcons.person_badge_plus,
  );
  static const AdaptiveIconData person_outline_rounded = AdaptiveIconData(
    Icons.person_outline_rounded,
    CupertinoIcons.person,
  );
  static const AdaptiveIconData person_remove_outlined = AdaptiveIconData(
    Icons.person_remove_outlined,
    CupertinoIcons.person_badge_minus,
  );
  static const AdaptiveIconData person_remove_rounded = AdaptiveIconData(
    Icons.person_remove_rounded,
    CupertinoIcons.person_badge_minus_fill,
  );
  static const AdaptiveIconData person_rounded = AdaptiveIconData(
    Icons.person_rounded,
    CupertinoIcons.person_fill,
  );
  static const AdaptiveIconData phone_in_talk_rounded = AdaptiveIconData(
    Icons.phone_in_talk_rounded,
    CupertinoIcons.phone_fill,
  );
  static const AdaptiveIconData phone_locked_rounded = AdaptiveIconData(
    Icons.phone_locked_rounded,
    CupertinoIcons.phone_fill,
  );
  static const AdaptiveIconData phone_rounded = AdaptiveIconData(
    Icons.phone_rounded,
    CupertinoIcons.phone_fill,
  );
  static const AdaptiveIconData phonelink_off_rounded = AdaptiveIconData(
    Icons.phonelink_off_rounded,
    CupertinoIcons.device_phone_portrait,
  );
  static const AdaptiveIconData photo_camera_rounded = AdaptiveIconData(
    Icons.photo_camera_rounded,
    CupertinoIcons.camera_fill,
  );
  static const AdaptiveIconData photo_library_rounded = AdaptiveIconData(
    Icons.photo_library_rounded,
    CupertinoIcons.photo_on_rectangle,
  );
  static const AdaptiveIconData photo_outlined = AdaptiveIconData(
    Icons.photo_outlined,
    CupertinoIcons.photo,
  );
  static const AdaptiveIconData photo_rounded = AdaptiveIconData(
    Icons.photo_rounded,
    CupertinoIcons.photo_fill,
  );
  static const AdaptiveIconData play_arrow = AdaptiveIconData(
    Icons.play_arrow,
    CupertinoIcons.play_fill,
  );
  static const AdaptiveIconData play_arrow_rounded = AdaptiveIconData(
    Icons.play_arrow_rounded,
    CupertinoIcons.play_fill,
  );
  static const AdaptiveIconData play_circle_fill_rounded = AdaptiveIconData(
    Icons.play_circle_fill_rounded,
    CupertinoIcons.play_circle_fill,
  );
  static const AdaptiveIconData present_to_all = AdaptiveIconData(
    Icons.present_to_all,
    CupertinoIcons.rectangle_on_rectangle,
  );
  static const AdaptiveIconData privacy_tip_rounded = AdaptiveIconData(
    Icons.privacy_tip_rounded,
    CupertinoIcons.exclamationmark_shield_fill,
  );
  static const AdaptiveIconData public_rounded = AdaptiveIconData(
    Icons.public_rounded,
    CupertinoIcons.globe,
  );
  static const AdaptiveIconData qr_code_2_rounded = AdaptiveIconData(
    Icons.qr_code_2_rounded,
    CupertinoIcons.qrcode,
  );
  static const AdaptiveIconData qr_code_scanner_rounded = AdaptiveIconData(
    Icons.qr_code_scanner_rounded,
    CupertinoIcons.qrcode_viewfinder,
  );
  static const AdaptiveIconData queue_music_rounded = AdaptiveIconData(
    Icons.queue_music_rounded,
    CupertinoIcons.music_note_list,
  );
  static const AdaptiveIconData radio_button_checked_rounded = AdaptiveIconData(
    Icons.radio_button_checked_rounded,
    CupertinoIcons.largecircle_fill_circle,
  );
  static const AdaptiveIconData radio_button_off_rounded = AdaptiveIconData(
    Icons.radio_button_off_rounded,
    CupertinoIcons.circle,
  );
  static const AdaptiveIconData radio_button_unchecked = AdaptiveIconData(
    Icons.radio_button_unchecked,
    CupertinoIcons.circle,
  );
  static const AdaptiveIconData radio_button_unchecked_rounded = AdaptiveIconData(
    Icons.radio_button_unchecked_rounded,
    CupertinoIcons.circle,
  );
  static const AdaptiveIconData record_voice_over_rounded = AdaptiveIconData(
    Icons.record_voice_over_rounded,
    CupertinoIcons.waveform,
  );
  static const AdaptiveIconData redo_rounded = AdaptiveIconData(
    Icons.redo_rounded,
    CupertinoIcons.arrow_uturn_right,
  );
  static const AdaptiveIconData refresh_rounded = AdaptiveIconData(
    Icons.refresh_rounded,
    CupertinoIcons.arrow_clockwise,
  );
  static const AdaptiveIconData remove_circle_outline_rounded = AdaptiveIconData(
    Icons.remove_circle_outline_rounded,
    CupertinoIcons.minus_circle,
  );
  static const AdaptiveIconData restore_rounded = AdaptiveIconData(
    Icons.restore_rounded,
    CupertinoIcons.arrow_counterclockwise,
  );
  static const AdaptiveIconData rocket_launch_rounded = AdaptiveIconData(
    Icons.rocket_launch_rounded,
    CupertinoIcons.rocket_fill,
  );
  static const AdaptiveIconData rotate_right_rounded = AdaptiveIconData(
    Icons.rotate_right_rounded,
    CupertinoIcons.rotate_right,
  );
  static const AdaptiveIconData save_alt_rounded = AdaptiveIconData(
    Icons.save_alt_rounded,
    CupertinoIcons.arrow_down_to_line,
  );
  static const AdaptiveIconData schedule_rounded = AdaptiveIconData(
    Icons.schedule_rounded,
    CupertinoIcons.clock,
  );
  static const AdaptiveIconData screen_share_rounded = AdaptiveIconData(
    Icons.screen_share_rounded,
    CupertinoIcons.rectangle_on_rectangle,
  );
  static const AdaptiveIconData search = AdaptiveIconData(
    Icons.search,
    CupertinoIcons.search,
  );
  static const AdaptiveIconData search_rounded = AdaptiveIconData(
    Icons.search_rounded,
    CupertinoIcons.search,
  );
  static const AdaptiveIconData security_rounded = AdaptiveIconData(
    Icons.security_rounded,
    CupertinoIcons.shield_lefthalf_fill,
  );
  static const AdaptiveIconData send = AdaptiveIconData(
    Icons.send,
    CupertinoIcons.paperplane_fill,
  );
  static const AdaptiveIconData send_rounded = AdaptiveIconData(
    Icons.send_rounded,
    CupertinoIcons.paperplane_fill,
  );
  static const AdaptiveIconData settings_outlined = AdaptiveIconData(
    Icons.settings_outlined,
    CupertinoIcons.gear,
  );
  static const AdaptiveIconData share_outlined = AdaptiveIconData(
    Icons.share_outlined,
    CupertinoIcons.square_arrow_up,
  );
  static const AdaptiveIconData share_rounded = AdaptiveIconData(
    Icons.share_rounded,
    CupertinoIcons.square_arrow_up,
  );
  static const AdaptiveIconData shield_moon_rounded = AdaptiveIconData(
    Icons.shield_moon_rounded,
    CupertinoIcons.moon_stars_fill,
  );
  static const AdaptiveIconData shield_outlined = AdaptiveIconData(
    Icons.shield_outlined,
    CupertinoIcons.shield,
  );
  static const AdaptiveIconData shield_rounded = AdaptiveIconData(
    Icons.shield_rounded,
    CupertinoIcons.shield_fill,
  );
  static const AdaptiveIconData short_text_rounded = AdaptiveIconData(
    Icons.short_text_rounded,
    CupertinoIcons.text_alignleft,
  );
  static const AdaptiveIconData smart_display_rounded = AdaptiveIconData(
    Icons.smart_display_rounded,
    CupertinoIcons.play_rectangle_fill,
  );
  static const AdaptiveIconData smartphone_rounded = AdaptiveIconData(
    Icons.smartphone_rounded,
    CupertinoIcons.device_phone_portrait,
  );
  static const AdaptiveIconData star_outline_rounded = AdaptiveIconData(
    Icons.star_outline_rounded,
    CupertinoIcons.star,
  );
  static const AdaptiveIconData star_rounded = AdaptiveIconData(
    Icons.star_rounded,
    CupertinoIcons.star_fill,
  );
  static const AdaptiveIconData sticky_note_2_rounded = AdaptiveIconData(
    Icons.sticky_note_2_rounded,
    CupertinoIcons.doc_text_fill,
  );
  static const AdaptiveIconData stop_circle_outlined = AdaptiveIconData(
    Icons.stop_circle_outlined,
    CupertinoIcons.stop_circle,
  );
  static const AdaptiveIconData stop_rounded = AdaptiveIconData(
    Icons.stop_rounded,
    CupertinoIcons.stop_fill,
  );
  static const AdaptiveIconData subtitles_outlined = AdaptiveIconData(
    Icons.subtitles_outlined,
    CupertinoIcons.captions_bubble,
  );
  static const AdaptiveIconData support_agent_rounded = AdaptiveIconData(
    Icons.support_agent_rounded,
    CupertinoIcons.person_crop_circle_badge_exclam,
  );
  static const AdaptiveIconData swap_vert_rounded = AdaptiveIconData(
    Icons.swap_vert_rounded,
    CupertinoIcons.arrow_up_arrow_down,
  );
  static const AdaptiveIconData sync_alt_rounded = AdaptiveIconData(
    Icons.sync_alt_rounded,
    CupertinoIcons.arrow_right_arrow_left,
  );
  static const AdaptiveIconData sync_problem_rounded = AdaptiveIconData(
    Icons.sync_problem_rounded,
    CupertinoIcons.arrow_2_circlepath,
  );
  static const AdaptiveIconData sync_rounded = AdaptiveIconData(
    Icons.sync_rounded,
    CupertinoIcons.arrow_2_circlepath,
  );
  static const AdaptiveIconData tag_rounded = AdaptiveIconData(
    Icons.tag_rounded,
    CupertinoIcons.number,
  );
  static const AdaptiveIconData text_decrease_rounded = AdaptiveIconData(
    Icons.text_decrease_rounded,
    CupertinoIcons.textformat_size,
  );
  static const AdaptiveIconData text_fields = AdaptiveIconData(
    Icons.text_fields,
    CupertinoIcons.textformat,
  );
  static const AdaptiveIconData text_increase_rounded = AdaptiveIconData(
    Icons.text_increase_rounded,
    CupertinoIcons.textformat_size,
  );
  static const AdaptiveIconData timer_outlined = AdaptiveIconData(
    Icons.timer_outlined,
    CupertinoIcons.timer,
  );
  static const AdaptiveIconData title_rounded = AdaptiveIconData(
    Icons.title_rounded,
    CupertinoIcons.textformat,
  );
  static const AdaptiveIconData touch_app = AdaptiveIconData(
    Icons.touch_app,
    CupertinoIcons.hand_point_right,
  );
  static const AdaptiveIconData touch_app_rounded = AdaptiveIconData(
    Icons.touch_app_rounded,
    CupertinoIcons.hand_point_right,
  );
  static const AdaptiveIconData translate_rounded = AdaptiveIconData(
    Icons.translate_rounded,
    CupertinoIcons.globe,
  );
  static const AdaptiveIconData tune_rounded = AdaptiveIconData(
    Icons.tune_rounded,
    CupertinoIcons.slider_horizontal_3,
  );
  static const AdaptiveIconData unarchive_outlined = AdaptiveIconData(
    Icons.unarchive_outlined,
    CupertinoIcons.tray_arrow_up,
  );
  static const AdaptiveIconData undo_rounded = AdaptiveIconData(
    Icons.undo_rounded,
    CupertinoIcons.arrow_uturn_left,
  );
  static const AdaptiveIconData verified_rounded = AdaptiveIconData(
    Icons.verified_rounded,
    CupertinoIcons.checkmark_seal_fill,
  );
  static const AdaptiveIconData verified_user_rounded = AdaptiveIconData(
    Icons.verified_user_rounded,
    CupertinoIcons.checkmark_shield_fill,
  );
  static const AdaptiveIconData vibration_rounded = AdaptiveIconData(
    Icons.vibration_rounded,
    CupertinoIcons.device_phone_portrait,
  );
  static const AdaptiveIconData videocam_rounded = AdaptiveIconData(
    Icons.videocam_rounded,
    CupertinoIcons.video_camera_solid,
  );
  static const AdaptiveIconData visibility_off_outlined = AdaptiveIconData(
    Icons.visibility_off_outlined,
    CupertinoIcons.eye_slash,
  );
  static const AdaptiveIconData visibility_outlined = AdaptiveIconData(
    Icons.visibility_outlined,
    CupertinoIcons.eye,
  );
  static const AdaptiveIconData visibility_rounded = AdaptiveIconData(
    Icons.visibility_rounded,
    CupertinoIcons.eye_fill,
  );
  static const AdaptiveIconData volume_off_rounded = AdaptiveIconData(
    Icons.volume_off_rounded,
    CupertinoIcons.speaker_slash_fill,
  );
  static const AdaptiveIconData volume_up_rounded = AdaptiveIconData(
    Icons.volume_up_rounded,
    CupertinoIcons.speaker_2_fill,
  );
  static const AdaptiveIconData volunteer_activism_rounded = AdaptiveIconData(
    Icons.volunteer_activism_rounded,
    CupertinoIcons.heart_fill,
  );
  static const AdaptiveIconData vpn_lock_rounded = AdaptiveIconData(
    Icons.vpn_lock_rounded,
    CupertinoIcons.lock_shield,
  );
  static const AdaptiveIconData wallpaper_rounded = AdaptiveIconData(
    Icons.wallpaper_rounded,
    CupertinoIcons.photo_on_rectangle,
  );
  static const AdaptiveIconData warning_amber_rounded = AdaptiveIconData(
    Icons.warning_amber_rounded,
    CupertinoIcons.exclamationmark_triangle,
  );
  static const AdaptiveIconData wifi_off_rounded = AdaptiveIconData(
    Icons.wifi_off_rounded,
    CupertinoIcons.wifi_slash,
  );
  static const AdaptiveIconData workspace_premium_rounded = AdaptiveIconData(
    Icons.workspace_premium_rounded,
    CupertinoIcons.rosette,
  );
  static const AdaptiveIconData workspaces_rounded = AdaptiveIconData(
    Icons.workspaces_rounded,
    CupertinoIcons.circle_grid_3x3_fill,
  );
}
