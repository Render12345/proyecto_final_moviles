import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucket = 'imagenes_lab';

  /// Sube una imagen al bucket `imagenes_lab` en Supabase Storage
  /// (soporta `File` en móvil o `Uint8List` en web/escritorio) y retorna su URL pública.
  Future<String> subirImagen({
    required String carpeta, // Ej: 'perfiles' o 'dispositivos'
    required String nombreArchivo,
    File? archivoMovil,
    Uint8List? bytesWeb,
  }) async {
    final ruta =
        '$carpeta/${DateTime.now().millisecondsSinceEpoch}_$nombreArchivo.jpg';

    if (bytesWeb != null) {
      await _supabase.storage.from(_bucket).uploadBinary(
            ruta,
            bytesWeb,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } else if (archivoMovil != null) {
      await _supabase.storage.from(_bucket).upload(
            ruta,
            archivoMovil,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } else {
      throw Exception('No se proporcionó ninguna imagen para subir.');
    }

    return _supabase.storage.from(_bucket).getPublicUrl(ruta);
  }

  /// Elimina un archivo del bucket a partir de su URL pública si alguna vez necesitas borrarlo.
  Future<void> eliminarImagenPorUrl(String publicUrl) async {
    if (publicUrl.isEmpty) return;

    final uri = Uri.tryParse(publicUrl);
    if (uri == null) return;

    final marcador = '/object/public/$_bucket/';
    final indice = uri.path.indexOf(marcador);
    if (indice == -1) return;

    final rutaRelativa = uri.path.substring(indice + marcador.length);
    if (rutaRelativa.isNotEmpty) {
      await _supabase.storage.from(_bucket).remove([rutaRelativa]);
    }
  }
}