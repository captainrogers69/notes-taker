import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/theme/weave_theme.dart';
import 'package:weave/core/widgets/quick_capture_field.dart';
import 'package:weave/features/lists/domain/entities/task_list.dart';

import '../../features/up_next/up_next_fakes.dart';

final _now = DateTime(2026, 11, 5, 10, 0);
final _lists = [taskList('l1', 'Errands'), taskList('l2', 'Groceries')];

/// The field with its list held by the host, as a screen would.
Widget _host({
  required List<(String?, String)> submitted,
  String? initial = 'l1',
  List<TaskList>? lists,
  bool phoneBar = false,
  Future<bool> Function(String raw)? result,
}) => MaterialApp(
  theme: weaveTheme(Brightness.light),
  home: Material(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: HookBuilder(
          builder: (context) {
            final listId = useState(initial);
            return QuickCaptureField(
              listId: listId.value,
              lists: lists ?? _lists,
              phoneBar: phoneBar,
              now: () => _now,
              onListChange: (id) => listId.value = id,
              onSubmit: (raw) async {
                submitted.add((listId.value, raw));
                return result == null ? true : result(raw);
              },
            );
          },
        ),
      ),
    ),
  ),
);

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  testWidgets('typing "tomorrow 6pm" shows "Due Tomorrow 18:00" before Enter', (
    tester,
  ) async {
    final submitted = <(String?, String)>[];
    await tester.pumpWidget(_host(submitted: submitted));
    await tester.enterText(find.byType(EditableText), 'call mom tomorrow 6pm');
    await tester.pump();
    // The 03 read-back: "<read-back> · adds as “<text>”".
    expect(
      find.text('Due Tomorrow 18:00 · adds as “call mom”'),
      findsOneWidget,
    );
    expect(submitted, isEmpty);
  });

  testWidgets('Enter adds to chosen list and clears field', (tester) async {
    final submitted = <(String?, String)>[];
    await tester.pumpWidget(_host(submitted: submitted));
    // The list is a chip inside the field.
    expect(find.text('Errands'), findsOneWidget);
    await tester.tap(find.text('Errands'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries').last);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'oat milk 6pm');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, [('l2', 'oat milk 6pm')]);
    expect(_editable(tester).controller.text, isEmpty);
    // Stays ready for the next one.
    expect(_editable(tester).focusNode.hasFocus, isTrue);
  });

  testWidgets('Enter on an empty field does nothing', (tester) async {
    final submitted = <(String?, String)>[];
    await tester.pumpWidget(_host(submitted: submitted));
    await tester.enterText(find.byType(EditableText), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, isEmpty);
  });

  testWidgets('hint on focus; the parse line keeps its height', (tester) async {
    final submitted = <(String?, String)>[];
    await tester.pumpWidget(_host(submitted: submitted));
    const hint =
        'Times and days are understood: 6pm, 18:30, tomorrow, tonight, in 2 h.';
    final h0 = tester.getSize(find.byType(QuickCaptureField)).height;
    expect(find.text(hint), findsNothing);

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(find.text(hint), findsOneWidget);
    expect(tester.getSize(find.byType(QuickCaptureField)).height, h0);

    await tester.enterText(find.byType(EditableText), 'dentist sat 10am');
    await tester.pump();
    expect(find.text(hint), findsNothing);
    expect(find.textContaining('Due Sat 10:00'), findsOneWidget);
    expect(tester.getSize(find.byType(QuickCaptureField)).height, h0);

    // Text without a date or time: no read-back; the hint stays (03).
    await tester.enterText(find.byType(EditableText), 'buy milk');
    await tester.pump();
    expect(find.text(hint), findsOneWidget);
    expect(find.textContaining('Due'), findsNothing);
    expect(tester.getSize(find.byType(QuickCaptureField)).height, h0);
  });

  testWidgets('field is 40 high, 44 in the phone add bar; no Add button', (
    tester,
  ) async {
    await tester.pumpWidget(_host(submitted: []));
    expect(tester.getSize(find.byKey(QuickCaptureField.boxKey)).height, 40);
    expect(find.text('Add'), findsNothing);
    await tester.pumpWidget(_host(submitted: [], phoneBar: true));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(QuickCaptureField.boxKey)).height, 44);
  });

  testWidgets('field and chip are labelled; the field is announced once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(submitted: []));
    expect(find.bySemanticsLabel(RegExp(r'^Add a task')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Add to list')), findsOneWidget);
    // One label; the placeholder is not read out as a second one.
    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.label, 'Add a task');
    expect(node.hint, isNot(contains('try')));
    semantics.dispose();
  });

  testWidgets('phone add bar: no parse line until there is a read-back', (
    tester,
  ) async {
    await tester.pumpWidget(_host(submitted: [], phoneBar: true));
    expect(tester.getSize(find.byType(QuickCaptureField)).height, 44);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(tester.getSize(find.byType(QuickCaptureField)).height, 44);
    await tester.enterText(find.byType(EditableText), 'tea 6pm');
    await tester.pump();
    expect(find.textContaining('Due today 18:00'), findsOneWidget);
    expect(tester.getSize(find.byType(QuickCaptureField)).height, 44 + 6 + 20);
  });

  testWidgets('desktop: the read-back hides when unfocused, its line stays', (
    tester,
  ) async {
    await tester.pumpWidget(_host(submitted: []));
    final h0 = tester.getSize(find.byType(QuickCaptureField)).height;
    await tester.enterText(find.byType(EditableText), 'tea 6pm');
    await tester.pump();
    expect(find.textContaining('Due today 18:00'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.textContaining('Due today 18:00'), findsNothing);
    expect(tester.getSize(find.byType(QuickCaptureField)).height, h0);
  });

  testWidgets('a refused add keeps the text', (tester) async {
    final submitted = <(String?, String)>[];
    await tester.pumpWidget(
      _host(submitted: submitted, result: (_) async => false),
    );
    await tester.enterText(find.byType(EditableText), 'oat milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, hasLength(1));
    expect(_editable(tester).controller.text, 'oat milk');
  });

  testWidgets('a failing add keeps the text', (tester) async {
    await tester.pumpWidget(
      _host(submitted: [], result: (_) async => throw StateError('db')),
    );
    await tester.enterText(find.byType(EditableText), 'oat milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_editable(tester).controller.text, 'oat milk');
  });

  testWidgets('Enter while an IME is composing does not add', (tester) async {
    final submitted = <(String?, String)>[];
    await tester.pumpWidget(_host(submitted: submitted));
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'にほ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, isEmpty);
    expect(_editable(tester).controller.text, 'にほ');
  });
}
