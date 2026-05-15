import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _kAzul    = Color(0xFF001455);
const _kNaranja = Color(0xFFE8751A);
const _kBase    = 'http://172.16.13.105:3000';

const double _mapAncho = 1600.0;
const double _mapAlto  = 900.0;

// ─── Modelo ────────────────────────────────────────────────────────────────────

class TiendaInfo {
  final String id;
  final String nombre;
  final String ubicacion;
  final String horario;
  final String tipo;
  final double? pixelX;
  final double? pixelY;

  const TiendaInfo({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.horario,
    required this.tipo,
    this.pixelX,
    this.pixelY,
  });

  bool get tieneCoordenadas => pixelX != null && pixelY != null;

  static TiendaInfo desdeJson(Map<String, dynamic> json) {
    return TiendaInfo(
      id:       json['id']?.toString() ?? '',
      nombre:   json['nombre']     as String? ?? '',
      ubicacion: json['descripcion'] as String? ?? 'Campus UCN',
      horario:  json['horario']    as String? ?? 'Consultar horario',
      tipo:     json['tipo']       as String? ?? 'tienda',
      pixelX:   double.tryParse(json['longitud']?.toString() ?? ''),
      pixelY:   double.tryParse(json['latitud']?.toString()  ?? ''),
    );
  }
}

// ─── Página ────────────────────────────────────────────────────────────────────

class SearchPage extends StatefulWidget {
  final Map<String, dynamic>? usuario;
  const SearchPage({super.key, this.usuario});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  bool _cargando = false;
  List<TiendaInfo> _tiendas = [];

  static const List<TiendaInfo> _fallback = [
    TiendaInfo(id: '1', nombre: 'Amadora',      ubicacion: 'Sector Centro',   horario: 'Lun-Vie: 07:00 - 18:00', tipo: 'cafeteria', pixelX: 1010, pixelY: 420),
    TiendaInfo(id: '2', nombre: 'Bar Lácteo',   ubicacion: 'Sector Derecho',  horario: 'Lun-Vie: 08:00 - 17:30', tipo: 'kiosco',    pixelX: 1260, pixelY: 500),
    TiendaInfo(id: '3', nombre: 'El encuentro', ubicacion: 'Sector Ciencias', horario: 'Lun-Vie: 07:30 - 19:00', tipo: 'tienda',    pixelX: 600,  pixelY: 650),
    TiendaInfo(id: '4', nombre: 'Casino',       ubicacion: 'Sector Centro',   horario: 'Lun-Vie: 11:30 - 14:00', tipo: 'casino',    pixelX: 800,  pixelY: 450),
  ];

  @override
  void initState() {
    super.initState();
    _cargarTiendas();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargarTiendas() async {
    setState(() => _cargando = true);
    try {
      final token   = widget.usuario?['token'] ?? '';
      final headers = token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};

      final res = await http
          .get(Uri.parse('$_kBase/api/tiendas'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      final data    = jsonDecode(res.body) as List? ?? [];
      final tiendas = data.map((t) => TiendaInfo.desdeJson(t as Map<String, dynamic>)).toList();
      setState(() {
        _tiendas  = tiendas.isNotEmpty ? tiendas : _fallback;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _tiendas = _fallback; _cargando = false; });
    }
  }

  List<TiendaInfo> get _tiendasFiltradas {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return _tiendas;
    return _tiendas.where((t) => t.nombre.toLowerCase().contains(q)).toList();
  }

  void _mostrarTienda(TiendaInfo tienda) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetallesTiendaModal(tienda: tienda, usuario: widget.usuario),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiendas = _tiendasFiltradas;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Mapa
        Image.asset('assets/MapaUCN.png', fit: BoxFit.cover),

        // Pines sobre el mapa
        LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final alto  = constraints.maxHeight;

            final relacion         = _mapAncho / _mapAlto;
            final relacionPantalla = ancho / alto;

            final double imgAncho;
            final double imgAlto;
            final double offsetX;
            final double offsetY;

            if (relacionPantalla > relacion) {
              imgAlto  = alto;
              imgAncho = alto * relacion;
              offsetX  = (ancho - imgAncho) / 2;
              offsetY  = 0;
            } else {
              imgAncho = ancho;
              imgAlto  = ancho / relacion;
              offsetX  = 0;
              offsetY  = (alto - imgAlto) / 2;
            }

            return Stack(
              fit: StackFit.expand,
              children: tiendas
                  .where((t) => t.tieneCoordenadas)
                  .map((tienda) => Positioned(
                        left: offsetX + (tienda.pixelX! / _mapAncho) * imgAncho - 18,
                        top:  offsetY + (tienda.pixelY! / _mapAlto)  * imgAlto  - 36,
                        child: GestureDetector(
                          onTap: () => _mostrarTienda(tienda),
                          child: Tooltip(
                            message: tienda.nombre,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 36,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),

        // Chips de tiendas (sin navbar)
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: _cargando
              ? const SizedBox(
                  height: 36,
                  child: Center(
                    child: CircularProgressIndicator(color: _kNaranja, strokeWidth: 2),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: tiendas
                        .map((tienda) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ElevatedButton(
                                onPressed: () => _mostrarTienda(tienda),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kNaranja,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  elevation: 2,
                                ),
                                child: Text(tienda.nombre,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Modal tienda ──────────────────────────────────────────────────────────────

class DetallesTiendaModal extends StatefulWidget {
  final TiendaInfo tienda;
  final Map<String, dynamic>? usuario;
  const DetallesTiendaModal({super.key, required this.tienda, this.usuario});

  @override
  State<DetallesTiendaModal> createState() => _DetallesTiendaModalState();
}

class _DetallesTiendaModalState extends State<DetallesTiendaModal> {
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final token   = widget.usuario?['token'] ?? '';
      final headers = token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};

      final res = await http
          .get(Uri.parse('$_kBase/api/tienda/${widget.tienda.id}/productos'),
              headers: headers)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      setState(() {
        _productos = List<Map<String, dynamic>>.from(
            jsonDecode(res.body) as List? ?? []);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(widget.tienda.nombre,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: _kAzul)),
              const SizedBox(height: 16),

              _infoRow(Icons.location_on, widget.tienda.ubicacion),
              const SizedBox(height: 12),
              _infoRow(Icons.schedule, widget.tienda.horario),
              const SizedBox(height: 28),

              const Text('Productos disponibles',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: _kAzul)),
              const SizedBox(height: 12),

              if (_cargando)
                const Center(child: CircularProgressIndicator(color: _kNaranja))
              else if (_productos.isEmpty)
                const Text('Sin productos disponibles',
                    style: TextStyle(color: Colors.grey, fontSize: 14))
              else
                ..._productos
                    .where((p) => p['disponible'] == true)
                    .map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: _kNaranja,
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(p['nombre'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black87)),
                              ),
                              Text('\$${p['precio'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _kAzul)),
                            ],
                          ),
                        )),

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNaranja,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cerrar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icono, String texto) => Row(
        children: [
          Icon(icono, color: _kNaranja, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Text(texto,
                  style: const TextStyle(fontSize: 16, color: Colors.grey))),
        ],
      );
}

// ─── Modal perfil ──────────────────────────────────────────────────────────────

class PerfilModal extends StatelessWidget {
  final Map<String, dynamic>? usuario;
  const PerfilModal({super.key, this.usuario});

  @override
  Widget build(BuildContext context) {
    final nombre  = usuario?['nombre'] as String? ?? 'Usuario';
    final email   = usuario?['email']  as String? ?? '';
    final rol     = usuario?['rol']    as String? ?? 'alumno';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),

          CircleAvatar(
            radius: 36,
            backgroundColor: _kAzul,
            child: Text(inicial,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),

          Text(nombre,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _kAzul)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _kAzul.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(rol,
                style: const TextStyle(
                    fontSize: 12, color: _kAzul, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}