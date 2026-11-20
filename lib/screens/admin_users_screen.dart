import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/email_auth.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  void _abrirFormularioUsuario(
    BuildContext context,
    WidgetRef ref, {
    UserModel? usuarioEditar,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _FormularioUsuarioDialog(usuarioEditar: usuarioEditar),
    );
  }

  void _mostrarError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              try {
                await authService.cerrarSesion();
              } catch (error) {
                _mostrarError(context, error);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioUsuario(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error al cargar usuarios: $error')),
        data: (usuarios) {
          if (usuarios.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              bottom: 88,
              top: 8,
              left: 12,
              right: 12,
            ),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    usuario.nombre.isEmpty ? 'Sin nombre' : usuario.nombre,
                  ),
                  subtitle: Text(
                    '${usuario.email}\n'
                    'Tarjeta ficticia: ${usuario.cardNumber.isEmpty ? "Sin asignar" : usuario.cardNumber}\n'
                    'Acceso: ${usuario.autorizado ? "Activo" : "Pendiente"}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: usuario.autorizado,
                        onChanged: (autorizado) async {
                          try {
                            await authService.adminActualizarUsuario(
                              uid: usuario.uid,
                              nombre: usuario.nombre,
                              email: usuario.email,
                              autorizado: autorizado,
                            );
                          } catch (error) {
                            if (context.mounted) {
                              _mostrarError(context, error);
                            }
                          }
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _abrirFormularioUsuario(
                              context,
                              ref,
                              usuarioEditar: usuario,
                            );
                          } else if (action == 'delete') {
                            _confirmarEliminacion(context, authService, usuario);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminacion(
    BuildContext context,
    AuthService authService,
    UserModel usuario,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar la cuenta de ${usuario.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await authService.adminEliminarUsuario(usuario.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado.')),
        );
      }
    } catch (error) {
      _mostrarError(context, error);
    }
  }
}

class _FormularioUsuarioDialog extends ConsumerStatefulWidget {
  const _FormularioUsuarioDialog({this.usuarioEditar});

  final UserModel? usuarioEditar;

  @override
  ConsumerState<_FormularioUsuarioDialog> createState() =>
      _FormularioUsuarioDialogState();
}

class _FormularioUsuarioDialogState
    extends ConsumerState<_FormularioUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late bool _autorizado;
  bool _guardando = false;

  bool get _esEdicion => widget.usuarioEditar != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.usuarioEditar?.nombre ?? '',
    );
    _emailCtrl = TextEditingController(
      text: widget.usuarioEditar?.email ?? '',
    );
    _passCtrl = TextEditingController();
    _autorizado = widget.usuarioEditar?.autorizado ?? false;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final authService = ref.read(authServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? cardNumber;
      if (_esEdicion) {
        await authService.adminActualizarUsuario(
          uid: widget.usuarioEditar!.uid,
          nombre: _nombreCtrl.text,
          email: _emailCtrl.text,
          autorizado: _autorizado,
        );
      } else {
        cardNumber = await authService.adminCrearUsuario(
          nombre: _nombreCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
          autorizado: _autorizado,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'Usuario actualizado.'
                : 'Usuario creado. Tarjeta ficticia: $cardNumber. '
                    'Se envió el correo de verificación.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar usuario' : 'Dar de alta usuario'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre completo'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Ingresa un nombre.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                        ? null
                        : 'Ingresa un correo válido.';
                  },
                ),
                if (!_esEdicion) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña inicial (mín. 6)',
                    ),
                    validator: (value) => (value?.length ?? 0) >= 6
                        ? null
                        : 'La contraseña debe tener al menos 6 caracteres.',
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Autorizado para encender aires'),
                  value: _autorizado,
                  onChanged: (value) => setState(() => _autorizado = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(_esEdicion ? 'Guardar cambios' : 'Crear usuario'),
        ),
      ],
    );
  }
}
