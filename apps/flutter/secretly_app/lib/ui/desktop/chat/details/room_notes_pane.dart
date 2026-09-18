// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../design/tokens.dart';
import '../../primitives/desktop_text_field.dart';

/// ◆ «ЗАМЕТКИ» — ТРЕТЬЯ ВКЛАДКА ПАНЕЛИ СОЗВОНА ИЗ МАКЕТА.
///
/// Заметки — то, что остаётся ПОСЛЕ разговора: адрес, цифра, «сделать к
/// четвергу». До сих пор записать это было некуда: единственный вид текста в
/// приложении — сообщение, а у сообщения нет вида «только для меня».
///
/// 🔴 ЗАМЕТКА ЛИЧНАЯ И НИКУДА НЕ ЕДЕТ. Её не шифруют для собеседника, не
/// кладут в очередь отправки и не показывают в переписке. Об этом сказано
/// прямо под полем: вкладка в окне общего разговора обязана объяснить, что
/// она не общая, иначе кто-нибудь напишет туда «буду через 10 минут».
///
/// 🔴 И В РЕЗЕРВНУЮ КОПИЮ ОНА НЕ ВХОДИТ — тоже сказано под полем.
///
/// Копия собирается по явному списку таблиц и столбцов
/// (`safe_backup_snapshot_contract.dart`), и заметок в нём нет. Добавить их
/// туда нельзя дёшево: восстановление на ТЕЛЕФОНЕ полезло бы в таблицу,
/// которой у него нет, и рисковать восстановлением истории ради заметок
/// нельзя. Значит, остаётся сказать правду: копия их не увезёт.
///
/// 🔴 И ПРИ ЭТОМ ОНА НЕ ЛЕЖИТ ОТКРЫТЫМ ТЕКСТОМ. Проще всего было положить её
/// в обычные настройки окна, рядом с выбором камеры. Но заметка с созвона —
/// запись того же разговора, и хранить её открыто рядом с зашифрованной
/// историей значило бы обойти собственное обещание с чёрного хода. Поэтому
/// она в той же базе под тем же ключом — см. `AppDb.desktopRoomNote`.
///
/// Одна и та же панель стоит в двух местах: во вкладке созвона и в «Инфо»
/// правой панели комнаты. Второе — не украшение: заметка, которую видно
/// только пока идёт звонок, бесполезна ровно тогда, когда за ней приходят.
class RoomNotesPane extends StatefulWidget {
  const RoomNotesPane({
    super.key,
    required this.convoId,
    required this.load,
    required this.save,
    this.expand = true,
  });

  /// 🔴 ЧТЕНИЕ И ЗАПИСЬ — ДВА КОЛБЭКА, А НЕ ССЫЛКА НА ВЬЮ-МОДЕЛЬ.
  ///
  /// Панели нужны ровно две операции, и знать про весь склад окна ради них
  /// незачем. Заодно это единственная форма, в которой её можно проверить
  /// тестом: собрать `DesktopAppViewModel` без живого контроллера нельзя, и
  /// панель с ним внутри осталась бы непроверенной.
  final Future<String> Function(String convoId) load;
  final Future<void> Function(String convoId, String body) save;

  /// Разговор, к которому привязана заметка. Пусто — панель не показывается.
  final String convoId;

  /// `true` — поле тянется на всю высоту (вкладка созвона);
  /// `false` — карточка на несколько строк («Инфо» правой панели).
  final bool expand;

  @override
  State<RoomNotesPane> createState() => _RoomNotesPaneState();
}

class _RoomNotesPaneState extends State<RoomNotesPane> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  bool _loading = true;

  /// Что уже лежит в базе. Сравниваем с ним, чтобы не писать на каждый удар
  /// по клавише и не трогать базу, когда ничего не изменилось.
  String _saved = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RoomNotesPane old) {
    super.didUpdateWidget(old);
    if (old.convoId != widget.convoId) {
      // Сначала дописываем заметку ПРЕЖНЕГО разговора, иначе переключение
      // комнаты стирало бы несохранённое.
      _flush(convoId: old.convoId);
      setState(() => _loading = true);
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final body = await widget.load(widget.convoId);
    if (!mounted) return;
    setState(() {
      _saved = body;
      _text.text = body;
      _loading = false;
    });
  }

  /// Пишет заметку, если она изменилась. `convoId` передаётся явно: при
  /// переключении комнаты сохранить надо ПРЕЖНЮЮ.
  void _flush({String? convoId}) {
    final id = convoId ?? widget.convoId;
    final body = _text.text;
    if (id.isEmpty) return;
    if (convoId == null && body == _saved) return;
    _saved = body;
    unawaited(widget.save(id, body));
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    // Пауза в наборе, а не каждая буква: запись идёт в зашифрованную базу.
    _debounce = Timer(const Duration(milliseconds: 700), _flush);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // 🔴 Окно созвона закрывается вместе с разговором, и последняя фраза
    // почти всегда дописывается в последнюю секунду. Без записи здесь она
    // терялась бы ровно в тот момент, ради которого вкладку и завели.
    _flush();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (widget.convoId.isEmpty) return const SizedBox.shrink();
    if (_loading) {
      return widget.expand ? const SizedBox.expand() : const SizedBox.shrink();
    }

    final field = DesktopTextField(
      controller: _text,
      hintText: 'Что запомнить из этого разговора…',
      onChanged: _onChanged,
      maxLines: widget.expand ? null : 6,
      minLines: widget.expand ? null : 3,
    );

    final note = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(FluentIcons.lock_closed_16_regular, size: 14, color: c.textTertiary),
        const SizedBox(width: DSpace.p6),
        Expanded(
          child: Text(
            'Видно только вам. Не отправляется, не попадает в переписку и '
            'не входит в резервную копию — живёт на этом компьютере, в той же '
            'зашифрованной базе, что и сообщения.',
            style: DType.caption.copyWith(color: c.textTertiary, height: 1.4),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.m,
        DSpace.m,
        DSpace.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (widget.expand) Expanded(child: field) else field,
          const SizedBox(height: DSpace.s),
          note,
        ],
      ),
    );
  }
}
