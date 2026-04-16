import 'package:flutter/material.dart';
import 'dart:math';
import 'search_page.dart';

class NoiseOverlay extends CustomPainter {
  final double noiseSize;
  final double density;
  final Color noiseColor;

  NoiseOverlay({
    this.noiseSize = 4,
    this.density = 0.62,
    this.noiseColor = const Color.fromARGB(64, 0, 0, 0),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Seed para consistencia
    final paint = Paint()..color = noiseColor;

    for (double x = 0; x < size.width; x += noiseSize) {
      for (double y = 0; y < size.height; y += noiseSize) {
        if (random.nextDouble() < density) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, noiseSize, noiseSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(NoiseOverlay oldDelegate) => false;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Barra azul oscura en la parte superior con ruido
          Container(
            height: 80,
            color: const Color(0xFF001455), // Azul oscuro
            child: Stack(
              children: [
                // Contenido de la barra
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/logo-ucn.png',
                        width: 50,
                      ),
                    ),
                  ],
                ),
                // Capa de ruido encima
                CustomPaint(
                  painter: NoiseOverlay(
                    noiseSize: 4,
                    density: 0.62,
                    noiseColor: const Color.fromARGB(64, 0, 0, 0),
                  ),
                  size: Size.infinite,
                ),
              ],
            ),
          ),

          // Contenido principal (imagen + panel derecho)
          Expanded(
            child: Row(
              children: [
                // Panel izquierdo con imagen - abarcar todo el espacio disponible
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.white,
                    child: Image.asset(
                      'assets/chaparras.jpg', // tu foto de comida
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),

                // Panel derecho con texto y botón
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.orange,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Título Bite Bytes - dos líneas
                        Column(
                          children: [
                            Text(
                              "Bite",
                              style: TextStyle(
                                fontSize: 180,
                                fontFamily: 'jsMath-cmmi10',
                                color: Colors.black,
                                height: 0.9,
                              ),
                            ),
                            Text(
                              "Bytes",
                              style: TextStyle(
                                fontSize: 140,
                                fontFamily: 'jsMath-cmmi10',
                                color: Colors.black,
                                height: 0.9,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Botón Empezar
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SearchPage()),
                            );
                          },
                          child: const Text("Empezar →"),
                        ),
                      ],
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
