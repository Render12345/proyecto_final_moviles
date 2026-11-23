
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/report_model.dart';
import 'notification_service.dart';

class ReportService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // ============================================================
  // CREAR REPORTE
  // ============================================================

  Future<void> crearReporte({
    required String deviceId,
    required String salonId,
    required String salonNombre,
    required String tipo,
    String descripcion = '',
  }) async {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión activa.');
    }

    if (tipo != 'no_apaga' && tipo != 'no_enciende') {
      throw Exception('El tipo de reporte no es válido.');
    }

    if (salonId.trim().isEmpty || salonNombre.trim().isEmpty) {
      throw Exception('El dispositivo no tiene un salón asignado.');
    }

    final referencia = _database.ref('reports').push();

    await referencia.set({
      'user_id': usuario.uid,
      'user_email': usuario.email ?? '',
      'device_id': deviceId,
      'salon_id': salonId,
      'salon_nombre': salonNombre,
      'tipo': tipo,
      'descripcion': descripcion.trim(),
      'estado': 'pending',
      'fecha_creacion': ServerValue.timestamp,
      'atendido_por': null,
      'fecha_atencion': null,
    });

    // Solicitar el envío de la notificación sin bloquear
    // la creación del reporte.
    final reportId = referencia.key;

    if (reportId != null) {
      unawaited(
        NotificationService.notificarNuevoReporte(reportId),
      );
    }
  }

  // ============================================================
  // ESCUCHAR REPORTES
  // ============================================================

  Stream<List<ReportModel>> escucharReportes() {
    return _database.ref('reports').onValue.map((event) {
      final valor = event.snapshot.value;

      if (valor == null || valor is! Map) {
        return <ReportModel>[];
      }

      final reportes = valor.entries
          .where((entry) => entry.value is Map)
          .map(
            (entry) => ReportModel.fromMap(
              entry.key.toString(),
              entry.value as Map<dynamic, dynamic>,
            ),
          )
          .toList();

      reportes.sort(
        (a, b) => b.fechaCreacion.compareTo(a.fechaCreacion),
      );

      return reportes;
    });
  }

  // ============================================================
  // MARCAR REPORTE COMO ATENDIDO
  // ============================================================

  Future<void> marcarComoAtendido(String reportId) async {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión activa.');
    }

    await _database.ref('reports/$reportId').update({
      'estado': 'attended',
      'atendido_por': usuario.uid,
      'fecha_atencion': ServerValue.timestamp,
    });
  }
}
