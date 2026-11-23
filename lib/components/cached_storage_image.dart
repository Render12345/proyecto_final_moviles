import 'dart:io';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';

enum CachedImageType {
  perfil,
  salon,
}

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

  Future<File>? _imagenFuture;

  bool get _tieneRuta => widget.ruta.trim().isNotEmpty;

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
    final ruta = widget.ruta.trim();

    if (ruta.startsWith('http://') ||
        ruta.startsWith('https://')) {
      return _storage.obtenerArchivoDesdeUrl(
        ruta,
        identificador: ruta,
      );
    }

    return widget.tipo == CachedImageType.perfil
        ? _storage.obtenerArchivoImagen(ruta)
        : _storage.obtenerArchivoFotoSalon(ruta);
  }

  void _cargarImagen() {
    _imagenFuture = _tieneRuta ? _obtenerImagen() : null;
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
    if (!_tieneRuta) {
      return _imagenPredeterminada(context);
    }

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

class CachedProfileAvatar extends StatefulWidget {
  final String ruta;
  final double radius;

  const CachedProfileAvatar({
    super.key,
    required this.ruta,
    this.radius = 42,
  });

  @override
  State<CachedProfileAvatar> createState() =>
      _CachedProfileAvatarState();
}

class _CachedProfileAvatarState extends State<CachedProfileAvatar> {
  final StorageService _storage = StorageService();

  Future<File>? _imagenFuture;

  bool get _tieneRuta => widget.ruta.trim().isNotEmpty;

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
    final ruta = widget.ruta.trim();

    if (ruta.startsWith('http://') ||
        ruta.startsWith('https://')) {
      return _storage.obtenerArchivoDesdeUrl(
        ruta,
        identificador: ruta,
      );
    }

    return _storage.obtenerArchivoImagen(ruta);
  }

  void _cargarImagen() {
    _imagenFuture = _tieneRuta ? _obtenerImagen() : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_tieneRuta) {
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
