import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:weave/app/router.dart';
import 'package:weave/app/shell/app_shell.dart';
import 'package:weave/app/shell/phone_shell.dart';
import 'package:weave/app/shell/placeholder_pages.dart';
import 'package:weave/app/shell/shell_actions.dart';
import 'package:weave/app/shell/shell_cubit.dart';
import 'package:weave/app/shell/sidebar.dart';
import 'package:weave/app/shell/tab_bar.dart';
import 'package:weave/app/weave_app.dart';
import 'package:weave/core/auth/auth_gateway.dart';
import 'package:weave/core/di/core_di.dart';
import 'package:weave/core/sync/sync_status.dart';
import 'package:weave/core/theme/note_color.dart';
import 'package:weave/core/theme/weave_theme.dart';
import 'package:weave/core/theme/weave_tokens.dart';
import 'package:weave/core/widgets/pressable.dart';
import 'package:weave/core/widgets/sync_status_badge.dart';
import 'package:weave/core/widgets/undo_toast.dart';
import 'package:weave/core/widgets/weave_icons.dart';
import 'package:weave/features/account/presentation/session_cubit.dart';
import 'package:weave/features/items/domain/entities/item.dart';
import 'package:weave/features/items/domain/repositories/items_repository.dart';
import 'package:weave/features/lists/domain/entities/task_list.dart';
import 'package:weave/features/items/domain/usecases/add_item.dart';
import 'package:weave/features/items/domain/usecases/toggle_done.dart';
import 'package:weave/features/lists/domain/repositories/lists_repository.dart';
import 'package:weave/core/widgets/quick_capture_field.dart';
import 'package:weave/features/up_next/presentation/capture_cubit.dart';
import 'package:weave/features/up_next/presentation/up_next_cubit.dart';
import 'package:weave/features/up_next/presentation/up_next_page.dart';

import '../features/up_next/up_next_fakes.dart' as up;

/// A stream source that replays its latest value to every new listener
/// (as a Drift watch query does).
class _Replay<T> {
  _Replay(this.value);

  T value;
  final _c = StreamController<T>.broadcast();

  Stream<T> get stream => Stream.multi((m) {
    m.add(value);
    final s = _c.stream.listen(m.add);
    m.onCancel = s.cancel;
  });

  void add(T v) {
    value = v;
    _c.add(v);
  }
}

class FakeLists extends Fake implements ListsRepository {
  final active = _Replay<List<TaskList>>(const []);
  final archived = _Replay<List<TaskList>>(const []);
  final trashed = _Replay<List<TaskList>>(const []);
  final miniBar = _Replay<Set<String>>(const {});
  int activeCalls = 0;

  @override
  Stream<List<TaskList>> watchActive() {
    activeCalls++;
    return active.stream;
  }

  @override
  Stream<List<TaskList>> watchArchived() => archived.stream;

  @override
  Stream<List<TaskList>> watchTrashed() => trashed.stream;

  @override
  Stream<Set<String>> watchShownInMiniBar() => miniBar.stream;
}

class FakeItems extends Fake implements ItemsRepository {
  final upNext = _Replay<List<Item>>(const []);
  final upNextAt = <DateTime>[];

  @override
  Stream<List<Item>> watchUpNext(DateTime now) {
    upNextAt.add(now);
    return upNext.stream;
  }
}

class MockSession extends MockCubit<SessionState> implements SessionCubit {}

TaskList _list(
  String id,
  String name, {
  int open = 0,
  bool pinned = false,
  NoteColor color = NoteColor.yellow,
}) => TaskList(
  id: id,
  name: name,
  color: color,
  sortKey: id,
  pinnedToTop: pinned,
  hideDone: false,
  openCount: open,
);

Item _item(String id) => Item(
  id: id,
  listId: 'l1',
  kind: ItemKind.task,
  text: 'x',
  done: false,
  indent: 0,
  sortKey: id,
);

class Spy {
  int newList = 0;
  int signIn = 0;
  int retry = 0;

  ShellActions get actions => ShellActions(
    newList: (_) => newList++,
    signIn: (_) => signIn++,
    retrySync: () async => retry++,
  );
}

late FakeLists lists;
late FakeItems items;
late MockSession session;
late StreamController<SyncStatus> engine;
late Spy spy;

void _setUp({
  SessionState state = const LocalSession(),
  SyncStatus status = SyncStatus.localOnly,
  bool signedOut = false,
  AuthUser? user,
  int devices = 3,
}) {
  lists = FakeLists();
  items = FakeItems();
  spy = Spy();
  session = MockSession();
  whenListen(session, const Stream<SessionState>.empty(), initialState: state);
  when(() => session.accountSignedOut).thenReturn(signedOut);
  when(() => session.currentUser).thenReturn(user);
  engine = StreamController<SyncStatus>.broadcast();
  sl
    ..registerSingleton<SessionCubit>(session)
    ..registerSingleton<SyncStatusCubit>(
      SyncStatusCubit(
        status: engine.stream,
        initial: status,
        signedInNow: status != SyncStatus.localOnly,
      ),
    )
    ..registerFactory<ShellCubit>(
      () => ShellCubit(
        lists: lists,
        items: items,
        deviceCount: () => Stream.value(devices),
      ),
    );
  // Up next reads its own sources, so the shell's counts stay its own.
  final upItems = up.FakeItemsStore();
  final upLists = up.FakeLists()..active.add([up.taskList('l1', 'Errands')]);
  sl
    ..registerFactory<UpNextCubit>(
      () => UpNextCubit(
        items: upItems,
        lists: upLists,
        toggleDone: ToggleDone(upItems),
      ),
    )
    ..registerFactory<CaptureCubit>(
      () => CaptureCubit(
        lists: upLists,
        addItem: AddItem(upItems),
        capturePref: () => Stream.value(null),
      ),
    );
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(WeaveApp(router: buildRouter(actions: spy.actions)));
  await tester.pumpAndSettle();
}

const _wide = Size(1440, 900);

/// Runs a test on macOS; the variant resets the platform override itself.
final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);
const _phone = Size(390, 844);

/// A minimal themed host for single widgets.
Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
  theme: weaveTheme(b),
  home: Material(child: Center(child: child)),
);

void main() {
  tearDown(() async {
    await engine.close();
    await sl.reset();
  });

  group('layout', () {
    testWidgets('wide layout shows sidebar with lists and counts', (
      tester,
    ) async {
      _setUp();
      lists.active.add([
        _list('l1', 'Errands', open: 4, pinned: true),
        _list('l2', 'Groceries', open: 3),
        _list('l3', 'Ideas'),
      ]);
      lists.archived.add([_list('a1', 'Old')]);
      lists.trashed.add([_list('t1', 'Older'), _list('t2', 'Oldest')]);
      items.upNext.add([_item('i1'), _item('i2')]);
      await _pumpApp(tester, _wide);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byType(PhoneTabBar), findsNothing);
      final side = find.byType(Sidebar);
      Finder inSide(String text) =>
          find.descendant(of: side, matching: find.text(text));
      expect(inSide('Weave'), findsOneWidget);
      expect(inSide('Up next'), findsOneWidget);
      expect(inSide('Pinned'), findsOneWidget);
      expect(inSide('Lists'), findsOneWidget);
      expect(inSide('New list'), findsOneWidget);
      expect(inSide('Archive and trash'), findsOneWidget);
      expect(inSide('Settings'), findsOneWidget);

      Finder row(String label) =>
          find.ancestor(of: inSide(label), matching: find.byType(NavRow));
      String? countOf(String label) => tester
          .widgetList<Text>(
            find.descendant(of: row(label), matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .lastWhere((d) => d != label, orElse: () => null);
      expect(countOf('Errands'), '4');
      expect(countOf('Groceries'), '3');
      expect(countOf('Ideas'), ''); // nothing open: no count
      expect(countOf('Up next'), '2');
      expect(countOf('Archive and trash'), '3');
      // Pinned lists come under "Pinned", before "Lists".
      expect(
        tester.getTopLeft(inSide('Errands')).dy,
        lessThan(tester.getTopLeft(inSide('Lists')).dy),
      );
      expect(
        tester.getTopLeft(inSide('Groceries')).dy,
        greaterThan(tester.getTopLeft(inSide('Lists')).dy),
      );
      // Local mode: the sync line and the user row.
      expect(inSide('On this phone only'), findsOneWidget);
      expect(inSide('Local mode'), findsOneWidget);
      expect(inSide('Sign in to sync devices'), findsOneWidget);
    });

    testWidgets('sidebar is 256 wide, 224 under 1100 px', (tester) async {
      _setUp();
      await _pumpApp(tester, _wide);
      expect(tester.getSize(find.byType(Sidebar)).width, 256);
      await _pumpApp(tester, const Size(1000, 800));
      expect(tester.getSize(find.byType(Sidebar)).width, 224);
    });

    testWidgets('narrow layout shows 4 tabs', (tester) async {
      _setUp();
      items.upNext.add([_item('i1')]);
      await _pumpApp(tester, _phone);

      expect(find.byType(Sidebar), findsNothing);
      final bar = find.byType(PhoneTabBar);
      expect(bar, findsOneWidget);
      for (final label in ['Up next', 'Lists', 'Search', 'Settings']) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      // Today's open count on the Up next tab.
      expect(find.descendant(of: bar, matching: find.text('1')), findsOne);
    });

    testWidgets('Android back on Search or Settings goes to Up next', (
      tester,
    ) async {
      _setUp();
      await _pumpApp(tester, _phone);
      final bar = find.byType(PhoneTabBar);
      for (final tab in ['Search', 'Settings', 'Lists']) {
        await tester.tap(find.descendant(of: bar, matching: find.text(tab)));
        await tester.pumpAndSettle();
        expect(tester.widget<PhoneTabBar>(bar).current, isNot(AppRoute.upNext));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.widget<PhoneTabBar>(bar).current, AppRoute.upNext);
      }
    });

    testWidgets('an unknown path lands on Up next', (tester) async {
      _setUp();
      tester.view
        ..physicalSize = _wide
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WeaveApp(
          router: buildRouter(actions: spy.actions, initialLocation: '/nope'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byType(UpNextPage), findsOneWidget);
    });

    testWidgets('/lists on a wide window is Up next from the first frame', (
      tester,
    ) async {
      _setUp();
      tester.view
        ..physicalSize = _wide
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WeaveApp(
          router: buildRouter(actions: spy.actions, initialLocation: '/lists'),
        ),
      );
      expect(find.byType(ListsPlaceholder), findsNothing);
      expect(find.byType(UpNextPage), findsOneWidget);
    });

    testWidgets('a tab opens its screen', (tester) async {
      _setUp();
      await _pumpApp(tester, _phone);
      final bar = find.byType(PhoneTabBar);
      await tester.tap(find.descendant(of: bar, matching: find.text('Lists')));
      await tester.pumpAndSettle();
      expect(tester.widget<PhoneTabBar>(bar).current, AppRoute.lists);
      await tester.tap(
        find.descendant(of: bar, matching: find.text('Settings')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<PhoneTabBar>(bar).current, AppRoute.settings);
    });

    testWidgets('a sidebar list opens the list route', (tester) async {
      _setUp();
      lists.active.add([_list('l1', 'Errands', open: 4)]);
      await _pumpApp(tester, _wide);
      await tester.tap(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.text('Errands'),
        ),
      );
      await tester.pumpAndSettle();
      // The placeholder titles the list screen with the list's name.
      expect(find.text('Errands'), findsNWidgets(2));
    });
  });

  group('sync badge', () {
    test('sheet copy for every status (Task 14 / 01 prototype)', () {
      String sheet(SyncStatus s, {int devices = 3, bool signedOut = false}) =>
          syncBadgeLabel(
            s,
            devices: devices,
            signedOut: signedOut,
            platform: TargetPlatform.macOS,
          );
      expect(sheet(SyncStatus.synced), 'Synced · 3 devices');
      expect(sheet(SyncStatus.synced, devices: 1), 'Synced · 1 device');
      expect(sheet(SyncStatus.syncing), 'Syncing…');
      expect(sheet(SyncStatus.offline), 'Offline · saved here');
      expect(sheet(SyncStatus.error), "Can't sync");
      expect(sheet(SyncStatus.localOnly), 'On this Mac only');
      expect(
        sheet(SyncStatus.localOnly, signedOut: true),
        'Signed out · sign in again to sync',
      );
      // Signed out only matters while sync is off.
      expect(sheet(SyncStatus.synced, signedOut: true), 'Synced · 3 devices');
    });

    test('sidebar copy for every status (03 prototype)', () {
      String side(SyncStatus s, {bool signedOut = false}) => syncBadgeLabel(
        s,
        devices: 3,
        signedOut: signedOut,
        style: SyncBadgeStyle.sidebar,
        platform: TargetPlatform.windows,
      );
      expect(side(SyncStatus.synced), 'Synced · 3 devices');
      expect(side(SyncStatus.syncing), 'Syncing…');
      expect(side(SyncStatus.offline), 'Offline · changes saved here');
      expect(side(SyncStatus.error), 'Sync error · retrying');
      expect(side(SyncStatus.localOnly), 'On this PC only');
      expect(
        side(SyncStatus.localOnly, signedOut: true),
        'Signed out · sign in again to sync',
      );
    });

    test('local-only copy names the platform', () {
      String here(TargetPlatform p) =>
          syncBadgeLabel(SyncStatus.localOnly, devices: 1, platform: p);
      expect(here(TargetPlatform.macOS), 'On this Mac only');
      expect(here(TargetPlatform.windows), 'On this PC only');
      expect(here(TargetPlatform.linux), 'On this PC only');
      expect(here(TargetPlatform.iOS), 'On this phone only');
      expect(here(TargetPlatform.android), 'On this phone only');
    });

    testWidgets('badge shows "Offline · saved here" for offline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SyncStatusBadge(status: SyncStatus.offline)),
      );
      expect(find.text('Offline · saved here'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('"Can\'t sync" offers Retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          SyncStatusBadge(status: SyncStatus.error, onRetry: () => retried++),
        ),
      );
      expect(find.text("Can't sync"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('signed out by the server offers Sign in', (tester) async {
      var signIn = 0;
      await tester.pumpWidget(
        _host(
          SyncStatusBadge(
            status: SyncStatus.localOnly,
            signedOut: true,
            onSignIn: () => signIn++,
          ),
        ),
      );
      expect(find.text('Signed out · sign in again to sync'), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      expect(signIn, 1);
    });

    testWidgets('sidebar line follows the sync status and device count', (
      tester,
    ) async {
      const user = AuthUser(id: 'u1', email: 'mayank@example.com');
      _setUp(
        state: const SignedIn(user),
        status: SyncStatus.synced,
        user: user,
      );
      await _pumpApp(tester, _wide);
      final side = find.byType(Sidebar);
      expect(
        find.descendant(of: side, matching: find.text('Synced · 3 devices')),
        findsOneWidget,
      );
      // Signed in: the account row, not local mode.
      expect(
        find.descendant(of: side, matching: find.text('mayank@example.com')),
        findsOneWidget,
      );
      expect(find.text('Local mode'), findsNothing);

      engine.add(SyncStatus.offline);
      await tester.pumpAndSettle();
      expect(find.text('Offline · changes saved here'), findsOneWidget);

      engine.add(SyncStatus.error);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync error · retrying'));
      expect(spy.retry, 1);
    });

    testWidgets('sidebar shows "Signed out" after a server-side sign-out', (
      tester,
    ) async {
      _setUp(signedOut: true);
      await _pumpApp(tester, _wide);
      expect(find.text('On this phone only'), findsNothing);
      final line = find.text('Signed out · sign in again to sync');
      expect(line, findsOneWidget);
      // One place per action (C4): the line is text only; Sign in is the
      // user row.
      expect(
        find.ancestor(of: line, matching: find.byType(Pressable)),
        findsNothing,
      );
      await tester.tap(line);
      expect(spy.signIn, 0);
      await tester.tap(find.text('Local mode'));
      expect(spy.signIn, 1);
    });

    testWidgets('user row is not "Local mode" while signing in', (
      tester,
    ) async {
      _setUp(state: const SigningIn());
      await _pumpApp(tester, _wide);
      expect(find.text('Local mode'), findsNothing);
      expect(find.text('Sign in to sync devices'), findsNothing);
    });
  });

  group('counts', () {
    test('the Up next count is re-read on the wall-clock minute', () {
      fakeAsync((async) {
        final lists = FakeLists();
        final items = FakeItems();
        final start = DateTime(2026, 11, 3, 23, 59, 50);
        final c = ShellCubit(
          lists: lists,
          items: items,
          now: () => start.add(async.elapsed),
        );
        async.flushMicrotasks();
        expect(items.upNextAt, [start]);
        async.elapse(const Duration(seconds: 10));
        expect(items.upNextAt.last, DateTime(2026, 11, 4));
        async.elapse(const Duration(seconds: 59));
        expect(items.upNextAt, hasLength(2));
        async.elapse(const Duration(seconds: 1));
        expect(items.upNextAt.last, DateTime(2026, 11, 4, 0, 1));
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    testWidgets('sidebar counts update when the stream emits', (tester) async {
      _setUp();
      lists.active.add([_list('l1', 'Errands', open: 4)]);
      await _pumpApp(tester, _wide);
      final row = find.ancestor(
        of: find.descendant(
          of: find.byType(Sidebar),
          matching: find.text('Errands'),
        ),
        matching: find.byType(NavRow),
      );
      expect(find.descendant(of: row, matching: find.text('4')), findsOne);

      lists.active.add([
        _list('l1', 'Errands', open: 5),
        _list('l2', 'Groceries', open: 2),
      ]);
      items.upNext.add([_item('i1'), _item('i2'), _item('i3')]);
      await tester.pumpAndSettle();
      expect(find.descendant(of: row, matching: find.text('5')), findsOne);
      expect(find.text('Groceries'), findsOneWidget);
      final upNext = find.ancestor(
        of: find.descendant(
          of: find.byType(Sidebar),
          matching: find.text('Up next'),
        ),
        matching: find.byType(NavRow),
      );
      expect(find.descendant(of: upNext, matching: find.text('3')), findsOne);
    });

    testWidgets('time-based counts are re-read every minute and on resume', (
      tester,
    ) async {
      _setUp();
      await _pumpApp(tester, _wide);
      final calls = items.upNextAt.length;
      expect(calls, greaterThan(0));

      final active = lists.activeCalls;
      await tester.pump(const Duration(minutes: 1));
      expect(items.upNextAt.length, calls + 1);
      expect(lists.activeCalls, active, reason: 'only Up next on the tick');

      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(items.upNextAt.length, calls + 2);
      expect(lists.activeCalls, active + 1, reason: 'everything on resume');
    });
  });

  group('keyboard', () {
    EditableText searchField(WidgetTester tester) => tester.widget(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.byType(EditableText),
      ),
    );

    testWidgets('Ctrl+K focuses search', (tester) async {
      _setUp();
      await _pumpApp(tester, _wide);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Search notes')), findsOneWidget);
      semantics.dispose();
      expect(searchField(tester).focusNode.hasFocus, isFalse);
      expect(find.text('Ctrl+K'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(searchField(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('⌘K focuses search on macOS', variant: _mac, (tester) async {
      _setUp();
      await _pumpApp(tester, _wide);
      expect(find.text('⌘K'), findsOneWidget);
      expect(find.text('⌘N'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(searchField(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('shortcuts still work after a field loses focus', (
      tester,
    ) async {
      _setUp();
      await _pumpApp(tester, _wide);
      await tester.tap(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.byType(EditableText),
        ),
      );
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(spy.newList, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(searchField(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('Ctrl+K and Ctrl+N work while the capture field has focus', (
      tester,
    ) async {
      _setUp();
      await _pumpApp(tester, _wide);
      final capture = find.descendant(
        of: find.byType(QuickCaptureField),
        matching: find.byType(EditableText),
      );
      // Up next does not take focus on its own (03: no autofocus).
      expect(tester.widget<EditableText>(capture).focusNode.hasFocus, isFalse);
      await tester.tap(capture);
      await tester.pump();
      expect(tester.widget<EditableText>(capture).focusNode.hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(spy.newList, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(searchField(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('phone add bar holds the capture field on Up next only', (
      tester,
    ) async {
      _setUp();
      await _pumpApp(tester, _phone);
      final bar = find.byType(PhoneTabBar);
      expect(find.byType(UpNextAddBar), findsOneWidget);
      // The add bar sits just above the tabs.
      expect(
        tester.getRect(find.byType(UpNextAddBar)).bottom,
        lessThanOrEqualTo(tester.getRect(bar).top),
      );
      await tester.tap(find.descendant(of: bar, matching: find.text('Search')));
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureField), findsNothing);
    });

    testWidgets('Ctrl+N starts a new list', (tester) async {
      _setUp();
      await _pumpApp(tester, _wide);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(spy.newList, 1);
      // Also from the search field, and from the sidebar row.
      await tester.tap(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.byType(EditableText),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(spy.newList, 2);
      await tester.tap(find.text('New list'));
      expect(spy.newList, 3);
    });

    testWidgets(
      '⌘N starts a new list on macOS; Ctrl+N does not',
      variant: _mac,
      (tester) async {
        _setUp();
        await _pumpApp(tester, _wide);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        expect(spy.newList, 1);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(spy.newList, 1);
      },
    );
  });

  group('tab bar styling', () {
    Future<void> pumpBar(WidgetTester tester, TargetPlatform p) =>
        tester.pumpWidget(
          _host(
            SizedBox(
              width: 390,
              child: PhoneTabBar(
                current: AppRoute.lists,
                upNextCount: 2,
                platform: p,
                onSelect: (_) {},
              ),
            ),
          ),
        );

    Iterable<WeaveIcon> icons(WidgetTester tester) =>
        tester.widgetList<WeaveIcon>(find.byType(WeaveIcon));

    double labelSize(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style?.fontSize ?? 0;

    BoxDecoration barDecoration(WidgetTester tester) =>
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(PhoneTabBar),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;

    testWidgets('iOS: heavier current icon, 11 px labels, surface + border', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.iOS);
      final current = icons(
        tester,
      ).firstWhere((i) => i.icon == WeaveIcons.list);
      expect(current.strokeWidth, 2);
      expect(
        icons(
          tester,
        ).where((i) => i.icon != WeaveIcons.list).map((i) => i.strokeWidth),
        everyElement(1.5),
      );
      expect(labelSize(tester, 'Lists'), 11);
      final d = barDecoration(tester);
      expect(d.color, WeaveTokens.light.surface);
      expect(d.border, isNotNull);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Android: pill behind the current icon, 12 px labels', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.android);
      expect(icons(tester).map((i) => i.strokeWidth), everyElement(1.5));
      expect(labelSize(tester, 'Lists'), 12);
      final d = barDecoration(tester);
      expect(d.color, WeaveTokens.light.ground);
      expect(d.border, isNull);
      final pills = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((b) => b.borderRadius == BorderRadius.circular(16));
      expect(pills, hasLength(4));
      expect(
        pills.where((b) => b.color == WeaveTokens.light.raised),
        hasLength(1),
      );
    });
  });

  group('undo toast', () {
    Future<UndoToastController> pumpToastHost(
      WidgetTester tester, {
      Widget? addBar,
    }) async {
      final toast = UndoToastController();
      addTearDown(toast.dispose);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 390,
            height: 600,
            child: UndoToastScope(
              controller: toast,
              child: Stack(
                children: [UndoToastLayer(controller: toast, bottom: 24)],
              ),
            ),
          ),
        ),
      );
      return toast;
    }

    testWidgets('undo toast calls undo when tapped and disappears after 4 s', (
      tester,
    ) async {
      final toast = await pumpToastHost(tester);
      var undone = 0;
      toast.show('Checked "Buy milk"', () async => undone++);
      await tester.pump();
      expect(find.text('Checked "Buy milk"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Checked "Buy milk"'), findsNothing);

      toast.show('Archived Errands', () async => undone++);
      await tester.pump();
      expect(find.text('Archived Errands'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3900));
      expect(find.text('Archived Errands'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100)); // 4 s
      await tester.pump(UndoToastController.exitDuration);
      expect(find.text('Archived Errands'), findsNothing);
      expect(undone, 1);
    });

    test('undo runs once; a disposed controller ignores show', () {
      final toast = UndoToastController();
      var undone = 0;
      toast.show('Deleted "Eggs"', () async => undone++);
      toast
        ..undo()
        ..undo();
      expect(undone, 1);
      toast.dispose();
      expect(() => toast.show('late', null), returnsNormally);
      expect(() => toast.hide(), returnsNormally);
    });

    testWidgets('Undo from the keyboard during the fade does nothing more', (
      tester,
    ) async {
      final toast = await pumpToastHost(tester);
      var undone = 0;
      toast.show('Checked "Buy milk"', () async => undone++);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 50)); // fading
      Actions.maybeInvoke(
        tester.element(find.text('Undo')),
        const ActivateIntent(),
      );
      await tester.pumpAndSettle();
      expect(undone, 1);
    });

    testWidgets('the Undo focus ring is drawn in on-primary', (tester) async {
      final toast = await pumpToastHost(tester);
      toast.show('Checked "Buy milk"', () async {});
      await tester.pump();
      final undo = tester.widget<Pressable>(
        find.ancestor(of: find.text('Undo'), matching: find.byType(Pressable)),
      );
      expect(undo.ringColor, WeaveTokens.light.onPrimary);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('UndoToast.show finds the shell scope', (tester) async {
      _setUp();
      await _pumpApp(tester, _wide);
      final ctx = tester.element(find.byType(Sidebar));
      UndoToast.show(ctx, 'Deleted "Eggs"', () async {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the rise
      expect(find.text('Deleted "Eggs"'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      // Bottom centre on desktop, 24 above the window edge.
      final rect = tester.getRect(
        find
            .ancestor(
              of: find.text('Deleted "Eggs"'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(rect.center.dx, closeTo(_wide.width / 2, 1));
      expect(rect.bottom, closeTo(_wide.height - 24, 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Deleted "Eggs"'), findsNothing);
    });

    testWidgets('the toast sits above the add bar on phones', (tester) async {
      _setUp();
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final toast = UndoToastController();
      addTearDown(toast.dispose);
      const addBarKey = Key('addbar');
      await tester.pumpWidget(
        _host(
          SizedBox.fromSize(
            size: _phone,
            child: PhoneShell(
              location: const ShellLocation(AppRoute.upNext),
              toast: toast,
              upNextCount: 0,
              addBar: const SizedBox(key: addBarKey, height: 44),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      toast.show('Checked "Buy milk"', () async {});
      await tester.pumpAndSettle();
      final toastRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Checked "Buy milk"'),
              matching: find.byType(Container),
            )
            .first,
      );
      final addBarTop = tester.getRect(find.byKey(addBarKey)).top - 8;
      expect(toastRect.bottom, lessThanOrEqualTo(addBarTop));
      expect(toastRect.bottom, closeTo(addBarTop - PhoneShell.toastGap, 1));
      expect(toastRect.center.dx, closeTo(_phone.width / 2, 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
