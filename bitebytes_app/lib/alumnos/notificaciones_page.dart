import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'package:intl/intl.dart';
import 'ofertas_page.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class NotificacionesPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const NotificacionesPage({super.key, required this.usuario});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  bool _cargando = true;
  List<dynamic> _notificaciones = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final token = widget.usuario['token'] ?? '';
      final res = await http.get(
        Uri.parse('${Env.apiUrl}/api/notificaciones'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      setState(() {
        _notificaciones = jsonDecode(res.body) as List? ?? [];
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _marcarLeida(String id, String tipo, String referenciaId) async {
    try {
      final token = widget.usuario['token'] ?? '';
      await http.patch(
        Uri.parse('${Env.apiUrl}/api/notificaciones/$id/leida'),
        headers: {'Authorization': 'Bearer $token'},
      );
      // Navegar a la página correspondiente (OfertasPage en este caso)
      if (!mounted) return;
      if (tipo == 'oferta') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OfertasPage(usuario: widget.usuario)),
        ).then((_) => _cargar()); // Recargar al volver
      } else {
        _cargar();
      }
    } catch (_) {
      debugPrint('Error al marcar leída');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: _kAzul,
        foregroundColor: Colors.white,
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kDorado))
          : _notificaciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No tienes notificaciones',
                          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kDorado,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notificaciones.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final n = _notificaciones[i];
                      final leida = n['leida'] as bool? ?? false;
                      final fecha = n['creado_en'] != null ? DateTime.tryParse(n['creado_en']) : null;
                      
                      return InkWell(
                        onTap: () => _marcarLeida(n['id'], n['tipo'] ?? '', n['referencia_id'] ?? ''),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: leida ? Colors.white : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: leida ? const Color(0xFFE5E7EB) : _kDorado.withOpacity(0.5),
                              width: leida ? 0.5 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: leida ? const Color(0xFFF3F4F6) : _kDorado.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  n['tipo'] == 'oferta' ? Icons.local_offer : Icons.notifications,
                                  size: 20,
                                  color: leida ? const Color(0xFF9CA3AF) : _kDorado,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(n['titulo'] ?? '',
                                              style: TextStyle(
                                                fontWeight: leida ? FontWeight.w500 : FontWeight.bold,
                                                fontSize: 14,
                                                color: const Color(0xFF111827),
                                              )),
                                        ),
                                        if (!leida)
                                          Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.red, shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n['mensaje'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: leida ? const Color(0xFF6B7280) : const Color(0xFF374151),
                                        )),
                                    if (fecha != null) ...[
                                      const SizedBox(height: 8),
                                      Text(DateFormat('dd MMM, HH:mm').format(fecha.toLocal()),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
