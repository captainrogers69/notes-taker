import 'package:get_it/get_it.dart';

import '../core/database/weave_database.dart';
import '../core/sync/device_names.dart';
import '../features/items/domain/repositories/items_repository.dart';
import '../features/lists/domain/repositories/lists_repository.dart';
import 'shell/shell_cubit.dart';

/// Registers the app shell's cubit. Needs `registerCore` first.
void registerApp(GetIt sl) {
  sl.registerFactory<ShellCubit>(
    () => ShellCubit(
      lists: sl<ListsRepository>(),
      items: sl<ItemsRepository>(),
      deviceCount: () => DeviceNames.watchCount(sl<WeaveDatabase>()),
    ),
  );
}
