import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTypography {
  roboto,
  poppins,
  lato,
}

extension AppTypographyExtension on AppTypography {
  String get nombre {
    switch (this) {
      case AppTypography.roboto:
        return 'Roboto';
      case AppTypography.poppins:
        return 'Poppins';
      case AppTypography.lato:
        return 'Lato';
    }
  }

  String get fontFamily {
    switch (this) {
      case AppTypography.roboto:
        return 'Roboto';
      case AppTypography.poppins:
        return 'Poppins';
      case AppTypography.lato:
        return 'Lato';
    }
  }
}

class TypographyNotifier extends Notifier<AppTypography> {
  bool _cambioManual = false;

  @override
  AppTypography build() {
    _cargarTipografia();
    return AppTypography.roboto;
  }

  Future<void> _cargarTipografia() async {
    final preferencias = await SharedPreferences.getInstance();

    if (_cambioManual) return;

    final guardada = preferencias.getString('app_typography');

    final tipografia = AppTypography.values.where(
      (opcion) => opcion.name == guardada,
    );

    if (tipografia.isNotEmpty) {
      state = tipografia.first;
    }
  }

  Future<void> cambiarTipografia(AppTypography nuevaTipografia) async {
    _cambioManual = true;
    state = nuevaTipografia;

    final preferencias = await SharedPreferences.getInstance();

    await preferencias.setString(
      'app_typography',
      nuevaTipografia.name,
    );
  }
}

final typographyProvider =
    NotifierProvider<TypographyNotifier, AppTypography>(
  TypographyNotifier.new,
);
