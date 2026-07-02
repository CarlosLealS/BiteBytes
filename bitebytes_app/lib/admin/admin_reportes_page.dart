import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'package:intl/intl.dart';

const kAzul = Color(0xFF0B1F5C);
const kDorado = Color(0xFFF5A623);

class AdminReportesPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AdminReportesPage({super.key, required this.usuario});

  @override
  State<AdminReportesPage> createState() => _AdminReportesPageState();
}

class _AdminReportesPageState extends State<AdminReportesPage> {
  bool _cargando = true;
  List<dynamic> _reportes = [];

  String get _base => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(Uri.parse('$_base/api/admin/reportes'), headers: _headers);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _reportes = jsonDecode(res.body);
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _resolverReporte(int reporteId, String accion) async {
    int? diasSancion;
    String? motivoSancion;

    if (accion == 'sancionar') {
      final diasCtrl = TextEditingController(text: '7');
      final motivoCtrl = TextEditingController(text: 'Infracción a las normas comunitarias');

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aplicar Sanción', style: TextStyle(color: kAzul)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Al sancionar, el comentario original se eliminará permanentemente de la base de datos.'),
              const SizedBox(height: 16),
              TextField(
                controller: diasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días de sanción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la sanción (visible para el usuario)',
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
              child: const Text('Sancionar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
      diasSancion = int.tryParse(diasCtrl.text) ?? 7;
      motivoSancion = motivoCtrl.text;
    } else {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Descartar Reporte'),
          content: const Text('¿Estás seguro de descartar este reporte? No se tomarán acciones.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _cargando = true);
    try {
      final res = await http.post(
        Uri.parse('$_base/api/admin/reportes/$reporteId/resolver'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'accion': accion,
          'dias_sancion': diasSancion,
          'motivo_sancion': motivoSancion,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte resuelto')));
        }
        _cargarReportes();
      } else {
        setState(() => _cargando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al resolver reporte')));
        }
      }
    } catch (_) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión')));
      }
    }
  }

  String _formatearFecha(String fechaIso) {
    if (fechaIso.isEmpty) return '';
    final dt = DateTime.tryParse(fechaIso);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
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
                'Moderación de Comentarios',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kAzul),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: kAzul),
                onPressed: _cargarReportes,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _reportes.isEmpty
                ? const Center(child: Text('No hay reportes pendientes de revisión.'))
                : ListView.builder(
                    itemCount: _reportes.length,
                    itemBuilder: (ctx, i) {
                      final r = _reportes[i];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Reporte #${r['reporte_id']} - ${_formatearFecha(r['reporte_creado_en'])}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kAzul.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Contexto: ${r['tipo_resenia'].toString().toUpperCase()}',
                                      style: const TextStyle(color: kAzul, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Comentario Reportado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            r['comentario_texto'] ?? '(Comentario eliminado o vacío)',
                                            style: const TextStyle(fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Autor del comentario: ${r['autor_nombre'] ?? 'Desconocido'} (${r['autor_email'] ?? 'N/A'})', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Motivo del Reporte:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text(r['motivo'] ?? 'Sin motivo', style: const TextStyle(color: Colors.black87)),
                                        const SizedBox(height: 12),
                                        Text('Reportado por: ${r['reportador_nombre']} (${r['reportador_email']})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _resolverReporte(r['reporte_id'], 'descartar'),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Descartar Reporte'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _resolverReporte(r['reporte_id'], 'sancionar'),
                                    icon: const Icon(Icons.gavel, size: 18),
                                    label: const Text('Sancionar Autor'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
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
