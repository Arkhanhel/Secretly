// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// 🔴 ЖИВЫЕ РАМКИ: двадцать четыре персонажа из набора `profile_fx`.
//
// Чем они отличаются от двадцати рамок в `cosmetics_catalog.dart`. Те — ПЕТЛИ:
// у каждой есть период, кадры пекутся в атлас и потом просто показываются. У
// этих периода нет: движение считают пружины, а моменты подёргиваний берутся
// из случайных чисел — ровно ради этого макет и написан («неровный ритм»).
// Поэтому они не идут через атлас и не участвуют в проверке шва петли: печь
// нечего. Живут на своём тикере, который считает настоящее `dt`.
//
// 🔴 ДВА СЛОЯ БЕЗ ДВУХ СЛОЁВ. Набор просит класть уши, хвост и волну ПОД фото,
// а кольцо и лапки — поверх. Его собственный виджет `AnimatedAvatarFrame`
// рисует фотографию сам; у нас её рисует вызывающая сторона — портрет собирают
// `FramedAvatar` и `Avatar`, — и перекраивать их нельзя: телефон выпущен.
// Выход тот же, что на бумаге: задние части рисуются с вырезанным кругом
// фотографии. Видно ровно то же, а порядок слоёв у вызывающей стороны не
// меняется ни на строчку.
//
// 🔴 СИСТЕМА КООРДИНАТ. Набор рисует на холсте 200×200, круг фотографии в нём
// r = `sim.av` (55–58 % холста). У нас квадрат `size`, фото занимает 0.86 от
// него. Значит холст рамки шире квадрата примерно в полтора раза и СОЗНАТЕЛЬНО
// вылезает за него: там живут уши, руки и ноты. `CustomPaint` не обрезает,
// `FramedAvatar` складывает слои с `Clip.none` — рисунок доходит целиком.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../thermal_guard.dart';
import '../wave1_l10n.dart';
import 'cosmetic_animation_scope.dart';
import 'cosmetic_motion_gate.dart';
import 'profile_fx.dart';

// 🔴 Наружу отдаём только то, чем пользуется приложение, и БЕЗ `AvatarFrame`:
// так называется и перечисление набора, и наш класс записи каталога. Две
// одинаковые фамилии в одном файле — это не стиль, а будущая путаница.
export 'profile_fx.dart' show FrameSim, FramePalette, FrameInputs;

/// Идентификатор рамки в профиле → персонаж набора.
///
/// 🔴 ИДЕНТИФИКАТОРЫ НЕ РАВНЫ ИМЕНАМ ПЕРЕЧИСЛЕНИЯ, И ЭТО НАМЕРЕННО. Строка
/// лежит в `profile_meta` у человека и у всех, кто его видит; переименование
/// набора не должно сбрасывать чужой выбор на «без рамки». Первые три — те,
/// что уже стояли у людей до прихода набора.
const Map<String, AvatarFrame> kLiveFrameKinds = <String, AvatarFrame>{
  'cat': AvatarFrame.ryzhik,
  'coder': AvatarFrame.coder,
  'music': AvatarFrame.music,
  'aquarium': AvatarFrame.aquarium,
  'slime': AvatarFrame.slime,
  'octopus': AvatarFrame.octopus,
  'bird': AvatarFrame.bird,
  'lava_lamp': AvatarFrame.lavaLamp,
  'ghost': AvatarFrame.ghost,
  'streak': AvatarFrame.streak,
  'level_up': AvatarFrame.levelUp,
  'live': AvatarFrame.live,
  'bubble_gum': AvatarFrame.bubbleGum,
  'stickers': AvatarFrame.stickers,
  'aura': AvatarFrame.aura,
  'glitch': AvatarFrame.glitch,
  'social_battery': AvatarFrame.socialBattery,
  'typing': AvatarFrame.typing,
  'saturn': AvatarFrame.saturn,
  'vinyl': AvatarFrame.vinyl,
  'weather': AvatarFrame.weather,
  'sleep': AvatarFrame.sleep,
  'pixel': AvatarFrame.pixel,
  'chrome': AvatarFrame.chrome,
};

List<String> get kLiveFrameIds => kLiveFrameKinds.keys.toList(growable: false);

bool isLiveFrameId(String? id) => id != null && kLiveFrameKinds.containsKey(id);

/// Ниже этого размера движения нет вовсе: портрет меньше пальца, и дёргающееся
/// ухо на нём читается как дефект отрисовки, а не как жизнь.
///
/// 🔴 Порог опущен с 56 до 36 по решению владельца от 23.09.2026: в шапке
/// переписки (42) и на значке профиля внизу (40) персонаж должен ЖИТЬ. Там он
/// на экране один-два, и кадр стоит около 0.3 мс — это ничто. Списки же
/// обходятся без движения не по размеру, а по месту: они гасят тикер через
/// `TickerMode`, см. `chats_screen.dart`.
const double kLiveFrameMinAnimatedPx = 36;

/// Ниже этого размера рисуется одно кольцо, без ушей, рук и нот.
///
/// 🔴 24 — это уже не «список чатов», а значок размером с букву: там персонажа
/// не разглядеть при любом желании. Прежние 48 отрезали его и в шапке
/// переписки, и в строке списка — владелец 23.09.2026 попросил вернуть
/// персонажа везде, и вылет за квадрат стал не бедой, а условием: места под
/// уши и наушники вызывающая сторона обязана не обрезать.
const double kLiveFrameFullPx = 24;

/// Персонаж по идентификатору из профиля. `null` — рамка не живая.
FrameSim? makeLiveFrame(String? id) {
  final kind = id == null ? null : kLiveFrameKinds[id];
  return kind == null ? null : createFrameSim(kind);
}

// ─────────────────────── разбудить персонажа ───────────────────────

/// Нажатие, которое персонаж чувствует.
///
/// 🔴 ПОЧЕМУ ОБЛАСТЬ, А НЕ ПАРАМЕТР. Рамку рисует не тот, кто знает про
/// нажатие: портрет собирают `FramedAvatar` и `Avatar`, а те зовут
/// `frame.builder(size)` — подпись, общая у всех сорока четырёх рамок. Чтобы
/// передать нажатие параметром, пришлось бы менять эту подпись и каждое место
/// вызова, включая экраны телефона. Область передаёт его сквозь них, ничего не
/// трогая: кто рисует живую рамку — подпишется, остальные не заметят.
class LiveFramePressScope extends InheritedNotifier<ValueNotifier<bool>> {
  const LiveFramePressScope({
    super.key,
    required ValueNotifier<bool> pressed,
    required super.child,
  }) : super(notifier: pressed);

  /// `false`, если области нет: рамка в списке чатов и в шапке переписки живёт
  /// сама по себе, будить её некому.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiveFramePressScope>()
          ?.notifier
          ?.value ??
      false;

  /// Сам переключатель — для кнопки. `null` там, где области нет.
  ///
  /// Читает БЕЗ подписки: кнопке незачем перестраиваться от чужого нажатия,
  /// она и так перестроится от своего.
  static ValueNotifier<bool>? controllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LiveFramePressScope>()?.notifier;
}

/// Сколько длится «особое» состояние, прежде чем персонаж сам вернётся в покой.
///
/// 🔴 ВОЗВРАТ ПО ВРЕМЕНИ, А НЕ ВТОРЫМ НАЖАТИЕМ. Решение владельца от
/// 23.09.2026. Нажатие здесь — это не переключатель настройки, а тычок: кота
/// погладили, призрак сказал «бу», пластинку скретчнули. Оставлять человека с
/// кнопкой «выключить обратно» значит превращать шалость в режим, про который
/// надо помнить.
///
/// Числа подобраны на глаз по длине самого действия: разовые выходки короче,
/// «режимы» вроде дедлайна и гравитации длиннее. Одно место — чтобы правка
/// ритма была правкой таблицы, а не поиском по коду.
const Map<String, double> _kLiveFrameActionSeconds = <String, double>{
  'cat': 3.0,
  'coder': 4.0,
  'music': 2.5,
  'aquarium': 3.0,
  'slime': 1.6,
  'octopus': 3.0,
  'bird': 2.2,
  'lava_lamp': 3.5,
  'ghost': 1.8,
  'streak': 2.0,
  'level_up': 2.6,
  'live': 2.0,
  'bubble_gum': 2.0,
  'stickers': 2.6,
  'aura': 2.4,
  'glitch': 1.8,
  'social_battery': 2.8,
  'typing': 2.4,
  'saturn': 3.0,
  'vinyl': 1.8,
  'weather': 3.2,
  'sleep': 2.6,
  'pixel': 2.0,
  'chrome': 2.4,
};

Duration liveFrameActionDuration(String? id) => Duration(
  milliseconds: (((id == null ? null : _kLiveFrameActionSeconds[id]) ?? 2.6) *
          1000)
      .round(),
);

/// Держатель нажатия: заводит переключатель, кладёт его над [child] и сам
/// возвращает персонажа в покой, когда выходка доиграна.
///
/// 🔴 ОБЁРТКА, А НЕ ПЕРЕДЕЛКА ЭКРАНА. Шапка профиля — большой `build` без
/// состояния; превращать её в `StatefulWidget` ради одного `bool` значило бы
/// тронуть три десятка строк в файле, где каждая правка ведёт к телефону.
/// Обёртка добавляет ровно одну строку, а кнопка достаёт переключатель через
/// `Builder` — он оказывается НИЖЕ держателя в дереве, хотя в коде написан
/// раньше.
class LiveFramePressHost extends StatefulWidget {
  const LiveFramePressHost({super.key, required this.frameId, required this.child});

  /// Рамка, чьё время возврата берём.
  final String? frameId;

  final Widget child;

  @override
  State<LiveFramePressHost> createState() => _LiveFramePressHostState();
}

class _LiveFramePressHostState extends State<LiveFramePressHost> {
  final ValueNotifier<bool> _pressed = ValueNotifier<bool>(false);
  Timer? _back;

  @override
  void initState() {
    super.initState();
    _pressed.addListener(_scheduleReturn);
  }

  void _scheduleReturn() {
    _back?.cancel();
    if (!_pressed.value) return;
    // Повторное нажатие во время выходки продлевает её, а не обрывает:
    // таймер заводится заново от последнего нажатия.
    _back = Timer(liveFrameActionDuration(widget.frameId), () {
      if (mounted) _pressed.value = false;
    });
  }

  @override
  void dispose() {
    _back?.cancel();
    _pressed.removeListener(_scheduleReturn);
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LiveFramePressScope(pressed: _pressed, child: widget.child);
}

/// Подписи кнопки, которая будит персонажа.
///
/// 🔴 ЖИВУТ ЗДЕСЬ, А НЕ В ARB. Это не подпись окна, а свойство КОНКРЕТНОЙ
/// рамки — как её название, которое тоже лежит таблицей в каталоге. Добавить
/// рамку значит добавить сюда одну строку, а не восемь файлов переводов.
///
/// Глагол у каждого персонажа свой и взят из макета: кота гладят, у кодера
/// дедлайн, пластинку скретчат. Общее «Оживить» на все двадцать четыре было бы
/// короче, но перестало бы объяснять, что именно сейчас произойдёт.
///
/// Подпись ОДНА, а не пара: состояние возвращается само, и «Хватит» на кнопке
/// было бы обещанием, которого она больше не выполняет.
const Map<String, Map<String, String>> _kLiveFrameActions = {
  'cat': {'ru': 'Погладить', 'en': 'Pet', 'uk': 'Погладити', 'es': 'Acariciar', 'pt': 'Fazer festa', 'fr': 'Caresser', 'de': 'Streicheln'},
  'coder': {'ru': 'Дедлайн!', 'en': 'Deadline!', 'uk': 'Дедлайн!', 'es': '¡Fecha límite!', 'pt': 'Prazo!', 'fr': 'Deadline !', 'de': 'Deadline!'},
  'music': {'ru': 'Пауза', 'en': 'Pause', 'uk': 'Пауза', 'es': 'Pausa', 'pt': 'Pausa', 'fr': 'Pause', 'de': 'Pause'},
  'aquarium': {'ru': 'Покормить', 'en': 'Feed', 'uk': 'Погодувати', 'es': 'Dar de comer', 'pt': 'Alimentar', 'fr': 'Nourrir', 'de': 'Füttern'},
  'slime': {'ru': 'Ткнуть', 'en': 'Poke', 'uk': 'Штовхнути', 'es': 'Tocar', 'pt': 'Cutucar', 'fr': 'Toucher', 'de': 'Anstupsen'},
  'octopus': {'ru': 'Обнять', 'en': 'Hug', 'uk': 'Обійняти', 'es': 'Abrazar', 'pt': 'Abraçar', 'fr': 'Câliner', 'de': 'Umarmen'},
  'bird': {'ru': 'Спугнуть', 'en': 'Startle', 'uk': 'Сполохати', 'es': 'Espantar', 'pt': 'Assustar', 'fr': 'Faire fuir', 'de': 'Aufscheuchen'},
  'lava_lamp': {'ru': 'Нагреть', 'en': 'Heat up', 'uk': 'Нагріти', 'es': 'Calentar', 'pt': 'Aquecer', 'fr': 'Chauffer', 'de': 'Aufheizen'},
  'ghost': {'ru': 'Бу!', 'en': 'Boo!', 'uk': 'Бу!', 'es': '¡Bu!', 'pt': 'Bu!', 'fr': 'Bouh !', 'de': 'Buh!'},
  'streak': {'ru': '+1 день', 'en': '+1 day', 'uk': '+1 день', 'es': '+1 día', 'pt': '+1 dia', 'fr': '+1 jour', 'de': '+1 Tag'},
  'level_up': {'ru': '+25 XP', 'en': '+25 XP', 'uk': '+25 XP', 'es': '+25 XP', 'pt': '+25 XP', 'fr': '+25 XP', 'de': '+25 XP'},
  'live': {'ru': 'Лайкнуть', 'en': 'Like', 'uk': 'Лайкнути', 'es': 'Dar like', 'pt': 'Curtir', 'fr': 'Aimer', 'de': 'Liken'},
  'bubble_gum': {'ru': 'Лопнуть', 'en': 'Pop', 'uk': 'Луснути', 'es': 'Reventar', 'pt': 'Estourar', 'fr': 'Faire éclater', 'de': 'Platzen'},
  'stickers': {'ru': 'Отклеить', 'en': 'Peel off', 'uk': 'Відклеїти', 'es': 'Despegar', 'pt': 'Descolar', 'fr': 'Décoller', 'de': 'Ablösen'},
  'aura': {'ru': 'Сменить вайб', 'en': 'Switch vibe', 'uk': 'Змінити вайб', 'es': 'Cambiar vibra', 'pt': 'Mudar a vibe', 'fr': 'Changer de vibe', 'de': 'Vibe wechseln'},
  'glitch': {'ru': 'Сломать', 'en': 'Break it', 'uk': 'Зламати', 'es': 'Romper', 'pt': 'Quebrar', 'fr': 'Casser', 'de': 'Kaputtmachen'},
  'social_battery': {'ru': 'Зарядить', 'en': 'Charge', 'uk': 'Зарядити', 'es': 'Cargar', 'pt': 'Carregar', 'fr': 'Recharger', 'de': 'Aufladen'},
  'typing': {'ru': 'Отправить', 'en': 'Send', 'uk': 'Надіслати', 'es': 'Enviar', 'pt': 'Enviar', 'fr': 'Envoyer', 'de': 'Senden'},
  'saturn': {'ru': 'Гравитация', 'en': 'Gravity', 'uk': 'Гравітація', 'es': 'Gravedad', 'pt': 'Gravidade', 'fr': 'Gravité', 'de': 'Schwerkraft'},
  'vinyl': {'ru': 'Скретч!', 'en': 'Scratch!', 'uk': 'Скретч!', 'es': '¡Scratch!', 'pt': 'Scratch!', 'fr': 'Scratch !', 'de': 'Scratch!'},
  'weather': {'ru': 'Солнце', 'en': 'Sunshine', 'uk': 'Сонце', 'es': 'Sol', 'pt': 'Sol', 'fr': 'Soleil', 'de': 'Sonne'},
  'sleep': {'ru': 'Разбудить', 'en': 'Wake up', 'uk': 'Розбудити', 'es': 'Despertar', 'pt': 'Acordar', 'fr': 'Réveiller', 'de': 'Wecken'},
  'pixel': {'ru': 'Взорвать', 'en': 'Blow up', 'uk': 'Підірвати', 'es': 'Explotar', 'pt': 'Explodir', 'fr': 'Faire exploser', 'de': 'Sprengen'},
  'chrome': {'ru': 'Капнуть', 'en': 'Drip', 'uk': 'Крапнути', 'es': 'Gotear', 'pt': 'Pingar', 'fr': 'Goutte', 'de': 'Tropfen'},
};

/// Подпись кнопки для рамки [id]. `null` — у рамки нет действия, и кнопку
/// показывать нельзя: пустая кнопка хуже отсутствующей.
String? liveFrameActionLabel(BuildContext context, String? id) =>
    liveFrameActionLabelForLocale(wave1LocaleTagFromContext(context), id);

/// То же, но по метке языка — без дерева виджетов, чтобы полноту переводов
/// можно было проверить обычным тестом, а не поднимая экран.
String? liveFrameActionLabelForLocale(String localeTag, String? id) {
  if (id == null) return null;
  final row = _kLiveFrameActions[id];
  if (row == null) return null;
  // pt_BR берёт португальские глаголы: они совпадают, а отдельная строка
  // разъехалась бы при первой же правке.
  return row[localeTag] ??
      (localeTag == 'pt_BR' ? row['pt'] : null) ??
      row['en']!;
}

// ─────────────────────────── показ ───────────────────────────

/// Рамка-персонаж на квадрате [size].
///
/// Рисуется в координатах набора (холст 200×200) и СОЗНАТЕЛЬНО выходит за
/// квадрат: там уши, руки и ноты. Вызывающая сторона не должна обрезать.
class LiveFrameView extends StatefulWidget {
  const LiveFrameView({
    super.key,
    required this.size,
    required this.id,
    this.pressed = false,
  });

  final double size;
  final String id;

  /// Единственный вход набора. Обычно приходит из [LiveFramePressScope];
  /// параметром его задают проверки и витрины.
  final bool pressed;

  @override
  State<LiveFrameView> createState() => _LiveFrameViewState();
}

class _LiveFrameViewState extends State<LiveFrameView>
    with SingleTickerProviderStateMixin {
  // Не `late final`: тикер, созданный лениво, был бы построен уже внутри
  // dispose(), а createTicker смотрит TickerMode на умершем элементе.
  Ticker? _ticker;
  FrameSim? _sim;
  double _last = 0;
  bool _animated = false;

  /// Нажатие из области над портретом.
  bool _scopePressed = false;

  bool get _pressed => widget.pressed || _scopePressed;

  @visibleForTesting
  FrameSim? get debugSim => _sim;

  @override
  void initState() {
    super.initState();
    _sim = makeLiveFrame(widget.id)?..active = _pressed;
  }

  @override
  void didUpdateWidget(covariant LiveFrameView old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _sim?.dispose();
      _sim = makeLiveFrame(widget.id)?..active = _pressed;
    }
    if (old.size != widget.size) _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔴 Подписка на область идёт ЗДЕСЬ, а не в build: так состояние узнаёт о
    // нажатии, даже если кадр в этот миг рисует тикер, а не перестроение.
    final pressed = LiveFramePressScope.of(context);
    if (pressed != _scopePressed) {
      _scopePressed = pressed;
      final sim = _sim;
      if (sim != null) {
        sim.active = _pressed;
        // 🔴 Состояние ставится СРАЗУ, а не ближайшим кадром тикера: тот
        // считает время по стенным часам, и запаздывание в 16 мс видно
        // глазу, а на неподвижном портрете не происходило бы ничего.
        if (!_animated) sim.settle();
      }
    }
    _syncTicker();
  }

  void _syncTicker() {
    // 🔴 Четыре условия, и каждое стоило отдельного разбора: настройка
    // «украшения собеседников» (списки и чат), немой тикер под закрытым
    // маршрутом, «меньше движения» в системе и размер. Ниже 56 точек персонаж
    // превращается в кашу, и набор прямо велит показывать кадр.
    final allowed =
        CosmeticAnimationScope.of(context) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.size >= kLiveFrameMinAnimatedPx;
    if (allowed == _animated) return;
    _animated = allowed;
    if (allowed) {
      _last = DateTime.now().millisecondsSinceEpoch / 1000.0;
      (_ticker ??= createTicker(_onTick)).start();
    } else {
      _ticker?.stop();
      // Неподвижный кадр — не нулевая секунда: набор прогоняет полторы
      // секунды симуляции, чтобы поза была осмысленной, а не стартовой.
      _sim?.settle();
    }
  }

  void _onTick(Duration _) {
    // Держим картинку, пока устройство греется или пока список летит: в эти
    // мгновения каждая миллисекунда принадлежит прокрутке.
    if (!ThermalGuard.effectsAllowed.value) return;
    if (CosmeticMotionGate.holdAnimations) return;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    // Тот же потолок, что у петель: пружинам 60 кадров в секунду достаточно,
    // а на 120-герцевом экране это ровно вдвое меньше работы.
    final dt = now - _last;
    if (dt < 1 / 60) return;
    _last = now;
    // Шаг Эйлера разваливается на длинном кадре: ограничение в 33 мс — то же,
    // что в наборе, и оно же спасает после возвращения из фона.
    _sim
      ?..active = _pressed
      ..tick(dt > 1 / 30 ? 1 / 30 : dt);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _sim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = _sim;
    if (sim == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final palette = FramePalette(
      ThemeData.estimateBrightnessForColor(scheme.surface) == Brightness.dark,
      // 🔴 Не макетный белый, а ПОВЕРХНОСТЬ, на которой лежит портрет: этим
      // цветом рисуется ободок между фотографией и кольцом, и чужой цвет
      // выдал бы себя полоской.
      scheme.surface,
    );
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: LiveFramePainter(
            sim: sim,
            palette: palette,
            ringOnly: widget.size < kLiveFrameFullPx,
          ),
        ),
      ),
    );
  }
}

/// Рисует персонажа в координатах набора, подгоняя круг фотографии под наш.
class LiveFramePainter extends CustomPainter {
  LiveFramePainter({
    required this.sim,
    required this.palette,
    this.ringOnly = false,
  }) : super(repaint: sim);

  final FrameSim sim;
  final FramePalette palette;

  /// Рисовать одно кольцо — см. [kLiveFrameFullPx].
  final bool ringOnly;

  /// Доля квадрата, которую занимает фотография у `FramedAvatar`.
  static const double avatarFraction = 0.86;

  /// Весь холст МИНУС круг фотографии. Задние части персонажа рисуются только
  /// здесь — это и заменяет второй слой под аватаром.
  static Path photoHole(FrameSim sim) => Path.combine(
    PathOperation.difference,
    Path()..addRect(const Rect.fromLTRB(-260, -260, 460, 460)),
    Path()..addOval(
      Rect.fromCircle(center: Offset(sim.cx, sim.cy), radius: sim.av),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final k = (size.width * avatarFraction / 2) / sim.av;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    canvas.translate(-sim.cx, -sim.cy);

    if (!ringOnly) {
      // Задние части — с вырезанным кругом фотографии: в наборе их закрывает
      // непрозрачная подложка под аватаром, у нас — сама фотография.
      canvas.save();
      canvas.clipPath(photoHole(sim));
      sim.back(canvas, palette);
      canvas.restore();
    }

    // Кольцо и ободок идут в преобразовании тела — оно сжимает их на ударе.
    sim.withBody(canvas, () {
      if (sim.drawRing) sim.paintRing(canvas);
      // 🔴 Ободок кольцевой полоской, а не кругом. В наборе здесь сплошной
      // круг подложки ПОД фотографией; у нас фотографию рисует вызывающая
      // сторона, и сплошной круг закрыл бы лицо.
      canvas.drawCircle(
        Offset(sim.cx, sim.cy),
        sim.av + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = palette.bg,
      );
    });

    if (!ringOnly) sim.front(canvas, palette);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiveFramePainter old) =>
      old.sim != sim || old.palette != palette || old.ringOnly != ringOnly;
}
