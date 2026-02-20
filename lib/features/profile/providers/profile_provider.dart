import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/profile_models.dart';

class ProfileNotifier extends Notifier<ProfileState> {
  final _api = ApiClient.instance;

  @override
  ProfileState build() {
    return const ProfileState();
  }

  Future<void> fetchProfile(String address) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/profile/$address');
      final profile = PlayerProfile.fromJson(response);
      state = ProfileState(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);
