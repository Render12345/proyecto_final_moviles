import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import 'package:proyecto_final_moviles/config/email_auth.dart';
import 'package:proyecto_final_moviles/models/user_model.dart';
import 'package:proyecto_final_moviles/services/storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

final isLoggingOutProvider = StateProvider<bool>((ref) => false);

final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ============================================================
// DATOS DEL USUARIO ACTUAL
// ============================================================

final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  final authUser = authState.asData?.value;

  if (authUser == null) {
    return Stream.value(null);
  }

  return FirebaseDatabase.instance.ref('users/${authUser.uid}').onValue.map((
    event,
  ) {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      return null;
    }

    final raw = event.snapshot.value;

    if (raw is! Map) {
      return null;
    }

    return UserModel.fromMap(authUser.uid, raw);
  });
});

// ============================================================
// LISTA DE USUARIOS (SOLO ADMINISTRADORES)
// ============================================================

final allUsersProvider = StreamProvider<List<UserModel>>((ref) async* {
  final authState = ref.watch(firebaseAuthStateProvider);
  final authUser = authState.asData?.value;

  if (authUser == null) {
    yield [];
    return;
  }

  final database = FirebaseDatabase.instance;

  final adminSnapshot = await database.ref('users/${authUser.uid}/role').get();

  if (!adminSnapshot.exists || adminSnapshot.value != 'admin') {
    yield [];
    return;
  }

  yield* database.ref('users').onValue.map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      return <UserModel>[];
    }

    final raw = event.snapshot.value;

    if (raw is! Map) {
      return <UserModel>[];
    }

    return raw.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => UserModel.fromMap(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          ),
        )
        .toList();
  });
});

// ============================================================
// ESTADO DE LA INTERFAZ DE LOGIN
// ============================================================

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

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void toggleRegisterMode() {
    state = state.copyWith(isRegisterMode: !state.isRegisterMode);
  }

  void toggleObscurePassword() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }
}

final loginUiProvider = StateNotifierProvider<LoginUiNotifier, LoginUiState>(
  (ref) => LoginUiNotifier(),
);

// ============================================================
// SUBIDA DE FOTO DE PERFIL MEDIANTE EXPRESS
// ============================================================

class PerfilUploadNotifier extends StateNotifier<AsyncValue<String?>> {
  PerfilUploadNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> actualizarFotoPerfil({
    required String uid,
    required XFile imagen,
  }) async {
    state = const AsyncLoading();

    try {
      final usuarioActual = FirebaseAuth.instance.currentUser;

      if (usuarioActual == null) {
        throw Exception('No hay una sesión activa.');
      }

      if (usuarioActual.uid != uid) {
        throw Exception('No puedes modificar la fotografía de otro usuario.');
      }

      final ruta = await _ref
          .read(storageServiceProvider)
          .subirImagen(imagen: imagen);

      await FirebaseDatabase.instance.ref('users/$uid').update({
        'foto_url': ruta,
      });

      _ref.invalidate(currentUserDataProvider);

      state = AsyncData(ruta);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final perfilUploadProvider =
    StateNotifierProvider<PerfilUploadNotifier, AsyncValue<String?>>(
      (ref) => PerfilUploadNotifier(ref),
    );
