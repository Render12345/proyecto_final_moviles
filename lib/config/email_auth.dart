import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../models/user_model.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  AuthCredential? _githubCredentialPendiente;
  String? _githubEmailPendiente;

  bool get hayCredencialGitHubPendiente => _githubCredentialPendiente != null;

  String? get correoGitHubPendiente => _githubEmailPendiente;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // INICIALIZAR GOOGLE SIGN IN
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

  // VINCULAR UNA CREDENCIAL PENDIENTE
  Future<UserCredential?> vincularCredencialPendiente(
    AuthCredential credential,
  ) async {
    final user = _auth.currentUser;

    if (user == null) return null;

    return await user.linkWithCredential(credential);
  }

  // 5. INICIO DE SESIÓN CON GOOGLE
  // Compatible con google_sign_in v7+
  
Future<UserCredential?> loginConGoogle() async {
  try {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount googleUser =
        await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);

    if (userCred.user != null) {
      await _guardarUsuarioOAuthSiNoExiste(
        userCred.user!,
        'google.com',
      );
    }

    return userCred;
  } on GoogleSignInException catch (e) {
    // Cancelar el selector de cuentas no es un error.
    if (e.code == GoogleSignInExceptionCode.canceled) {
      debugPrint('Inicio de sesión con Google cancelado por el usuario.');
      return null;
    }

    rethrow;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'account-exists-with-different-credential') {
      throw Exception(
        'Este correo ya está registrado con otro método de acceso. '
        'Inicia sesión con el proveedor que usaste originalmente.',
      );
    }

    rethrow;
  }
}


  // 6. VINCULAR GITHUB A LA CUENTA ACTUAL
  Future<UserCredential?> vincularGitHub() async {
    try {
      final userActual = _auth.currentUser;

      if (userActual == null) {
        throw Exception('No hay una sesión activa.');
      }

      final githubProvider = GithubAuthProvider();

      final resultado = await userActual.linkWithProvider(githubProvider);

      debugPrint('GitHub vinculado correctamente.');
      debugPrint('UID: ${resultado.user?.uid}');

      for (final provider in resultado.user?.providerData ?? []) {
        debugPrint('Proveedor: ${provider.providerId}');
      }

      return resultado;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error al vincular GitHub: ${e.code}');
      debugPrint('Mensaje: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error al vincular GitHub: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // 7. VINCULAR GOOGLE A LA CUENTA ACTUAL
  // Compatible con google_sign_in v7+
  Future<UserCredential?> vincularGoogle() async {
    try {
      final userActual = _auth.currentUser;

      if (userActual == null) {
        throw Exception('No hay una sesión activa.');
      }

      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('No se pudo obtener el token de Google.');
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final resultado = await userActual.linkWithCredential(credential);

      debugPrint('Google vinculado correctamente.');
      debugPrint('UID: ${resultado.user?.uid}');

      for (final provider in resultado.user?.providerData ?? []) {
        debugPrint('Proveedor: ${provider.providerId}');
      }

      return resultado;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error al vincular Google: ${e.code}');
      debugPrint('Mensaje: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error al vincular Google: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // 8. OBTENER LOS PROVEEDORES VINCULADOS
  List<String> obtenerProveedoresVinculados() {
    final user = _auth.currentUser;

    if (user == null) return [];

    return user.providerData.map((provider) => provider.providerId).toList();
  }

  Future<UserCredential?> vincularCorreoPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    if (user.email?.toLowerCase() != email.toLowerCase()) {
      throw Exception('El correo no coincide con el de la cuenta actual.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    return await user.linkWithCredential(credential);
  }

  Future<UserCredential?> loginConGitHub() async {
    _githubCredentialPendiente = null;
    _githubEmailPendiente = null;

    // Usuario que ya tiene sesión antes de intentar GitHub.
    final usuarioAnterior = _auth.currentUser;

    debugPrint('========== INICIO GITHUB ==========');
    debugPrint(
      'Usuario Firebase anterior: ${usuarioAnterior?.email ?? "Sin sesión"}',
    );
    debugPrint('UID anterior: ${usuarioAnterior?.uid ?? "Ninguno"}');

    try {
      final githubProvider = GithubAuthProvider();

      final userCred = await _auth.signInWithProvider(githubProvider);

      if (userCred.user != null) {
        debugPrint('========== GITHUB AUTENTICADO ==========');
        debugPrint('Correo: ${userCred.user!.email}');
        debugPrint('UID: ${userCred.user!.uid}');

        for (final provider in userCred.user!.providerData) {
          debugPrint(
            'Proveedor: ${provider.providerId} | '
            'Correo: ${provider.email} | '
            'UID proveedor: ${provider.uid}',
          );
        }

        await _guardarUsuarioOAuthSiNoExiste(userCred.user!, 'github.com');
      }

      return userCred;
    } on FirebaseAuthException catch (e) {
      debugPrint('========== ERROR FIREBASE GITHUB ==========');
      debugPrint('Código: ${e.code}');
      debugPrint('Mensaje: ${e.message}');
      debugPrint('Correo detectado por Firebase: ${e.email}');
      debugPrint('Credencial pendiente disponible: ${e.credential != null}');
      debugPrint(
        'Proveedor de la credencial: '
        '${e.credential?.providerId ?? "No disponible"}',
      );

      // Guardar la información para completar la vinculación.
      if (e.code == 'account-exists-with-different-credential') {
        _githubCredentialPendiente = e.credential;
        _githubEmailPendiente = e.email;

        debugPrint('========== CONFLICTO DE CUENTA ==========');
        debugPrint('Correo pendiente: $_githubEmailPendiente');
        debugPrint('Usuario Firebase actual: ${_auth.currentUser?.email}');
      }

      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error inesperado GitHub: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<UserCredential?> completarVinculacionGitHub() async {
    final userActual = _auth.currentUser;
    final credential = _githubCredentialPendiente;

    if (userActual == null) {
      throw Exception('No hay una sesión activa.');
    }

    if (credential == null) {
      throw Exception('No existe una credencial pendiente de GitHub.');
    }

    try {
      final emailPendiente = _githubEmailPendiente?.toLowerCase();
      final emailActual = userActual.email?.toLowerCase();
      debugPrint('========== VALIDACIÓN DE VINCULACIÓN ==========');
      debugPrint('UID actual: ${userActual.uid}');
      debugPrint('Correo actual: ${userActual.email}');
      debugPrint('Correo GitHub pendiente: $_githubEmailPendiente');
      debugPrint('Proveedores actuales: ${obtenerProveedoresVinculados()}');

      if (emailPendiente != null &&
          emailActual != null &&
          emailPendiente != emailActual) {
        throw Exception(
          'El correo de la cuenta autenticada no coincide '
          'con el correo de GitHub.',
        );
      }

      final resultado = await userActual.linkWithCredential(credential);

      debugPrint('GitHub vinculado correctamente.');
      debugPrint('UID conservado: ${resultado.user?.uid}');

      _githubCredentialPendiente = null;
      _githubEmailPendiente = null;

      return resultado;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error al completar vinculación: ${e.code}');
      debugPrint('Mensaje: ${e.message}');
      rethrow;
    }
  }

  Future<UserCredential?> loginConGoogleParaVincular(
    String correoEsperado,
  ) async {
    try {
      await _ensureGoogleInitialized();

      // Seleccionar una cuenta de Google.
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Comprobar que sea el correo esperado.
      if (googleUser.email.toLowerCase() != correoEsperado.toLowerCase()) {
        throw Exception(
          'Seleccionaste una cuenta de Google diferente '
          'al correo de GitHub.',
        );
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No se pudo obtener el token de Google.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      // Autenticar la cuenta existente en Firebase.
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error Google para vinculación: ${e.code}');
      debugPrint('Mensaje: ${e.message}');
      rethrow;
    }
  }

  // GUARDAR USUARIO OAUTH SI NO EXISTE EN REALTIME DATABASE
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

  Future<void> adminCrearUsuario({
    required String nombre,
    required String email,
    required String password,
    required String role,
    required bool autorizado,
  }) async {
    FirebaseApp? secondaryApp;
    User? createdUser;

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

      createdUser = cred.user;

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
    } catch (e) {
      // Si algo falla después de crear la cuenta, intentamos eliminarla.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Conservamos el error original.
        }
      }

      rethrow;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<void> adminActualizarUsuario({
    required String uid,
    required String nombre,
    required String role,
    required bool autorizado,
  }) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw Exception('No hay una sesión activa.');
    }

    final nombreLimpio = nombre.trim();

    if (nombreLimpio.isEmpty) {
      throw Exception('El nombre no puede estar vacío.');
    }

    // Un administrador puede editar su nombre,
    // pero no modificar sus propios permisos.
    if (usuarioActual.uid == uid) {
      await _db.child('users/$uid/profile').update({'nombre': nombreLimpio});

      return;
    }

    await _db.child('users/$uid').update({
      'profile/nombre': nombreLimpio,
      'role': role,
      'autorizado': autorizado,
    });
  }

  Future<void> adminEliminarUsuario(String uid) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw Exception('No hay una sesión activa.');
    }

    if (usuarioActual.uid == uid) {
      throw Exception(
        'No puedes eliminar tu propia cuenta desde el panel de administración.',
      );
    }

    final token = await usuarioActual.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('No se pudo obtener el token de autenticación.');
    }

    final response = await http.delete(
      Uri.parse('https://qr-dispositivos.onrender.com/api/admin/users/$uid'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data is Map
            ? data['mensaje'] ?? 'No se pudo eliminar el usuario.'
            : 'No se pudo eliminar el usuario.',
      );
    }
  }

  // 13. CERRAR SESIÓN
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  Future<void> actualizarPerfil({
    required String nombre,
    String? fotoUrl,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    final nombreLimpio = nombre.trim();

    if (nombreLimpio.isEmpty) {
      throw Exception('El nombre no puede estar vacío.');
    }

    await user.updateDisplayName(nombreLimpio);

    final cambios = <String, dynamic>{'profile/nombre': nombreLimpio};

    if (fotoUrl != null) {
      cambios['profile/foto_url'] = fotoUrl;
    }

    await _db.child('users/${user.uid}/profile').update({
      'nombre': nombreLimpio,
      if (fotoUrl != null) 'foto_url': fotoUrl,
    });

    await user.reload();
  }
}
