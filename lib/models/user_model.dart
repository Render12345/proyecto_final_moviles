class UserModel {
  final String uid;
  final String nombre;
  final String email;
  final String fotoUrl;
  final String provider;
  final String role; // 'admin' o 'user'
  final bool autorizado;
  final String planSuscripcion;
  final Map<String, bool> dispositivosVinculados;

  UserModel({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.fotoUrl,
    required this.provider,
    required this.role,
    required this.autorizado,
    required this.planSuscripcion,
    required this.dispositivosVinculados,
  });

  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    final rawVinculados =
        map['dispositivos_vinculados'] as Map<dynamic, dynamic>? ?? {};
    final vinculados = rawVinculados.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );

    return UserModel(
      uid: uid,
      nombre: map['nombre']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fotoUrl: map['foto_url']?.toString() ?? '',
      provider: map['provider']?.toString() ?? 'password',
      role: map['role']?.toString() ?? 'user',
      autorizado: map['autorizado'] == true,
      planSuscripcion: map['plan_suscripcion']?.toString() ?? 'ninguno',
      dispositivosVinculados: vinculados,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'foto_url': fotoUrl,
      'provider': provider,
      'role': role,
      'autorizado': autorizado,
      'plan_suscripcion': planSuscripcion,
      'dispositivos_vinculados': dispositivosVinculados,
    };
  }
}