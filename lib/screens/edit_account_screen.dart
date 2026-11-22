import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class EditAccountScreen extends ConsumerStatefulWidget {
  final UserModel userData;

  const EditAccountScreen({super.key, required this.userData});

  @override
  ConsumerState<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  late final TextEditingController _nombreCtrl;
  Future<String>? _urlFotoFuture;
  String? _rutaFotoActual;

  bool get _puedeEditarFoto => widget.userData.provider == 'password';

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.userData.nombre);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _mostrarMensaje(String mensaje, {bool error = false}) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _guardarNombre() async {
    try {
      await ref
          .read(authServiceProvider)
          .actualizarPerfil(nombre: _nombreCtrl.text);

      ref.invalidate(currentUserDataProvider);

      await _mostrarMensaje('Nombre actualizado correctamente.');
    } catch (e) {
      await _mostrarMensaje('No se pudo actualizar: $e', error: true);
    }
  }

  Future<void> _seleccionarFoto() async {
    if (!_puedeEditarFoto) return;

    try {
      final imagen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (imagen == null || !mounted) return;

      final storage = ref.read(storageServiceProvider);
      final authService = ref.read(authServiceProvider);

      final rutaAnterior =
          ref.read(currentUserDataProvider).value?.fotoUrl ??
          widget.userData.fotoUrl;
      final nuevaRuta = await storage.subirImagen(imagen: imagen);

      await authService.actualizarPerfil(
        nombre: _nombreCtrl.text.trim(),
        fotoUrl: nuevaRuta,
      );

      if (rutaAnterior.startsWith('perfiles/')) {
        try {
          await storage.eliminarImagen(rutaAnterior);
        } catch (_) {
          // La nueva fotografía ya quedó guardada.
        }
      }

      ref.invalidate(currentUserDataProvider);

      await _mostrarMensaje('Fotografía actualizada.');
    } catch (e) {
      await _mostrarMensaje(
        'No se pudo cambiar la fotografía: $e',
        error: true,
      );
    }
  }

  Future<void> _vincularProveedor(
    Future<void> Function() accion,
    String mensaje,
  ) async {
    try {
      await accion();

      if (!mounted) return;

      // Actualizar el estado de autenticación y los proveedores.
      ref.invalidate(firebaseAuthStateProvider);

      await _mostrarMensaje(mensaje);
    } catch (e) {
      await _mostrarMensaje(
        'No se pudo completar la vinculación: $e',
        error: true,
      );
    }
  }

  Future<void> _vincularCorreo() async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) =>
          _VincularCorreoDialog(correoInicial: widget.userData.email),
    );

    if (datos == null || !mounted) return;

    try {
      await ref
          .read(authServiceProvider)
          .vincularCorreoPassword(
            email: datos['email']!,
            password: datos['password']!,
          );

      if (!mounted) return;

      ref.invalidate(firebaseAuthStateProvider);

      await _mostrarMensaje('Correo y contraseña vinculados.');
    } catch (e) {
      await _mostrarMensaje('No se pudo vincular el correo: $e', error: true);
    }
  }

  Widget _fotoPerfil(String foto) {
    if (foto.isEmpty) {
      return const CircleAvatar(
        radius: 48,
        child: Icon(Icons.person, size: 48),
      );
    }

    if (foto.startsWith('http://') || foto.startsWith('https://')) {
      return CircleAvatar(
        key: ValueKey(foto),
        radius: 48,
        backgroundImage: NetworkImage(foto),
      );
    }

    if (foto.startsWith('perfiles/')) {
      if (_rutaFotoActual != foto) {
        _rutaFotoActual = foto;
        _urlFotoFuture = ref
            .read(storageServiceProvider)
            .obtenerUrlImagen(foto);
      }

      return FutureBuilder<String>(
        key: ValueKey(foto),
        future: _urlFotoFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(snapshot.data!),
            );
          }

          if (snapshot.hasError) {
            return const CircleAvatar(
              radius: 48,
              child: Icon(Icons.broken_image_outlined),
            );
          }

          return const CircleAvatar(
            radius: 48,
            child: CircularProgressIndicator(),
          );
        },
      );
    }

    return const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48));
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(currentUserDataProvider);
    final userData = userDataAsync.value ?? widget.userData;

    if (userDataAsync.hasValue &&
        userDataAsync.value != null &&
        _nombreCtrl.text == widget.userData.nombre) {
      _nombreCtrl.text = userData.nombre;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;

    final proveedores =
        firebaseUser?.providerData.map((p) => p.providerId).toSet() ??
        <String>{};

    final tieneGoogle = proveedores.contains('google.com');
    final tieneGitHub = proveedores.contains('github.com');
    final tienePassword = proveedores.contains('password');

    return Scaffold(
      appBar: AppBar(title: const Text('Editar cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                _fotoPerfil(userData.fotoUrl),
                const SizedBox(height: 12),
                if (_puedeEditarFoto)
                  OutlinedButton.icon(
                    onPressed: _seleccionarFoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Cambiar fotografía'),
                  )
                else
                  const Text(
                    'Fotografía administrada por tu proveedor de acceso',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Información personal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _guardarNombre,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar nombre'),
          ),
          const SizedBox(height: 28),
          Text(
            'Métodos de inicio de sesión',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _ProveedorTile(
            nombre: 'Google',
            vinculado: tieneGoogle,
            icono: Icons.g_mobiledata,
            onVincular: () => _vincularProveedor(() async {
              await ref.read(authServiceProvider).vincularGoogle();
            }, 'Google vinculado correctamente.'),
          ),
          _ProveedorTile(
            nombre: 'GitHub',
            vinculado: tieneGitHub,
            icono: Icons.code,
            onVincular: () => _vincularProveedor(() async {
              await ref.read(authServiceProvider).vincularGitHub();
            }, 'GitHub vinculado correctamente.'),
          ),
          _ProveedorTile(
            nombre: 'Correo y contraseña',
            vinculado: tienePassword,
            icono: Icons.email_outlined,
            onVincular: _vincularCorreo,
          ),
          const SizedBox(height: 16),
          Text(
            'Correo de la cuenta: ${userData.email}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _VincularCorreoDialog extends StatefulWidget {
  final String correoInicial;

  const _VincularCorreoDialog({required this.correoInicial});

  @override
  State<_VincularCorreoDialog> createState() => _VincularCorreoDialogState();
}

class _VincularCorreoDialogState extends State<_VincularCorreoDialog> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.correoInicial);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vincular correo y contraseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                helperText: 'Mínimo 6 caracteres',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'email': _emailCtrl.text.trim(),
              'password': _passwordCtrl.text,
            });
          },
          child: const Text('Vincular'),
        ),
      ],
    );
  }
}

class _ProveedorTile extends StatelessWidget {
  final String nombre;
  final bool vinculado;
  final IconData icono;
  final VoidCallback onVincular;

  const _ProveedorTile({
    required this.nombre,
    required this.vinculado,
    required this.icono,
    required this.onVincular,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icono),
        title: Text(nombre),
        subtitle: Text(vinculado ? 'Vinculado' : 'No vinculado'),
        trailing: vinculado
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(onPressed: onVincular, child: const Text('Vincular')),
      ),
    );
  }
}
