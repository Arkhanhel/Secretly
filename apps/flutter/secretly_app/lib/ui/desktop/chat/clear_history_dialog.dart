// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Подтверждение очистки/удаления с возможностью сделать то же у собеседника.
///
/// 🔴 ОДНА КНОПКА — ОДНО ПОВЕДЕНИЕ, ГДЕ БЫ ОНА НИ СТОЯЛА (16.09.2026).
///
/// Диалог жил приватным методом в разделе чатов, и поэтому «Очистить историю»
/// в меню списка предлагала галочку «и у собеседника», а та же кнопка в
/// карточке собеседника — нет. Человек, нажавший её не оттуда, о второй
/// возможности просто не узнавал: подпись одна, а делают разное.
///
/// [peerTitle] `null` — галочки нет вовсе: в комнате чистить «у собеседника»
/// некого, а свою переписку с собой незачем.
Future<({bool alsoForPeer})?> confirmClearWithPeer(
  BuildContext context, {
  required String title,
  required String body,
  required String okLabel,
  required String? peerTitle,
}) {
  var alsoForPeer = false;
    return showDialog<({bool alsoForPeer})>(
      context: context,
      builder: (ctx) {
        final cc = DColors.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: cc.elevated,
              title: Text(
                title,
                style: DType.title.copyWith(color: cc.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: DType.body.copyWith(color: cc.textSecondary),
                  ),
                  if (peerTitle != null) ...[
                    const SizedBox(height: DSpace.m),
                    InkWell(
                      onTap: () =>
                          setLocalState(() => alsoForPeer = !alsoForPeer),
                      borderRadius: BorderRadius.circular(DRadii.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: DSpace.xs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: alsoForPeer,
                              onChanged: (v) =>
                                  setLocalState(() => alsoForPeer = v ?? false),
                              activeColor: cc.danger,
                            ),
                            const SizedBox(width: DSpace.xs),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Очистить историю у собеседника '
                                  '($peerTitle)',
                                  style: DType.body.copyWith(
                                    color: cc.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: DSpace.xs),
                      child: Text(
                        'Сообщения пропадут и на его устройстве, и на всех '
                        'ваших. Отменить это нельзя.',
                        style: DType.caption.copyWith(color: cc.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Отмена',
                    style: DType.label.copyWith(color: cc.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop((alsoForPeer: alsoForPeer)),
                  child: Text(
                    okLabel,
                    style: DType.label.copyWith(
                      color: cc.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
