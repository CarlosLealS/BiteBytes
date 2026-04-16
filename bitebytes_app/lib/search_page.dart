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
    final lugares = [
      {'nombre': 'Cafetería Amadora', 'x': 1110.0, 'y': 340.0},
      {'nombre': 'Cafetería Derecho', 'x': 1310.0, 'y': 390.0},
      {'nombre': 'Cafetería Ciencias del mar',   'x': 760.0,  'y': 510.0},
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
          Expanded(                                // ← necesario para que el Stack ocupe el espacio restante
            child: Stack(
              children: [
                // Imagen de fondo
                Image.asset(
                  "assets/MapaUCN.png",
                  width: double.infinity,
                  height: double.infinity,         // ← ocupa todo el Expanded
                  fit: BoxFit.contain,
                ),
                // Puntos con tooltip
                ...lugares.map((lugar) => Positioned(
                  left: lugar['x'] as double,
                  top: lugar['y'] as double,
                  child: Tooltip(
                    message: lugar['nombre'] as String,
                    child: Icon(
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
                )),                                // ← paréntesis que faltaba
              ],
            ),
          ),
        ],
      ),
    );
  }
}