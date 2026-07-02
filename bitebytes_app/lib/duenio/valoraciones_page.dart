import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'package:intl/intl.dart';

const kAzul = Color(0xFF0B1F5C);
const kDorado = Color(0xFFF5A623);

class ValoracionesPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const ValoracionesPage({super.key, required this.usuario});

  @override
  State<ValoracionesPage> createState() => _ValoracionesPageState();
}

class _ValoracionesPageState extends State<ValoracionesPage> {
  bool _cargando = true;
  List<dynamic> _resenias = [];

  String get _base => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';
  String get _tiendaId => widget.usuario['tienda_id'] ?? '';

  @override
  void initState() {
    super.initState();
    _cargarResenias();
  }

  Future<void> _cargarResenias() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(
        Uri.parse('$_base/api/tienda/$_tiendaId/todas-resenias'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _resenias = jsonDecode(res.body);
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reportarResenia(Map<String, dynamic> resenia) async {
    final motivoCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reportar Comentario', style: TextStyle(color: kAzul)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comentario de ${resenia['usuario_nombre']}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('"${resenia['comentario'] ?? ''}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo del reporte',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Enviar Reporte', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final motivo = motivoCtrl.text.trim();
      if (motivo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes ingresar un motivo')));
        return;
      }
      try {
        final res = await http.post(
          Uri.parse('$_base/api/tienda/reportar-resenia'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'resenia_id': resenia['resenia_id'],
            'tipo_resenia': resenia['tipo_resenia'],
            'motivo': motivo,
          }),
        );
        if (res.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentario reportado. Un administrador lo revisará.')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar el reporte.')));
          }
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión.')));
        }
      }
    }
  }

  String _formatearFecha(String fechaIso) {
    if (fechaIso.isEmpty) return '';
    final dt = DateTime.tryParse(fechaIso);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  Color _colorPorTipo(String tipo) {
    switch (tipo) {
      case 'tienda': return Colors.blue;
      case 'producto': return Colors.green;
      case 'publicacion': return Colors.orange;
      case 'plato': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: kDorado));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Todas las Valoraciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kAzul),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: kAzul),
                onPressed: _cargarResenias,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _resenias.isEmpty
                ? const Center(child: Text('No hay valoraciones aún.'))
                : ListView.builder(
                    itemCount: _resenias.length,
                    itemBuilder: (ctx, i) {
                      final r = _resenias[i];
                      final tieneComentario = r['comentario'] != null && r['comentario'].toString().trim().isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: kAzul.withOpacity(0.1),
                                    radius: 20,
                                    child: Text(
                                      (r['usuario_nombre'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(color: kAzul, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r['usuario_nombre'] ?? 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(_formatearFecha(r['creado_en']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < (r['calificacion'] ?? 0) ? Icons.star : Icons.star_border,
                                        color: kDorado,
                                        size: 18,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: tieneComentario
                                        ? Text('"${r['comentario']}"', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic))
                                        : const Text('Sin comentario', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  ),
                                  if (tieneComentario)
                                    IconButton(
                                      icon: const Icon(Icons.outlined_flag, color: Colors.redAccent, size: 20),
                                      tooltip: 'Reportar comentario',
                                      onPressed: () => _reportarResenia(r),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _colorPorTipo(r['tipo_resenia']).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r['tipo_resenia'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color: _colorPorTipo(r['tipo_resenia']),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}