
class ScheduleModel {
  final String scheduleId;
  final String deviceId;
  final String userId;
  final String? userEmail;
  final DateTime startAt;
  final int durationHours;
  final DateTime endAt;
  final String status;
  final DateTime? createdAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  const ScheduleModel({
    required this.scheduleId,
    required this.deviceId,
    required this.userId,
    this.userEmail,
    required this.startAt,
    required this.durationHours,
    required this.endAt,
    required this.status,
    this.createdAt,
    this.cancelledAt,
    this.cancelledBy,
  });

  factory ScheduleModel.fromMap(Map<dynamic, dynamic> map) {
    DateTime parseDate(dynamic value, String field) {
      if (value is! String || value.isEmpty) {
        throw FormatException('La fecha "$field" no es válida.');
      }

      final parsed = DateTime.tryParse(value);

      if (parsed == null) {
        throw FormatException('No se pudo interpretar "$field".');
      }

      return parsed;
    }

    final scheduleId =
        (map['scheduleId'] ?? map['schedule_id'])?.toString();

    final deviceId =
        (map['device_id'] ?? map['deviceId'])?.toString();

    final userId = map['user_id']?.toString();

    final duration = map['duration_hours'];

    if (scheduleId == null || scheduleId.isEmpty) {
      throw const FormatException('Falta el identificador de la programación.');
    }

    if (deviceId == null || deviceId.isEmpty) {
      throw const FormatException('Falta el identificador del dispositivo.');
    }

    if (userId == null || userId.isEmpty) {
      throw const FormatException('Falta el identificador del usuario.');
    }

    if (duration is! num) {
      throw const FormatException('La duración de la programación no es válida.');
    }

    return ScheduleModel(
      scheduleId: scheduleId,
      deviceId: deviceId,
      userId: userId,
      userEmail: map['user_email']?.toString(),
      startAt: parseDate(map['start_at'], 'start_at'),
      durationHours: duration.toInt(),
      endAt: parseDate(map['end_at'], 'end_at'),
      status: map['status']?.toString() ?? 'unknown',
      createdAt: map['created_at'] == null
          ? null
          : parseDate(map['created_at'], 'created_at'),
      cancelledAt: map['cancelled_at'] == null
          ? null
          : parseDate(map['cancelled_at'], 'cancelled_at'),
      cancelledBy: map['cancelled_by']?.toString(),
    );
  }

  bool get estaPendiente => status == 'scheduled';

  bool get estaCancelada => status == 'cancelled';

  bool get estaCompletada => status == 'completed';

  factory ScheduleModel.fromResponse(Map<dynamic, dynamic> map) {
    return ScheduleModel.fromMap(map);
  }
}
