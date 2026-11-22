
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../screens/edit_account_screen.dart';
import '../screens/admin_users_screen.dart';
import '../services/storage_service.dart';

class AppEndDrawer extends ConsumerWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const AppEndDrawer({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  Future<String?> _obtenerFoto() async {
    final foto = userData.fotoUrl;

    if (foto.isEmpty) return null;

    if (foto.startsWith('http://') || foto.startsWith('https://')) {
      return foto;
    }

    if (foto.startsWith('perfiles/')) {
      return StorageService().obtenerUrlImagen(foto);
    }

    return null;
  }

  void _mostrarInformacionCorreo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de la cuenta'),
        content: const Text(
          'La cuenta se encuentra vinculada con otro método de sesión, '
          'favor de acceder a la app y vincular la sesión y añadir a su '
          'cuenta correspondiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esAdministrador = userData.role == 'admin';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 28,
              ),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                children: [
                  FutureBuilder<String?>(
                    future: _obtenerFoto(),
                    builder: (context, snapshot) {
                      final foto = snapshot.data;

                      return CircleAvatar(
                        radius: 42,
                        backgroundImage:
                            foto != null ? NetworkImage(foto) : null,
                        child: foto == null
                            ? const Icon(Icons.person, size: 42)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userData.nombre.isEmpty
                        ? 'Usuario'
                        : userData.nombre,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _mostrarInformacionCorreo(context),
                    child: Text(
                      userData.email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(
                      esAdministrador
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      size: 18,
                    ),
                    label: Text(
                      esAdministrador ? 'Administrador' : 'Usuario',
                    ),
                  ),
                ],
              ),
            ),

            if (esAdministrador)
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Administrar usuarios'),
                subtitle: const Text('Gestionar cuentas y permisos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminUsersScreen(
                        userData: userData,
                        onLogout: onLogout,
                      ),
                    ),
                  );
                },
              ),

            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Editar cuenta'),
              subtitle: const Text('Perfil y métodos de acceso'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditAccountScreen(
                      userData: userData,
                    ),
                  ),
                );
              },
            ),

            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await onLogout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
