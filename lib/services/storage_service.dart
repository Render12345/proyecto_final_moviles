import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static const String _baseUrl =
      'https://qr-dispositivos.onrender.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _obtenerToken() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('No se pudo obtener el token de autenticación.');
    }

    return token;
  }

  MediaType _obtenerTipoImagen(XFile imagen) {
    final mime = imagen.mimeType?.toLowerCase();

    switch (mime) {
      case 'image/png':
        return MediaType('image', 'png');
      case 'image/webp':
        return MediaType('image', 'webp');
      case 'image/jpeg':
        return MediaType('image', 'jpeg');
      default:
        final extension = imagen.name.split('.').last.toLowerCase();

        switch (extension) {
          case 'png':
            return MediaType('image', 'png');
          case 'webp':
            return MediaType('image', 'webp');
          case 'jpg':
          case 'jpeg':
          default:
            return MediaType('image', 'jpeg');
        }
    }
  }

  /// Sube una fotografía de perfil y devuelve su ruta en Supabase Storage.
  Future<String> subirImagen({
    required XFile imagen,
  }) async {
    final token = await _obtenerToken();
    final bytes = await imagen.readAsBytes();

    final uri = Uri.parse('$_baseUrl/api/storage/profile');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'imagen',
        bytes,
        filename: imagen.name,
        contentType: _obtenerTipoImagen(imagen),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(
        data is Map
            ? data['mensaje'] ?? 'No se pudo subir la imagen.'
            : 'No se pudo subir la imagen.',
      );
    }

    if (data is! Map || data['ruta'] == null) {
      throw Exception('El servidor no devolvió la ruta de la imagen.');
    }

    return data['ruta'].toString();
  }

  /// Obtiene una URL firmada para visualizar una imagen.
  Future<String> obtenerUrlImagen(String ruta) async {
    if (ruta.isEmpty) {
      throw Exception('La ruta de la imagen está vacía.');
    }

    final token = await _obtenerToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/api/storage/profile/url'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'ruta': ruta}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data is Map
            ? data['mensaje'] ?? 'No se pudo obtener la imagen.'
            : 'No se pudo obtener la imagen.',
      );
    }

    if (data is! Map || data['url'] == null) {
      throw Exception('El servidor no devolvió la URL de la imagen.');
    }

    return data['url'].toString();
  }

  /// Elimina una fotografía de perfil del almacenamiento.
  Future<void> eliminarImagen(String ruta) async {
    if (ruta.isEmpty) return;

    final token = await _obtenerToken();

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/storage/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'ruta': ruta}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
        data is Map
            ? data['mensaje'] ?? 'No se pudo eliminar la imagen.'
            : 'No se pudo eliminar la imagen.',
      );
    }
  }
}
