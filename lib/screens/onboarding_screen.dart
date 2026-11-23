import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;

  final List<_OnboardingItem> _paginas = const [
    _OnboardingItem(
      icono: Icons.ac_unit,
      titulo: 'Bienvenido a Control Aires ITC',
      descripcion:
          'Una herramienta para facilitar la administración y el '
          'control de los equipos de aire acondicionado del instituto.',
    ),
    _OnboardingItem(
      icono: Icons.meeting_room_outlined,
      titulo: 'Control inteligente de aulas',
      descripcion:
          'Consulta dispositivos, identifica equipos mediante códigos QR '
          'y administra las programaciones de los salones.',
    ),
    _OnboardingItem(
      icono: Icons.notifications_active_outlined,
      titulo: 'Mantente siempre informado',
      descripcion:
          'Recibe notificaciones, consulta el estado de tus dispositivos '
          'y comunica cualquier falla a los administradores.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    await ref.read(onboardingCompletedProvider.notifier).completar();
  }

  void _siguiente() {
    final paginaActual = ref.read(onboardingPageProvider);

    if (paginaActual == _paginas.length - 1) {
      _finalizar();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginaActual = ref.watch(onboardingPageProvider);
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finalizar,
                  child: const Text('Omitir'),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _paginas.length,
                  onPageChanged: (pagina) {
                    ref
                        .read(onboardingPageProvider.notifier)
                        .cambiarPagina(pagina);
                  },
                  itemBuilder: (context, index) {
                    final item = _paginas[index];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            color: colores.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icono,
                            size: 100,
                            color: colores.primary,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          item.titulo,
                          textAlign: TextAlign.center,
                          style: tema.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          item.descripcion,
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _paginas.length,
                  (index) {
                    final seleccionado = paginaActual == index;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: seleccionado ? 26 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: seleccionado
                            ? colores.primary
                            : colores.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _siguiente,
                  child: Text(
                    paginaActual == _paginas.length - 1
                        ? 'Comenzar'
                        : 'Siguiente',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _OnboardingItem({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });
}
