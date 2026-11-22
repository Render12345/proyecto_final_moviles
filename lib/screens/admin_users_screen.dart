import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proyecto_final_moviles/models/user_model.dart';
import 'package:proyecto_final_moviles/providers/auth_provider.dart';
import 'package:proyecto_final_moviles/components/app_end_drawer.dart';

class AdminUsersScreen extends ConsumerWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const AdminUsersScreen({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  void _abrirFormularioUsuario(
    BuildContext context, {
    UserModel? usuarioEditar,
  }) {
    showDialog(
      context: context,
      builder: (_) => _FormularioUsuarioDialog(usuarioEditar: usuarioEditar),
    );
  }

  Future<void> _eliminarUsuario(
    BuildContext context,
    WidgetRef ref,
    UserModel usuario,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Deseas eliminar el registro de ${usuario.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await ref.read(authServiceProvider).adminEliminarUsuario(usuario.uid);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Opciones de cuenta',
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),

      endDrawer: AppEndDrawer(userData: userData, onLogout: onLogout),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioUsuario(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
      ),

      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar los usuarios.\n$err',
              textAlign: TextAlign.center,
            ),
          ),
        ),

        data: (usuarios) {
          if (usuarios.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No hay usuarios registrados'),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Text(
                'Administración',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${usuarios.length} usuarios registrados',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              ...usuarios.map((usuario) {
                final esAdmin = usuario.role == 'admin';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 23,
                            backgroundColor: esAdmin
                                ? Colors.indigo.withValues(alpha: 0.12)
                                : Colors.teal.withValues(alpha: 0.12),
                            child: Icon(
                              esAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: esAdmin ? Colors.indigo : Colors.teal,
                            ),
                          ),
                          title: Text(
                            usuario.nombre.isEmpty
                                ? 'Sin nombre'
                                : usuario.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  usuario.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Chip(
                                  label: Text(
                                    esAdmin ? 'Administrador' : 'Usuario',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Opciones',
                            onSelected: (accion) {
                              if (accion == 'editar') {
                                _abrirFormularioUsuario(
                                  context,
                                  usuarioEditar: usuario,
                                );
                              } else if (accion == 'eliminar') {
                                _eliminarUsuario(context, ref, usuario);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined),
                                    SizedBox(width: 10),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 20),

                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Permiso de encendido',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Autorizar el control de los aires',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: usuario.autorizado,
                              onChanged: (valor) async {
                                try {
                                  await authService.adminActualizarUsuario(
                                    uid: usuario.uid,
                                    nombre: usuario.nombre,
                                    role: usuario.role,
                                    autorizado: valor,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'No se pudo actualizar: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _FormularioUsuarioDialog extends ConsumerStatefulWidget {
  final UserModel? usuarioEditar;

  const _FormularioUsuarioDialog({this.usuarioEditar});

  @override
  ConsumerState<_FormularioUsuarioDialog> createState() =>
      _FormularioUsuarioDialogState();
}

class _FormularioUsuarioDialogState
    extends ConsumerState<_FormularioUsuarioDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;

  late String _rolSeleccionado;
  late bool _autorizado;

  bool _guardando = false;

  bool get _esEdicion => widget.usuarioEditar != null;

  @override
  void initState() {
    super.initState();

    _nombreCtrl = TextEditingController(
      text: widget.usuarioEditar?.nombre ?? '',
    );
    _emailCtrl = TextEditingController(text: widget.usuarioEditar?.email ?? '');
    _passCtrl = TextEditingController();

    _rolSeleccionado = widget.usuarioEditar?.role ?? 'user';
    _autorizado = widget.usuarioEditar?.autorizado ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarUsuario() async {
    if (_guardando) return;

    setState(() => _guardando = true);

    try {
      final authService = ref.read(authServiceProvider);

      if (_esEdicion) {
        await authService.adminActualizarUsuario(
          uid: widget.usuarioEditar!.uid,
          nombre: _nombreCtrl.text.trim(),
          role: _rolSeleccionado,
          autorizado: _autorizado,
        );
      } else {
        await authService.adminCrearUsuario(
          nombre: _nombreCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          role: _rolSeleccionado,
          autorizado: _autorizado,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esEdicion ? 'Usuario actualizado' : 'Usuario creado'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar usuario' : 'Nuevo usuario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              enabled: !_guardando,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            if (!_esEdicion) ...[
              TextField(
                controller: _emailCtrl,
                enabled: !_guardando,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                enabled: !_guardando,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña inicial',
                  helperText: 'Mínimo 6 caracteres',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            DropdownButtonFormField<String>(
              initialValue: _rolSeleccionado,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Rol en el sistema',
                prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('Usuario normal')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      if (valor != null) {
                        setState(() {
                          _rolSeleccionado = valor;
                        });
                      }
                    },
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Autorizado para encender aires'),
              value: _autorizado,
              onChanged: _guardando
                  ? null
                  : (valor) {
                      setState(() {
                        _autorizado = valor;
                      });
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardarUsuario,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_esEdicion ? 'Guardar' : 'Crear usuario'),
        ),
      ],
    );
  }
}
