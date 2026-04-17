import 'package:flutter/material.dart';
import 'search_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Fondo_home.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.18)),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 80,
                  color: const Color(0xFF001455),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Image.asset('assets/logo-ucn.png', width: 52),
                      const SizedBox(width: 16),
                      const Text(
                        'BiteBytes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxBlockWidth = constraints.maxWidth * 0.35;
                      return Padding(
                        padding: const EdgeInsets.only(right: 24.0),
                        child: Row(
                          children: [
                            Expanded(child: Container()),
                            Container(
                              width: maxBlockWidth.clamp(320.0, 520.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 20.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bite',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 120,
                                      fontFamily: 'FugazOne',
                                      color: const Color(0xFF0B1A49),
                                      height: 0.85,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 14,
                                          color: Colors.black.withOpacity(0.25),
                                          offset: const Offset(4, 5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Bytes',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 120,
                                      fontFamily: 'FugazOne',
                                      color: const Color(0xFF0B1A49),
                                      height: 0.85,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 14,
                                          color: Colors.black.withOpacity(0.25),
                                          offset: const Offset(4, 5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Sabor, estilo y rapidez en cada mordisco. Encuentra tu próxima comida favorita ahora.',
                                    textAlign: TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      height: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0B1A49),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 44,
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SearchPage(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Empezar →',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
