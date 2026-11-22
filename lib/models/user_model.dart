class UserModel {
  final String uid;
  final String nombre;
  final String email;
  final String fotoUrl;
  final String provider;
  final String role;
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
    // Nuevo formato: información editable dentro de profile.
    final rawProfile = map['profile'];
    final profile = rawProfile is Map ? rawProfile : <dynamic, dynamic>{};

    // Compatibilidad temporal con los registros anteriores.
    final nombre = profile['nombre'] ?? map['nombre'];
    final fotoUrl = profile['foto_url'] ?? map['foto_url'];

    final rawVinculados = map['dispositivos_vinculados'];
    final vinculadosMap = rawVinculados is Map
        ? rawVinculados
        : <dynamic, dynamic>{};

    final vinculados = vinculadosMap.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );

    return UserModel(
      uid: uid,
      nombre: nombre?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fotoUrl: fotoUrl?.toString() ?? '',
      provider: map['provider']?.toString() ?? 'password',
      role: map['role']?.toString() ?? 'user',
      autorizado: map['autorizado'] == true,
      planSuscripcion: map['plan_suscripcion']?.toString() ?? 'ninguno',
      dispositivosVinculados: vinculados,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profile': {
        'nombre': nombre,
        'foto_url': fotoUrl,
      },
      'email': email,
      'provider': provider,
      'role': role,
      'autorizado': autorizado,
      'plan_suscripcion': planSuscripcion,
      'dispositivos_vinculados': dispositivosVinculados,
    };
  }
}
