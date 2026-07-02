import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const _kAzul    = Color(0xFF0B1F5C);
const _kDorado  = Color(0xFFF5A623);
final _kBase    = Env.apiUrl;

const double _mapAncho = 1600.0;
const double _mapAlto  = 900.0;

class AdminMapaPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AdminMapaPage({super.key, required this.usuario});

  @override
  State<AdminMapaPage> createState() => _AdminMapaPageState();
}

class _AdminMapaPageState extends State<AdminMapaPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _tiendas = [];
  Map<String, dynamic>? _tiendaSeleccionada;
  
  double? _pixelX;
  double? _pixelY;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarTiendas();
  }

  Future<void> _cargarTiendas() async {
    setState(() => _cargando = true);
    try {
      final token = widget.usuario['token'] ?? '';
      final res = await http.get(
        Uri.parse('$_kBase/api/admin/tiendas'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _tiendas = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _seleccionarTienda(Map<String, dynamic>? tienda) {
    setState(() {
      _tiendaSeleccionada = tienda;
      if (tienda != null) {
        _pixelX = double.tryParse(tienda['longitud']?.toString() ?? '');
        _pixelY = double.tryParse(tienda['latitud']?.toString() ?? '');
      } else {
        _pixelX = null;
        _pixelY = null;
      }
    });
  }

  Future<void> _guardarUbicacion() async {
    if (_tiendaSeleccionada == null || _pixelX == null || _pixelY == null) return;
    
    setState(() => _guardando = true);
    try {
      final token = widget.usuario['token'] ?? '';
      final id = _tiendaSeleccionada!['id'];
      final res = await http.patch(
        Uri.parse('$_kBase/api/admin/tiendas/$id/ubicacion'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitud': _pixelY, // En la BD latitud = Y
          'longitud': _pixelX, // En la BD longitud = X
        }),
      );

      if (!mounted) return;
      setState(() => _guardando = false);

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación guardada con éxito'), backgroundColor: Colors.green),
        );
        // Actualizar la lista local
        final index = _tiendas.indexWhere((t) => t['id'] == id);
        if (index != -1) {
          _tiendas[index]['latitud'] = _pixelY;
          _tiendas[index]['longitud'] = _pixelX;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar ubicación'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controles superiores
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator(color: _kDorado))
                    : DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: const InputDecoration(
                          labelText: 'Selecciona una tienda para ubicar',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: _tiendaSeleccionada,
                        items: _tiendas.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t['nombre'] ?? 'Sin nombre'),
                          );
                        }).toList(),
                        onChanged: _seleccionarTienda,
                      ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _guardando || _tiendaSeleccionada == null || _pixelX == null
                    ? null
                    : _guardarUbicacion,
                icon: _guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Guardar Ubicación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAzul,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        
        // Mapa interactivo
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth;
              final alto = constraints.maxHeight;

              final relacion = _mapAncho / _mapAlto;
              final relacionPantalla = ancho / alto;

              double imgAncho;
              double imgAlto;
              double offsetX;
              double offsetY;

              if (relacionPantalla > relacion) {
                // Pantalla más ancha que el mapa → ajustar por ALTURA
                imgAlto  = alto;
                imgAncho = alto * relacion;
                offsetY  = 0;
                offsetX  = (ancho - imgAncho) / 2;
              } else {
                // Pantalla más alta que el mapa → ajustar por ANCHURA
                imgAncho = ancho;
                imgAlto  = ancho / relacion;
                offsetX  = 0;
                offsetY  = (alto - imgAlto) / 2;
              }

              final bool esMobile = ancho < 600;

              Widget contenidoMapa = Stack(
                clipBehavior: Clip.none,
                children: [
                  // Imagen con el mismo tamaño y offset que los pines
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: imgAncho,
                    height: imgAlto,
                    child: Image.asset('assets/MapaUCN.png', fit: BoxFit.fill),
                  ),

                  // Pin de la tienda seleccionada
                  if (_pixelX != null && _pixelY != null)
                    Positioned(
                      left: offsetX + (_pixelX! / _mapAncho) * imgAncho - 20,
                      top: offsetY + (_pixelY! / _mapAlto) * imgAlto - 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                ],
              );

              Widget mapaInteractivo = GestureDetector(
                onTapDown: (details) {
                  if (_tiendaSeleccionada == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor selecciona una tienda primero'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  final localX = details.localPosition.dx;
                  final localY = details.localPosition.dy;

                  final xEnImg = localX - offsetX;
                  final yEnImg = localY - offsetY;

                  if (xEnImg >= 0 && xEnImg <= imgAncho && yEnImg >= 0 && yEnImg <= imgAlto) {
                    setState(() {
                      _pixelX = (xEnImg / imgAncho) * _mapAncho;
                      _pixelY = (yEnImg / imgAlto) * _mapAlto;
                    });
                  }
                },
                child: SizedBox(
                  width: ancho,
                  height: alto,
                  child: contenidoMapa,
                ),
              );

              return Stack(
                children: [
                  Container(color: Colors.grey[200]),
                  if (esMobile)
                    InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(0),
                      minScale: 0.8,
                      maxScale: 4.0,
                      constrained: true,
                      child: mapaInteractivo,
                    )
                  else
                    mapaInteractivo,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
