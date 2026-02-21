import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/clan_models.dart';

/// Manages clan state — create, join, leave, search via backend API.
class ClanNotifier extends Notifier<ClanState> {
  final _api = ApiClient.instance;

  /// Full unfiltered list for client-side search.
  List<Clan> _allClans = [];

  @override
  ClanState build() {
    // Kick off initial loads (non-blocking).
    Future.microtask(() {
      loadMyClan();
      loadClans();
    });
    return const ClanState();
  }

  // ── Helpers ──────────────────────────────────────────────

  static int _calcWinRate(int wins, int total) {
    if (total == 0) return 0;
    return ((wins / total) * 100).round();
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

  /// Parse a clan JSON map into a Clan object.
  Clan _parseClan(Map<String, dynamic> c, {List<ClanMember>? members}) {
    final totalWins = (c['totalWins'] as int?) ?? 0;
    final totalLosses = (c['totalLosses'] as int?) ?? 0;
    final totalGamesPlayed = (c['totalGamesPlayed'] as int?) ?? 0;

    return Clan(
      id: c['id'] as String,
      name: c['name'] as String,
      tag: c['tag'] as String,
      description: (c['description'] as String?) ?? '',
      leaderAddress: (c['leaderAddress'] as String?) ?? '',
      memberCount: (c['memberCount'] as int?) ?? members?.length ?? 1,
      maxMembers: (c['maxMembers'] as int?) ?? 50,
      winRate: (c['winRate'] as int?) ??
          _calcWinRate(totalWins, totalGamesPlayed > 0 ? totalGamesPlayed : totalWins + totalLosses),
      totalWins: totalWins,
      totalLosses: totalLosses,
      totalTies: (c['totalTies'] as int?) ?? 0,
      totalPnl: ((c['totalPnl'] as num?) ?? 0).toDouble(),
      totalGamesPlayed: totalGamesPlayed,
      bestStreak: (c['bestStreak'] as int?) ?? 0,
      members: members ?? const [],
      createdAt: DateTime.tryParse(c['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Parse a members JSON list into ClanMember objects.
  List<ClanMember> _parseMembers(List<dynamic> membersJson) {
    return membersJson.map((m) {
      final member = m as Map<String, dynamic>;
      return ClanMember(
        address: member['address'] as String,
        gamerTag: (member['gamerTag'] as String?) ?? 'Unknown',
        role: _parseRole(member['role'] as String),
        wins: (member['wins'] as int?) ?? 0,
        losses: (member['losses'] as int?) ?? 0,
        ties: (member['ties'] as int?) ?? 0,
        totalPnl: ((member['totalPnl'] as num?) ?? 0).toDouble(),
        currentStreak: (member['currentStreak'] as int?) ?? 0,
        gamesPlayed: (member['gamesPlayed'] as int?) ?? 0,
        joinedAt: DateTime.tryParse(member['joinedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  // ── Data Loading ─────────────────────────────────────────

  /// Fetch the current user's clan from the backend.
  Future<void> loadMyClan() async {
    if (!_api.hasToken) return;

    try {
      final response = await _api.get('/clan/my');
      final clanJson = response['clan'];

      if (clanJson == null) {
        state = state.copyWith(clearUserClan: true);
        return;
      }

      final c = clanJson as Map<String, dynamic>;
      final members = c['members'] != null
          ? _parseMembers(c['members'] as List<dynamic>)
          : <ClanMember>[];

      final clan = _parseClan(c, members: members);
      state = state.copyWith(userClan: clan);
    } catch (_) {
      // Silently fail — user just won't see their clan.
    }
  }

  /// Fetch all clans from the backend.
  Future<void> loadClans({String? sortBy}) async {
    final sort = sortBy ?? state.sortBy;
    state = state.copyWith(isLoading: true, sortBy: sort);

    try {
      final response = await _api.get('/clan?sortBy=$sort');
      final clansJson = response['clans'] as List<dynamic>;
      _allClans = clansJson.map((json) {
        final c = json as Map<String, dynamic>;
        return _parseClan(c);
      }).toList();

      state = state.copyWith(
        browseClansList: _filteredClans(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Apply search filter to the cached clan list.
  List<Clan> _filteredClans() {
    final query = state.searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _allClans;

    return _allClans.where((clan) {
      return clan.name.toLowerCase().contains(query) ||
          clan.tag.toLowerCase().contains(query);
    }).toList();
  }

  // ── Mutations ────────────────────────────────────────────

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
        createdAt: DateTime.tryParse(response['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

      state = state.copyWith(userClan: clan, isCreating: false);

      // Refresh browse list so new clan appears.
      loadClans();
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
      final members = clanResponse['members'] != null
          ? _parseMembers(clanResponse['members'] as List<dynamic>)
          : <ClanMember>[];

      final clan = _parseClan(clanResponse, members: members);

      state = state.copyWith(userClan: clan, isLoading: false);

      // Refresh browse list so member counts update.
      loadClans();
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

      // Refresh browse list so member counts update.
      loadClans();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to leave clan: ${e.toString()}',
      );
    }
  }

  /// Update clan details (leader only).
  Future<bool> updateClan({String? name, String? tag, String? description}) async {
    if (!state.hasClan) return false;

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (tag != null) body['tag'] = tag.toUpperCase();
      if (description != null) body['description'] = description;

      await _api.patch('/clan/${state.userClan!.id}', body);
      await loadMyClan();
      loadClans();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Delete the clan (leader only).
  Future<bool> deleteClan() async {
    if (!state.hasClan) return false;

    try {
      await _api.delete('/clan/${state.userClan!.id}');
      state = state.copyWith(clearUserClan: true, clearError: true);
      loadClans();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Kick a member from the clan (leader only).
  Future<bool> kickMember(String address) async {
    if (!state.hasClan) return false;

    try {
      await _api.delete('/clan/${state.userClan!.id}/members/$address');
      await loadMyClan();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Change a member's role (leader only).
  Future<bool> changeMemberRole(String address, String role) async {
    if (!state.hasClan) return false;

    try {
      await _api.patch('/clan/${state.userClan!.id}/members/$address', {
        'role': role,
      });
      await loadMyClan();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Transfer leadership to another member (leader only).
  Future<bool> transferLeadership(String toAddress) async {
    if (!state.hasClan) return false;

    try {
      await _api.post('/clan/${state.userClan!.id}/transfer', {
        'toAddress': toAddress,
      });
      await loadMyClan();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Filter clans by search query (client-side filter on loaded list).
  void searchClans(String query) {
    // Update query first, then filter.
    state = state.copyWith(searchQuery: query);
    state = state.copyWith(browseClansList: _filteredClans());
  }
}

final clanProvider =
    NotifierProvider<ClanNotifier, ClanState>(ClanNotifier.new);
