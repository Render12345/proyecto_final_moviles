import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../config/email_auth.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

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