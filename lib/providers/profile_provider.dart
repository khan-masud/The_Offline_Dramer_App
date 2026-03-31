import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfileState>(
  (ref) => UserProfileNotifier(),
);

class UserProfileState {
  final String name;
  final String photoUrl;
  final bool isLoading;

  const UserProfileState({
    this.name = 'Dreamer',
    this.photoUrl = '',
    this.isLoading = true,
  });

  UserProfileState copyWith({String? name, String? photoUrl, bool? isLoading}) {
    return UserProfileState(
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier() : super(const UserProfileState()) {
    _load();
  }

  static const _nameKey = 'profile_name';
  static const _photoKey = 'profile_photo_url';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      name: prefs.getString(_nameKey)?.trim().isNotEmpty == true
          ? prefs.getString(_nameKey)!.trim()
          : 'Dreamer',
      photoUrl: prefs.getString(_photoKey)?.trim() ?? '',
      isLoading: false,
    );
  }

  Future<void> saveProfile({required String name, required String photoUrl}) async {
    final normalizedName = name.trim().isEmpty ? 'Dreamer' : name.trim();
    final normalizedPhoto = photoUrl.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, normalizedName);
    await prefs.setString(_photoKey, normalizedPhoto);
    state = state.copyWith(name: normalizedName, photoUrl: normalizedPhoto);
  }
}
