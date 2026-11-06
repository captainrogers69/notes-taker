/// Cancels every scheduled local notification. Sign-out and delete account
/// call it after the wipe, so no reminder of the old account fires.
/// Task 21 implements it with `flutter_local_notifications`.
abstract class NotificationCanceller {
  Future<void> cancelAll();
}

/// Default until reminders exist (Task 21).
class NoopNotificationCanceller implements NotificationCanceller {
  const NoopNotificationCanceller();

  @override
  Future<void> cancelAll() async {}
}
