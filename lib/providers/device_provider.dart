import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../services/device_service.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService();
});

final devicesProvider = FutureProvider<List<DeviceModel>>((ref) {
  return ref.watch(deviceServiceProvider).obtenerDispositivos();
});

final deviceDetailProvider =
    FutureProvider.family<DeviceModel, String>((ref, deviceId) {
  return ref
      .watch(deviceServiceProvider)
      .obtenerDispositivo(deviceId);
});
