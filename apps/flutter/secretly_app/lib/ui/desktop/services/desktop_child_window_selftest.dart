// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'desktop_child_windows.dart';

/// Самотест отдельного окна: `Secretly --child-window-selftest` (29.09.2026).
///
/// Сборка Windows проверяется в CI, где глазами окно не посмотреть. Программа
/// трижды открывает второе окно, дожидается его кадра, закрывает и выходит с
/// кодом 0. Итог — в `%TEMP%/secretly_child_window_selftest.txt`.
const String kChildWindowSelftestArg = '--child-window-selftest';

const String _kSelftestWindowId = 'selftest';

Future<void> runDesktopChildWindowSelftest() async {
  final log = <String>[];
  var closedRounds = 0;
  try {
    final windows = DesktopChildWindows.instance;
    final supported = await windows.isSupported();
    log.add('supported=$supported');
    if (supported) {
      for (var round = 0; round < 3; round++) {
        final painted = Completer<void>();
        final opened = await windows.open(
          DesktopChildWindowSpec(
            id: _kSelftestWindowId,
            title: 'Secretly selftest',
            size: const Size(360, 240),
            builder: (_) => _SelftestContent(
              round: round,
              onFirstFrame: () {
                if (!painted.isCompleted) painted.complete();
              },
            ),
          ),
        );
        final viewId = windows.viewOf(_kSelftestWindowId)?.viewId;
        log.add('round=$round opened=$opened view=$viewId');
        if (!opened) break;
        await painted.future.timeout(const Duration(seconds: 10));
        log.add('round=$round painted');
        await windows.close(_kSelftestWindowId);
        closedRounds++;
        log.add('round=$round closed');
      }
    }
  } catch (e) {
    log.add('error=$e');
  }
  final ok = closedRounds == 3;
  try {
    File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'secretly_child_window_selftest.txt',
    ).writeAsStringSync('${ok ? 'OK' : 'FAIL'}\n${log.join('\n')}\n');
  } catch (_) {}
  exit(ok ? 0 : 3);
}

class _SelftestContent extends StatefulWidget {
  const _SelftestContent({required this.round, required this.onFirstFrame});

  final int round;
  final VoidCallback onFirstFrame;

  @override
  State<_SelftestContent> createState() => _SelftestContentState();
}

class _SelftestContentState extends State<_SelftestContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFirstFrame());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF17191F),
        child: Center(
          child: Text(
            'Secretly · ${widget.round + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
