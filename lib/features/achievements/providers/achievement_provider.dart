import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/achievement_models.dart';

class AchievementNotifier extends Notifier<AchievementsState> {
  final _api = ApiClient.instance;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  @override
  AchievementsState build() {
    ref.onDispose(() {
      _wsSubscription?.cancel();
    });

    // Listen for real-time achievement unlock events.
    _wsSubscription?.cancel();
    _wsSubscription = _api.wsStream.listen(_handleWsEvent);

    return const AchievementsState();
  }

  void _handleWsEvent(Map<String, dynamic> data) {
    if (data['type'] == 'achievement_unlocked') {
      final newAchievements = (data['achievements'] as List<dynamic>?) ?? [];
      if (newAchievements.isEmpty) return;

      // Mark newly unlocked achievements in local state
      final updated = state.achievements.map((a) {
        final isNewlyUnlocked = newAchievements.any((n) => n['id'] == a.id);
        return isNewlyUnlocked ? a.copyWith(unlocked: true) : a;
      }).toList();

      final unlockedCount = updated.where((a) => a.unlocked).length;
      state = state.copyWith(
        achievements: updated,
        unlockedCount: unlockedCount,
      );

      // Store newly unlocked achievements for toast display
      _pendingToasts.addAll(
        newAchievements.map((n) => Achievement.fromJson(
          Map<String, dynamic>.from(n as Map)..['unlocked'] = true,
        )),
      );
      _toastController.add(_pendingToasts.removeAt(0));
    }
  }

  /// Stream of achievements to show as toasts.
  final _toastController = StreamController<Achievement>.broadcast();
  final _pendingToasts = <Achievement>[];
  Stream<Achievement> get toastStream => _toastController.stream;

  /// Fetch achievements for a given wallet address.
  Future<void> fetchAchievements(String address) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _api.get('/profile/$address/achievements');
      final list = (response['achievements'] as List<dynamic>)
          .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
          .toList();

      state = AchievementsState(
        achievements: list,
        isLoading: false,
        unlockedCount: response['unlockedCount'] as int? ?? 0,
        totalCount: response['totalCount'] as int? ?? 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final achievementProvider =
    NotifierProvider<AchievementNotifier, AchievementsState>(
        AchievementNotifier.new);
