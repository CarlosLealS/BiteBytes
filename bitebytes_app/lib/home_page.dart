import 'package:flutter/material.dart';
import 'login.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          return isMobile
              ? const _MobileLayout()
              : const _DesktopLayout();
        },
      ),
    );
  }
}

// ─── MÓVIL ────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo
        Image.asset('assets/Fondo_home.png', fit: BoxFit.cover),

        // Gradiente oscuro de abajo hacia arriba
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.35, 1.0],
              colors: [
                Color(0x99001455),
                Color(0x44000000),
                Color(0xEE000000),
              ],
            ),
          ),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navbar
              Container(
                height: 60,
                color: const Color(0xFF001455).withOpacity(0.92),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Image.asset('assets/logo-ucn.png', width: 36),
                    const SizedBox(width: 10),
                    const Text(
                      'BiteBytes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Contenido inferior
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    const Text(
                      'Bite',
                      style: TextStyle(
                        fontSize: 72,
                        fontFamily: 'FugazOne',
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'Bytes',
                      style: TextStyle(
                        fontSize: 72,
                        fontFamily: 'FugazOne',
                        color: Color(0xFFF5A623),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Descripción
                    const Text(
                      'Sabor, estilo y rapidez en cada mordisco.\nEncuentra tu comida favorita en el campus.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.55,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Botón principal
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5A623),
                          foregroundColor: const Color(0xFF001455),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginPage()),
                        ),
                        child: const Text(
                          'Empezar →',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Link secundario
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginPage()),
                        ),
                        child: const Text(
                          'Ya tengo una cuenta  →',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── DESKTOP ──────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/Fondo_home.png', fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.22)),

        SafeArea(
          child: Column(
            children: [
              // Navbar
              Container(
                height: 80,
                color: const Color(0xFF001455).withOpacity(0.90),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Image.asset('assets/logo-ucn.png', width: 52),
                    const SizedBox(width: 14),
                    const Text(
                      'BiteBytes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final panelW =
                      (constraints.maxWidth * 0.36).clamp(360.0, 520.0);
                  final titleSize =
                      (constraints.maxWidth * 0.07).clamp(72.0, 118.0);
                  return Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: Row(
                      children: [
                        const Spacer(),
                        Container(
                          width: panelW,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 36),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bite',
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontFamily: 'FugazOne',
                                  color: Colors.white,
                                  height: 0.88,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 16,
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(4, 5),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Bytes',
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontFamily: 'FugazOne',
                                  color: const Color(0xFFF5A623),
                                  height: 0.88,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 16,
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(4, 5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Sabor, estilo y rapidez en cada mordisco. Encuentra tu próxima comida favorita ahora.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  height: 1.6,
                                  fontFamily: 'Poppins',
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF5A623),
                                  foregroundColor: const Color(0xFF001455),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 44, vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                ),
                                child: const Text(
                                  'Empezar →',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
