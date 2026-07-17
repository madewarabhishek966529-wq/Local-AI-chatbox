import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_storage.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/providers/chat_providers.dart';
import '../domain/app_settings.dart';

/// Fixed Hive key: there's exactly one settings document per signed-in
/// device/user, so no need to key it by id.
const _settingsCacheKey = 'user_settings';

/// Loads settings from the Hive cache first (instant, works offline), then
/// refreshes from the backend in the background. Every update is written
/// to Hive immediately and pushed to the backend when reachable, mirroring
/// the offline-first pattern used by `ConversationListNotifier`.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final ChatRepository repository;
  final Ref ref;

  SettingsNotifier(this.repository, this.ref) : super(_loadFromCache()) {
    refresh();
  }

  static AppSettings _loadFromCache() {
    final raw = HiveStorage.settings.get(_settingsCacheKey) as String?;
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> _cache(AppSettings settings) async {
    await HiveStorage.settings.put(
      _settingsCacheKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<void> refresh() async {
    try {
      final settings = await repository.getSettings();
      state = settings;
      ref.read(backendReachabilityProvider.notifier).markReachable();
      await _cache(settings);
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
      // keep whatever's already in state (cache or previous fetch)
    }
  }

  /// Applies `update` to the current settings, caches immediately so the
  /// change survives app restarts even offline, then pushes to the backend
  /// when reachable. On failure the local (optimistic) value stands; it
  /// will reconcile on the next `refresh()`.
  Future<void> _apply(AppSettings updated) async {
    state = updated;
    await _cache(updated);
    try {
      final saved = await repository.updateSettings(updated);
      state = saved;
      await _cache(saved);
      ref.read(backendReachabilityProvider.notifier).markReachable();
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
    }
  }

  Future<void> setTemperature(double value) =>
      _apply(state.copyWith(temperature: value));
  Future<void> setTopP(double value) => _apply(state.copyWith(topP: value));
  Future<void> setTopK(int value) => _apply(state.copyWith(topK: value));
  Future<void> setMaxTokens(int value) =>
      _apply(state.copyWith(maxTokens: value));
  Future<void> setStreamingEnabled(bool value) =>
      _apply(state.copyWith(streamingEnabled: value));
  Future<void> setMarkdownEnabled(bool value) =>
      _apply(state.copyWith(markdownEnabled: value));
  Future<void> setAnimationsEnabled(bool value) =>
      _apply(state.copyWith(animationsEnabled: value));
  Future<void> setTheme(String value) => _apply(state.copyWith(theme: value));
  Future<void> setFontSize(String value) =>
      _apply(state.copyWith(fontSize: value));
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.watch(chatRepositoryProvider), ref),
);
