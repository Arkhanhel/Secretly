// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../primitives/hover_listener.dart';

/// Полоса вкладок правой панели: «Инфо · Участники · Медиа».
///
/// 🔴 ЗАЧЕМ ВКЛАДКИ, ЕСЛИ РАНЬШЕ ВСЁ БЫЛО ОДНИМ СВИТКОМ.
///
/// Панель подробностей комнаты была одной непрерывной лентой: обложка,
/// портрет, кнопки, темы, описание, сведения, переключатели чата, заявки,
/// список участников, забаненные — и в самом низу галерея, у которой СВОИ
/// четыре вкладки. Получалась прокрутка внутри прокрутки и экран на три
/// высоты окна: чтобы дойти до медиа, нужно было проехать мимо всех
/// участников, а чтобы вернуться к переключателю «в архив» — проехать обратно.
///
/// Вкладки режут это на три коротких экрана. Ни один из них не длиннее панели,
/// у каждого своя прокрутка, и переход между ними стоит одного нажатия вместо
/// десяти оборотов колеса.
///
/// Шапка (портрет, имя, кнопки действий) остаётся НАД полосой и не уезжает:
/// она отвечает на вопрос «с кем я», а он не зависит от выбранной вкладки.
class DetailsTabs extends StatelessWidget {
  const DetailsTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (tabs.length < 2) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: HoverListener(
                onTap: () => onChanged(i),
                cursor: SystemMouseCursors.click,
                builder: (ctx, hovered, pressed) {
                  final active = i == index;
                  return Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Подчёркивание, а не заливка: полоса стоит на границе
                      // шапки и содержимого, и заливка сделала бы из неё
                      // третью панель.
                      border: Border(
                        bottom: BorderSide(
                          color: active ? c.accentPrimary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tabs[i],
                        style: DType.label.copyWith(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: active
                              ? c.textPrimary
                              : (hovered ? c.textPrimary : c.textSecondary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
