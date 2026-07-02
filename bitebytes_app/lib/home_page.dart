import 'package:flutter/material.dart';
import 'login.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo
          Image.asset('assets/Fondo_home.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.30)),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;
                return Column(
                  children: [
                    // ── Navbar ──────────────────────────────────────────
                    Container(
                      height: isMobile ? 60 : 80,
                      color: const Color(0xFF001455).withOpacity(0.92),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Image.asset('assets/logo-ucn.png',
                              width: isMobile ? 38 : 52),
                          const SizedBox(width: 12),
                          Text(
                            'BiteBytes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 24,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Contenido ────────────────────────────────────────
                    Expanded(
                      child: isMobile
                          ? _LayoutMobile(constraints: constraints)
                          : _LayoutDesktop(constraints: constraints),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Layout móvil: contenido centrado ────────────────────────────────────────

class _LayoutMobile extends StatelessWidget {
  final BoxConstraints constraints;
  const _LayoutMobile({required this.constraints});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título grande
            Text(
              'Bite',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (constraints.maxWidth * 0.22).clamp(60.0, 96.0),
                fontFamily: 'FugazOne',
                color: Colors.white,
                height: 0.9,
                shadows: [
                  Shadow(
                    blurRadius: 20,
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(3, 4),
                  ),
                ],
              ),
            ),
            Text(
              'Bytes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (constraints.maxWidth * 0.22).clamp(60.0, 96.0),
                fontFamily: 'FugazOne',
                color: const Color(0xFFF5A623),
                height: 0.9,
                shadows: [
                  Shadow(
                    blurRadius: 20,
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(3, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Descripción
            const Text(
              'Sabor, estilo y rapidez en cada mordisco.\nEncuentra tu próxima comida favorita ahora.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.6,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Botón
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  foregroundColor: const Color(0xFF0B1A49),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: const Text(
                  'Empezar →',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Link secundario
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              child: const Text(
                'Iniciar sesión',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Layout desktop: panel a la derecha ──────────────────────────────────────

class _LayoutDesktop extends StatelessWidget {
  final BoxConstraints constraints;
  const _LayoutDesktop({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final panelWidth = (constraints.maxWidth * 0.35).clamp(340.0, 520.0);
    final titleSize  = (constraints.maxWidth * 0.07).clamp(72.0, 120.0);

    return Padding(
      padding: const EdgeInsets.only(right: 40),
      child: Row(
        children: [
          const Spacer(),
          Container(
            width: panelWidth,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
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
                    height: 0.85,
                    shadows: [
                      Shadow(
                        blurRadius: 14,
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
                    height: 0.85,
                    shadows: [
                      Shadow(
                        blurRadius: 14,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(4, 5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sabor, estilo y rapidez en cada mordisco. Encuentra tu próxima comida favorita ahora.',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    height: 1.55,
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
                    foregroundColor: const Color(0xFF0B1A49),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 44, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
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
  }
}
