import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;
  FirebaseApp? _verificationApp;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }
  }

  // 1. INICIO DE SESIÓN CON CORREO Y CONTRASEÑA
  Future<UserCredential> loginConCorreo(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // 2. AUTO-REGISTRO CON CORREO + ENVÍO DE VERIFICACIÓN
  Future<UserCredential> registrarConCorreo({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('No se pudo obtener el usuario creado.');
    }

    try {
      await user.updateDisplayName(nombre.trim());
      await user.sendEmailVerification();

      final nuevoUsuario = UserModel(
        uid: user.uid,
        nombre: nombre.trim(),
        email: email.trim(),
        fotoUrl: '',
        provider: 'password',
        role: 'user',
        autorizado: false,
        planSuscripcion: 'ninguno',
        dispositivosVinculados: {},
      );

      await _db.child('users/${user.uid}').set(nuevoUsuario.toMap());
      return cred;
    } catch (error, stackTrace) {
      try {
        await user.delete();
        await _auth.signOut();
      } catch (cleanupError) {
        throw StateError(
          'Falló el registro ($error) y no se pudo limpiar la cuenta '
          'incompleta ($cleanupError).',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // 3. REENVIAR CORREO DE VERIFICACIÓN Y RECARGAR ESTADO
  Future<void> reenviarVerificacion() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> verificarSiYaConfirmoCorreo() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // 4. RECUPERAR CONTRASEÑA
  Future<void> recuperarPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // 5. INICIO DE SESIÓN CON GOOGLE (google_sign_in v7+)
  Future<UserCredential?> loginConGoogle() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    if (userCred.user != null) {
      await _guardarUsuarioOAuthSiNoExiste(userCred.user!, 'google.com');
    }
    return userCred;
  }

  // 6. INICIO DE SESIÓN CON GITHUB
  Future<UserCredential?> loginConGitHub() async {
    final GithubAuthProvider githubProvider = GithubAuthProvider();
    final userCred = await _auth.signInWithProvider(githubProvider);
    if (userCred.user != null) {
      await _guardarUsuarioOAuthSiNoExiste(userCred.user!, 'github.com');
    }
    return userCred;
  }

  Future<void> _guardarUsuarioOAuthSiNoExiste(
    User user,
    String providerId,
  ) async {
    final ref = _db.child('users/${user.uid}');
    final snap = await ref.get();
    if (!snap.exists) {
      final nuevo = UserModel(
        uid: user.uid,
        nombre: user.displayName ?? 'Usuario',
        email: user.email ?? '',
        fotoUrl: user.photoURL ?? '',
        provider: providerId,
        role: 'user',
        autorizado: false,
        planSuscripcion: 'ninguno',
        dispositivosVinculados: {},
      );
      try {
        await ref.set(nuevo.toMap());
      } catch (error, stackTrace) {
        try {
          await _auth.signOut();
        } catch (cleanupError) {
          throw StateError(
            'No se pudo guardar el perfil ($error) y tampoco cerrar la '
            'sesión incompleta ($cleanupError).',
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  Future<FirebaseAuth> _getVerificationAuth() async {
    final app = _verificationApp ??= await Firebase.initializeApp(
      name: 'UserVerification',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<String> adminCrearUsuario({
    required String nombre,
    required String email,
    required String password,
    required bool autorizado,
  }) async {
    final result = await _functions.httpsCallable('adminCreateUser').call({
      'displayName': nombre.trim(),
      'email': email.trim(),
      'password': password,
      'authorized': autorizado,
    });
    final data = Map<Object?, Object?>.from(result.data as Map);
    final uid = data['uid'] as String;
    final cardNumber = data['cardNumber'] as String;

    FirebaseAuth? secondaryAuth;
    try {
      secondaryAuth = await _getVerificationAuth();
      final credential = await secondaryAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final createdUser = credential.user;
      if (createdUser == null) {
        throw StateError('No se pudo obtener la cuenta creada.');
      }
      await createdUser.sendEmailVerification();
      await secondaryAuth.signOut();
      return cardNumber;
    } catch (error, stackTrace) {
      Object? cleanupError;
      if (secondaryAuth?.currentUser != null) {
        try {
          await secondaryAuth!.signOut();
        } catch (signOutError) {
          cleanupError = signOutError;
        }
      }
      try {
        await _functions.httpsCallable('adminDeleteUser').call({'uid': uid});
      } catch (deleteError) {
        cleanupError ??= deleteError;
      }
      if (cleanupError != null) {
        throw StateError(
          'No se pudo completar la verificación del correo ($error) y la '
          'limpieza de la cuenta también falló ($cleanupError).',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> adminActualizarUsuario({
    required String uid,
    required String nombre,
    required String email,
    required bool autorizado,
  }) async {
    await _functions.httpsCallable('adminUpdateUser').call({
      'uid': uid,
      'displayName': nombre.trim(),
      'email': email.trim(),
      'authorized': autorizado,
    });
  }

  Future<void> adminEliminarUsuario(String uid) async {
    await _functions.httpsCallable('adminDeleteUser').call({'uid': uid});
  }

  Future<void> cerrarSesion() async {
    if (_googleInitialized) {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}