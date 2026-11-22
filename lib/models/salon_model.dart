class SalonModel {
  final String id;
  final String nombre;
  final String descripcion;
  final String edificio;
  final String? fotoUrl;
  final bool activo;
  final String creadoPor;
  final int fechaCreacion;

  const SalonModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.edificio = '',
    this.fotoUrl,
    this.activo = true,
    required this.creadoPor,
    required this.fechaCreacion,
  });

  factory SalonModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final foto = map['foto_url']?.toString();

    return SalonModel(
      id: id,
      nombre: (map['nombre'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      edificio: (map['edificio'] ?? '').toString(),
      fotoUrl: foto == null || foto.isEmpty ? null : foto,
      activo: map['activo'] == true,
      creadoPor: (map['creado_por'] ?? '').toString(),
      fechaCreacion: (map['fecha_creacion'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'edificio': edificio,
      'foto_url': fotoUrl,
      'activo': activo,
      'creado_por': creadoPor,
      'fecha_creacion': fechaCreacion,
    };
  }

  SalonModel copyWith({
    String? nombre,
    String? descripcion,
    String? edificio,
    String? fotoUrl,
    bool quitarFoto = false,
    bool? activo,
  }) {
    return SalonModel(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      edificio: edificio ?? this.edificio,
      fotoUrl: quitarFoto ? null : (fotoUrl ?? this.fotoUrl),
      activo: activo ?? this.activo,
      creadoPor: creadoPor,
      fechaCreacion: fechaCreacion,
    );
  }
}
