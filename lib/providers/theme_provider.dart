import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _cambioManual = false;

  @override
  ThemeMode build() {
    _cargarTema();
    return ThemeMode.light;
  }

  Future<void> _cargarTema() async {
    final preferencias = await SharedPreferences.getInstance();

    // Si el usuario ya eligió un tema, respetamos su elección.
    if (_cambioManual) return;

    final temaGuardado = preferencias.getString('theme_mode');

    if (temaGuardado == 'dark') {
      state = ThemeMode.dark;
    } else if (temaGuardado == 'light') {
      state = ThemeMode.light;
    }
  }

  Future<void> cambiarTema(ThemeMode nuevoTema) async {
    _cambioManual = true;
    state = nuevoTema;

    final preferencias = await SharedPreferences.getInstance();

    await preferencias.setString(
      'theme_mode',
      nuevoTema == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
