// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Profile FX — живые рамки аватаров и обложки профиля.
///
/// ```dart
/// import 'package:profile_fx/profile_fx.dart';
///
/// AnimatedAvatarFrame(frame: AvatarFrame.ryzhik, size: 160, child: Image.network(url, fit: BoxFit.cover));
/// ProfileCover(style: ProfileCoverStyle.aurora);
/// ```
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

part 'profile_fx/util.dart';
part 'profile_fx/bridge.dart';
part 'profile_fx/extras.dart';
part 'profile_fx/extras_drift_astro.dart';
part 'profile_fx/frames/avatar_frame.dart';
part 'profile_fx/frames/characters.dart';
part 'profile_fx/frames/effects.dart';
part 'profile_fx/frames/status.dart';
part 'profile_fx/covers/profile_cover.dart';
part 'profile_fx/covers/scenes.dart';
part 'profile_fx/covers/showcase.dart';
