import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  void _abrirFormularioUsuario(
    BuildContext context,
    WidgetRef ref, {
    UserModel? usuarioEditar,
  }) {
    showDialog(
      context: context,
      builder: (_) => _FormularioUsuarioDialog(usuarioEditar: usuarioEditar),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios (CRUD)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => authService.cerrarSesion(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioUsuario(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Usuario'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error al cargar usuarios: $err')),
        data: (usuarios) {
          if (usuarios.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88, top: 8, left: 12, right: 12),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final u = usuarios[index];
              final esAdmin = u.role == 'admin';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esAdmin ? Colors.indigo : Colors.teal,
                    child: Icon(
                      esAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(u.nombre.isEmpty ? 'Sin nombre' : u.nombre),
                  subtitle: Text(
                    '${u.email}\nRol: ${u.role.toUpperCase()} • Acceso: ${u.autorizado ? "Activo" : "Pendiente"}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: u.autorizado,
                        onChanged: (val) => authService.adminActualizarUsuario(
                          uid: u.uid,
                          nombre: u.nombre,
                          role: u.role,
                          autorizado: val,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _abrirFormularioUsuario(context, ref, usuarioEditar: u),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar usuario'),
                              content: Text(
                                '¿Seguro que deseas eliminar el registro de ${u.email}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sí, eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (confirmar == true) {
                            await authService.adminEliminarUsuario(u.uid);
                          }
                        },
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
    _nombreCtrl = TextEditingController(text: widget.usuarioEditar?.nombre ?? '');
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar Usuario' : 'Dar de Alta Usuario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            const SizedBox(height: 12),
            if (!_esEdicion) ...[
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña inicial (mín. 6)',
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: _rolSeleccionado,
              decoration: const InputDecoration(labelText: 'Rol en el sistema'),
              items: const [
                DropdownMenuItem(
                  value: 'user',
                  child: Text('Usuario Normal (Laboratorio)'),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text('Administrador'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _rolSeleccionado = val);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Autorizado para encender aires'),
              value: _autorizado,
              onChanged: (val) => setState(() => _autorizado = val),
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
          onPressed: _guardando
              ? null
              : () async {
                  setState(() => _guardando = true);
                  final authService = ref.read(authServiceProvider);
                  try {
                    if (_esEdicion) {
                      await authService.adminActualizarUsuario(
                        uid: widget.usuarioEditar!.uid,
                        nombre: _nombreCtrl.text,
                        role: _rolSeleccionado,
                        autorizado: _autorizado,
                      );
                    } else {
                      await authService.adminCrearUsuario(
                        nombre: _nombreCtrl.text,
                        email: _emailCtrl.text,
                        password: _passCtrl.text,
                        role: _rolSeleccionado,
                        autorizado: _autorizado,
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _esEdicion
                                ? 'Usuario actualizado'
                                : 'Usuario dado de alta',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _guardando = false);
                  }
                },
          child: _guardando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_esEdicion ? 'Guardar cambios' : 'Crear usuario'),
        ),
      ],
    );
  }
}