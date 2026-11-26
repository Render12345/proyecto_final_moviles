import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../components/cached_storage_image.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class EditAccountScreen extends ConsumerStatefulWidget {
  final UserModel userData;

  const EditAccountScreen({
    super.key,
    required this.userData,
  });

  @override
  ConsumerState<EditAccountScreen> createState() =>
      _EditAccountScreenState();
}

class _EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  late final TextEditingController _nombreCtrl;

  bool get _puedeEditarFoto => widget.userData.provider == 'password';

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.userData.nombre,
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _mostrarMensaje(
    String mensaje, {
    bool error = false,
  }) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _guardarNombre() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      await _mostrarMensaje(
        'El nombre no puede estar vacío.',
        error: true,
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).actualizarPerfil(
            nombre: _nombreCtrl.text.trim(),
          );

      ref.invalidate(currentUserDataProvider);

      await _mostrarMensaje(
        'Nombre actualizado correctamente.',
      );
    } catch (e) {
      await _mostrarMensaje(
        'No se pudo actualizar: $e',
        error: true,
      );
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

      final nuevaRuta = await storage.subirImagen(
        imagen: imagen,
      );

      await authService.actualizarPerfil(
        nombre: _nombreCtrl.text.trim(),
        fotoUrl: nuevaRuta,
      );

      if (rutaAnterior.startsWith('perfiles/') &&
          rutaAnterior != nuevaRuta) {
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
      builder: (_) => _VincularCorreoDialog(
        correoInicial: widget.userData.email,
      ),
    );

    if (datos == null || !mounted) return;

    try {
      await ref.read(authServiceProvider).vincularCorreoPassword(
            email: datos['email']!,
            password: datos['password']!,
          );

      if (!mounted) return;

      ref.invalidate(firebaseAuthStateProvider);

      await _mostrarMensaje(
        'Correo y contraseña vinculados.',
      );
    } catch (e) {
      await _mostrarMensaje(
        'No se pudo vincular el correo: $e',
        error: true,
      );
    }
  }

  Widget _fotoPerfil(String foto) {
    if (foto.isEmpty) {
      return const CircleAvatar(
        radius: 48,
        child: Icon(Icons.person, size: 48),
      );
    }

    if (foto.startsWith('perfiles/')) {
      return ClipOval(
        child: SizedBox(
          width: 96,
          height: 96,
          child: CachedStorageImage(
            ruta: foto,
            tipo: CachedImageType.perfil,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorWidget: const ColoredBox(
              color: Colors.black12,
              child: Icon(
                Icons.broken_image_outlined,
                size: 36,
              ),
            ),
          ),
        ),
      );
    }

    if (foto.startsWith('http://') || foto.startsWith('https://')) {
      return CircleAvatar(
        key: ValueKey(foto),
        radius: 48,
        backgroundImage: NetworkImage(foto),
      );
    }

    return const CircleAvatar(
      radius: 48,
      child: Icon(Icons.person, size: 48),
    );
  }

  Widget _construirPerfil(UserModel userData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fotoPerfil(userData.fotoUrl),
            const SizedBox(height: 12),
            Text(
              userData.nombre,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              userData.email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
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
    );
  }

  Widget _construirInformacionPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información personal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nombreCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _guardarNombre,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar nombre'),
          ),
        ),
      ],
    );
  }

  Widget _construirProveedores({
    required bool tieneGoogle,
    required bool tieneGitHub,
    required bool tienePassword,
    required String email,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métodos de inicio de sesión',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _ProveedorTile(
          nombre: 'Google',
          vinculado: tieneGoogle,
          icono: Icons.g_mobiledata,
          onVincular: () => _vincularProveedor(
            () async {
              await ref.read(authServiceProvider).vincularGoogle();
            },
            'Google vinculado correctamente.',
          ),
        ),
        _ProveedorTile(
          nombre: 'GitHub',
          vinculado: tieneGitHub,
          icono: Icons.code,
          onVincular: () => _vincularProveedor(
            () async {
              await ref.read(authServiceProvider).vincularGitHub();
            },
            'GitHub vinculado correctamente.',
          ),
        ),
        _ProveedorTile(
          nombre: 'Correo y contraseña',
          vinculado: tienePassword,
          icono: Icons.email_outlined,
          onVincular: _vincularCorreo,
        ),
        const SizedBox(height: 8),
        Text(
          'Correo de la cuenta: $email',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
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
      appBar: AppBar(
        title: const Text(
          'Editar cuenta',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final esPantallaAmplia = ancho >= 850;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: esPantallaAmplia
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 280,
                              child: _construirPerfil(userData),
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _construirInformacionPersonal(),
                                  const SizedBox(height: 32),
                                  _construirProveedores(
                                    tieneGoogle: tieneGoogle,
                                    tieneGitHub: tieneGitHub,
                                    tienePassword: tienePassword,
                                    email: userData.email,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _construirPerfil(userData),
                            const SizedBox(height: 28),
                            _construirInformacionPersonal(),
                            const SizedBox(height: 28),
                            _construirProveedores(
                              tieneGoogle: tieneGoogle,
                              tieneGitHub: tieneGitHub,
                              tienePassword: tienePassword,
                              email: userData.email,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// DIÁLOGO PARA VINCULAR CORREO
// ============================================================

class _VincularCorreoDialog extends StatefulWidget {
  final String correoInicial;

  const _VincularCorreoDialog({
    required this.correoInicial,
  });

  @override
  State<_VincularCorreoDialog> createState() =>
      _VincularCorreoDialogState();
}

class _VincularCorreoDialogState extends State<_VincularCorreoDialog> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _passwordCtrl =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(
      text: widget.correoInicial,
    );
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
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
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

// ============================================================
// MÉTODOS DE INICIO DE SESIÓN
// ============================================================

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
        subtitle: Text(
          vinculado ? 'Vinculado' : 'No vinculado',
        ),
        trailing: vinculado
            ? const Icon(
                Icons.check_circle,
                color: Colors.green,
              )
            : TextButton(
                onPressed: onVincular,
                child: const Text('Vincular'),
              ),
      ),
    );
  }
}
