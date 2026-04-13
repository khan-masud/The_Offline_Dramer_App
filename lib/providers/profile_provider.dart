import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfileState>(
  (ref) => UserProfileNotifier(),
);

class UserProfileState {
  final String name;
  final String photoPath; // Local file path (not URL)
  final String photoData; // base64 image data for web
  final bool isLoading;

  const UserProfileState({
    this.name = 'Dreamer',
    this.photoPath = '',
    this.photoData = '',
    this.isLoading = true,
  });

  UserProfileState copyWith({
    String? name,
    String? photoPath,
    String? photoData,
    bool? isLoading,
  }) {
    return UserProfileState(
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      photoData: photoData ?? this.photoData,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Uint8List? get photoBytes {
    if (photoData.isEmpty) return null;
    try {
      return base64Decode(photoData);
    } catch (_) {
      return null;
    }
  }

  bool get hasPhoto {
    if (kIsWeb) {
      return photoBytes != null;
    }
    if (photoPath.isEmpty) return false;
    try {
      return File(photoPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  ImageProvider? get imageProvider {
    final bytes = photoBytes;
    if (bytes != null) {
      return MemoryImage(bytes);
    }

    if (kIsWeb || photoPath.isEmpty) return null;

    try {
      final file = File(photoPath);
      if (!file.existsSync()) return null;
      return FileImage(file);
    } catch (_) {
      return null;
    }
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier() : super(const UserProfileState()) {
    _load();
  }

  static const _nameKey = 'profile_name';
  static const _photoKey = 'profile_image_path';
  static const _legacyPhotoKey = 'profile_photo_path';
  static const _photoDataKey = 'profile_image_data';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final photoPath = (prefs.getString(_photoKey) ?? prefs.getString(_legacyPhotoKey) ?? '').trim();
    final photoData = (prefs.getString(_photoDataKey) ?? '').trim();
    state = state.copyWith(
      name: prefs.getString(_nameKey)?.trim().isNotEmpty == true
          ? prefs.getString(_nameKey)!.trim()
          : 'Dreamer',
      photoPath: photoPath,
      photoData: photoData,
      isLoading: false,
    );
  }

  Future<void> saveName(String name) async {
    final normalizedName = name.trim().isEmpty ? 'Dreamer' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, normalizedName);
    state = state.copyWith(name: normalizedName);
  }

  /// Save picked image.
  /// - Web: stores base64 bytes in SharedPreferences.
  /// - Native: copies file into app directory and stores local path.
  Future<void> saveProfileImage(XFile imageFile, {Uint8List? imageBytes}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final bytes = imageBytes ?? await imageFile.readAsBytes();
        if (bytes.isEmpty) return;

        final encoded = base64Encode(bytes);
        await prefs.setString(_photoDataKey, encoded);
        await prefs.setString(_photoKey, '');
        await prefs.setString(_legacyPhotoKey, '');

        state = state.copyWith(photoPath: '', photoData: encoded);
        return;
      }

      final source = File(imageFile.path);
      if (!source.existsSync()) return;

      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory(p.join(appDir.path, 'profile'));
      if (!profileDir.existsSync()) {
        profileDir.createSync(recursive: true);
      }

      // Delete old image if exists
      if (state.photoPath.isNotEmpty) {
        final oldFile = File(state.photoPath);
        if (oldFile.existsSync()) {
          oldFile.deleteSync();
        }
      }

      // Copy to app directory with timestamp to avoid caching issues
      final ext = p.extension(source.path);
      final newPath = p.join(profileDir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}$ext');
      await source.copy(newPath);

      await prefs.setString(_photoKey, newPath);
      await prefs.setString(_legacyPhotoKey, newPath);
      await prefs.setString(_photoDataKey, '');
      state = state.copyWith(photoPath: newPath, photoData: '');
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> removeProfileImage() async {
    if (!kIsWeb && state.photoPath.isNotEmpty) {
      final file = File(state.photoPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoKey, '');
    await prefs.setString(_legacyPhotoKey, '');
    await prefs.setString(_photoDataKey, '');
    state = state.copyWith(photoPath: '', photoData: '');
  }

  // Legacy support: also save with old method signature for backward compat
  Future<void> saveProfile({required String name, required String photoUrl}) async {
    await saveName(name);
    // If photoUrl is a local file path that exists, treat it as local
    if (!kIsWeb && photoUrl.isNotEmpty && File(photoUrl).existsSync()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_photoKey, photoUrl);
      await prefs.setString(_legacyPhotoKey, photoUrl);
      await prefs.setString(_photoDataKey, '');
      state = state.copyWith(photoPath: photoUrl, photoData: '');
    }
  }
}
