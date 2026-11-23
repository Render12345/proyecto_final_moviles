import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNotifier extends AsyncNotifier<bool> {
  static const String _claveOnboarding = 'onboarding_completado';

  @override
  Future<bool> build() async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getBool(_claveOnboarding) ?? false;
  }

  Future<void> completar() async {
    final preferencias = await SharedPreferences.getInstance();

    await preferencias.setBool(_claveOnboarding, true);

    state = const AsyncData(true);
  }

  Future<void> reiniciar() async {
    final preferencias = await SharedPreferences.getInstance();

    await preferencias.remove(_claveOnboarding);

    state = const AsyncData(false);
  }
}

final onboardingCompletedProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingPageNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void cambiarPagina(int pagina) {
    state = pagina;
  }
}

final onboardingPageProvider =
    NotifierProvider<OnboardingPageNotifier, int>(
  OnboardingPageNotifier.new,
);
