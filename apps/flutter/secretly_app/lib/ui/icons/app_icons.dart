// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

/// SF-style icon mappings (Cupertino / Apple-like regular style).
class AppIcons {
  AppIcons._();

  // ── Navigation & tabs ──
  static const IconData chats = CupertinoIcons.chat_bubble_2;
  static const IconData chatsFilled = CupertinoIcons.chat_bubble_2_fill;
  static const IconData groups = CupertinoIcons.person_3;
  static const IconData groupsFilled = CupertinoIcons.person_3_fill;
  static const IconData profile = CupertinoIcons.person_crop_circle;
  static const IconData profileFilled = CupertinoIcons.person_crop_circle_fill;
  static const IconData contacts = CupertinoIcons.person_2;
  static const IconData contactsFilled = CupertinoIcons.person_2_fill;
  static const IconData settings = CupertinoIcons.gear;
  static const IconData settingsFilled = CupertinoIcons.gear_solid;

  // ── Actions ──
  static const IconData search = CupertinoIcons.search;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData closeCircle = CupertinoIcons.xmark_circle_fill;
  static const IconData add = CupertinoIcons.plus;
  static const IconData more = CupertinoIcons.ellipsis;
  static const IconData moreVert = CupertinoIcons.ellipsis_vertical;
  static const IconData menu = CupertinoIcons.line_horizontal_3;
  static const IconData favorites = CupertinoIcons.star;
  static const IconData send = CupertinoIcons.paperplane;
  static const IconData reply = CupertinoIcons.arrowshape_turn_up_left;
  static const IconData forward = CupertinoIcons.arrowshape_turn_up_right;
  static const IconData copy = CupertinoIcons.doc_on_doc_fill;
  static const IconData copyOutline = CupertinoIcons.doc_on_doc;
  static const IconData delete = CupertinoIcons.delete_solid;
  static const IconData edit = CupertinoIcons.pencil;
  static const IconData pin = CupertinoIcons.pin;
  static const IconData block = CupertinoIcons.nosign;
  static const IconData archive = CupertinoIcons.archivebox;
  static const IconData unarchive = CupertinoIcons.tray_arrow_up_fill;
  static const IconData refresh = CupertinoIcons.arrow_clockwise;

  // ── Navigation arrows ──
  static const IconData chevronRight = CupertinoIcons.chevron_right;
  static const IconData chevronDown = CupertinoIcons.chevron_down;
  static const IconData arrowBack = CupertinoIcons.chevron_back;
  // In-chat search navigation (prev/next match).
  static const IconData searchUp = CupertinoIcons.chevron_up;
  static const IconData searchDown = CupertinoIcons.chevron_down;

  // ── Theme ──
  static const IconData themeDark = CupertinoIcons.moon;
  static const IconData themeLight = CupertinoIcons.sun_max;

  // ── Users & contacts ──
  static const IconData createGroup = CupertinoIcons.person_3;
  static const IconData personOutline = CupertinoIcons.person;
  static const IconData personSolid = CupertinoIcons.person_fill;
  static const IconData personAdd = CupertinoIcons.person_add;
  static const IconData groupOutline = CupertinoIcons.person_3;

  // ── Chat ──
  static const IconData chatBubble = CupertinoIcons.chat_bubble_2;
  static const IconData chatBubbleSolid = CupertinoIcons.chat_bubble_2_fill;

  // ── Media ──
  static const IconData photo = CupertinoIcons.photo;
  static const IconData photoSolid = CupertinoIcons.photo_fill;
  static const IconData brokenImage = CupertinoIcons.exclamationmark_triangle;
  static const IconData camera = CupertinoIcons.camera;
  static const IconData addPhoto = CupertinoIcons.camera;
  static const IconData wallpaper = CupertinoIcons.paintbrush;
  static const IconData video = CupertinoIcons.videocam;
  static const IconData videoSolid = CupertinoIcons.videocam_fill;
  static const IconData videoOff = CupertinoIcons.video_camera;
  static const IconData musicNote = CupertinoIcons.music_note;
  static const IconData fileOutline = CupertinoIcons.doc;
  static const IconData attach = CupertinoIcons.paperclip;
  static const IconData poll = CupertinoIcons.chart_bar_alt_fill;
  static const IconData topic = CupertinoIcons.number;
  static const IconData calendar = CupertinoIcons.calendar;
  static const IconData location = CupertinoIcons.location_solid;

  // ── Audio / media controls ──
  static const IconData play = CupertinoIcons.play;
  static const IconData pause = CupertinoIcons.pause;
  static const IconData playFill = CupertinoIcons.play_fill;
  static const IconData pauseFill = CupertinoIcons.pause_fill;
  static const IconData playCircle = CupertinoIcons.play_circle;
  static const IconData skipPrev = CupertinoIcons.backward_end_fill;
  static const IconData skipNext = CupertinoIcons.forward_end_fill;
  static const IconData volumeUp = CupertinoIcons.speaker_3_fill;
  static const IconData volumeDown = CupertinoIcons.speaker_1_fill;
  static const IconData bluetoothAudio = Icons.bluetooth_audio_rounded;
  static const IconData headphones = Icons.headphones_rounded;

  // ── Phone / calls ──
  static const IconData call = CupertinoIcons.phone;
  static const IconData callSolid = CupertinoIcons.phone_fill;
  static const IconData callAlt = CupertinoIcons.phone;
  static const IconData callEnd = CupertinoIcons.phone_down_fill;
  static const IconData roomCallAction = Icons.phone_in_talk_rounded;
  static const IconData leaveRoomAction = Icons.logout_rounded;
  static const IconData cameraSwitch = CupertinoIcons.camera_rotate_fill;
  static const IconData screenShare = Icons.present_to_all;
  static const IconData screenShareOff = Icons.cancel_presentation;

  // ── Mic ──
  static const IconData mic = CupertinoIcons.mic;
  static const IconData micOff = CupertinoIcons.mic_slash_fill;

  // ── Security & verification ──
  static const IconData lock = CupertinoIcons.lock;
  static const IconData shield = CupertinoIcons.shield;
  static const IconData verified = CupertinoIcons.check_mark_circled_solid;
  static const IconData verifiedOutline = CupertinoIcons.check_mark_circled;
  static const IconData fingerprint = CupertinoIcons.shield_fill;
  static const IconData privacyTip = CupertinoIcons.hand_raised;
  static const IconData security = CupertinoIcons.shield;

  // ── Notifications ──
  static const IconData at = CupertinoIcons.at;
  static const IconData bell = CupertinoIcons.bell;
  static const IconData bellSolid = CupertinoIcons.bell_fill;
  static const IconData bellOff = CupertinoIcons.bell_slash;
  static const IconData bellOffSolid = CupertinoIcons.bell_slash_fill;

  // ── Checks & selection ──
  static const IconData check = CupertinoIcons.check_mark;
  static const IconData checkCircle = CupertinoIcons.check_mark_circled;
  static const IconData checkCircleSolid =
      CupertinoIcons.check_mark_circled_solid;
  static const IconData checkDouble = CupertinoIcons.check_mark_circled_solid;
  static const IconData radioChecked = CupertinoIcons.check_mark_circled_solid;
  static const IconData radioUnchecked = CupertinoIcons.circle;
  static const IconData circleOutline = CupertinoIcons.circle;

  // ── Status ──
  static const IconData schedule = CupertinoIcons.clock;
  static const IconData hourglass = CupertinoIcons.hourglass;
  static const IconData errorOutline = CupertinoIcons.exclamationmark_circle;

  // ── QR codes ──
  static const IconData qrCode = CupertinoIcons.qrcode;
  static const IconData qrScanner = CupertinoIcons.qrcode_viewfinder;

  // ── Settings sub-items ──
  static const IconData language = CupertinoIcons.globe;
  static const IconData devices = CupertinoIcons.desktopcomputer;
  static const IconData linkedDevices = CupertinoIcons.desktopcomputer;
  static const IconData bug = CupertinoIcons.ant_fill;
  static const IconData restart = CupertinoIcons.refresh;

  // ── Cloud / backup ──
  static const IconData cloud = CupertinoIcons.cloud;
  static const IconData cloudUpload = CupertinoIcons.cloud_upload;
  static const IconData cloudDownload = CupertinoIcons.cloud_download;

  // ── Misc ──
  static const IconData tag = CupertinoIcons.tag_fill;
  static const IconData badge = CupertinoIcons.person_crop_rectangle_fill;
  static const IconData timer = CupertinoIcons.timer;
  static const IconData emoji = CupertinoIcons.smiley;
  static const IconData ondemandVideo = CupertinoIcons.videocam;
}
