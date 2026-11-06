/// Whether local edits are queued for sync. Off in local mode (no account),
/// on while signed in; `SessionCubit` flips it. `ChangeWriter` reads it on
/// every write (see `registerCore`).
class OutboxGate {
  OutboxGate({this.enabled = false});

  bool enabled;
}
