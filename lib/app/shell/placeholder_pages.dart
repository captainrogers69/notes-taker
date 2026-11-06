import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'shell_actions.dart';
import 'shell_cubit.dart';

// Placeholders for screens later tasks build. Each shows only its title
// (no invented UI) and is replaced whole by its task:
// - UpNextPlaceholder → Task 15 (`up_next_page.dart`)
// - ListPlaceholder → Task 16 (`list_page.dart`)
// - ArchivePlaceholder, SearchPlaceholder → Task 19
// - SettingsPlaceholder → Task 20 (`settings_page.dart`)
// - ListsPlaceholder (phone Lists tab) → Task 16

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: ShellLayout.of(context).padding,
      children: [Text(title, style: Theme.of(context).textTheme.headlineSmall)],
    );
  }
}

class UpNextPlaceholder extends StatelessWidget {
  const UpNextPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'Up next');
}

class ListPlaceholder extends StatelessWidget {
  const ListPlaceholder({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final name = context.select<ShellCubit, String>(
      (c) =>
          c.state.lists
              .where((l) => l.id == listId)
              .map((l) => l.name)
              .firstOrNull ??
          '',
    );
    return PlaceholderPage(title: name);
  }
}

class ArchivePlaceholder extends StatelessWidget {
  const ArchivePlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'Archive and trash');
}

class SearchPlaceholder extends StatelessWidget {
  const SearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'Search');
}

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'Settings');
}

class ListsPlaceholder extends StatelessWidget {
  const ListsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'Lists');
}
