import 'package:get_it/get_it.dart';

import '../core/database/capture_pref.dart';
import '../core/database/weave_database.dart';
import '../core/sync/device_names.dart';
import '../features/items/domain/repositories/items_repository.dart';
import '../features/items/domain/usecases/add_item.dart';
import '../features/items/domain/usecases/add_item_below.dart';
import '../features/items/domain/usecases/delete_item.dart';
import '../features/items/domain/usecases/edit_text.dart';
import '../features/items/domain/usecases/indent_item.dart';
import '../features/items/domain/usecases/move_item.dart';
import '../features/items/domain/usecases/toggle_done.dart';
import '../features/items/domain/usecases/uncheck_all.dart';
import '../features/lists/domain/repositories/lists_repository.dart';
import '../features/lists/domain/usecases/archive_list.dart';
import '../features/lists/domain/usecases/trash_list.dart';
import '../features/lists/domain/usecases/update_list.dart';
import '../features/lists/presentation/list_cubit.dart';
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
  sl.registerFactoryParam<ListCubit, String, void>(
    (id, _) => ListCubit(
      listId: id,
      items: sl<ItemsRepository>(),
      lists: sl<ListsRepository>(),
      addItem: sl<AddItem>(),
      addItemBelow: AddItemBelow(sl<ItemsRepository>()),
      toggleDone: sl<ToggleDone>(),
      editText: sl<EditText>(),
      deleteItem: sl<DeleteItem>(),
      indentItem: sl<IndentItem>(),
      moveItem: sl<MoveItem>(),
      uncheckAll: sl<UncheckAll>(),
      updateList: sl<UpdateList>(),
      archiveList: sl<ArchiveList>(),
      trashList: sl<TrashList>(),
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
