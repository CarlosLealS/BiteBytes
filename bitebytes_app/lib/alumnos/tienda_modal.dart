import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const _kAzul    = Color(0xFF0B1F5C);
const _kNaranja = Color(0xFFE8751A);

// ─── Modelo TiendaInfo ─────────────────────────────────────────────────────────

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
      id:        json['id']?.toString() ?? '',
      nombre:    json['nombre']      as String? ?? '',
      ubicacion: json['descripcion'] as String? ?? 'Campus UCN',
      horario:   json['horario']     as String? ?? 'Consultar horario',
      tipo:      json['tipo']        as String? ?? 'tienda',
      pixelX:    double.tryParse(json['longitud']?.toString() ?? ''),
      pixelY:    double.tryParse(json['latitud']?.toString()  ?? ''),
    );
  }
}

// ─── Modal detalles tienda ─────────────────────────────────────────────────────

class DetallesTiendaModal extends StatefulWidget {
  final TiendaInfo tienda;
  final Map<String, dynamic>? usuario;
  final ValueChanged<String>? onIrTienda;
  const DetallesTiendaModal({super.key, required this.tienda, this.usuario, this.onIrTienda});

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
          .get(
            Uri.parse('${Env.apiUrl}/api/tienda/${widget.tienda.id}/productos'),
            headers: headers,
          )
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
              Row(
                children: [
                  if (widget.onIrTienda != null) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onIrTienda!(widget.tienda.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAzul,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Ir a la tienda',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: ElevatedButton(
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
                  ),
                ],
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