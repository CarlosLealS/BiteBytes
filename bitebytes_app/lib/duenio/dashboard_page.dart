import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const kAzul = Color(0xFF0B1F5C);
const kDorado = Color(0xFFF5A623);

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const DashboardPage({super.key, required this.usuario});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _cargando = true;
  int _totalProductos = 0;
  int _totalPublicaciones = 0;
  int _totalTrabajadores = 0;
  double _valoracionMedia = 0.0;
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _trabajadores = [];
  List<Map<String, dynamic>> _publicaciones = [];

  static final String _baseUrl = Env.apiUrl;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final token = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/productos'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/trabajadores'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/publicaciones'), headers: headers),
      ]);

      if (!mounted) return;

      final productos    = jsonDecode(responses[0].body) as List? ?? [];
      final trabajadores = jsonDecode(responses[1].body) as List? ?? [];
      final publicaciones = jsonDecode(responses[2].body) as List? ?? [];

      double totalVal = 0;
      int countVal = 0;
      for (final p in productos) {
        if (p['valoracion_media'] != null) {
          totalVal += (p['valoracion_media'] as num).toDouble();
          countVal++;
        }
      }

      setState(() {
        _productos       = List<Map<String, dynamic>>.from(productos.take(4));
        _trabajadores    = List<Map<String, dynamic>>.from(trabajadores.take(4));
        _publicaciones   = List<Map<String, dynamic>>.from(publicaciones.take(3));
        _totalProductos     = productos.where((p) => p['disponible'] == true).length;
        _totalPublicaciones = publicaciones.length;
        _totalTrabajadores  = trabajadores.length;
        _valoracionMedia    = countVal > 0 ? totalVal / countVal : 0.0;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: kDorado),
      );
    }

    return RefreshIndicator(
      color: kDorado,
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bienvenida(),
            const SizedBox(height: 20),
            _metricas(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _cardProductos()),
                const SizedBox(width: 16),
                Expanded(child: _cardTrabajadores()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _cardPublicaciones()),
                const SizedBox(width: 16),
                Expanded(child: _cardValoraciones()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bienvenida() {
    final nombre = widget.usuario['nombre'] ?? 'Dueño';
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches';
    return Text(
      '$saludo, $nombre',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
    );
  }

  Widget _metricas() {
    return Row(
      children: [
        _metricCard('Productos activos', '$_totalProductos', Icons.inventory_2_outlined, kAzul),
        const SizedBox(width: 12),
        _metricCard('Publicaciones', '$_totalPublicaciones', Icons.campaign_outlined, kAzul),
        const SizedBox(width: 12),
        _metricCard('Trabajadores', '$_totalTrabajadores', Icons.people_outline, kAzul),
        const SizedBox(width: 12),
        _metricCard('Valoración media', _valoracionMedia.toStringAsFixed(1), Icons.star_border_rounded, kDorado),
      ],
    );
  }

  Widget _metricCard(String label, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 10),
            Text(valor,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _cardProductos() {
    return _DashCard(
      titulo: 'Productos recientes',
      icono: Icons.inventory_2_outlined,
      child: _productos.isEmpty
          ? _vacio('Sin productos aún')
          : Column(
              children: _productos.map((p) {
                final disponible = p['disponible'] == true;
                return _filaItem(
                  nombre: p['nombre'] ?? '',
                  detalle: '\$${p['precio'] ?? 0}',
                  badge: disponible ? 'Disponible' : 'No disponible',
                  badgeColor: disponible ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                  badgeTextColor: disponible ? const Color(0xFF166534) : const Color(0xFF6B7280),
                );
              }).toList(),
            ),
    );
  }

  Widget _cardTrabajadores() {
    return _DashCard(
      titulo: 'Trabajadores',
      icono: Icons.people_outline,
      child: _trabajadores.isEmpty
          ? _vacio('Sin trabajadores aún')
          : Column(
              children: _trabajadores.map((t) {
                final nombre = t['nombre'] ?? 'Sin nombre';
                final iniciales = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFE6F1FB),
                        child: Text(iniciales,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0C447C))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(nombre,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                      ),
                      _badge('Activo', const Color(0xFFDCFCE7), const Color(0xFF166534)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _cardPublicaciones() {
    return _DashCard(
      titulo: 'Publicaciones activas',
      icono: Icons.campaign_outlined,
      child: _publicaciones.isEmpty
          ? _vacio('Sin publicaciones aún')
          : Column(
              children: _publicaciones.map((p) {
                return _filaItem(
                  nombre: p['nombre'] ?? '',
                  detalle: p['expira_en'] != null
                      ? 'Expira: ${_formatFecha(p['expira_en'])}'
                      : 'Sin vencimiento',
                  badge: 'Activa',
                  badgeColor: const Color(0xFFDCFCE7),
                  badgeTextColor: const Color(0xFF166534),
                );
              }).toList(),
            ),
    );
  }

  Widget _cardValoraciones() {
    return _DashCard(
      titulo: 'Valoraciones por producto',
      icono: Icons.star_border_rounded,
      child: _productos.isEmpty
          ? _vacio('Sin valoraciones aún')
          : Column(
              children: _productos.map((p) {
                final val = (p['valoracion_media'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          p['nombre'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: val / 5,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              val >= 4 ? kDorado : kAzul,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${val.toStringAsFixed(1)} ★',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _filaItem({
    required String nombre,
    required String detalle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis),
                Text(detalle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          _badge(badge, badgeColor, badgeTextColor),
        ],
      ),
    );
  }

  Widget _badge(String texto, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w500)),
    );
  }

  Widget _vacio(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(msg, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      ),
    );
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _DashCard extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  const _DashCard({required this.titulo, required this.icono, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: kDorado),
              const SizedBox(width: 6),
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 16, thickness: 0.5),
          child,
        ],
      ),
    );
  }
}