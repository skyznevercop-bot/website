import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/friend_models.dart';

/// Manages friends, friend requests, and challenges via the backend API.
class FriendNotifier extends Notifier<FriendsState> {
  final _api = ApiClient.instance;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  Timer? _pollTimer;

  @override
  FriendsState build() {
    ref.onDispose(() {
      _wsSub?.cancel();
      _pollTimer?.cancel();
    });
    Future.microtask(() => _init());
    return const FriendsState();
  }

  Future<void> _init() async {
    if (!_api.hasToken) return;
    // Attach WS listener FIRST so events during loadAll aren't lost.
    _listenWs();
    await loadAll();
    // Poll every 15s as fallback for missed WebSocket events.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_api.hasToken) loadAll();
    });
  }

  void _listenWs() {
    _wsSub?.cancel();
    _wsSub = _api.wsStream.listen((data) {
      final type = data['type'] as String?;
      if (type == 'friend_request' ||
          type == 'friend_accepted' ||
          type == 'challenge_received' ||
          type == 'challenge_declined' ||
          type == 'challenge_cancelled' ||
          type == 'ws_connected') {
        loadAll();
      }
    });
  }

  /// Load friends, requests, and challenges in parallel.
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Future.wait([loadFriends(), loadRequests(), loadChallenges()]);
    } catch (_) {}
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadFriends() async {
    try {
      final response = await _api.get('/friends');
      final list = (response['friends'] as List<dynamic>?) ?? [];
      state = state.copyWith(
        friends: list.map((j) => Friend.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      debugPrint('[Friends] loadFriends error: $e');
    }
  }

  Future<void> loadRequests() async {
    try {
      final response = await _api.get('/friends/requests');
      final list = (response['requests'] as List<dynamic>?) ?? [];
      state = state.copyWith(
        incomingRequests:
            list.map((j) => FriendRequest.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      debugPrint('[Friends] loadRequests error: $e');
    }
  }

  Future<void> loadChallenges() async {
    try {
      final response = await _api.get('/challenge/pending');
      final sent = (response['sent'] as List<dynamic>?) ?? [];
      final received = (response['received'] as List<dynamic>?) ?? [];
      state = state.copyWith(
        sentChallenges:
            sent.map((j) => Challenge.fromJson(j as Map<String, dynamic>)).toList(),
        receivedChallenges:
            received.map((j) => Challenge.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      debugPrint('[Friends] loadChallenges error: $e');
    }
  }

  /// Send a friend request by wallet address.
  Future<bool> addFriend(String address) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      final response = await _api.post('/friends/add', {'address': address});
      final status = response['status'] as String?;
      final msg = status == 'accepted'
          ? 'Friend request accepted!'
          : 'Friend request sent!';
      state = state.copyWith(successMessage: msg);
      await loadAll();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to add friend');
      return false;
    }
  }

  /// Accept an incoming friend request.
  Future<void> acceptRequest(String address) async {
    try {
      await _api.post('/friends/accept', {'address': address});
      state = state.copyWith(successMessage: 'Friend request accepted!');
      await loadAll();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  /// Remove a friend or decline a request.
  Future<void> removeFriend(String address) async {
    try {
      await _api.delete('/friends/$address');
      await loadAll();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  /// Create a challenge against a friend.
  Future<bool> createChallenge(
      String toAddress, String duration, double bet) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await _api.post('/challenge/create', {
        'toAddress': toAddress,
        'duration': duration,
        'bet': bet,
      });
      state = state.copyWith(successMessage: 'Challenge sent!');
      await loadChallenges();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to send challenge');
      return false;
    }
  }

  /// Accept a challenge.
  Future<bool> acceptChallenge(String challengeId) async {
    state = state.copyWith(clearError: true);
    try {
      final response = await _api.post('/challenge/$challengeId/accept');
      final matchId = response['matchId'] as String?;
      if (matchId != null) {
        state = state.copyWith(successMessage: 'Challenge accepted! Entering arena...');
      }
      await loadChallenges();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Decline a challenge.
  Future<void> declineChallenge(String challengeId) async {
    try {
      await _api.post('/challenge/$challengeId/decline');
      await loadChallenges();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  /// Cancel a challenge you sent.
  Future<void> cancelChallenge(String challengeId) async {
    try {
      await _api.post('/challenge/$challengeId/cancel');
      state = state.copyWith(successMessage: 'Challenge cancelled');
      await loadChallenges();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final friendProvider =
    NotifierProvider<FriendNotifier, FriendsState>(FriendNotifier.new);
