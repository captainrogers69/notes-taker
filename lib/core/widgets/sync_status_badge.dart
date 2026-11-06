import 'package:flutter/material.dart';

import '../helpers/platform_labels.dart';
import '../sync/sync_status.dart';
import '../theme/weave_theme.dart';
import 'pressable.dart';
import 'weave_icons.dart';

/// Where the badge sits; the two locked prototypes word two states
/// differently:
/// - [sheet]: the mini-bar sheet footer (01, `weave.js` `syncLine`):
///   "Offline · saved here", "Can't sync" + Retry.
/// - [sidebar]: the app's sidebar sync line (03, `app.js` `SYNC`):
///   "Offline · changes saved here", "Sync error · retrying" (the engine
///   retries on its own; tapping the line retries now).
enum SyncBadgeStyle { sheet, sidebar }

/// The words for [status]. [signedOut]: the session ended on the server
/// while this device's data still belongs to the account (see
/// `SessionCubit.accountSignedOut`); only read while [status] is
/// [SyncStatus.localOnly].
String syncBadgeLabel(
  SyncStatus status, {
  required int devices,
  bool signedOut = false,
  SyncBadgeStyle style = SyncBadgeStyle.sheet,
  TargetPlatform? platform,
}) {
  final sheet = style == SyncBadgeStyle.sheet;
  return switch (status) {
    SyncStatus.localOnly when signedOut => 'Signed out · sign in again to sync',
    SyncStatus.localOnly => 'On ${hereName(platform)} only',
    SyncStatus.synced =>
      'Synced · $devices ${devices == 1 ? 'device' : 'devices'}',
    SyncStatus.syncing => 'Syncing…',
    SyncStatus.offline =>
      sheet ? 'Offline · saved here' : 'Offline · changes saved here',
    SyncStatus.error => sheet ? "Can't sync" : 'Sync error · retrying',
  };
}

/// Sync state as one line: icon, words and, where the prototype has one,
/// an action ("Retry" for errors in the sheet; "Sign in" after a
/// server-side sign-out). In the [SyncBadgeStyle.sidebar] style only the
/// error line is an action (tap retries); the signed-out line is text only,
/// as the sidebar's user row is the one Sign in (C4).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.status,
    this.devices = 1,
    this.signedOut = false,
    this.style = SyncBadgeStyle.sheet,
    this.onRetry,
    this.onSignIn,
  });

  final SyncStatus status;
  final int devices;
  final bool signedOut;
  final SyncBadgeStyle style;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.bodySmall;
    final isSignedOut = signedOut && status == SyncStatus.localOnly;
    final label = syncBadgeLabel(
      status,
      devices: devices,
      signedOut: signedOut,
      style: style,
    );
    final trouble =
        isSignedOut ||
        status == SyncStatus.offline ||
        status == SyncStatus.error;
    final (actionLabel, action) = isSignedOut
        ? ('Sign in', onSignIn)
        : status == SyncStatus.error
        ? ('Retry', onRetry)
        : (null, null);

    if (style == SyncBadgeStyle.sidebar) {
      // app.css `.syncline`: cloud for an account (red when offline or
      // failing), laptop in local mode.
      final line = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          children: [
            WeaveIcon(
              status == SyncStatus.localOnly && !isSignedOut
                  ? WeaveIcons.laptop
                  : WeaveIcons.cloud,
              color: trouble ? t.negative : t.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: text?.copyWith(color: t.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      final retry = status == SyncStatus.error ? onRetry : null;
      return retry == null
          ? Semantics(container: true, child: line)
          : Pressable(
              onTap: retry,
              tooltip: 'Retry',
              semanticLabel: '$label. Retry',
              child: line,
            );
    }

    // weave.css `.sheet .foot .sync` + `.fbtn`.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WeaveIcon(
          status == SyncStatus.localOnly && !isSignedOut
              ? WeaveIcons.laptop
              : trouble
              ? WeaveIcons.cloudOff
              : WeaveIcons.cloud,
          color: status == SyncStatus.error ? t.negative : t.muted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: text?.copyWith(
              color: status == SyncStatus.error ? t.negative : t.muted,
            ),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 4),
          Pressable(
            onTap: action,
            child: SizedBox(
              height: 30,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    actionLabel,
                    style: text?.copyWith(color: t.text),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
