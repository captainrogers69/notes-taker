import 'package:get_it/get_it.dart';

import '../../features/lists/data/lists_repository_impl.dart';
import '../../features/lists/domain/repositories/lists_repository.dart';
import '../../features/lists/domain/usecases/archive_list.dart';
import '../../features/lists/domain/usecases/create_list.dart';
import '../../features/lists/domain/usecases/delete_list_forever.dart';
import '../../features/lists/domain/usecases/reorder_list.dart';
import '../../features/lists/domain/usecases/restore_deleted_list.dart';
import '../../features/lists/domain/usecases/restore_list.dart';
import '../../features/lists/domain/usecases/trash_list.dart';
import '../../features/lists/domain/usecases/update_list.dart';
import '../database/weave_database.dart';
import '../sync/change_writer.dart';

void registerLists(GetIt sl) {
  sl.registerLazySingleton<ListsRepository>(
    () => ListsRepositoryImpl(sl<WeaveDatabase>(), sl<ChangeWriter>()),
  );
  sl.registerFactory(() => CreateList(sl()));
  sl.registerFactory(() => UpdateList(sl()));
  sl.registerFactory(() => ArchiveList(sl()));
  sl.registerFactory(() => RestoreList(sl()));
  sl.registerFactory(() => TrashList(sl()));
  sl.registerFactory(() => DeleteListForever(sl()));
  sl.registerFactory(() => RestoreDeletedList(sl()));
  sl.registerFactory(() => ReorderList(sl()));
}
