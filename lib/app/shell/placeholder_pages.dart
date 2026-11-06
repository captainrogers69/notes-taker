import 'package:flutter/material.dart';

import '../../core/widgets/shell_layout.dart';

// Placeholders for screens later tasks build. Each shows only its title
// (no invented UI) and is replaced whole by its task:
// - ArchivePlaceholder, SearchPlaceholder → Task 19
// - SettingsPlaceholder → Task 20 (`settings_page.dart`)

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
