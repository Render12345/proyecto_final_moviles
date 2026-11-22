import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/salon_model.dart';
import 'storage_service.dart';

class SalonService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference get _salonesRef => _database.ref('salones');

  // ============================================================
  // OBTENER SALONES EN TIEMPO REAL
  // ============================================================

  Stream<List<SalonModel>> obtenerSalones() {
    return _salonesRef.onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <SalonModel>[];
      }

      final raw = event.snapshot.value;

      if (raw is! Map) {
        return <SalonModel>[];
      }

      return raw.entries
          .where((entry) => entry.value is Map)
          .map(
            (entry) => SalonModel.fromMap(
              entry.key.toString(),
              entry.value as Map<dynamic, dynamic>,
            ),
          )
          .toList()
        ..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
    });
  }

  // ============================================================
  // VALIDAR ADMINISTRADOR
  // ============================================================

  Future<void> _validarAdministrador() async {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión activa.');
    }

    final snapshot = await _database.ref('users/${usuario.uid}/role').get();

    if (!snapshot.exists || snapshot.value != 'admin') {
      throw Exception('No tienes permisos para realizar esta operación.');
    }
  }

  // ============================================================
  // REGISTRAR SALÓN
  // ============================================================

  Future<String> registrarSalon({
    required String nombre,
    required String descripcion,
    required String edificio,
    String? fotoUrl,
  }) async {
    await _validarAdministrador();

    final usuario = _auth.currentUser!;

    if (nombre.trim().isEmpty) {
      throw Exception('El nombre del salón es obligatorio.');
    }

    final referencia = _salonesRef.push();

    final salon = SalonModel(
      id: referencia.key!,
      nombre: nombre.trim(),
      descripcion: descripcion.trim(),
      edificio: edificio.trim(),
      fotoUrl: fotoUrl,
      creadoPor: usuario.uid,
      fechaCreacion: DateTime.now().millisecondsSinceEpoch,
    );

    await referencia.set(salon.toMap());

    return referencia.key!;
  }

  // ============================================================
  // ACTUALIZAR SALÓN
  // ============================================================

  Future<void> actualizarSalon({
    required String salonId,
    required String nombre,
    required String descripcion,
    required String edificio,
    String? fotoUrl,
    bool quitarFoto = false,
  }) async {
    await _validarAdministrador();

    if (nombre.trim().isEmpty) {
      throw Exception('El nombre del salón es obligatorio.');
    }

    final cambios = <String, dynamic>{
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'edificio': edificio.trim(),
    };

    if (fotoUrl != null) {
      cambios['foto_url'] = fotoUrl;
    } else if (quitarFoto) {
      cambios['foto_url'] = null;
    }

    await _salonesRef.child(salonId).update(cambios);
  }

  // ============================================================
  // CAMBIAR ESTADO DEL SALÓN
  // ============================================================

  Future<void> cambiarEstadoSalon({
    required String salonId,
    required bool activo,
  }) async {
    await _validarAdministrador();

    await _salonesRef.child(salonId).update({'activo': activo});
  }

  // ============================================================
  // ELIMINAR SALÓN
  // ============================================================

  
Future<void> eliminarSalon(String salonId) async {
  await _validarAdministrador();

  final referencia = _salonesRef.child(salonId);

  // Comprobar que el salón no tenga dispositivos.
  final snapshot = await referencia.child('dispositivos').get();

  if (snapshot.exists &&
      snapshot.value is Map &&
      (snapshot.value as Map).isNotEmpty) {
    throw Exception(
      'No puedes eliminar este salón porque tiene dispositivos registrados.',
    );
  }

  // Recuperar la ruta de la fotografía antes de eliminar el salón.
  final salonSnapshot = await referencia.get();

  final datos = salonSnapshot.value;

  final fotoUrl = datos is Map
      ? datos['foto_url']?.toString()
      : null;

  // Eliminar primero el registro de Firebase.
  await referencia.remove();

  // Eliminar la fotografía de Supabase, si existe.
  if (fotoUrl != null && fotoUrl.isNotEmpty) {
    try {
      await StorageService().eliminarFotoSalon(fotoUrl);
    } catch (error) {
      debugPrint(
        'El salón fue eliminado, pero no se pudo borrar su fotografía: $error',
      );

      throw Exception(
        'El salón se eliminó correctamente, pero no se pudo eliminar '
        'su fotografía de Supabase. Revisa la conexión e inténtalo nuevamente.',
      );
    }
  }
}

}
