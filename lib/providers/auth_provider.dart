import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/email_auth.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final isLoggingOutProvider = StateProvider<bool>((ref) => false);

final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(firebaseAuthStateProvider).value;
  if (authUser == null) return Stream.value(null);

  return FirebaseDatabase.instance
      .ref('users/${authUser.uid}')
      .onValue
      .map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return null;
    final raw = event.snapshot.value;
    if (raw is! Map) return null;
    return UserModel.fromMap(authUser.uid, raw);
  });
});

final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final authUser = ref.watch(firebaseAuthStateProvider).value;
  if (authUser == null) return Stream.value([]);

  return FirebaseDatabase.instance.ref('users').onValue.map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return [];
    final raw = event.snapshot.value;
    if (raw is! Map) return [];

    return raw.entries
        .where((e) => e.value is Map)
        .map(
          (e) => UserModel.fromMap(
            e.key.toString(),
            e.value as Map<dynamic, dynamic>,
          ),
        )
        .toList();
  });
});

class LoginUiState {
  final bool isLoading;
  final bool isRegisterMode;
  final bool obscurePassword;

  LoginUiState({
    this.isLoading = false,
    this.isRegisterMode = false,
    this.obscurePassword = true,
  });

  LoginUiState copyWith({
    bool? isLoading,
    bool? isRegisterMode,
    bool? obscurePassword,
  }) {
    return LoginUiState(
      isLoading: isLoading ?? this.isLoading,
      isRegisterMode: isRegisterMode ?? this.isRegisterMode,
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }
}

class LoginUiNotifier extends StateNotifier<LoginUiState> {
  LoginUiNotifier() : super(LoginUiState());

  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void toggleRegisterMode() =>
      state = state.copyWith(isRegisterMode: !state.isRegisterMode);
  void toggleObscurePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);
}

final loginUiProvider = StateNotifierProvider<LoginUiNotifier, LoginUiState>(
  (ref) => LoginUiNotifier(),
);

class PerfilUploadNotifier extends StateNotifier<AsyncValue<String?>> {
  PerfilUploadNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> actualizarFotoPerfil({
    required String uid,
    File? archivoMovil,
    Uint8List? bytesWeb,
  }) async {
    state = const AsyncLoading();
    try {
      final url = await _ref.read(storageServiceProvider).subirImagen(
            carpeta: 'perfiles',
            nombreArchivo: uid,
            archivoMovil: archivoMovil,
            bytesWeb: bytesWeb,
          );

      await FirebaseDatabase.instance.ref('users/$uid').update({
        'foto_url': url,
      });

      state = AsyncData(url);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final perfilUploadProvider =
    StateNotifierProvider<PerfilUploadNotifier, AsyncValue<String?>>((ref) {
  return PerfilUploadNotifier(ref);
});