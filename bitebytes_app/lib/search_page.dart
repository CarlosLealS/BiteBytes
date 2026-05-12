import 'package:flutter/material.dart';

class TiendaInfo {
  final String nombre;
  final String ubicacion;
  final String horario;
  final List<String> menu;
  final double x;
  final double y;

  TiendaInfo({
    required this.nombre,
    required this.ubicacion,
    required this.horario,
    required this.menu,
    required this.x,
    required this.y,
  });
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  final List<TiendaInfo> tiendas = [
    TiendaInfo(
      nombre: 'Amadora',
      ubicacion: 'Sector Centro',
      horario: 'Lun-Vie: 07:00 - 18:00',
      menu: ['Sándwiches', 'Café', 'Desayunos', 'Postres'],
      x: 1010.0 / 1600.0,
      y: 420.0 / 900.0,
    ),
    TiendaInfo(
      nombre: 'Bar Lácteo',
      ubicacion: 'Sector Derecho',
      horario: 'Lun-Vie: 08:00 - 17:30',
      menu: ['Bebidas', 'Snacks', 'Ensaladas', 'Juegos'],
      x: 1260.0 / 1600.0,
      y: 500.0 / 900.0,
    ),
    TiendaInfo(
      nombre: 'El encuentro',
      ubicacion: 'Sector Ciencias',
      horario: 'Lun-Vie: 07:30 - 19:00',
      menu: ['Comida Casera', 'Almuerzos', 'Bebidas', 'Postres'],
      x: 600.0 / 1600.0,
      y: 650.0 / 900.0,
    ),
    TiendaInfo(
      nombre: 'Casino',
      ubicacion: 'Sector Centro',
      horario: 'Lun-Vie: 11:30 - 14:00',
      menu: ['Menú Diario', 'Bebidas', 'Postre', 'Café'],
      x: 800.0 / 1600.0,
      y: 450.0 / 900.0,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _mostrarTienda(TiendaInfo tienda) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetallesTiendaModal(tienda: tienda),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double imagenOriginalAncho = 1600.0;
    const double imagenOriginalAlto = 900.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Mapa a pantalla completa
          Image.asset(
            "assets/MapaUCN.png",
            fit: BoxFit.cover,
          ),

          // Puntos interactivos en el mapa
          LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth;
              final alto = constraints.maxHeight;

              final relacion = imagenOriginalAncho / imagenOriginalAlto;
              final relacionPantalla = ancho / alto;

              late final double imagenAncho;
              late final double imagenAlto;
              late final double offsetX;
              late final double offsetY;

              if (relacionPantalla > relacion) {
                imagenAlto = alto;
                imagenAncho = alto * relacion;
                offsetX = (ancho - imagenAncho) / 2;
                offsetY = 0;
              } else {
                imagenAncho = ancho;
                imagenAlto = ancho / relacion;
                offsetX = 0;
                offsetY = (alto - imagenAlto) / 2;
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  ...tiendas.map((tienda) => Positioned(
                    left: offsetX + tienda.x * imagenAncho - 18,
                    top: offsetY + tienda.y * imagenAlto - 36,
                    child: GestureDetector(
                      onTap: () => _mostrarTienda(tienda),
                      child: Tooltip(
                        message: tienda.nombre,
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
                    ),
                  )),
                ],
              );
            },
          ),

          // Interfaz superior
          SafeArea(
            child: Column(
              children: [
                // Caja superior con logo y barra de búsqueda
                Container(
                  width: double.infinity,
                  color: const Color(0xFF001455),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/logo-ucn.png',
                        height: 50,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                    ],
                  ),
                ),

                // Botones de tiendas pegados a la izquierda
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tiendas.map((tienda) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ElevatedButton(
                              onPressed: () => _mostrarTienda(tienda),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8751A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                tienda.nombre,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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

class _DetallesTiendaModal extends StatelessWidget {
  final TiendaInfo tienda;

  const _DetallesTiendaModal({required this.tienda});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nombre de la tienda
              Text(
                tienda.nombre,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001455),
                ),
              ),
              const SizedBox(height: 16),

              // Ubicación
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFE8751A),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tienda.ubicacion,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Horario
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Color(0xFFE8751A),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tienda.horario,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Menú
              const Text(
                'Menú',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001455),
                ),
              ),
              const SizedBox(height: 12),

              // Items del menú
              ...tienda.menu.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8751A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 28),

              // Botón de acción
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8751A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ver Más',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}