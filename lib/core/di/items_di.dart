import 'package:get_it/get_it.dart';

import '../../features/items/data/items_repository_impl.dart';
import '../../features/items/domain/repositories/items_repository.dart';
import '../../features/items/domain/usecases/add_item.dart';
import '../../features/items/domain/usecases/delete_item.dart';
import '../../features/items/domain/usecases/edit_text.dart';
import '../../features/items/domain/usecases/indent_item.dart';
import '../../features/items/domain/usecases/move_item.dart';
import '../../features/items/domain/usecases/resolve_conflict.dart';
import '../../features/items/domain/usecases/set_due.dart';
import '../../features/items/domain/usecases/set_reminders.dart';
import '../../features/items/domain/usecases/set_repeat.dart';
import '../../features/items/domain/usecases/toggle_done.dart';
import '../../features/items/domain/usecases/uncheck_all.dart';
import '../database/weave_database.dart';
import '../sync/change_writer.dart';

void registerItems(GetIt sl) {
  sl.registerLazySingleton<ItemsRepository>(
    () => ItemsRepositoryImpl(sl<WeaveDatabase>(), sl<ChangeWriter>()),
  );
  sl.registerFactory(() => AddItem(sl()));
  sl.registerFactory(() => EditText(sl()));
  sl.registerFactory(() => ToggleDone(sl()));
  sl.registerFactory(() => SetDue(sl()));
  sl.registerFactory(() => SetReminders(sl()));
  sl.registerFactory(() => SetRepeat(sl()));
  sl.registerFactory(() => MoveItem(sl()));
  sl.registerFactory(() => IndentItem(sl()));
  sl.registerFactory(() => DeleteItem(sl()));
  sl.registerFactory(() => UncheckAll(sl()));
  sl.registerFactory(() => ResolveConflict(sl()));
}
