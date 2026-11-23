
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Tipo de fotografía que se desea recuperar de la caché.
enum CachedImageType {
  perfil,
  salon,
}

/// Componente reutilizable para mostrar imágenes guardadas localmente.
class CachedStorageImage extends StatefulWidget {
  final String ruta;
  final CachedImageType tipo;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedStorageImage({
    super.key,
    required this.ruta,
    required this.tipo,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedStorageImage> createState() => _CachedStorageImageState();
}

class _CachedStorageImageState extends State<CachedStorageImage> {
  final StorageService _storage = StorageService();

  late Future<File> _imagenFuture;

  @override
  void initState() {
    super.initState();
    _cargarImagen();
  }

  @override
  void didUpdateWidget(covariant CachedStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.ruta != widget.ruta ||
        oldWidget.tipo != widget.tipo) {
      _cargarImagen();
    }
  }

  Future<File> _obtenerImagen() {
    if (widget.ruta.startsWith('http://') ||
        widget.ruta.startsWith('https://')) {
      return _storage.obtenerArchivoDesdeUrl(
        widget.ruta,
        identificador: widget.ruta,
      );
    }

    return widget.tipo == CachedImageType.perfil
        ? _storage.obtenerArchivoImagen(widget.ruta)
        : _storage.obtenerArchivoFotoSalon(widget.ruta);
  }

  void _cargarImagen() {
    _imagenFuture = _obtenerImagen();
  }

  Widget _imagenPredeterminada(BuildContext context) {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _imagenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ??
              SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _imagenPredeterminada(context);
        }

        return Image.file(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return _imagenPredeterminada(context);
          },
        );
      },
    );
  }
}

/// Componente para mostrar fotografías de perfil en un CircleAvatar.
/// Admite rutas de Supabase y URL externas de Google o GitHub.
class CachedProfileAvatar extends StatefulWidget {
  final String ruta;
  final double radius;

  const CachedProfileAvatar({
    super.key,
    required this.ruta,
    this.radius = 42,
  });

  @override
  State<CachedProfileAvatar> createState() => _CachedProfileAvatarState();
}

class _CachedProfileAvatarState extends State<CachedProfileAvatar> {
  final StorageService _storage = StorageService();

  late Future<File> _imagenFuture;

  @override
  void initState() {
    super.initState();
    _cargarImagen();
  }

  @override
  void didUpdateWidget(covariant CachedProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.ruta != widget.ruta) {
      _cargarImagen();
    }
  }

  Future<File> _obtenerImagen() {
    if (widget.ruta.startsWith('http://') ||
        widget.ruta.startsWith('https://')) {
      return _storage.obtenerArchivoDesdeUrl(
        widget.ruta,
        identificador: widget.ruta,
      );
    }

    return _storage.obtenerArchivoImagen(widget.ruta);
  }

  void _cargarImagen() {
    _imagenFuture = _obtenerImagen();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ruta.isEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        child: Icon(
          Icons.person,
          size: widget.radius,
        ),
      );
    }

    return FutureBuilder<File>(
      future: _imagenFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundImage: FileImage(snapshot.data!),
          );
        }

        return CircleAvatar(
          radius: widget.radius,
          child: Icon(
            snapshot.hasError
                ? Icons.broken_image_outlined
                : Icons.person,
            size: widget.radius,
          ),
        );
      },
    );
  }
}
