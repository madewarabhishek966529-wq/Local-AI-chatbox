import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_config.dart';

/// Opens the Hive boxes the app needs for offline-first storage. Called
/// once from main() before runApp(). All chat history is written here
/// first; sync to the backend happens opportunistically when reachable.
class HiveStorage {
  HiveStorage._();

  static Future<void> init() async {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox(AppConfig.boxConversations),
      Hive.openBox(AppConfig.boxMessages),
      Hive.openBox(AppConfig.boxSettings),
      Hive.openBox(AppConfig.boxAuth),
    ]);
  }

  static Box get conversations => Hive.box(AppConfig.boxConversations);
  static Box get messages => Hive.box(AppConfig.boxMessages);
  static Box get settings => Hive.box(AppConfig.boxSettings);
  static Box get auth => Hive.box(AppConfig.boxAuth);
}
