import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

final databaseProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(() => service.dispose());
  return service;
});

// 我们在应用入口统一先 await init() 一次，然后再运行 runApp，所以这里可以通过 future provider 提供初始化保障。
final databaseInitProvider = FutureProvider<void>((ref) async {
  final dbService = ref.watch(databaseProvider);
  await dbService.init();
});
