class ReportModel {
  final String id;
  final String userId;
  final String userEmail;
  final String deviceId;
  final String salonId;
  final String salonNombre;
  final String tipo;
  final String descripcion;
  final String estado;
  final int fechaCreacion;
  final String? atendidoPor;
  final int? fechaAtencion;

  const ReportModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.deviceId,
    required this.salonId,
    required this.salonNombre,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    required this.fechaCreacion,
    this.atendidoPor,
    this.fechaAtencion,
  });

  factory ReportModel.fromMap(
    String id,
    Map<dynamic, dynamic> map,
  ) {
    return ReportModel(
      id: id,
      userId: (map['user_id'] ?? '').toString(),
      userEmail: (map['user_email'] ?? '').toString(),
      deviceId: (map['device_id'] ?? '').toString(),
      salonId: (map['salon_id'] ?? '').toString(),
      salonNombre: (map['salon_nombre'] ?? '').toString(),
      tipo: (map['tipo'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      estado: (map['estado'] ?? 'pending').toString(),
      fechaCreacion:
          (map['fecha_creacion'] as num?)?.toInt() ?? 0,
      atendidoPor: map['atendido_por']?.toString(),
      fechaAtencion:
          (map['fecha_atencion'] as num?)?.toInt(),
    );
  }

  String get tipoDescripcion {
    switch (tipo) {
      case 'no_apaga':
        return 'El aire acondicionado no apaga';
      case 'no_enciende':
        return 'El aire acondicionado no enciende';
      default:
        return 'Falla no identificada';
    }
  }

  bool get estaPendiente => estado == 'pending';
}
