// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// FFmpeg на телефонах — LGPL-3.0 (04.10.2026, поручение владельца).
///
/// iOS и Android везут LGPL-сборку FFmpegKit (вариант `full`, без x264 и
/// других GPL-компонентов), подключённую отдельными библиотеками. LGPL
/// требует сообщить о ней и приложить текст лицензии; Flutter сам видит лишь
/// лицензию плагина-обёртки, а не самого FFmpeg — поэтому запись здесь.
/// Компьютерам — своя запись (GPL), см. `lib/desktop/ffmpeg_license.dart`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../desktop/ffmpeg_license.dart' show kGplV3LicenseText;

/// Заявить FFmpeg (LGPL-3.0) на экране лицензий. Только iOS и Android.
void registerMobileFfmpegLicense({@visibleForTesting bool? onMobile}) {
  final mobile = onMobile ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));
  if (!mobile) return;
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(<String>[
      'FFmpeg',
      'FFmpegKit',
    ], '$kMobileFfmpegNoticeText\n$kLgplV3LicenseText\n$kGplV3LicenseText');
  });
}

const String kMobileFfmpegNoticeText = r'''
FFmpeg in Secretly for iOS and Android
======================================

Secretly uses FFmpeg (https://ffmpeg.org) to process video and images:
trimming, video messages, compression, animated avatars and stickers. It comes
from FFmpegKit, through the Flutter package ffmpeg_kit_flutter_new 4.2.1, in
the "full" variant that contains no GPL components: on iOS the 8.0.0 build,
on Android ffmpeg-kit-full 2.1.0 (FFmpeg 6.0).

This build of FFmpeg is licensed under the GNU Lesser General Public License,
version 3 (LGPL-3.0). Its text follows below, together with the GNU General
Public License, version 3, which the LGPL-3.0 refers to. FFmpeg is linked
dynamically as separate libraries, so it can be replaced by a modified version.

Video is encoded by the system H.264 encoder (MediaCodec on Android,
VideoToolbox on iOS), not by x264.

Sources: FFmpeg — https://ffmpeg.org/download.html; FFmpegKit builds —
https://github.com/sk3llo/ffmpeg_kit_flutter (release 8.0.0-full for iOS,
Maven com.antonkarpenko:ffmpeg-kit-full:2.1.0 for Android). The changes
Secretly made to the plugin are listed in
third_party/ffmpeg_kit_flutter_new/MODIFICATIONS.md of the Secretly source code
(https://github.com/Arkhanhel/Secretly). On request we will provide the exact
sources of the FFmpeg build shipped with a given version of the app.
''';

/// Дословный текст GNU LGPL v3 (из плагина FFmpegKit).
const String kLgplV3LicenseText = r'''
                   GNU LESSER GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.


  This version of the GNU Lesser General Public License incorporates
the terms and conditions of version 3 of the GNU General Public
License, supplemented by the additional permissions listed below.

  0. Additional Definitions.

  As used herein, "this License" refers to version 3 of the GNU Lesser
General Public License, and the "GNU GPL" refers to version 3 of the GNU
General Public License.

  "The Library" refers to a covered work governed by this License,
other than an Application or a Combined Work as defined below.

  An "Application" is any work that makes use of an interface provided
by the Library, but which is not otherwise based on the Library.
Defining a subclass of a class defined by the Library is deemed a mode
of using an interface provided by the Library.

  A "Combined Work" is a work produced by combining or linking an
Application with the Library.  The particular version of the Library
with which the Combined Work was made is also called the "Linked
Version".

  The "Minimal Corresponding Source" for a Combined Work means the
Corresponding Source for the Combined Work, excluding any source code
for portions of the Combined Work that, considered in isolation, are
based on the Application, and not on the Linked Version.

  The "Corresponding Application Code" for a Combined Work means the
object code and/or source code for the Application, including any data
and utility programs needed for reproducing the Combined Work from the
Application, but excluding the System Libraries of the Combined Work.

  1. Exception to Section 3 of the GNU GPL.

  You may convey a covered work under sections 3 and 4 of this License
without being bound by section 3 of the GNU GPL.

  2. Conveying Modified Versions.

  If you modify a copy of the Library, and, in your modifications, a
facility refers to a function or data to be supplied by an Application
that uses the facility (other than as an argument passed when the
facility is invoked), then you may convey a copy of the modified
version:

   a) under this License, provided that you make a good faith effort to
   ensure that, in the event an Application does not supply the
   function or data, the facility still operates, and performs
   whatever part of its purpose remains meaningful, or

   b) under the GNU GPL, with none of the additional permissions of
   this License applicable to that copy.

  3. Object Code Incorporating Material from Library Header Files.

  The object code form of an Application may incorporate material from
a header file that is part of the Library.  You may convey such object
code under terms of your choice, provided that, if the incorporated
material is not limited to numerical parameters, data structure
layouts and accessors, or small macros, inline functions and templates
(ten or fewer lines in length), you do both of the following:

   a) Give prominent notice with each copy of the object code that the
   Library is used in it and that the Library and its use are
   covered by this License.

   b) Accompany the object code with a copy of the GNU GPL and this license
   document.

  4. Combined Works.

  You may convey a Combined Work under terms of your choice that,
taken together, effectively do not restrict modification of the
portions of the Library contained in the Combined Work and reverse
engineering for debugging such modifications, if you also do each of
the following:

   a) Give prominent notice with each copy of the Combined Work that
   the Library is used in it and that the Library and its use are
   covered by this License.

   b) Accompany the Combined Work with a copy of the GNU GPL and this license
   document.

   c) For a Combined Work that displays copyright notices during
   execution, include the copyright notice for the Library among
   these notices, as well as a reference directing the user to the
   copies of the GNU GPL and this license document.

   d) Do one of the following:

       0) Convey the Minimal Corresponding Source under the terms of this
       License, and the Corresponding Application Code in a form
       suitable for, and under terms that permit, the user to
       recombine or relink the Application with a modified version of
       the Linked Version to produce a modified Combined Work, in the
       manner specified by section 6 of the GNU GPL for conveying
       Corresponding Source.

       1) Use a suitable shared library mechanism for linking with the
       Library.  A suitable mechanism is one that (a) uses at run time
       a copy of the Library already present on the user's computer
       system, and (b) will operate properly with a modified version
       of the Library that is interface-compatible with the Linked
       Version.

   e) Provide Installation Information, but only if you would otherwise
   be required to provide such information under section 6 of the
   GNU GPL, and only to the extent that such information is
   necessary to install and execute a modified version of the
   Combined Work produced by recombining or relinking the
   Application with a modified version of the Linked Version. (If
   you use option 4d0, the Installation Information must accompany
   the Minimal Corresponding Source and Corresponding Application
   Code. If you use option 4d1, you must provide the Installation
   Information in the manner specified by section 6 of the GNU GPL
   for conveying Corresponding Source.)

  5. Combined Libraries.

  You may place library facilities that are a work based on the
Library side by side in a single library together with other library
facilities that are not Applications and are not covered by this
License, and convey such a combined library under terms of your
choice, if you do both of the following:

   a) Accompany the combined library with a copy of the same work based
   on the Library, uncombined with any other library facilities,
   conveyed under the terms of this License.

   b) Give prominent notice with the combined library that part of it
   is a work based on the Library, and explaining where to find the
   accompanying uncombined form of the same work.

  6. Revised Versions of the GNU Lesser General Public License.

  The Free Software Foundation may publish revised and/or new versions
of the GNU Lesser General Public License from time to time. Such new
versions will be similar in spirit to the present version, but may
differ in detail to address new problems or concerns.

  Each version is given a distinguishing version number. If the
Library as you received it specifies that a certain numbered version
of the GNU Lesser General Public License "or any later version"
applies to it, you have the option of following the terms and
conditions either of that published version or of any later version
published by the Free Software Foundation. If the Library as you
received it does not specify a version number of the GNU Lesser
General Public License, you may choose any version of the GNU Lesser
General Public License ever published by the Free Software Foundation.

  If the Library as you received it specifies that a proxy can decide
whether future versions of the GNU Lesser General Public License shall
apply, that proxy's public statement of acceptance of any version is
permanent authorization for you to choose that version for the
Library.
''';
