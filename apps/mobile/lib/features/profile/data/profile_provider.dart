import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/features/profile/domain/models/user_profile.dart';
import 'profile_repository.dart';

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    return ref.read(profileRepositoryProvider).getProfile();
  }

  Future<void> refreshProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).getProfile();
    });
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).updateProfile(
            fullName: fullName,
            phone: phone,
            bio: bio,
            location: location,
          );
    });
  }

  Future<void> updateAvatar(String avatarUrl) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).updateAvatar(avatarUrl);
    });
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);
