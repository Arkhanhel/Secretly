// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Окна и элементы управления в стиле iPhone (17.11.2026): на iPhone — как у
// iOS, на Android — ровно прежние Material-виджеты.
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/welcome/welcome_style.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

/// Окно «Удалить чат?» в том виде, в каком его пишут экраны приложения.
Future<bool?> _askDelete(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => SecretlyAlertDialog(
    title: const Text('Удалить чат?'),
    content: const Text('Переписка удалится на этом устройстве.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Отмена'),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Удалить'),
      ),
    ],
  ),
);

class _Opener extends StatelessWidget {
  const _Opener(this.open);

  final Future<Object?> Function(BuildContext) open;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => open(context), child: const Text('открыть'));
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  _pressFadeTests();

  group('окно подтверждения', () {
    testWidgets('iPhone: окно iOS, «Удалить» красным, «Отмена» жирным', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      bool? result;
      await tester.pumpWidget(
        _host(_Opener((c) async => result = await _askDelete(c))),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Удалить чат?'), findsOneWidget);

      final del = tester.widget<Text>(find.text('Удалить'));
      expect(del.style?.color, const Color(0xFFFF3B30));
      expect(del.style?.fontWeight, FontWeight.w400);
      final cancel = tester.widget<Text>(find.text('Отмена'));
      expect(cancel.style?.fontWeight, FontWeight.w600);

      // Две кнопки — рядом, во всю ширину окна шириной 270.
      final delBox = tester.getRect(find.text('Удалить'));
      final cancelBox = tester.getRect(find.text('Отмена'));
      expect((delBox.center.dy - cancelBox.center.dy).abs(), lessThan(1));
      expect(cancelBox.center.dx, lessThan(delBox.center.dx));

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iPhone: тёмная тема, нажатие «Отмена» возвращает false', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      bool? result;
      await tester.pumpWidget(
        _host(
          _Opener((c) async => result = await _askDelete(c)),
          brightness: Brightness.dark,
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Удалить')).style?.color,
        const Color(0xFFFF453A),
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android: прежний AlertDialog', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_host(_Opener(_askDelete)));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iPhone: поле ввода и галочка работают, окно шире', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final name = TextEditingController();
      var also = false;
      await tester.pumpWidget(
        _host(
          _Opener(
            (c) => showDialog<void>(
              context: c,
              builder: (context) => StatefulBuilder(
                builder: (context, setState) => SecretlyAlertDialog(
                  title: const Text('Заблокировать?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: name),
                      CheckboxListTile(
                        value: also,
                        onChanged: (v) => setState(() => also = v == true),
                        title: const Text('Удалить чат'),
                      ),
                    ],
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Юрий');
      await tester.tap(find.text('Удалить чат'));
      await tester.pump();
      expect(name.text, 'Юрий');
      expect(also, isTrue);
      // Основное действие (кнопка с заливкой) — жирным.
      expect(
        tester.widget<Text>(find.text('Готово')).style?.fontWeight,
        FontWeight.w600,
      );
      // Окно со списком/формой — шире узкого системного.
      expect(tester.getSize(find.byType(TextField)).width, greaterThan(240));
      name.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iPhone: крутилка на кнопке окна не роняет вёрстку', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _host(
          _Opener(
            (c) => showDialog<void>(
              context: c,
              builder: (context) => SecretlyAlertDialog(
                title: const Text('Сохраняем…'),
                actions: [
                  TextButton(onPressed: null, child: const Text('Отмена')),
                  FilledButton(
                    onPressed: null,
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: SecretlySpinner(strokeWidth: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('крутилка', () {
    testWidgets('iPhone: без хода — индикатор Apple, с ходом — кольцо', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: SecretlySpinner()),
              SizedBox(
                width: 20,
                height: 20,
                child: SecretlySpinner(value: 0.4),
              ),
              IntrinsicHeight(child: Row(children: [SecretlySpinner()])),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoActivityIndicator), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final size = tester.getSize(
        find.byType(CupertinoActivityIndicator).first,
      );
      expect(size.width, lessThanOrEqualTo(20));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android: прежнее кольцо', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_host(const SecretlySpinner()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('переключатель', () {
    testWidgets('iPhone: переключатель Apple, строка нажимается целиком', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var on = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => SecretlySwitchListTile(
              value: on,
              onChanged: (v) => setState(() => on = v),
              title: const Text('Звук'),
            ),
          ),
        ),
      );
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.text('Звук'));
      await tester.pumpAndSettle();
      expect(on, isTrue);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(on, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android: прежние Switch и SwitchListTile', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SecretlySwitch(value: true, onChanged: (_) {}),
              SecretlySwitchListTile(
                value: false,
                onChanged: (_) {},
                title: const Text('Звук'),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('iPhone: дата и время — барабан, «Готово» возвращает выбор', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final now = DateTime(2026, 11, 17, 15, 0);
    DateTime? picked;
    var closed = false;
    await tester.pumpWidget(
      _host(
        _Opener((c) async {
          picked = await showAppleDateTimePicker(
            c,
            initial: now,
            minimum: now.subtract(const Duration(minutes: 1)),
            maximum: now.add(const Duration(days: 730)),
            doneLabel: 'Готово',
          );
          closed = true;
          return picked;
        }),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked, now);
    debugDefaultTargetPlatformOverride = null;
  });

  group('смахивание строки чата', () {
    Widget rows(List<String> log) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (final name in ['Аня', 'Борис'])
              AppleSwipeActions(
                key: ValueKey(name),
                leading: [
                  AppleSwipeAction(
                    label: 'Закрепить',
                    icon: Icons.push_pin,
                    color: const Color(0xFFFF9500),
                    onPressed: () => log.add('pin $name'),
                  ),
                ],
                trailing: [
                  AppleSwipeAction(
                    label: 'Без звука',
                    icon: Icons.notifications_off,
                    color: const Color(0xFF5856D6),
                    onPressed: () => log.add('mute $name'),
                  ),
                  AppleSwipeAction(
                    label: 'Удалить',
                    icon: Icons.delete,
                    color: const Color(0xFFFF3B30),
                    onPressed: () => log.add('delete $name'),
                  ),
                ],
                child: ListTile(
                  title: Text(name),
                  onTap: () => log.add('open $name'),
                ),
              ),
          ],
        ),
      ),
    );

    testWidgets('влево — «Без звука» и «Удалить», нажатие срабатывает', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(rows(log));
      expect(find.text('Удалить'), findsNothing);
      await tester.drag(find.text('Аня'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Без звука'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(log, ['delete Аня']);
      expect(find.text('Удалить'), findsNothing);
    });

    testWidgets('вправо — «Закрепить»', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(rows(log));
      await tester.drag(find.text('Борис'), const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Закрепить'));
      await tester.pumpAndSettle();
      expect(log, ['pin Борис']);
    });

    testWidgets('короткое движение — строка возвращается', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(rows(log));
      await tester.timedDrag(
        find.text('Аня'),
        const Offset(-30, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(find.text('Удалить'), findsNothing);
    });

    testWidgets('тап по открытой строке закрывает кнопки, чат не открывается', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(rows(log));
      await tester.drag(find.text('Аня'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Аня'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить'), findsNothing);
      expect(log, isEmpty);
      await tester.tap(find.text('Аня'));
      await tester.pumpAndSettle();
      expect(log, ['open Аня']);
    });

    testWidgets('открыть вторую строку — первая закрывается', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(rows(log));
      await tester.drag(find.text('Аня'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Борис'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Удалить'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Удалить')).dy,
        closeTo(tester.getCenter(find.text('Борис')).dy, 30),
      );
    });

    testWidgets('экранный диктор видит действия строки', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(rows(<String>[]));
      final data = tester
          .getSemantics(find.byKey(const ValueKey('Аня')))
          .getSemanticsData();
      final labels = [
        for (final id in data.customSemanticsActionIds ?? const <int>[])
          CustomSemanticsAction.getAction(id)?.label,
      ];
      expect(labels, containsAll(['Закрепить', 'Без звука', 'Удалить']));
      handle.dispose();
    });
  });

  test('значки действий: на iPhone — iOS, иначе прежние', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(appleShareIcon(Icons.share_outlined), CupertinoIcons.share);
    expect(appleBackIcon(Icons.arrow_back), CupertinoIcons.back);
    expect(appleMoreIcon(Icons.more_vert_rounded), CupertinoIcons.ellipsis);
    for (final p in [TargetPlatform.android, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = p;
      expect(appleShareIcon(Icons.share_outlined), Icons.share_outlined);
      expect(appleBackIcon(Icons.arrow_back), Icons.arrow_back);
      expect(appleMoreIcon(Icons.more_vert_rounded), Icons.more_vert_rounded);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  group('проверка 17.11 — найденное и исправленное', () {
    testWidgets('строка при смахивании НЕ пересоздаётся (аватар не мигает)', (
      tester,
    ) async {
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AppleSwipeActions(
                  trailing: [
                    AppleSwipeAction(
                      label: 'Удалить',
                      icon: Icons.delete,
                      color: Colors.red,
                      onPressed: () {},
                    ),
                  ],
                  child: _CountingRow(onInit: () => created++),
                ),
              ],
            ),
          ),
        ),
      );
      expect(created, 1);
      await tester.drag(find.byType(_CountingRow), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Удалить'), findsOneWidget);
      await tester.tap(find.byType(_CountingRow));
      await tester.pumpAndSettle();
      expect(created, 1, reason: 'открытие и закрытие не пересоздают строку');
    });

    testWidgets('нажатие мимо закрывает открытую строку', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppleSwipeActions(
                  trailing: [
                    AppleSwipeAction(
                      label: 'Удалить',
                      icon: Icons.delete,
                      color: Colors.red,
                      onPressed: () {},
                    ),
                  ],
                  child: const ListTile(title: Text('Аня')),
                ),
                const SizedBox(height: 300),
                TextButton(onPressed: () {}, child: const Text('другое')),
              ],
            ),
          ),
        ),
      );
      await tester.drag(find.text('Аня'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Удалить'), findsOneWidget);
      await tester.tap(find.text('другое'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить'), findsNothing);
    });

    testWidgets('iPhone: окно со своим тёмным фоном — поле не белое', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _host(
          _Opener(
            (c) => showDialog<void>(
              context: c,
              builder: (context) => SecretlyAlertDialog(
                backgroundColor: const Color(0xFF1F2733),
                title: const Text('Новый набор'),
                content: const TextField(style: TextStyle(color: Colors.white)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      final deco = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(deco.filled ?? false, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iPhone: розовая тема — «Отмена» синяя, не как «Удалить»', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE11D48),
            ).copyWith(primary: const Color(0xFFE11D48)),
          ),
          home: Scaffold(body: Center(child: _Opener(_askDelete))),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Отмена')).style?.color,
        const Color(0xFF007AFF),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iPhone: три кнопки — «Отмена» жирная и внизу', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _host(
          _Opener(
            (c) => showDialog<void>(
              context: c,
              builder: (context) => SecretlyAlertDialog(
                title: const Text('Покинуть комнату?'),
                actions: [
                  TextButton(
                    key: const ValueKey('cancel-key'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Передать'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Отмена')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester.getCenter(find.text('Отмена')).dy,
        greaterThan(tester.getCenter(find.text('Удалить')).dy),
      );
      // Ключ исходной кнопки сохранён (по нему ищут тесты).
      expect(find.byKey(const ValueKey('cancel-key')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

class _CountingRow extends StatefulWidget {
  const _CountingRow({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_CountingRow> createState() => _CountingRowState();
}

void _pressFadeTests() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('кнопки приветствия под пальцем: ${platform.name}', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Center(
              child: WelcomeTextButton(
                label: 'У меня уже есть аккаунт',
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('У меня уже есть аккаунт')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final fades = find.ancestor(
        of: find.text('У меня уже есть аккаунт'),
        matching: find.byType(AnimatedOpacity),
      );
      if (platform == TargetPlatform.iOS) {
        expect(tester.widget<AnimatedOpacity>(fades.first).opacity, 0.4);
      } else {
        // Android: прежняя кнопка Material со своим откликом.
        expect(find.byType(TextButton), findsOneWidget);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      if (platform == TargetPlatform.iOS) {
        expect(tester.widget<AnimatedOpacity>(fades.first).opacity, 1);
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

class _CountingRowState extends State<_CountingRow> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 64, child: Center(child: Text('строка')));
}
