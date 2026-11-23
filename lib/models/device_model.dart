
class DeviceModel {
  final String deviceId;
  final String macAddress;
  final String? salonId;
  final String? firmwareVersion;
  final String estado;
  final String fechaRegistro;
  final String qrData;

  final String? powerState;
  final DateTime? lastStateUpdate;

  const DeviceModel({
    required this.deviceId,
    required this.macAddress,
    this.salonId,
    this.firmwareVersion,
    required this.estado,
    required this.fechaRegistro,
    required this.qrData,
    this.powerState,
    this.lastStateUpdate,
  });

  factory DeviceModel.fromMap(Map<dynamic, dynamic> map) {
    final fechaEstado = map['last_state_update'];

    return DeviceModel(
      deviceId: (map['deviceId'] ?? '').toString(),
      macAddress: (map['mac_address'] ?? '').toString(),
      salonId: map['salon_id']?.toString(),
      firmwareVersion: map['firmware_version']?.toString(),
      estado: (map['estado'] ?? 'desconocido').toString(),
      fechaRegistro: (map['fecha_registro'] ?? '').toString(),
      qrData: (map['qr_data'] ?? '').toString(),
      powerState: map['power_state']?.toString().toLowerCase(),
      lastStateUpdate: fechaEstado == null
          ? null
          : DateTime.tryParse(fechaEstado.toString()),
    );
  }

  bool get tieneEstadoConfiable {
    if (powerState != 'on' && powerState != 'off') {
      return false;
    }

    final actualizacion = lastStateUpdate;

    if (actualizacion == null) return false;

    final diferencia = DateTime.now().difference(actualizacion);

    return !diferencia.isNegative &&
        diferencia.inMilliseconds <= 120000;
  }

  bool get estaEncendido =>
      tieneEstadoConfiable && powerState == 'on';

  bool get estaApagado =>
      tieneEstadoConfiable && powerState == 'off';
}
