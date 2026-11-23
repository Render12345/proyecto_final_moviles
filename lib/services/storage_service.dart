import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static const String _baseUrl = 'https://qr-dispositivos.onrender.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CacheManager _cacheImagenes = CacheManager(
    Config(
      'control_aires_imagenes',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );

  String _claveCache(String tipo, String identificador) {
    final uid = _auth.currentUser?.uid ?? 'publico';
    return '${uid}_${tipo}_$identificador';
  }

  Future<File> _obtenerArchivoCacheado({
    required String identificador,
    required String tipo,
    required Future<String> Function() obtenerUrl,
  }) async {
    final clave = _claveCache(tipo, identificador);

    final imagenGuardada = await _cacheImagenes.getFileFromCache(clave);

    if (imagenGuardada != null && await imagenGuardada.file.exists()) {
      // Si la imagen todavía está vigente, utilizarla.
      if (imagenGuardada.validTill.isAfter(DateTime.now())) {
        return imagenGuardada.file;
      }

      // Si venció, intentar actualizarla.
      try {
        final url = await obtenerUrl();

        return await _cacheImagenes.getSingleFile(url, key: clave);
      } catch (_) {
        // Si no hay conexión, conservar la imagen anterior.
        return imagenGuardada.file;
      }
    }

    // No existe una copia local: descargarla.
    final url = await obtenerUrl();

    return _cacheImagenes.getSingleFile(url, key: clave);
  }

  Future<File> obtenerArchivoImagen(String ruta) {
    return _obtenerArchivoCacheado(
      identificador: ruta,
      tipo: 'perfil',
      obtenerUrl: () => obtenerUrlImagen(ruta),
    );
  }

  Future<File> obtenerArchivoFotoSalon(String ruta) {
    return _obtenerArchivoCacheado(
      identificador: ruta,
      tipo: 'salon',
      obtenerUrl: () => obtenerUrlFotoSalon(ruta),
    );
  }

  Future<File> obtenerArchivoDesdeUrl(
    String url, {
    required String identificador,
  }) {
    return _obtenerArchivoCacheado(
      identificador: identificador,
      tipo: 'externa',
      obtenerUrl: () async => url,
    );
  }

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

  // ============================================================
  // FOTOGRAFÍAS DE PERFIL
  // ============================================================

  Future<String> subirImagen({required XFile imagen}) async {
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

    final ruta = data['ruta'].toString();

    await _cacheImagenes.removeFile(_claveCache('perfil', ruta));

    return ruta;
  }

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

    await _cacheImagenes.removeFile(_claveCache('perfil', ruta));
  }

  // ============================================================
  // FOTOGRAFÍAS DE SALONES
  // ============================================================

  Future<String> subirFotoSalon({
    required String salonId,
    required XFile imagen,
  }) async {
    final token = await _obtenerToken();
    final bytes = await imagen.readAsBytes();

    final uri = Uri.parse('$_baseUrl/api/storage/salons/$salonId');

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
            ? data['mensaje'] ?? 'No se pudo subir la fotografía del salón.'
            : 'No se pudo subir la fotografía del salón.',
      );
    }

    if (data is! Map || data['ruta'] == null) {
      throw Exception('El servidor no devolvió la ruta de la fotografía.');
    }

    final ruta = data['ruta'].toString();

    await _cacheImagenes.removeFile(_claveCache('salon', ruta));

    return ruta;
  }

  Future<String> obtenerUrlFotoSalon(String ruta) async {
    if (ruta.isEmpty) {
      throw Exception('La ruta de la fotografía está vacía.');
    }

    final token = await _obtenerToken();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/storage/salons/url'),
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
              ? data['mensaje'] ?? 'No se pudo obtener la fotografía.'
              : 'No se pudo obtener la fotografía.',
        );
      }

      if (data is! Map || data['url'] == null) {
        throw Exception('El servidor no devolvió la URL de la fotografía.');
      }

      return data['url'].toString();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> eliminarFotoSalon(String ruta) async {
    if (ruta.isEmpty) return;

    final token = await _obtenerToken();

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/storage/salons'),
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
            ? data['mensaje'] ?? 'No se pudo eliminar la fotografía.'
            : 'No se pudo eliminar la fotografía.',
      );
    }

    await _cacheImagenes.removeFile(_claveCache('salon', ruta));
  }
}
