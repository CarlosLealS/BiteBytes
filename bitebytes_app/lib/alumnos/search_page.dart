import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'tienda_modal.dart';

const _kNaranja = Color(0xFFE8751A);
final _kBase    = Env.apiUrl;

const double _mapAncho = 1600.0;
const double _mapAlto  = 900.0;

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

        // Chips de tiendas
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