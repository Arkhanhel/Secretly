// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../rooms/room_call_state.dart' show CachedRoomCall;
import '../design/colors.dart';
import '../design/radii.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../primitives/avatar.dart';
import '../primitives/hover_listener.dart';

/// Длительность созвона: `MM:SS`, а после часа — `H:MM:SS`.
///
/// 🔴 Отрицательное время показываем нулём. Момент начала приходит с чужого
/// устройства, и если его часы убежали вперёд, разность выходит отрицательной.
/// «-03:12» на плашке читается как поломка приложения, хотя сломаны часы.
String formatRoomCallDuration(int startedAtMs, int nowMs) {
  var total = (nowMs - startedAtMs) ~/ 1000;
  if (total < 0) total = 0;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// «3 участника» с русским склонением.
///
/// Числа 11–14 склоняются как «много», хотя оканчиваются на 1–4, — на этом
/// спотыкается почти каждый самодельный счётчик и выдаёт «11 участник».
///
/// Слово не сокращаем: «3 участ.» экономит четыре точки ширины и стоит
/// читаемости, а места в плашке хватает.
/// «1 участник», «2 участника», «5 участников» — по-русски.
///
/// Живёт здесь исторически (писалось для плашки созвона), но считает обычное
/// русское склонение и годится везде, где на десктопе нужно сказать, сколько
/// человек: шапка комнаты зовёт его же.
String formatParticipantsRu(int count) {
  final n = count.abs();
  final tens = n % 100;
  final ones = n % 10;
  if (tens >= 11 && tens <= 14) return '$count участников';
  if (ones == 1) return '$count участник';
  if (ones >= 2 && ones <= 4) return '$count участника';
  return '$count участников';
}

/// Плашка «Идёт обсуждение» под шапкой комнаты.
///
/// 🔴 РИСУЕТСЯ ТОЛЬКО ПО НАСТОЯЩЕМУ СОСТОЯНИЮ СОЗВОНА.
///
/// Источник — `AppController.getCachedRoomCall(roomId)`, тот же снимок
/// [CachedRoomCall], по которому живёт баннер в мобильной версии. Плашка
/// показывает ровно три вещи, и все три в снимке есть:
///
/// * идёт ли созвон (`state == 'active'` и не завершён),
/// * сколько человек сейчас внутри (`joinedParticipantCount`),
/// * сколько он длится (`startedAtMs`).
///
/// **Чего здесь сознательно НЕТ.**
///
/// В макете под заголовком стоит «Игорь говорит». Признак `speaking` в снимке
/// есть, но заполняет его только LiveKit и только тому, кто уже внутри
/// созвона: снимок с релея активного говорящего не несёт. Для человека
/// снаружи это поле — мусор произвольной свежести. Подписать чужой плашкой
/// «Игорь говорит», когда Игорь молчит десять минут, хуже, чем не подписывать
/// вовсе: один раз обманувшая строка обесценивает всю плашку.
///
/// Там же в макете стоит имя темы («Идёт обсуждение · Релиз 1.4»). Созвон у
/// нас принадлежит КОМНАТЕ, а не теме: связи «созвон ↔ тема» в протоколе нет.
/// Придумать её на стороне десктопа — значит развести десктоп с телефоном на
/// ровном месте. Поэтому заголовок без темы; если связь появится в протоколе,
/// её сюда добавит одна строка.
///
/// **Почему столбики не шевелятся.** Живой эквалайзер это вечная анимация в
/// углу окна — ровно тот источник постоянной перерисовки, который 12.09 стоил
/// нам тридцати процентов процессора на украшениях аватаров. Плашка и так
/// говорит, что созвон идёт, — словами и счётчиком времени. Столбики здесь
/// значок, а не измеритель.
/// Лицо участника созвона для плашки.
class RoomCallFace {
  const RoomCallFace({required this.name, this.avatarPath});

  final String name;
  final String? avatarPath;
}

class DesktopRoomCallBanner extends StatefulWidget {
  const DesktopRoomCallBanner({
    super.key,
    required this.call,
    required this.onJoin,
    this.faces = const <RoomCallFace>[],
    this.nowMs,
  });

  final CachedRoomCall call;

  /// Кто сейчас внутри — лицами, внахлёст, как в макете.
  ///
  /// 🔴 Счётчик отвечает «сколько», лица — «кто». Второе решает, входить ли
  /// сейчас: «3 участника» не говорит ничего, а три знакомых лица говорят всё.
  /// Пустой список — просто нет лиц: плашка от этого не ломается.
  final List<RoomCallFace> faces;

  /// Открыть экран созвона. Тот же обработчик, что у кнопки звонка в шапке, —
  /// «присоединиться» и «позвонить» в комнате это одно и то же действие.
  final VoidCallback onJoin;

  /// Точка отсчёта для длительности. Нужна тестам, чтобы не зависеть от часов.
  final int Function()? nowMs;

  @override
  State<DesktopRoomCallBanner> createState() => _DesktopRoomCallBannerState();
}

class _DesktopRoomCallBannerState extends State<DesktopRoomCallBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Раз в секунду и только пока плашка на экране: она показывает время, и
    // остановившиеся часы на ней выглядят как зависший созвон.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int _now() => widget.nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final call = widget.call;
    final joined = call.selfParticipant?.isJoined ?? false;
    final duration = formatRoomCallDuration(call.startedAtMs, _now());
    final people = formatParticipantsRu(call.joinedParticipantCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(DSpace.l, DSpace.m, DSpace.l, 0),
      child: DecoratedBox(
        // Островок, а не полоса: ровно та же форма, что у закреплённого
        // сообщения выше, и разный цвет по смыслу — зелёный «говорят», синий
        // «закреплено». Заливка РОВНАЯ (.12 из макета), а не переходом:
        // переход у одного островка и ровный тон у соседнего читались бы как
        // два разных вида плашек.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DRadii.lg),
          color: c.success.withValues(alpha: 0.12),
          border: Border.all(color: c.success.withValues(alpha: 0.24)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: DSpace.s + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(DRadii.r12),
                ),
                child: Icon(
                  FluentIcons.person_voice_20_filled,
                  size: 18,
                  color: c.success,
                ),
              ),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Идёт обсуждение',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.label.copyWith(
                        // Светлая мята, а не сам `success`: тот на своей же
                        // плёнке в 12 % почти сливается с ней — та же причина,
                        // что у подписи «Позвонить» и у полосы закреплённого.
                        color: c.mintSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$people · $duration',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.tiny.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.s),
              const _EqualizerGlyph(),
              if (widget.faces.isNotEmpty) ...[
                const SizedBox(width: DSpace.m),
                _FaceStack(faces: widget.faces),
              ],
              const SizedBox(width: DSpace.m),
              _JoinButton(
                label: joined ? 'Вернуться' : 'Присоединиться',
                onTap: widget.onJoin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Неподвижные столбики эквалайзера — значок «здесь звук», не измеритель.
/// Причина неподвижности расписана в шапке [DesktopRoomCallBanner].
/// Лица участников внахлёст.
///
/// Порядок — как в снимке созвона; кто вошёл раньше, тот левее. Наложение
/// экономит ширину: плашка живёт в одну строку над перепиской и растягиваться
/// ей некуда.
class _FaceStack extends StatelessWidget {
  const _FaceStack({required this.faces});

  final List<RoomCallFace> faces;

  static const double _size = 22;
  static const double _step = 15;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return SizedBox(
      width: _size + _step * (faces.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < faces.length; i++)
            Positioned(
              left: i * _step,
              child: Container(
                // Кольцо цветом плашки разделяет соседние лица: без него
                // наложенные кружки сливаются в пятно.
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: c.thread,
                  shape: BoxShape.circle,
                ),
                child: Avatar(
                  name: faces[i].name,
                  image: Avatar.fileImage(faces[i].avatarPath),
                  size: _size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EqualizerGlyph extends StatelessWidget {
  const _EqualizerGlyph();

  static const List<double> _heights = <double>[7, 13, 19, 11, 6];

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 2.5),
            Container(
              width: 3,
              height: _heights[i],
              decoration: BoxDecoration(
                color: c.success.withValues(alpha: i.isEven ? 0.9 : 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.success.withValues(
              alpha: pressed ? 1.0 : (hovered ? 0.92 : 0.82),
            ),
            borderRadius: BorderRadius.circular(DRadii.md),
          ),
          child: Text(
            label,
            style: DType.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
