import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/widgets/shell_layout.dart';
import 'package:weave/core/di/core_di.dart';
import 'package:weave/core/domain/note_color_id.dart';
import 'package:weave/core/theme/weave_theme.dart';
import 'package:weave/core/theme/weave_tokens.dart';
import 'package:weave/core/widgets/day_strip.dart';
import 'package:weave/core/widgets/day_thread.dart';
import 'package:weave/core/widgets/item_tile.dart';
import 'package:weave/core/widgets/quick_capture_field.dart';
import 'package:weave/core/widgets/undo_toast.dart';
import 'package:weave/features/items/domain/usecases/add_item.dart';
import 'package:weave/features/items/domain/usecases/toggle_done.dart';
import 'package:weave/features/up_next/presentation/capture_cubit.dart';
import 'package:weave/features/up_next/presentation/up_next_cubit.dart';
import 'package:weave/features/up_next/presentation/up_next_page.dart';

import 'up_next_fakes.dart';

// The prototype's moment: Tue 3 Nov 2026, 16:20.
final _now = DateTime(2026, 11, 3, 16, 20);
final _today = DateTime(2026, 11, 3);

late FakeItemsStore store;
late FakeLists lists;
late Replay<String?> pref;

void _setUp() {
  store = FakeItemsStore();
  lists = FakeLists();
  pref = Replay<String?>(null);
  sl
    ..registerFactory<UpNextCubit>(
      () => UpNextCubit(
        items: store,
        lists: lists,
        toggleDone: ToggleDone(store),
        now: () => _now,
      ),
    )
    ..registerFactory<CaptureCubit>(
      () => CaptureCubit(
        lists: lists,
        addItem: AddItem(store),
        capturePref: () => pref.stream,
        now: () => _now,
      ),
    );
}

/// What the shell gives a page: layout facts and the toast (owned here, so
/// its timers end with the tree).
Widget _shell(Widget child, {required bool phone}) => MaterialApp(
  theme: weaveTheme(Brightness.light),
  home: Material(
    child: HookBuilder(
      builder: (context) {
        final toast = useMemoized(UndoToastController.new);
        useEffect(() => toast.dispose, [toast]);
        return UndoToastScope(
          controller: toast,
          child: ShellLayout(
            isPhone: phone,
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                Positioned.fill(child: child),
                UndoToastLayer(controller: toast, bottom: 24),
              ],
            ),
          ),
        );
      },
    ),
  ),
);

void _size(WidgetTester tester, {required bool phone}) {
  tester.view
    ..physicalSize = phone ? const Size(390, 844) : const Size(1184, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, {bool phone = false}) async {
  _size(tester, phone: phone);
  await tester.pumpWidget(_shell(const UpNextPage(), phone: phone));
  await tester.pumpAndSettle();
}

void _seed() {
  lists.active.add([
    taskList('l1', 'Errands'),
    taskList('l2', 'Work', color: NoteColor.blue),
  ]);
  store
    ..put(task('pay', 'l1', 'Pay electricity bill', date: _today, minutes: 540))
    ..put(
      task(
        'reply',
        'l2',
        'Reply to design review',
        date: _today,
        minutes: 1020,
      ),
    )
    ..put(
      task('milk', 'l1', 'Buy milk', date: _today, minutes: 720, done: true),
    )
    ..put(
      task(
        'dentist',
        'l1',
        'Dentist',
        date: DateTime(2026, 11, 6),
        minutes: 600,
      ),
    );
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

Finder _tileOf(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(ItemTile));

void main() {
  tearDown(() => sl.reset());

  testWidgets('up next lists overdue first in red with list name', (
    tester,
  ) async {
    _setUp();
    _seed();
    await _pump(tester);
    final t = WeaveTokens.light;

    // Header (C2): date, title, one fact.
    expect(find.text('Tue 3 Nov'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(
      find.text('2 left today · next Reply to design review at 17:00'),
      findsOneWidget,
    );

    // One list: overdue, upcoming, done (C5).
    expect(
      _top(tester, 'Pay electricity bill'),
      lessThan(_top(tester, 'Reply to design review')),
    );
    expect(
      _top(tester, 'Reply to design review'),
      lessThan(_top(tester, 'Buy milk')),
    );
    // The overdue time is red, with the alert icon and hidden words.
    final late = find.descendant(
      of: _tileOf('Pay electricity bill'),
      matching: find.text('09:00'),
    );
    expect(tester.widget<Text>(late).style?.color, t.negative);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Overdue, 09:00')), findsOneWidget);
    semantics.dispose();
    final onTime = find.descendant(
      of: _tileOf('Reply to design review'),
      matching: find.text('17:00'),
    );
    expect(tester.widget<Text>(onTime).style?.color, t.muted);
    // Today spans two lists, so each row names its list.
    expect(
      find.descendant(
        of: _tileOf('Pay electricity bill'),
        matching: find.text('Errands'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _tileOf('Reply to design review'),
        matching: find.text('Work'),
      ),
      findsOneWidget,
    );
    // Done rows: solid strike.
    final milk = tester.widget<Text>(find.text('Buy milk'));
    expect(milk.style?.decoration, TextDecoration.lineThrough);

    // Later this week: count in the header, no list names.
    expect(find.text('Later this week'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.text('Fri 10:00'), findsOneWidget);
    expect(
      find.descendant(of: _tileOf('Dentist'), matching: find.text('Errands')),
      findsNothing,
    );
    // Desktop: the day thread card, not the strip.
    expect(find.text("Today's thread"), findsOneWidget);
    expect(find.byType(DayThread), findsOneWidget);
    expect(find.byType(DayStrip), findsNothing);
    // The one field sits in the Today card (C3).
    expect(find.byType(QuickCaptureField), findsOneWidget);
  });

  testWidgets('ticking shows undo toast and undo reopens task', (tester) async {
    _setUp();
    _seed();
    await _pump(tester);
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Check Reply to design review'));
    // Fill and strike (120 ms), fade (120 ms), then it is written.
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(store.items['reply']!.done, isTrue);
    expect(find.text('Checked "Reply to design review"'), findsOneWidget);
    // It stays on Today, last and struck through.
    expect(
      _top(tester, 'Reply to design review'),
      greaterThan(_top(tester, 'Buy milk')),
    );
    expect(
      find.bySemanticsLabel('Uncheck Reply to design review'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.items['reply']!.done, isFalse);
    expect(store.items['reply']!.doneAt, isNull);
    expect(
      find.bySemanticsLabel('Check Reply to design review'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('empty state copy from prototype when nothing is due', (
    tester,
  ) async {
    _setUp();
    lists.active.add([taskList('l1', 'Errands')]);
    await _pump(tester);
    expect(find.text('Nothing left for today'), findsOneWidget); // subline
    expect(find.text('Nothing left for today.'), findsOneWidget);
    expect(find.text('Nothing scheduled after today.'), findsOneWidget);
  });

  testWidgets('Enter in Up next adds to the chosen list and says where', (
    tester,
  ) async {
    _setUp();
    _seed();
    await _pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(QuickCaptureField),
        matching: find.text('Errands'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Work'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(QuickCaptureField),
        matching: find.byType(EditableText),
      ),
      'call mom tomorrow 6pm',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final added = store.items.values.singleWhere((i) => i.text == 'call mom');
    expect(added.listId, 'l2');
    expect(find.text('Added to Work · Due Tomorrow 18:00'), findsOneWidget);
  });

  testWidgets('phone: Today card with the one-line strip, no field', (
    tester,
  ) async {
    _setUp();
    _seed();
    await _pump(tester, phone: true);
    expect(find.byType(DayStrip), findsOneWidget);
    expect(find.byType(DayThread), findsNothing);
    expect(find.text("Today's thread"), findsNothing);
    // The add field is the shell's add bar, not in the page.
    expect(find.byType(QuickCaptureField), findsNothing);
    // List names are not shown on phones (app.css `.lay-phone .row .src`).
    expect(
      find.descendant(
        of: _tileOf('Pay electricity bill'),
        matching: find.text('Errands'),
      ),
      findsNothing,
    );
    // 44 px tick targets on phones.
    final semantics = tester.ensureSemantics();
    final check = find.bySemanticsLabel('Check Pay electricity bill');
    expect(tester.getSize(check).height, greaterThanOrEqualTo(44));
    semantics.dispose();
  });

  testWidgets('phone add bar adds to the capture list', (tester) async {
    _setUp();
    _seed();
    pref.add('l2');
    _size(tester, phone: true);
    await tester.pumpWidget(
      _shell(
        const Align(alignment: Alignment.bottomCenter, child: UpNextAddBar()),
        phone: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);
    expect(tester.getSize(find.byKey(QuickCaptureField.boxKey)).height, 44);
    await tester.enterText(find.byType(EditableText), 'stamps');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      store.items.values.singleWhere((i) => i.text == 'stamps').listId,
      'l2',
    );
  });

  testWidgets('a keyboard tick is instant', (tester) async {
    _setUp();
    _seed();
    await _pump(tester);
    final semantics = tester.ensureSemantics();
    final check = find.bySemanticsLabel('Check Reply to design review');
    Focus.of(
      tester.element(
        find
            .descendant(of: check, matching: find.byType(GestureDetector))
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(store.items['reply']!.done, isTrue);
    await tester.pump();
    // The fill is drawn at once too, no 120 ms ease.
    final circle = tester.widget<AnimatedContainer>(
      find.descendant(
        of: _tileOf('Reply to design review'),
        matching: find.byKey(ItemTile.circleKey),
      ),
    );
    expect(circle.duration, Duration.zero);
    semantics.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('tick, undo, tick again: stays ticked, one write', (
    tester,
  ) async {
    _setUp();
    _seed();
    await _pump(tester);
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Check Reply to design review'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(store.items['reply']!.done, isTrue);
    await tester.pump(const Duration(milliseconds: 1200)); // 1.5 s in
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump();
    expect(store.items['reply']!.done, isFalse);
    final before = store.writes.length;
    await tester.tap(find.bySemanticsLabel('Check Reply to design review'));
    await tester.pump(const Duration(milliseconds: 300));
    // Past the first tick's old 2 s fallback.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(store.writes.length - before, 1);
    expect(store.items['reply']!.done, isTrue);
    expect(
      find.bySemanticsLabel('Uncheck Reply to design review'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('phone rows: tick at 8, title at 38, 44 px target', (
    tester,
  ) async {
    _setUp();
    _seed();
    await _pump(tester, phone: true);
    final tile = _tileOf('Pay electricity bill');
    final left = tester.getTopLeft(tile).dx;
    expect(tester.getTopLeft(find.text('Pay electricity bill')).dx - left, 38);
    final semantics = tester.ensureSemantics();
    final check = tester.getRect(
      find.bySemanticsLabel('Check Pay electricity bill'),
    );
    expect(check.width, greaterThanOrEqualTo(44));
    expect(check.height, greaterThanOrEqualTo(44));
    // The 18 px circle sits 8 from the row's edge (app.css `.lay-phone .check`).
    final circle = find.descendant(
      of: tile,
      matching: find.byKey(ItemTile.circleKey),
    );
    expect(tester.getTopLeft(circle).dx - left, 8);
    semantics.dispose();
  });

  testWidgets('no list yet: Enter keeps the text and says why', (tester) async {
    _setUp();
    await _pump(tester);
    final field = find.descendant(
      of: find.byType(QuickCaptureField),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'call mom');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Make a list first'), findsOneWidget);
    expect(tester.widget<EditableText>(field).controller.text, 'call mom');
    expect(store.items, isEmpty);
  });

  testWidgets('a failing write keeps the text', (tester) async {
    _setUp();
    _seed();
    await _pump(tester);
    final field = find.descendant(
      of: find.byType(QuickCaptureField),
      matching: find.byType(EditableText),
    );
    store.failNext = true;
    await tester.enterText(field, 'call mom');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field).controller.text, 'call mom');
    expect(store.items.values.where((i) => i.text == 'call mom'), isEmpty);
    expect(find.text("Couldn't add that. Try again."), findsOneWidget);
  });

  group('cubits', () {
    test(
      'capture list: the pref when it is an active list, else the first',
      () async {
        _setUp();
        lists.active.add([taskList('l1', 'Errands'), taskList('l2', 'Work')]);
        final c = sl<CaptureCubit>();
        await pumpEventQueue();
        expect(c.state.listId, 'l1');
        pref.add('l2');
        await pumpEventQueue();
        expect(c.state.listId, 'l2');
        pref.add('gone');
        await pumpEventQueue();
        expect(c.state.listId, 'l1');
        // A pick on the field wins until that list goes away.
        c.pick('l2');
        expect(c.state.listId, 'l2');
        lists.active.add([taskList('l1', 'Errands')]);
        await pumpEventQueue();
        expect(c.state.listId, 'l1');
        await c.close();
      },
    );

    test('the minute tick follows the wall clock, across midnight', () {
      fakeAsync((async) {
        final store = FakeItemsStore();
        // 23:58:45: the first tick is 15 s away (the next :00), not 60.
        final start = DateTime(2026, 11, 3, 23, 58, 45);
        DateTime clock() => start.add(async.elapsed);
        final c = UpNextCubit(
          items: store,
          lists: FakeLists(),
          toggleDone: ToggleDone(store),
          now: clock,
        );
        async.flushMicrotasks();
        expect(c.state.now, DateTime(2026, 11, 3, 23, 58));
        async.elapse(const Duration(seconds: 14));
        expect(c.state.now, DateTime(2026, 11, 3, 23, 58));
        async.elapse(const Duration(seconds: 1));
        expect(c.state.now, DateTime(2026, 11, 3, 23, 59));
        expect(store.upNextAt.last, DateTime(2026, 11, 3, 23, 59));
        // Midnight: a new day re-reads today's done tasks for that day.
        async.elapse(const Duration(minutes: 1));
        expect(c.state.now, DateTime(2026, 11, 4));
        expect(store.doneTodayAt.last, DateTime(2026, 11, 4));
        expect(store.upNextAt.last, DateTime(2026, 11, 4));
        // Still on the minute an hour later (no drift).
        async.elapse(const Duration(hours: 1));
        expect(c.state.now, DateTime(2026, 11, 4, 1));
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });
  });
}
