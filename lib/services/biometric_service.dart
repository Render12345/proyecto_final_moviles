import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class CredencialesGuardadas {
  final String email;
  final String password;

  const CredencialesGuardadas(this.email, this.password);
}

/// Inicio de sesión con huella para cuentas de correo y contraseña.
///
/// Las credenciales se guardan cifradas (Keystore de Android) y solo se
/// leen después de que la huella sea verificada.
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';
  static const _kRechazado = 'bio_rechazado';

  /// El dispositivo tiene sensor y al menos una huella registrada.
  static Future<bool> disponible() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Biometría no disponible: $e');
      return false;
    }
  }

  /// Muestra el diálogo del sistema. Devuelve true si la huella fue válida.
  static Future<bool> autenticar() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Usa tu huella para iniciar sesión',
        biometricOnly: true,
      );
    } on LocalAuthException catch (e) {
      debugPrint('Biometría rechazada o cancelada: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Error de biometría: $e');
      return false;
    }
  }

  static Future<bool> tieneCredenciales() async {
    try {
      final email = await _storage.read(key: _kEmail);
      final pass = await _storage.read(key: _kPassword);
      return email != null && pass != null;
    } catch (_) {
      return false;
    }
  }

  static Future<CredencialesGuardadas?> obtenerCredenciales() async {
    try {
      final email = await _storage.read(key: _kEmail);
      final pass = await _storage.read(key: _kPassword);
      if (email == null || pass == null) return null;
      return CredencialesGuardadas(email, pass);
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardarCredenciales(String email, String password) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPassword, value: password);
    await _storage.delete(key: _kRechazado);
  }

  /// Desactiva la huella: borra las credenciales guardadas.
  static Future<void> borrar() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
  }

  /// El usuario dijo "No, gracias" al ofrecerle activar la huella.
  static Future<bool> rechazado() async {
    return (await _storage.read(key: _kRechazado)) == 'true';
  }

  static Future<void> marcarRechazado() async {
    await _storage.write(key: _kRechazado, value: 'true');
  }
}