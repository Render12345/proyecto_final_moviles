import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_model.dart';
import '../services/schedule_service.dart';

// ============================================================
// SERVICIO DE PROGRAMACIONES
// ============================================================

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

// ============================================================
// TODAS LAS PROGRAMACIONES DEL USUARIO
// ============================================================

final schedulesProvider = FutureProvider<List<ScheduleModel>>((ref) {
  return ref
      .watch(scheduleServiceProvider)
      .obtenerProgramaciones();
});

// ============================================================
// PROGRAMACIONES DE UN DISPOSITIVO
// ============================================================

final schedulesForDeviceProvider =
    Provider.family<AsyncValue<List<ScheduleModel>>, String>(
  (ref, deviceId) {
    final programacionesAsync = ref.watch(schedulesProvider);

    return programacionesAsync.whenData(
      (programaciones) => programaciones
          .where((programacion) => programacion.deviceId == deviceId)
          .toList(),
    );
  },
);
