import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/core_di.dart';
import '../../../core/domain/note_color_id.dart';
import '../../../core/helpers/due_label.dart';
import '../../../core/theme/weave_theme.dart';
import '../../../core/widgets/day_strip.dart';
import '../../../core/widgets/day_thread.dart';
import '../../../core/widgets/item_tile.dart';
import '../../../core/widgets/quick_capture_field.dart';
import '../../../core/widgets/shell_layout.dart';
import '../../../core/widgets/undo_toast.dart';
import '../../items/domain/entities/item.dart';
import 'capture_cubit.dart';
import 'up_next_cubit.dart';

/// Below this window width the Today and Later cards stack and the thread's
/// "07:00 to 23:00" goes (app.css tablet band, 720–1099).
const _stackBelow = 1100.0;

/// Up next, where the app opens (design playbook §9 Up next; 03
/// `nextScreen`). Header (date, title, one fact; C2). Desktop: the day
/// thread full width, then Today (the one add field, then overdue,
/// upcoming, done) beside Later this week. Phone: Today with the one-line
/// strip, then Later this week; the add field is the shell's add bar
/// ([UpNextAddBar]).
class UpNextPage extends StatelessWidget {
  const UpNextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UpNextCubit>(create: (_) => sl<UpNextCubit>()),
        // Lazy: only the desktop Today card reads it.
        BlocProvider<CaptureCubit>(create: (_) => sl<CaptureCubit>()),
      ],
      child: const _UpNextView(),
    );
  }
}

/// The phone add bar on Up next (pinned above the tabs by the shell): the
/// same field, 44 high, adding to the capture list or the one picked.
class UpNextAddBar extends StatelessWidget {
  const UpNextAddBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CaptureCubit>(
      create: (_) => sl<CaptureCubit>(),
      child: const _Capture(phoneBar: true),
    );
  }
}

class _UpNextView extends HookWidget {
  const _UpNextView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UpNextCubit>();
    final s = context.watch<UpNextCubit>().state;
    final layout = ShellLayout.of(context);
    final phone = layout.isPhone;
    final stack = MediaQuery.sizeOf(context).width < _stackBelow;
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;

    // The time-based queries are re-read every minute by the cubit and on
    // resume here.
    useOnAppLifecycleStateChange((_, now) {
      if (now == AppLifecycleState.resumed) cubit.refresh();
    });

    final colors = <String, NoteColor>{for (final l in s.lists) l.id: l.color};

    void open(Item i) =>
        GoRouter.maybeOf(context)?.go('/list/${Uri.encodeComponent(i.listId)}');

    Future<void> tick(Item i) async {
      final previous = await cubit.toggle(i.id);
      if (!context.mounted || i.done || previous.isEmpty) return;
      UndoToast.show(
        context,
        'Checked "${i.text}"',
        () => cubit.restore(i.id, previous),
      );
    }

    Widget tile(Item i, {required bool first, required bool showList}) =>
        ItemTile(
          key: ValueKey(i.id),
          item: i,
          now: s.now,
          listName: showList ? s.listOf(i.listId)?.name : null,
          color: colors[i.listId] ?? NoteColor.yellow,
          phone: phone,
          rule: !first,
          onTap: () => open(i),
          onToggle: () => unawaited(tick(i)),
        );

    // Header (C2): the date above the title, one fact under it.
    final next = s.next;
    final left = s.open.length;
    final numStyle = t.numeric.copyWith(color: t.text);
    final subline = Text.rich(
      left == 0
          ? const TextSpan(text: 'Nothing left for today')
          : TextSpan(
              children: [
                TextSpan(text: '$left', style: numStyle),
                const TextSpan(text: ' left today'),
                if (next != null) ...[
                  TextSpan(text: ' · next ${next.text} at '),
                  TextSpan(
                    text: fmtClock(next.due?.minutes ?? 0),
                    style: t.numeric,
                  ),
                ],
              ],
            ),
      style: theme.bodyMedium?.copyWith(color: t.muted),
    );
    final header = Padding(
      padding: EdgeInsets.only(bottom: phone ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              dateLabel(s.now),
              style: theme.bodySmall?.copyWith(color: t.muted),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              'Up next',
              style: theme.headlineSmall?.copyWith(height: 32 / 24),
            ),
          ),
          const SizedBox(height: 4),
          subline,
        ],
      ),
    );

    // Today: one list, no group labels (C5). A row names its list only
    // when today spans more than one list (never on phones).
    final rows = s.todayRows;
    final showList = !phone && rows.map((i) => i.listId).toSet().length > 1;
    final today = _Card(
      title: 'Today',
      phone: phone,
      children: [
        if (phone)
          _Inset(
            child: DayStrip(today: s.dueToday, now: s.now, colors: colors),
          ),
        if (!phone)
          const _Inset(
            child: Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _Capture(),
            ),
          ),
        if (rows.isEmpty)
          const _Inset(child: _Empty('Nothing left for today.'))
        else
          for (final (n, i) in rows.indexed)
            tile(i, first: n == 0, showList: showList),
      ],
    );

    final later = _Card(
      title: 'Later this week',
      meta: '${s.later.length}',
      phone: phone,
      children: [
        if (s.later.isEmpty)
          const _Inset(child: _Empty('Nothing scheduled after today.'))
        else
          for (final (n, i) in s.later.indexed)
            tile(i, first: n == 0, showList: false),
      ],
    );

    final List<Widget> body;
    if (phone) {
      body = [header, today, const SizedBox(height: 12), later];
    } else {
      final thread = _Card(
        title: "Today's thread",
        meta: stack ? null : '07:00 to 23:00',
        phone: false,
        children: [
          _Inset(
            child: DayThread(
              today: s.dueToday,
              now: s.now,
              colors: colors,
              onOpen: open,
            ),
          ),
        ],
      );
      body = [
        header,
        thread,
        const SizedBox(height: 12),
        if (stack) ...[
          today,
          const SizedBox(height: 12),
          later,
        ] else
          // Ragged bottoms on purpose (C12).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: today),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: later),
            ],
          ),
      ];
    }
    return ListView(padding: layout.padding, children: body);
  }
}

/// The add field bound to [CaptureCubit]. Adding says where it went
/// ("Added to Work · Due Tomorrow 18:00"), as 03 does for Up next.
class _Capture extends StatelessWidget {
  const _Capture({this.phoneBar = false});

  final bool phoneBar;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptureCubit>();
    final s = context.watch<CaptureCubit>().state;
    return QuickCaptureField(
      listId: s.listId,
      lists: s.lists,
      phoneBar: phoneBar,
      onListChange: cubit.pick,
      onSubmit: (raw) async {
        if (cubit.state.list == null) {
          UndoToast.show(context, 'Make a list first');
          return false;
        }
        try {
          final added = await cubit.add(raw);
          if (added != null && context.mounted) {
            UndoToast.show(context, added.message);
          }
          return added != null;
        } on Object catch (e) {
          developer.log('add failed: ${e.runtimeType}', name: 'Capture');
          if (context.mounted) {
            UndoToast.show(context, "Couldn't add that. Try again.");
          }
          return false;
        }
      },
    );
  }
}

/// `.card`: surface, 1 px border, radius 8, padding 20 (16 on phones);
/// header = 16/500 title + 13 muted meta. Rows run 8 px wider than the
/// card's content (`.row { margin: 0 -8px }`), so the card pads 8 less and
/// everything else sits in an [_Inset].
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.phone,
    required this.children,
    this.meta,
  });

  final String title;
  final String? meta;
  final bool phone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final pad = phone ? 16.0 : 20.0;
    final m = meta;
    return Container(
      padding: EdgeInsets.fromLTRB(pad - 8, pad, pad - 8, pad),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Inset(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.titleMedium?.copyWith(height: 24 / 16),
                    ),
                  ),
                  if (m != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      m,
                      style: t.numeric.copyWith(
                        fontSize: t.fsSmall,
                        color: t.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child);
}

/// `.empty`: muted copy in a 1 px dashed `control` box, radius 6.
class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CustomPaint(
      painter: _DashedBox(t.control, t.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: t.muted),
        ),
      ),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dashed = Path();
    for (final ui.PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        dashed.addPath(m.extractPath(d, d + 3), Offset.zero);
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedBox old) =>
      old.color != color || old.radius != radius;
}
