import 'package:get_it/get_it.dart';

import '../core/database/capture_pref.dart';
import '../core/database/weave_database.dart';
import '../core/sync/device_names.dart';
import '../features/items/domain/repositories/items_repository.dart';
import '../features/items/domain/usecases/add_item.dart';
import '../features/items/domain/usecases/toggle_done.dart';
import '../features/lists/domain/repositories/lists_repository.dart';
import '../features/up_next/presentation/capture_cubit.dart';
import '../features/up_next/presentation/up_next_cubit.dart';
import 'shell/shell_cubit.dart';

/// Registers the app shell's and the screens' cubits. Needs `registerCore`
/// first.
void registerApp(GetIt sl) {
  sl.registerFactory<ShellCubit>(
    () => ShellCubit(
      lists: sl<ListsRepository>(),
      items: sl<ItemsRepository>(),
      deviceCount: () => DeviceNames.watchCount(sl<WeaveDatabase>()),
    ),
  );
  sl.registerFactory<UpNextCubit>(
    () => UpNextCubit(
      items: sl<ItemsRepository>(),
      lists: sl<ListsRepository>(),
      toggleDone: sl<ToggleDone>(),
    ),
  );
  sl.registerFactory<CaptureCubit>(
    () => CaptureCubit(
      lists: sl<ListsRepository>(),
      addItem: sl<AddItem>(),
      capturePref: () => watchCaptureListId(sl<WeaveDatabase>()),
    ),
  );
}
