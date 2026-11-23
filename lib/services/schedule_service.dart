
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/schedule_model.dart';

class ScheduleService {
  static const String _baseUrl =
      'https://qr-dispositivos.onrender.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _obtenerToken() async {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw Exception('No hay una sesión activa.');
    }

    final token = await usuario.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('No se pudo obtener el token de Firebase.');
    }

    return token;
  }

  Future<Map<String, String>> _obtenerHeaders() async {
    final token = await _obtenerToken();

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  dynamic _procesarRespuesta(http.Response response) {
    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('El servidor devolvió una respuesta inválida.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final mensaje = data is Map
          ? data['mensaje']?.toString()
          : null;

      throw Exception(
        mensaje ?? 'Error al comunicarse con el servidor.',
      );
    }

    return data;
  }

  // ============================================================
  // LISTAR PROGRAMACIONES
  // ============================================================

  Future<List<ScheduleModel>> obtenerProgramaciones() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/schedules'),
      headers: await _obtenerHeaders(),
    );

    final data = _procesarRespuesta(response);

    if (data is! Map || data['programaciones'] is! List) {
      throw Exception(
        'La respuesta de programaciones no es válida.',
      );
    }

    return (data['programaciones'] as List)
        .whereType<Map>()
        .map((item) => ScheduleModel.fromMap(item))
        .toList();
  }

  // ============================================================
  // CREAR PROGRAMACIÓN: INICIO INMEDIATO
  // ============================================================

  Future<ScheduleModel> crearProgramacion({
    required String deviceId,
    required int durationHours,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/schedules'),
      headers: await _obtenerHeaders(),
      body: jsonEncode({
        'deviceId': deviceId,
        'durationHours': durationHours,
      }),
    );

    final data = _procesarRespuesta(response);

    if (data is! Map || data['programacion'] is! Map) {
      throw Exception(
        'No se recibió la programación creada.',
      );
    }

    return ScheduleModel.fromMap(
      data['programacion'] as Map,
    );
  }

  // ============================================================
  // CONSULTAR UNA PROGRAMACIÓN
  // ============================================================

  Future<ScheduleModel> obtenerProgramacion(
    String scheduleId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/schedules/${Uri.encodeComponent(scheduleId)}',
      ),
      headers: await _obtenerHeaders(),
    );

    final data = _procesarRespuesta(response);

    if (data is! Map || data['programacion'] is! Map) {
      throw Exception(
        'No se recibió la información de la programación.',
      );
    }

    final programacion = Map<dynamic, dynamic>.from(
      data['programacion'] as Map,
    );

    programacion['scheduleId'] ??= data['scheduleId'] ?? scheduleId;

    return ScheduleModel.fromMap(programacion);
  }

  // ============================================================
  // CANCELAR PROGRAMACIÓN
  // ============================================================

  Future<void> cancelarProgramacion(String scheduleId) async {
    final url = Uri.parse(
      '$_baseUrl/api/schedules/'
      '${Uri.encodeComponent(scheduleId)}/cancel',
    );

    debugPrint('========== DEBUG CANCELAR PROGRAMACIÓN ==========');
    debugPrint('ID recibido: $scheduleId');
    debugPrint('URL solicitada: $url');

    final headers = await _obtenerHeaders();

    final response = await http.patch(
      url,
      headers: headers,
    );

    debugPrint('Código HTTP: ${response.statusCode}');
    debugPrint('Respuesta del servidor: ${response.body}');
    debugPrint('==================================================');

    _procesarRespuesta(response);
  }
}
