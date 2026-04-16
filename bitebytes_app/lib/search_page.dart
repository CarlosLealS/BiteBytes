import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tamaño original de la imagen en píxeles
    const double imagenOriginalAncho = 1600.0; // ← pon el ancho real de MapaUCN.png
    const double imagenOriginalAlto  = 900.0;  // ← pon el alto real de MapaUCN.png

    // Coordenadas como porcentaje del tamaño original
    final lugares = [
      {'nombre': 'Cafetería Amadora',        'x': 1010.0 / imagenOriginalAncho, 'y': 420.0 / imagenOriginalAlto},
      {'nombre': 'Cafetería Derecho',         'x': 1260.0 / imagenOriginalAncho, 'y': 500.0 / imagenOriginalAlto},
      {'nombre': 'Cafetería Ciencias del mar','x': 600.0  / imagenOriginalAncho, 'y': 650.0 / imagenOriginalAlto},
    ];

    return Scaffold(
      body: Column(
        children: [
          // Caja superior con logo
          Container(
            width: double.infinity,
            color: const Color(0xFF001455),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo-ucn.png',
                  height: 80,
                ),
              ],
            ),
          ),

          // Barra de búsqueda debajo de la caja
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF001455)),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF001455)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Mapa con puntos
          Expanded(
            child: LayoutBuilder( // ← mide el espacio disponible en tiempo real
              builder: (context, constraints) {
                final ancho = constraints.maxWidth;
                final alto  = constraints.maxHeight;

                // Calcular tamaño real de la imagen con BoxFit.contain
                final escala = (ancho / imagenOriginalAncho)
                    .clamp(0.0, alto / imagenOriginalAlto);
                final imagenAncho = imagenOriginalAncho * escala;
                final imagenAlto  = imagenOriginalAlto  * escala;

                // Offset para centrar la imagen
                final offsetX = (ancho - imagenAncho) / 2;
                final offsetY = (alto  - imagenAlto)  / 2;

                return Stack(
                  children: [
                    // Imagen de fondo
                    Image.asset(
                      "assets/MapaUCN.png",
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                    ),
                    // Puntos con tooltip
                    ...lugares.map((lugar) => Positioned(
                      left: offsetX + (lugar['x'] as double) * imagenAncho - 18,
                      top:  offsetY + (lugar['y'] as double) * imagenAlto  - 36,
                      child: Tooltip(
                        message: lugar['nombre'] as String,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 36,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    )),
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