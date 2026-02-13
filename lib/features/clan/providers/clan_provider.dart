import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/clan_models.dart';

/// Manages clan state — create, join, leave, search via backend API.
class ClanNotifier extends Notifier<ClanState> {
  final _api = ApiClient.instance;

  @override
  ClanState build() => const ClanState();

  /// Fetch all clans from the backend.
  Future<void> loadClans() async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.get('/clan');
      final clansJson = response['clans'] as List<dynamic>;
      final clans = clansJson.map((json) {
        final c = json as Map<String, dynamic>;
        return Clan(
          id: c['id'] as String,
          name: c['name'] as String,
          tag: c['tag'] as String,
          description: (c['description'] as String?) ?? '',
          memberCount: c['memberCount'] as int,
          winRate: _calcWinRate(
            c['totalWins'] as int,
            c['totalLosses'] as int,
          ),
          totalWins: c['totalWins'] as int,
          totalLosses: c['totalLosses'] as int,
          createdAt: DateTime.parse(c['createdAt'] as String),
        );
      }).toList();

      state = state.copyWith(
        browseClansList: clans,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  static int _calcWinRate(int wins, int losses) {
    final total = wins + losses;
    if (total == 0) return 0;
    return ((wins / total) * 100).round();
  }

  /// Create a new clan via backend API.
  Future<void> createClan(
      String name, String tag, String description) async {
    if (state.hasClan || state.isCreating) return;

    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final response = await _api.post('/clan', {
        'name': name,
        'tag': tag.toUpperCase(),
        'description': description,
      });

      final clan = Clan(
        id: response['id'] as String,
        name: response['name'] as String,
        tag: response['tag'] as String,
        description: (response['description'] as String?) ?? '',
        memberCount: 1,
        winRate: 0,
        totalWins: 0,
        totalLosses: 0,
        members: [
          ClanMember(
            address: '',
            gamerTag: 'You',
            role: ClanRole.leader,
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );

      state = state.copyWith(userClan: clan, isCreating: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Failed to create clan: ${e.toString()}',
      );
    }
  }

  /// Join a clan by ID via backend API.
  Future<void> joinClan(String clanId) async {
    if (state.hasClan || state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _api.post('/clan/$clanId/join');

      // Fetch the full clan details.
      final clanResponse = await _api.get('/clan/$clanId');

      final members = (clanResponse['members'] as List<dynamic>)
          .map((m) {
        final member = m as Map<String, dynamic>;
        return ClanMember(
          address: member['address'] as String,
          gamerTag: member['gamerTag'] as String,
          role: _parseRole(member['role'] as String),
          joinedAt: DateTime.parse(member['joinedAt'] as String),
        );
      }).toList();

      final clan = Clan(
        id: clanResponse['id'] as String,
        name: clanResponse['name'] as String,
        tag: clanResponse['tag'] as String,
        description: (clanResponse['description'] as String?) ?? '',
        memberCount: clanResponse['memberCount'] as int,
        winRate: _calcWinRate(
          clanResponse['totalWins'] as int,
          clanResponse['totalLosses'] as int,
        ),
        totalWins: clanResponse['totalWins'] as int,
        totalLosses: clanResponse['totalLosses'] as int,
        members: members,
        createdAt: DateTime.parse(clanResponse['createdAt'] as String),
      );

      state = state.copyWith(userClan: clan, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to join clan: ${e.toString()}',
      );
    }
  }

  /// Leave the current clan via backend API.
  Future<void> leaveClan() async {
    if (!state.hasClan) return;

    try {
      await _api.delete('/clan/${state.userClan!.id}/leave');
      state = state.copyWith(clearUserClan: true, clearError: true);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to leave clan: ${e.toString()}',
      );
    }
  }

  /// Filter clans by search query (client-side filter on loaded list).
  void searchClans(String query) {
    state = state.copyWith(searchQuery: query);
    loadClans();
  }

  static ClanRole _parseRole(String role) {
    switch (role) {
      case 'LEADER':
        return ClanRole.leader;
      case 'CO_LEADER':
        return ClanRole.coLeader;
      case 'ELDER':
        return ClanRole.elder;
      default:
        return ClanRole.member;
    }
  }
}

final clanProvider =
    NotifierProvider<ClanNotifier, ClanState>(ClanNotifier.new);
