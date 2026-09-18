// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Окно созвона: то, что было в данных и не доходило до глаз.
//
// 🔴 ТРИ ВЕЩИ.
//
// 1. Признак `deafened` лежал в снимке созвона с самого начала и не читался
//    окном НИ РАЗУ. Человек, выключивший себе звук, выглядел в списке обычным
//    участником с включённым микрофоном: ему говорили, а он не слышал, и никто
//    за столом об этом не знал.
//
// 2. Запасная сетка лиц (когда видео нет ни у кого) была без предела: на
//    двенадцати участниках портреты по 88 точек не помещались в сцену и ряд
//    уезжал за край — тем вернее, чем крупнее созвон.
//
// 3. Во всплывашке входящего звонка «Отклонить» и «Ответить» стояли двумя
//    одинаковыми половинами. Всплывашка приходит внезапно и ловит палец на
//    полпути; половина площади под необратимым «отклонить» — это приглашение
//    промахнуться.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final call = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();
  final toast = File(
    'lib/ui/desktop/calls/incoming_call_toast.dart',
  ).readAsStringSync();

  test('🔴 «не слышит» доходит до списка участников', () {
    expect(call.contains('deafened: p.deafened'), isTrue,
        reason: 'признак есть в снимке — его надо прокинуть в строку');
    expect(call.contains("'не слышит'"), isTrue);
    expect(
      call.contains('FluentIcons.speaker_off_24_filled'),
      isTrue,
      reason: 'наушники важнее микрофона: кто не слышит, тот не участвует, и '
          'состояние его микрофона в этот момент ничего не решает',
    );
  });

  test('🔴 сетка лиц на сцене ограничена и говорит, скольких не показала', () {
    expect(call.contains('_kStageFacesMax'), isTrue);
    expect(call.contains('participants.take(_kStageFacesMax)'), isTrue);
    expect(call.contains('_StageOverflow('), isTrue);
    expect(
      call.contains("'+\$count'"),
      isTrue,
      reason: '«ещё трое» и «ещё тридцать» — разные новости; обрыв без числа '
          'заставляет открывать список, чтобы узнать какая',
    );
  });

  test('🔴 отклонить — узкая кнопка, ответить — широкая', () {
    final i = toast.indexOf("label: 'Отклонить'");
    expect(i, -1, reason: 'у отклонения больше нет подписи — оно узкое');
    expect(toast.contains("tooltip: 'Отклонить'"), isTrue,
        reason: 'значок без слова обязан называть себя хотя бы по наведению');
    // Отклонение стоит фиксированной ширины, ответ — в Expanded.
    final decline = toast.indexOf('call_end_24_filled');
    final accept = toast.indexOf('call_24_filled');
    expect(decline < accept, isTrue);
    expect(
      toast.substring(decline, accept).contains('width: 46'),
      isTrue,
    );
    expect(
      toast.substring(accept).contains('Expanded(') ||
          toast.substring(decline, accept).contains('Expanded('),
      isTrue,
    );
  });

  // 🔴 ВО ВРЕМЯ ДЕМОНСТРАЦИИ ЭКРАНА В ОКНЕ НЕ БЫЛО НИ ОДНОГО ЛИЦА.
  //
  // Сцену занимает экран, справа — текстовые строки списка участников. А
  // разговор идёт между людьми: видеть их в этот момент нужнее всего.
  //
  // Заодно закрывается и «своего кадра не видно нигде»: своё видео попадало
  // на сцену только когда ты говоришь или когда ты в созвоне ОДИН, и в
  // разговоре с другими человек не мог проверить, в кадре ли он.
  group('лента плиток участников', () {
    test('лента стоит рядом со сценой и только в созвоне на двоих и больше', () {
      expect(call.contains('_participantStrip(c)'), isTrue);
      expect(call.contains('width: 212'), isTrue);
      expect(
        call.contains('if (_joined.length >= 2)'),
        isTrue,
        reason: 'вдвоём лента показала бы одну плитку рядом с тем же кадром',
      );
    });

    test('🔴 своя плитка — ПЕРВОЙ', () {
      // В созвоне на восьмерых, стоя в общем порядке, она уезжала бы под
      // нижний край ленты — то есть ровно тогда, когда проверить себя
      // тревожнее всего.
      expect(call.contains('final ordered = ['), isTrue);
      expect(
        call.contains('..._joined.where((p) => _runtimeFor(p.deviceId)?.isSelf ?? false)'),
        isTrue,
      );
    });

    // 🔴 ПОВТОРОМ СЧИТАЕТСЯ КАДР, А НЕ УЧАСТНИК (уточнено 15.09.2026).
    //
    // Раньше у правила была ещё и техническая причина:
    // `buildParticipantVideoView` отдавал ОДИН вид на участника и всегда
    // предпочитал демонстрацию камере, так что плитка показывающего экран
    // показала бы второй раз тот же экран.
    //
    // Теперь вид спрашивается явно, и лицо того, кто показывает экран, — не
    // повтор, а ВТОРОЙ его вид: ровно лента из макета. Повтором осталось лицо,
    // когда на сцене тоже лицо.
    test('🔴 чей КАДР на сцене — в плитке не повторяется', () {
      expect(call.contains('final onStage = pick != null && pick.deviceId == p.deviceId'), isTrue);
      expect(call.contains('final faceOnStage = onStage && !pick.screenShare;'), isTrue);
      expect(call.contains('final view = (!faceOnStage && hasCamera && media != null)'), isTrue);
    });

    test('свою камеру в плитке зеркалим', () {
      expect(call.contains('mirror: runtime.isSelf'), isTrue);
    });

    test('🔴 измерителя уровня, которого нет в данных, не рисуем', () {
      // В макете у плитки столбики уровня. Уровня звука в состоянии НЕТ —
      // только двухпозиционный признак «говорит». Три полоски «громкости»,
      // которые на самом деле включаются разом, — это измеритель, который
      // ничего не измеряет.
      expect(call.contains('speaking: media?.isParticipantSpeaking'), isTrue);
    });
  });

  // 🔴 ВЫБРАТЬ УСТРОЙСТВО ВЫВОДА БЫЛО НЕЧЕМ.
  //
  // На компьютере устройств почти всегда больше одного: гарнитура, колонки,
  // монитор. Поменять их можно было только системными настройками — то есть
  // уйдя из созвона глазами и руками, посреди разговора.
  //
  // Движок умеет это давно: `audioRouteState` публикует список, а
  // `selectAudioRoute` его применяет — тем же путём работает телефон. Ничего
  // нового ради этого не заведено.
  group('выбор устройства вывода', () {
    test('список берётся из движка, а не придумывается', () {
      expect(call.contains('audioRouteState.value.availableRoutes'), isTrue);
      expect(call.contains('manager.selectAudioRoute(r.deviceId)'), isTrue);
    });

    test('🔴 шеврона нет, когда выбирать не из чего', () {
      // Стрелка, за которой один пункт, обещает выбор, которого нет.
      expect(
        call.contains('onExpand: _audioRoutes().length > 1 ? _pickAudioRoute : null'),
        isTrue,
      );
      expect(call.contains('if (routes.length < 2) return;'), isTrue);
    });

    test('🔴 шеврон — своя кнопка, а не часть нажатия по микрофону', () {
      // Нажать на микрофон во время созвона нужно быстро и не глядя. Если то
      // же нажатие иногда открывает список, человек промахнётся ровно тогда,
      // когда хотел просто замолчать.
      expect(call.contains('final void Function(BuildContext anchorContext)? onExpand;'), isTrue);
      expect(call.contains("message: 'Выбрать устройство'"), isTrue);
    });

    test('окно подписано на список устройств', () {
      // Список приезжает ПОСЛЕ подключения: без подписки шеврон не появился
      // бы до следующей перерисовки по другой причине.
      expect(
        call.contains('audioRouteState.addListener(_onRuntime)'),
        isTrue,
      );
      expect(
        call.contains('audioRouteState.removeListener(_onRuntime)'),
        isTrue,
      );
    });
  });

  // 🔴 ПИСАТЬ ВО ВРЕМЯ СОЗВОНА БЫЛО НЕЧЕМ.
  //
  // Окно созвона лежит ПОВЕРХ приложения: переписка комнаты, пока оно
  // открыто, не видна. Скинуть ссылку или адрес, о котором только что
  // договорились, можно было только свернув созвон — то есть выйдя из
  // разговора глазами ровно в тот момент, когда он идёт.
  group('чат созвона', () {
    test('панель разрезана на вкладки той же полосой, что подробности', () {
      expect(call.contains('DetailsTabs('), isTrue);
      expect(call.contains("'Участники · \${participants.length}', 'Чат'"), isTrue);
    });

    test('🔴 это ТА ЖЕ переписка комнаты, а не новая сущность', () {
      // Завести «чат созвона» отдельно значило бы создать переписку, которой
      // после звонка нигде нет.
      expect(call.contains('widget.controller.sendGroupMessage('), isTrue);
      expect(call.contains('groupId: widget.groupId,'), isTrue);
      expect(call.contains('widget.controller.loadEvents('), isTrue);
    });

    test('показывается хвост ленты, а не вся история', () {
      expect(call.contains('static const int _kChatTail = 30;'), isTrue);
      expect(call.contains('limit: _kChatTail'), isTrue);
    });

    test('🔴 отказ отправки говорится словами', () {
      // В комнате «писать могут только админы» отправка падает молча, и
      // человек во время созвона решит, что сломалось приложение.
      expect(call.contains('_chatError = _stripDartPrefix(e)'), isTrue);
      expect(call.contains('if (_chatError != null)'), isTrue);
    });

    test('срезание приставок Dart — одно на оба места', () {
      // Перевод «404» в «созвон не начать» чату не подходит: он про созвон.
      expect(call.contains('static String _stripDartPrefix(Object error)'), isTrue);
      expect(call.contains('final text = _stripDartPrefix(error);'), isTrue);
      expect(
        "for (final prefix in const ['Bad state: '".allMatches(call).length,
        1,
        reason: 'второй копии срезания быть не должно',
      );
    });

    test('нечитаемая строка не уносит весь хвост', () {
      expect(call.contains('continue; // одна нечитаемая строка'), isTrue);
    });
  });

  // 🔴 ЖИВАЯ ПРОВЕРКА ВДВОЁМ (14.09.2026) — два дефекта, которых не видел
  // ни один тест и которые нельзя было найти в одиночку.
  group('созвон вдвоём: найдено живьём', () {
    test('🔴 из созвона МОЖНО выйти, даже когда висит другое действие', () {
      // Было: `_run` начинался с `if (_busy != null) return`, а все кнопки
      // дока — `enabled: !busy`. Нажатие «Камера» ушло в запрос, который не
      // вернулся, и `_busy` остался навсегда. После этого не работало ничего,
      // включая «Выйти»: человек заперт в созвоне. Проверено живьём.
      expect(call.contains('if (_busy != null && !force) return;'), isTrue);
      expect(call.contains("_run('leave', force: true"), isTrue);
      // У кнопки выхода нет `enabled: !busy`.
      final i = call.indexOf("label: 'Выйти'");
      expect(i, greaterThan(0));
      final block = call.substring(i, i + 500);
      expect(block.contains('enabled: true'), isTrue);
      expect(block.contains('enabled: !busy'), isFalse);
    });

    test('🔴 ни одно действие не висит вечно', () {
      expect(call.contains('await body().timeout(timeout);'), isTrue);
      expect(call.contains('on TimeoutException'), isTrue);
      expect(call.contains('Сервер не ответил.'), isTrue);
    });

    test('отсутствие медиа-канала названо словами, а не молчанием', () {
      // Страховка, а не диагноз: настоящей причиной в этот раз был не relay
      // (у него LiveKit настроен), а незапущенный `RoomCallManager` — см.
      // тест ниже. Но если канала однажды действительно не будет, окно
      // обязано сказать это словами, а не гасить кнопки молча.
      expect(call.contains('bool get _mediaBackendReady'), isTrue);
      expect(
        call.contains('RelayRoomCallMediaBackendKind.livekit'),
        isTrue,
      );
      expect(call.contains('enabled: !busy && _mediaBackendReady'), isTrue);
      expect(
        call.contains('не будет ни '),
        isTrue,
        reason: 'плашка должна называть последствие, а не код ошибки',
      );
    });

    test('сессии ещё нет — молчим, а не пугаем', () {
      // Важно именно так: без менеджера сессии не было вовсе, и плашка
      // «сервер не выдал канал» обвинила бы сервер в чужой вине.
      expect(call.contains('if (backend == null) return true;'), isTrue);
    });
  });

  // 🔴 «ВЫГЛЯДИТ УБОГО, НИЧЕГО НЕ ПОНЯТНО» — замечание владельца о первой
  // редакции чата созвона (14.09.2026).
  //
  // Было: стена одинаковых мелких строк «Вы / текст» — без времени, без лиц,
  // без единого разделения. В узкой панели это читалось как список слов, а не
  // как разговор.
  group('чат созвона: вид', () {
    test('реплики пузырями, своя — справа', () {
      expect(call.contains('class _CallChatBubble'), isTrue);
      expect(
        call.contains('line.mine\n            ? MainAxisAlignment.end'),
        isTrue,
      );
    });

    test('🔴 имя и лицо НЕ повторяются у подряд идущих реплик', () {
      // Повтор у каждой строки и делал из панели кашу.
      expect(call.contains('final startsGroup ='), isTrue);
      expect(call.contains('showAuthor: startsGroup'), isTrue);
      expect(call.contains('if (showAuthor && !line.mine)'), isTrue);
    });

    test('время — у последней реплики в связке', () {
      expect(call.contains('final endsGroup ='), isTrue);
      expect(call.contains('showTime: endsGroup'), isTrue);
      expect(call.contains('_hhmm(line.timestampMs)'), isTrue);
    });

    test('без лица пузыри стоят по одной вертикали', () {
      // На месте лица остаётся отступ, иначе связка «ступеньками».
      expect(call.contains('width: 26,'), isTrue);
      expect(call.contains('? Avatar('), isTrue);
    });
  });

  // 🔴 ДЕСКТОП НЕ ЗАПУСКАЛ `RoomCallManager` ВООБЩЕ (14.09.2026).
  //
  // Телефон создаёт два управляющих: `CallManager` для личных звонков и
  // `RoomCallManager` для комнатных. Десктопный вход создавал только первый.
  // Снаружи созвон выглядел рабочим — список участников и «2 в эфире»
  // приходят из снимка звонка с релея, а не из менеджера. А медиа-сессию,
  // LiveKit, дорожки, признак речи и выбор устройства даёт именно он.
  test('🔴 десктоп запускает управляющий комнатных созвонов', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(app.contains('RoomCallManager(controller: _controller)..start()'), isTrue);
    expect(app.contains('RoomCallManager.instance = rcm;'), isTrue);
    // И отпускает его вместе с личным.
    expect(app.contains('RoomCallManager.instance = null;'), isTrue);
    expect(app.contains('unawaited(rcm.dispose());'), isTrue);
  });

  test('меню выбора устройства раскрывается ВВЕРХ', () {
    // Док стоит у нижнего края окна: список, раскрытый вниз, ложился поверх
    // самих кнопок — выбираешь динамик, а под пальцем «Выйти». Проверено
    // живьём.
    expect(call.contains('_menuAnchorAbove(anchorContext, routes.length)'), isTrue);
    expect(call.contains('origin.dy - height - 8'), isTrue);
  });

  // Шапка окна созвона по макету.
  //
  // 🔴 Было: высота 52, замок в чипе и таймер тем же шрифтом, что и всё
  // остальное. В макете — 46, эквалайзер и МОНОШИРИННЫЕ цифры: таймер,
  // набранный пропорциональным шрифтом, дёргает строку на каждой секунде.
  group('шапка созвона', () {
    test('высота и поля из макета', () {
      expect(call.contains('height: 46,'), isTrue);
      expect(call.contains('EdgeInsets.fromLTRB(isMacOS ? 78 : 14, 0, 14, 0)'), isTrue);
    });

    test('чип: 26, радиус, мятная плёнка и моноширинный таймер', () {
      expect(call.contains('height: 26,'), isTrue);
      expect(call.contains('c.voice.withValues(alpha: 0.14)'), isTrue);
      expect(call.contains('style: DType.mono.copyWith('), isTrue);
      expect(call.contains('color: c.mintSoft'), isTrue);
    });

    test('🔴 замок не выброшен молча, а переехал в подсказку', () {
      expect(call.contains("message: 'Созвон защищён сквозным шифрованием'"), isTrue);
      expect(call.contains('lock_closed_16_filled'), isFalse);
    });

    test('🔴 эквалайзер оживает ТОЛЬКО от настоящей речи', () {
      // Уровня звука в состоянии нет — только двухпозиционный признак.
      // Полоски, пляшущие по таймеру, изображали бы громкость, которой никто
      // не измерял, в том самом окне, где человек решает, слышно его или нет.
      expect(call.contains('class _Equalizer'), isTrue);
      expect(call.contains('anyoneSpeaking: _speakingDeviceIds().isNotEmpty'), isTrue);
      expect(call.contains('static const List<double> _heights = [4, 6, 9];'), isTrue);
    });
  });
}
