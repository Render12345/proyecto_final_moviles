import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/device_model.dart';

class DeviceService {
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
  // LISTAR DISPOSITIVOS
  // ============================================================

  Future<List<DeviceModel>> obtenerDispositivos() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/devices'),
      headers: await _obtenerHeaders(),
    );

    final data = _procesarRespuesta(response);

    if (data is! Map || data['dispositivos'] is! List) {
      throw Exception('La respuesta de dispositivos no es válida.');
    }

    return (data['dispositivos'] as List)
        .whereType<Map>()
        .map((item) => DeviceModel.fromMap(item))
        .toList();
  }

  // ============================================================
  // CONSULTAR UN DISPOSITIVO
  // ============================================================

  Future<DeviceModel> obtenerDispositivo(String deviceId) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/devices/${Uri.encodeComponent(deviceId)}',
      ),
      headers: await _obtenerHeaders(),
    );

    final data = _procesarRespuesta(response);

    if (data is! Map || data['dispositivo'] is! Map) {
      throw Exception('No se recibió la información del dispositivo.');
    }

    return DeviceModel.fromMap(data['dispositivo'] as Map);
  }

  // ============================================================
  // OBTENER QR
  // ============================================================

  Future<String> obtenerQr(String deviceId) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/devices/${Uri.encodeComponent(deviceId)}/qr',
      ),
      headers: await _obtenerHeaders(),
    );

    final data = _procesarRespuesta(response);

    if (data is! Map || data['qr'] == null) {
      throw Exception('No se pudo obtener el código QR.');
    }

    return data['qr'].toString();
  }

  // ============================================================
  // ASIGNAR O DESASIGNAR SALÓN
  // ============================================================

  Future<void> asignarSalon({
    required String deviceId,
    required String? salonId,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$_baseUrl/api/devices/${Uri.encodeComponent(deviceId)}/salon',
      ),
      headers: await _obtenerHeaders(),
      body: jsonEncode({'salonId': salonId}),
    );

    _procesarRespuesta(response);
  }

  // ============================================================
  // ELIMINAR DISPOSITIVO
  // ============================================================

  Future<void> eliminarDispositivo(String deviceId) async {
    final response = await http.delete(
      Uri.parse(
        '$_baseUrl/api/devices/${Uri.encodeComponent(deviceId)}',
      ),
      headers: await _obtenerHeaders(),
    );

    _procesarRespuesta(response);
  }
}
