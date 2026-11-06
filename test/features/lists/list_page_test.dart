import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:weave/app/shell/shell_actions.dart';
import 'package:weave/core/di/core_di.dart';
import 'package:weave/core/domain/note_color_id.dart';
import 'package:weave/core/theme/weave_theme.dart';
import 'package:weave/core/widgets/quick_capture_field.dart';
import 'package:weave/core/widgets/shell_layout.dart';
import 'package:weave/core/widgets/undo_toast.dart';
import 'package:weave/features/items/domain/repositories/items_repository.dart';
import 'package:weave/features/items/domain/usecases/add_item.dart';
import 'package:weave/features/items/domain/usecases/add_item_below.dart';
import 'package:weave/features/items/domain/usecases/delete_item.dart';
import 'package:weave/features/items/domain/usecases/edit_text.dart';
import 'package:weave/features/items/domain/usecases/indent_item.dart';
import 'package:weave/features/items/domain/usecases/move_item.dart';
import 'package:weave/features/items/domain/usecases/toggle_done.dart';
import 'package:weave/features/items/domain/usecases/uncheck_all.dart';
import 'package:weave/features/lists/domain/entities/task_list.dart';
import 'package:weave/features/lists/domain/repositories/lists_repository.dart';
import 'package:weave/features/lists/domain/usecases/archive_list.dart';
import 'package:weave/features/lists/domain/usecases/trash_list.dart';
import 'package:weave/features/lists/domain/usecases/update_list.dart';
import 'package:weave/features/lists/presentation/list_cubit.dart';
import 'package:weave/features/lists/presentation/list_page.dart';

import '../up_next/up_next_fakes.dart';
import 'list_fakes.dart';

final _now = DateTime(2026, 11, 5, 16, 20);
late FakeListItems store;
late FakeListStore lists;

TaskList _list({bool hideDone = false}) => TaskList(
  id: 'l1',
  name: 'Errands',
  color: NoteColor.blue,
  sortKey: 'a',
  pinnedToTop: false,
  hideDone: hideDone,
);

/// Writes that answer late, as the real database's do.
class _SlowItems extends FakeListItems {
  static const delay = Duration(milliseconds: 50);
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> update(String id, Map<String, Object?> fields) async {
    calls.add(fields);
    await Future<void>.delayed(delay);
    await super.update(id, fields);
  }
}

void _setUp({bool hideDone = false, ItemsRepository? real}) {
  store = FakeListItems();
  final repo = real ?? store;
  lists = FakeListStore()..put(_list(hideDone: hideDone));
  addTearDown(sl.reset);
  sl.registerFactoryParam<ListCubit, String, void>(
    (id, _) => ListCubit(
      listId: id,
      items: repo,
      lists: lists,
      addItem: AddItem(repo),
      addItemBelow: AddItemBelow(repo),
      toggleDone: ToggleDone(repo),
      editText: EditText(repo),
      deleteItem: DeleteItem(repo),
      indentItem: IndentItem(repo),
      moveItem: MoveItem(repo),
      uncheckAll: UncheckAll(repo),
      updateList: UpdateList(lists),
      archiveList: ArchiveList(lists, clock: () => _now),
      trashList: TrashList(lists, clock: () => _now),
      now: () => _now,
    ),
  );
}

Future<void> _pump(WidgetTester tester, {bool phone = false}) async {
  tester.view
    ..physicalSize = phone ? const Size(390, 844) : const Size(1184, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/list/l1',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('UP NEXT'),
        routes: const [],
      ),
      GoRoute(
        path: '/list/:id',
        builder: (_, s) => ListPage(
          key: ValueKey(s.pathParameters['id']),
          listId: s.pathParameters['id']!,
          isNew: s.uri.queryParameters['new'] == '1',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp(
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
                    Positioned.fill(child: Router.withConfig(config: router)),
                    UndoToastLayer(controller: toast, bottom: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Row titles top to bottom (the editors' text).
List<String> _rows(WidgetTester tester) => tester
    .widgetList<EditableText>(
      find.descendant(
        of: find.byKey(ListPage.rowsKey),
        matching: find.byType(EditableText),
      ),
    )
    .map((e) => e.controller.text)
    .toList();

Finder _editor(String text) => find.descendant(
  of: find.byKey(ListPage.rowsKey),
  matching: find.byWidgetPredicate(
    (w) => w is EditableText && w.controller.text == text,
  ),
);

Future<void> _focus(WidgetTester tester, String text) async {
  await tester.tap(_editor(text));
  await tester.pump();
}

void _seedThree() {
  store
    ..put(keyed('a', 'l1', 'Oldest', 'a1'))
    ..put(keyed('b', 'l1', 'Middle', 'a2'))
    ..put(keyed('c', 'l1', 'Newest', 'a3'));
}

void main() {
  group('review fixes', () {
    testWidgets(
      'a focused idle row takes another device\'s edit and keeps it',
      (tester) async {
        _setUp();
        _seedThree();
        await _pump(tester);
        await _focus(tester, 'Middle');
        await store.update('b', {'text': 'Remote edit'});
        await tester.pumpAndSettle();
        expect(_rows(tester), ['Newest', 'Remote edit', 'Oldest']);
        await tester.tap(_editor('Oldest'));
        await tester.pumpAndSettle();
        expect(store.items['b']!.text, 'Remote edit');
      },
    );

    testWidgets('a focused idle title takes a rename and keeps it', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await tester.tap(find.byKey(ListPage.titleKey));
      await tester.pump();
      await lists.update('l1', {'name': 'Remote name'});
      await tester.pumpAndSettle();
      await tester.tap(_editor('Oldest'));
      await tester.pumpAndSettle();
      expect(lists.lists['l1']!.name, 'Remote name');
    });

    testWidgets('own saves do not disturb typing', (tester) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      await tester.enterText(_editor('Middle'), 'First');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(_editor('First'), 'First second');
      await store.update('b', {'text': 'First'}); // A late echo.
      await tester.pump();
      expect(_rows(tester), ['Newest', 'First second', 'Oldest']);
    });

    testWidgets('a trailing space in the name survives its own save', (
      tester,
    ) async {
      _setUp();
      await _pump(tester);
      final title = find.byKey(ListPage.titleKey);
      await tester.tap(title);
      await tester.enterText(title, 'My ');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(lists.lists['l1']!.name, 'My');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: title, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        'My ',
      );
    });

    testWidgets('a blank row from another device survives leaving', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      store.put(keyed('rem', 'l1', '', 'a25'));
      await _pump(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(store.items['rem']!.deletedAt, isNull);
    });

    testWidgets('typing saves after a pause, without leaving the row', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      await tester.enterText(_editor('Middle'), 'Typed');
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.items['b']!.text, 'Middle');
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.items['b']!.text, 'Typed');
    });

    testWidgets('the app going to the background saves typing at once', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await _focus(tester, 'Middle');
      await tester.enterText(_editor('Middle'), 'Typed');
      final title = find.byKey(ListPage.titleKey);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(store.items['b']!.text, 'Typed');
      expect(title, findsOneWidget);
    });

    testWidgets('quitting the app saves typing first', (tester) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      await tester.enterText(_editor('Middle'), 'Typed');
      await tester.binding.handleRequestAppExit();
      await tester.pump();
      expect(store.items['b']!.text, 'Typed');
    });

    testWidgets('switching apps keeps a new blank row', (tester) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await _focus(tester, 'Middle');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Newest', 'Middle', '', 'Oldest']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // What the focus manager does on macOS and Windows.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Newest', 'Middle', '', 'Oldest']);
    });

    testWidgets('Backspace on a cleared task offers Undo', (tester) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      await tester.enterText(_editor('Middle'), '');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Newest', 'Oldest']);
      expect(find.text('Deleted "Middle"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Newest', 'Middle', 'Oldest']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Backspace on a row that never had text shows no toast', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a blanked title refills with Untitled list on leaving', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      lists.put(
        TaskList(
          id: 'l1',
          name: 'Untitled list',
          color: NoteColor.blue,
          sortKey: 'a',
          pinnedToTop: false,
          hideDone: false,
        ),
      );
      await _pump(tester);
      final title = find.byKey(ListPage.titleKey);
      await tester.tap(title);
      await tester.pump();
      await tester.enterText(title, '');
      await tester.tap(_editor('Oldest'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: title, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        'Untitled list',
      );
    });

    testWidgets('spaces in a new row count as blank', (tester) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.enterText(_editor(''), '   ');
      await tester.tap(_editor('Oldest'));
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Newest', 'Middle', 'Oldest']);
    });

    testWidgets('Escape leaves the row and clears the selection', (
      tester,
    ) async {
      _setUp();
      _seedThree();
      await _pump(tester);
      await _focus(tester, 'Middle');
      final node = tester.widget<EditableText>(_editor('Middle')).focusNode;
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(node.hasFocus, isFalse);
      final cubit = BlocProvider.of<ListCubit>(
        tester.element(_editor('Middle')),
      );
      expect(cubit.state.selectedItemId, isNull);
    });

    testWidgets('with slow writes: blur writes nothing untyped, no jump back', (
      tester,
    ) async {
      final slow = _SlowItems();
      _setUp(real: slow);
      slow
        ..put(keyed('a', 'l1', 'Oldest', 'a1'))
        ..put(keyed('b', 'l1', 'Middle', 'a2'));
      await _pump(tester);
      expect(_rows(tester), ['Middle', 'Oldest']);

      // Another device's edit lands while the row sits focused.
      await _focus(tester, 'Middle');
      // Not awaited: its delay runs on the test's clock, which pumps move.
      final remote = slow.update('b', {'text': 'Remote edit'});
      await tester.pump(_SlowItems.delay);
      await remote;
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Remote edit', 'Oldest']);
      slow.calls.clear();
      await tester.tap(_editor('Oldest'));
      await tester.pumpAndSettle();
      expect(slow.items['b']!.text, 'Remote edit');
      expect(slow.calls, isEmpty);

      // A second save while the first is on its way: when the first answers,
      // the field has nothing unsaved and must still not jump back.
      await tester.enterText(_editor('Oldest'), 'One');
      await tester.pump(const Duration(milliseconds: 510));
      await tester.enterText(_editor('One'), 'One two');
      await tester.tap(_editor('Remote edit'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 31));
      expect(slow.items['a']!.text, 'One');
      expect(_rows(tester), ['Remote edit', 'One two']);
      await tester.pumpAndSettle();
      expect(slow.items['a']!.text, 'One two');
      expect(_rows(tester), ['Remote edit', 'One two']);
    });

    testWidgets('a list or row that is gone is not written to', (tester) async {
      _setUp();
      final cubit = sl<ListCubit>(param1: 'missing');
      await tester.pump();
      await cubit.rename('Ghost');
      await cubit.editText('nope', 'Ghost');
      await cubit.close();
      expect(lists.lists.containsKey('missing'), isFalse);
      expect(store.items.containsKey('nope'), isFalse);
    });
  });

  testWidgets('add field adds parsed task at correct position', (tester) async {
    _setUp();
    store.put(keyed('a', 'l1', 'Existing', 'a1'));
    await _pump(tester);
    final field = find.descendant(
      of: find.byType(QuickCaptureField),
      matching: find.byType(EditableText),
    );
    // The 03 add row sits under the rows, on the note.
    expect(
      tester.getTopLeft(field).dy,
      greaterThan(tester.getTopLeft(_editor('Existing')).dy),
    );
    await tester.enterText(field, 'call mom tomorrow 6pm');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final added = store.items.values.firstWhere((i) => i.text == 'call mom');
    expect(added.due?.minutes, 18 * 60);
    expect(added.listId, 'l1');
    expect(tester.widget<EditableText>(field).controller.text, isEmpty);

    // Untimed: newest first, above the older task.
    await tester.enterText(field, 'buy milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['call mom', 'buy milk', 'Existing']);
  });

  testWidgets('Done group collapsed shows count', (tester) async {
    _setUp();
    store
      ..put(keyed('a', 'l1', 'Open', 'a1'))
      ..put(keyed('b', 'l1', 'Done one', 'a2', done: true))
      ..put(keyed('c', 'l1', 'Done two', 'a3', done: true));
    await _pump(tester);
    expect(find.text('Done · 2'), findsOneWidget);
    expect(_editor('Done one'), findsNothing);
    await tester.tap(find.text('Done · 2'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == 'Done one',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hide done replaces group with "2 done, hidden · Show"', (
    tester,
  ) async {
    _setUp(hideDone: true);
    store
      ..put(keyed('a', 'l1', 'Open', 'a1'))
      ..put(keyed('b', 'l1', 'Done one', 'a2', done: true))
      ..put(keyed('c', 'l1', 'Done two', 'a3', done: true));
    await _pump(tester);
    expect(find.text('2 done, hidden'), findsOneWidget);
    expect(find.text('Done · 2'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.hideDone, isFalse);
    expect(find.text('Done · 2'), findsOneWidget);
  });

  testWidgets('Alt+Down moves item below next', (tester) async {
    _setUp();
    _seedThree();
    await _pump(tester);
    expect(_rows(tester), ['Newest', 'Middle', 'Oldest']);
    await _focus(tester, 'Newest');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Middle', 'Newest', 'Oldest']);
    // Up again, and past the top does nothing.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Newest', 'Middle', 'Oldest']);
  });

  testWidgets('a task with a due date keeps its time order', (tester) async {
    _setUp();
    _seedThree();
    store.put(task('d', 'l1', 'Dated', date: DateTime(2026, 11, 6)));
    await _pump(tester);
    await _focus(tester, 'Dated');
    final before = store.writes.length;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();
    expect(store.writes.length, before);
    expect(_rows(tester).first, 'Dated');
  });

  testWidgets('Tab indents to 1, Shift+Tab back to 0', (tester) async {
    _setUp();
    store.put(keyed('a', 'l1', 'Task', 'a1'));
    await _pump(tester);
    await _focus(tester, 'Task');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(store.items['a']!.indent, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(store.items['a']!.indent, 0);
  });

  testWidgets('Enter adds a task below and focuses it; Backspace removes', (
    tester,
  ) async {
    _setUp();
    _seedThree();
    await _pump(tester);
    await _focus(tester, 'Newest');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Newest', '', 'Middle', 'Oldest']);
    final blank = tester.widget<EditableText>(_editor(''));
    expect(blank.focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Newest', 'Middle', 'Oldest']);
    expect(
      tester.widget<EditableText>(_editor('Newest')).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('editing a row writes on blur; a blank new row goes away', (
    tester,
  ) async {
    _setUp();
    _seedThree();
    await _pump(tester);
    await _focus(tester, 'Middle');
    await tester.enterText(_editor('Middle'), 'Renamed');
    expect(store.items['b']!.text, 'Middle');
    await tester.tap(_editor('Oldest'));
    await tester.pumpAndSettle();
    expect(store.items['b']!.text, 'Renamed');

    // Clearing a task and leaving keeps the old text.
    await tester.enterText(_editor('Oldest'), '');
    await tester.tap(_editor('Newest'));
    await tester.pumpAndSettle();
    expect(store.items['a']!.text, 'Oldest');
    expect(_rows(tester), ['Newest', 'Renamed', 'Oldest']);

    // A row made by Enter and left blank leaves no trace.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Newest', '', 'Renamed', 'Oldest']);
    await tester.tap(_editor('Oldest'));
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Newest', 'Renamed', 'Oldest']);
  });

  testWidgets('leaving the screen while typing keeps the row and the name', (
    tester,
  ) async {
    _setUp();
    _seedThree();
    await _pump(tester);
    await _focus(tester, 'Middle');
    await tester.enterText(_editor('Middle'), 'Typed row');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(store.items['b']!.text, 'Typed row');

    await _pump(tester);
    final title = find.byKey(ListPage.titleKey);
    await tester.tap(title);
    await tester.enterText(title, 'Typed name');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(lists.lists['l1']!.name, 'Typed name');
  });

  testWidgets('archive from menu navigates to Up next and shows undo', (
    tester,
  ) async {
    _setUp();
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.archivedAt, isNotNull);
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('Archived Errands'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.archivedAt, isNull);
    expect(find.text('UP NEXT'), findsNothing);
    expect(find.text('Errands'), findsWidgets);
  });

  testWidgets('delete from menu trashes the list with undo', (tester) async {
    _setUp();
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete list…'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.deletedAt, isNotNull);
    expect(find.text('Moved Errands to trash'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.deletedAt, isNull);
  });

  testWidgets('uncheck all reopens all done', (tester) async {
    _setUp();
    store
      ..put(keyed('b', 'l1', 'Done one', 'a2', done: true))
      ..put(keyed('c', 'l1', 'Done two', 'a3', done: true));
    await _pump(tester);
    await tester.tap(find.text('Uncheck all'));
    await tester.pumpAndSettle();
    expect(store.items.values.where((i) => i.done), isEmpty);
    expect(find.text('Unchecked 2 in Errands'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.items.values.where((i) => i.done), hasLength(2));
  });

  testWidgets('title edit renames; a blank title is Untitled list', (
    tester,
  ) async {
    _setUp();
    await _pump(tester);
    final title = find.byKey(ListPage.titleKey);
    await tester.tap(title);
    await tester.enterText(title, 'Groceries');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.name, 'Groceries');
    await tester.enterText(title, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.name, 'Untitled list');
  });

  testWidgets('the dot opens the colour menu', (tester) async {
    _setUp();
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Change colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.color, NoteColor.green);
  });

  testWidgets('pin and hide done from the menu', (tester) async {
    _setUp();
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.pinnedToTop, isTrue);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide done tasks'));
    await tester.pumpAndSettle();
    expect(lists.lists['l1']!.hideDone, isTrue);
  });

  testWidgets('Show in mini bar is desktop only and toggles', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _setUp();
    await _pump(tester);
    await tester.tap(find.text('Show in mini bar'));
    await tester.pumpAndSettle();
    expect(lists.shown, {'l1'});
    expect(find.text('In mini bar'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('no mini bar button off desktop', (tester) async {
    _setUp();
    await _pump(tester);
    expect(find.text('Show in mini bar'), findsNothing);
  });

  testWidgets('subline counts what is left; all done', (tester) async {
    _setUp();
    store.put(keyed('a', 'l1', 'Open', 'a1'));
    await _pump(tester);
    expect(find.textContaining('1 left'), findsOneWidget);
    store.put(keyed('a', 'l1', 'Open', 'a1', done: true));
    await tester.pumpAndSettle();
    expect(find.text('All done'), findsOneWidget);
  });

  testWidgets('empty list says so; a list that goes away leaves', (
    tester,
  ) async {
    _setUp();
    await _pump(tester);
    expect(
      find.text('Nothing here yet. Type below and press Enter.'),
      findsOneWidget,
    );
    lists.put(
      TaskList(
        id: 'l1',
        name: 'Errands',
        color: NoteColor.blue,
        sortKey: 'a',
        pinnedToTop: false,
        hideDone: false,
        deletedAt: _now,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('UP NEXT'), findsOneWidget);
  });

  testWidgets('ticking shows undo; the task lands in Done', (tester) async {
    _setUp();
    store.put(keyed('a', 'l1', 'Open', 'a1'));
    await _pump(tester);
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Check Open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(store.items['a']!.done, isTrue);
    expect(find.text('Checked "Open"'), findsOneWidget);
    expect(find.text('Done · 1'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.items['a']!.done, isFalse);
    semantics.dispose();
  });

  testWidgets('New list makes Untitled list, next colour, name selected', (
    tester,
  ) async {
    _setUp();
    lists.put(
      TaskList(
        id: 'l2',
        name: 'Work',
        color: NoteColor.green,
        sortKey: 'b',
        pinnedToTop: false,
        hideDone: false,
      ),
    );
    sl.registerSingleton<ListsRepository>(lists);
    await _pump(tester);
    ShellActions.standard().newList(tester.element(find.byType(ListPage)));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    final made = lists.lists.values.singleWhere(
      (l) => l.name == 'Untitled list',
    );
    expect(made.color, NoteColor.values[2]);
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ListPage.titleKey),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
    expect(field.controller.selection.extentOffset, 'Untitled list'.length);
  });

  testWidgets('phone: no add row on the note; rows open on tap', (
    tester,
  ) async {
    _setUp();
    store.put(keyed('a', 'l1', 'Open', 'a1'));
    await _pump(tester, phone: true);
    expect(find.byType(QuickCaptureField), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byKey(ListPage.titleKey), findsOneWidget);
  });
}
