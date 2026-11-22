
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/salon_model.dart';
import '../providers/salon_provider.dart';
import '../services/storage_service.dart';

class SalonFormScreen extends ConsumerStatefulWidget {
  final SalonModel? salon;

  const SalonFormScreen({
    super.key,
    this.salon,
  });

  @override
  ConsumerState<SalonFormScreen> createState() =>
      _SalonFormScreenState();
}

class _SalonFormScreenState extends ConsumerState<SalonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();

  late final TextEditingController _nombreController;
  late final TextEditingController _edificioController;
  late final TextEditingController _descripcionController;

  XFile? _fotoSeleccionada;
  bool _quitarFoto = false;
  bool _guardando = false;

  Future<String>? _fotoExistenteFuture;

  bool get _esEdicion => widget.salon != null;

  String? get _fotoActual => widget.salon?.fotoUrl;

  @override
  void initState() {
    super.initState();

    _nombreController = TextEditingController(
      text: widget.salon?.nombre ?? '',
    );

    _edificioController = TextEditingController(
      text: widget.salon?.edificio ?? '',
    );

    _descripcionController = TextEditingController(
      text: widget.salon?.descripcion ?? '',
    );

    if (_fotoActual != null && _fotoActual!.isNotEmpty) {
      _fotoExistenteFuture =
          _storageService.obtenerUrlFotoSalon(_fotoActual!);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edificioController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // ============================================================
  // SELECCIONAR FOTOGRAFÍA
  // ============================================================

  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final imagen = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (imagen == null || !mounted) return;

      setState(() {
        _fotoSeleccionada = imagen;
        _quitarFoto = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar la fotografía: $e'),
        ),
      );
    }
  }

  Future<void> _mostrarOpcionesFoto() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar fotografía'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFoto(ImageSource.gallery);
                },
              ),
              if (_fotoSeleccionada != null ||
                  (_fotoActual != null &&
                      _fotoActual!.isNotEmpty &&
                      !_quitarFoto))
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Quitar fotografía',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    setState(() {
                      _fotoSeleccionada = null;
                      _quitarFoto = true;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // VISTA PREVIA
  // ============================================================

  Widget _construirVistaPrevia() {
    if (_fotoSeleccionada != null) {
      return Image.file(
        File(_fotoSeleccionada!.path),
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
      );
    }

    if (_quitarFoto ||
        _fotoActual == null ||
        _fotoActual!.isEmpty) {
      return _imagenPredeterminada();
    }

    return FutureBuilder<String>(
      future: _fotoExistenteFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 190,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _imagenPredeterminada();
        }

        return Image.network(
          snapshot.data!,
          width: double.infinity,
          height: 190,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _imagenPredeterminada();
          },
        );
      },
    );
  }

  Widget _imagenPredeterminada() {
    return Container(
      width: double.infinity,
      height: 190,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 65,
          ),
          SizedBox(height: 8),
          Text('Sin fotografía'),
        ],
      ),
    );
  }

  // ============================================================
  // GUARDAR SALÓN
  // ============================================================

  Future<void> _guardarSalon() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    String? nuevaRuta;
    final rutaAnterior = _fotoActual;

    try {
      final servicio = ref.read(salonServiceProvider);

      if (_esEdicion) {
        if (_fotoSeleccionada != null) {
          nuevaRuta = await _storageService.subirFotoSalon(
            salonId: widget.salon!.id,
            imagen: _fotoSeleccionada!,
          );
        }

        await servicio.actualizarSalon(
          salonId: widget.salon!.id,
          nombre: _nombreController.text,
          edificio: _edificioController.text,
          descripcion: _descripcionController.text,
          fotoUrl: nuevaRuta,
          quitarFoto: _quitarFoto,
        );
      } else {
        final salonId = await servicio.registrarSalon(
          nombre: _nombreController.text,
          edificio: _edificioController.text,
          descripcion: _descripcionController.text,
        );

        if (_fotoSeleccionada != null) {
          try {
            nuevaRuta = await _storageService.subirFotoSalon(
              salonId: salonId,
              imagen: _fotoSeleccionada!,
            );

            await servicio.actualizarSalon(
              salonId: salonId,
              nombre: _nombreController.text,
              edificio: _edificioController.text,
              descripcion: _descripcionController.text,
              fotoUrl: nuevaRuta,
            );
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'El salón se registró, pero no se pudo guardar su fotografía: $e',
                ),
                backgroundColor: Colors.orange,
              ),
            );

            Navigator.pop(context);
            return;
          }
        }
      }

      // Eliminar la fotografía anterior solamente después
      // de confirmar que Firebase guardó la nueva información.
      if (rutaAnterior != null &&
          rutaAnterior.isNotEmpty &&
          (nuevaRuta != null || _quitarFoto)) {
        try {
          await _storageService.eliminarFotoSalon(rutaAnterior);
        } catch (e) {
          debugPrint('No se pudo eliminar la fotografía anterior: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'Salón actualizado correctamente.'
                : 'Salón registrado correctamente.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      // Si la subida se realizó, pero falló la actualización
      // de Firebase, intentamos retirar el archivo nuevo.
      if (nuevaRuta != null) {
        try {
          await _storageService.eliminarFotoSalon(nuevaRuta);
        } catch (error) {
          debugPrint('No se pudo limpiar la fotografía nueva: $error');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esEdicion ? 'Editar salón' : 'Nuevo salón',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fotografía del salón',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Opcional. Puedes agregarla ahora o después.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _construirVistaPrevia(),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _guardando
                      ? null
                      : _mostrarOpcionesFoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Agregar o cambiar fotografía'),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Información del salón',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del salón',
                  hintText: 'Ej. Aula A-101',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre del salón.';
                  }

                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _edificioController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Edificio',
                  hintText: 'Ej. A',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _descripcionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ubicación o información adicional del salón',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _guardarSalon,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _guardando
                        ? 'Guardando...'
                        : _esEdicion
                            ? 'Guardar cambios'
                            : 'Registrar salón',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
