import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

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
      password: password.trim(),
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
      password: password.trim(),
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('No se pudo obtener el usuario creado.');
    }

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
      await ref.set(nuevo.toMap());
    }
  }

  // 7. CRUD ADMIN: DAR DE ALTA USUARIO SIN CERRAR SESIÓN DEL ADMIN
  Future<void> adminCrearUsuario({
    required String nombre,
    required String email,
    required String password,
    required String role, // 'user' o 'admin'
    required bool autorizado,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final createdUser = cred.user;
      if (createdUser == null) {
        throw Exception('No se pudo crear el usuario secundario.');
      }

      await createdUser.updateDisplayName(nombre.trim());
      await createdUser.sendEmailVerification();

      final nuevoUsuario = UserModel(
        uid: createdUser.uid,
        nombre: nombre.trim(),
        email: email.trim(),
        fotoUrl: '',
        provider: 'password',
        role: role,
        autorizado: autorizado,
        planSuscripcion: 'ninguno',
        dispositivosVinculados: {},
      );

      await _db.child('users/${createdUser.uid}').set(nuevoUsuario.toMap());
      await secondaryAuth.signOut();
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  // CRUD ADMIN: ACTUALIZAR ROL Y AUTORIZACIÓN
  Future<void> adminActualizarUsuario({
    required String uid,
    required String nombre,
    required String role,
    required bool autorizado,
  }) async {
    await _db.child('users/$uid').update({
      'nombre': nombre.trim(),
      'role': role,
      'autorizado': autorizado,
    });
  }

  // CRUD ADMIN: ELIMINAR REGISTRO DEL USUARIO EN REALTIME DATABASE
  Future<void> adminEliminarUsuario(String uid) async {
    await _db.child('users/$uid').remove();
  }

  Future<void> cerrarSesion() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}