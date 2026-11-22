
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/salon_model.dart';
import '../services/salon_service.dart';
import 'auth_provider.dart';

final salonServiceProvider = Provider<SalonService>((ref) {
  return SalonService();
});

final salonesProvider = StreamProvider<List<SalonModel>>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  final authUser = authState.asData?.value;

  // Si no hay sesión, no mantener un listener de Firebase.
  if (authUser == null) {
    return Stream.value([]);
  }

  return ref.watch(salonServiceProvider).obtenerSalones();
});
