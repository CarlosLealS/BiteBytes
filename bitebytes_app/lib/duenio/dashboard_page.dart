import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const kAzul   = Color(0xFF0B1F5C);
const kDorado = Color(0xFFF5A623);

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const DashboardPage({super.key, required this.usuario});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool    _cargando           = true;
  String? _errorMsg;
  int     _totalProductos     = 0;
  int     _totalPublicaciones = 0;
  int     _totalTrabajadores  = 0;
  double  _valoracionMedia    = 0.0;
  int     _totalResenias      = 0;
  List<Map<String, dynamic>> _productos     = [];
  List<Map<String, dynamic>> _trabajadores  = [];
  List<Map<String, dynamic>> _publicaciones = [];
  List<Map<String, dynamic>> _resenias      = [];

  static final String _baseUrl = Env.apiUrl;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  List _parseList(http.Response res) {
    debugPrint('${res.request?.url} → ${res.statusCode}');
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) return decoded['data'];
    return [];
  }

  Future<void> _cargarDatos() async {
    setState(() { _cargando = true; _errorMsg = null; });
    try {
      final token    = widget.usuario['token']     ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';

      if (tiendaId.isEmpty) {
        setState(() { _cargando = false; _errorMsg = 'No se encontró el ID de la tienda'; });
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/productos'),     headers: headers),
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/trabajadores'),  headers: headers),
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/publicaciones'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/tienda/$tiendaId/resenias'),      headers: headers),
      ]);

      if (!mounted) return;

      final productos     = _parseList(responses[0]);
      final trabajadores  = _parseList(responses[1]);
      final publicaciones = _parseList(responses[2]);
      final resenias      = _parseList(responses[3]);

      // Valoración media desde reseñas de la tienda
      double totalVal = 0;
      int    countVal = 0;
      for (final r in resenias) {
        if (r['calificacion'] != null) {
          totalVal += (r['calificacion'] as num).toDouble();
          countVal++;
        }
      }

      setState(() {
        _productos     = List<Map<String, dynamic>>.from(productos.take(4));
        _trabajadores  = List<Map<String, dynamic>>.from(trabajadores.take(4));
        _publicaciones = List<Map<String, dynamic>>.from(publicaciones.take(3));
        _resenias      = List<Map<String, dynamic>>.from(resenias.take(3));

        _totalProductos     = productos.where((p) {
          final d = p['disponible'];
          return d == true || d == 1;
        }).length;
        _totalPublicaciones = publicaciones.length;
        _totalTrabajadores  = trabajadores.length;
        _totalResenias      = resenias.length;
        _valoracionMedia    = countVal > 0 ? totalVal / countVal : 0.0;
        _cargando           = false;
      });
    } catch (e, stack) {
      debugPrint('Error dashboard: $e\n$stack');
      if (!mounted) return;
      setState(() { _cargando = false; _errorMsg = 'Error al cargar datos'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: kDorado));
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarDatos,
              style: ElevatedButton.styleFrom(backgroundColor: kAzul),
              child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
                Expanded(child: _cardResenias()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bienvenida ─────────────────────────────────────────────────────────────

  Widget _bienvenida() {
    final nombre = widget.usuario['nombre'] ?? 'Dueño';
    final hora   = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches';
    return Text('$saludo, $nombre',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF111827)));
  }

  // ─── Métricas ────────────────────────────────────────────────────────────────

  Widget _metricas() {
    return Row(children: [
      _metricCard('Productos activos', '$_totalProductos',
          Icons.inventory_2_outlined, kAzul),
      const SizedBox(width: 12),
      _metricCard('Publicaciones', '$_totalPublicaciones',
          Icons.campaign_outlined, kAzul),
      const SizedBox(width: 12),
      _metricCard('Trabajadores', '$_totalTrabajadores',
          Icons.people_outline, kAzul),
      const SizedBox(width: 12),
      _metricCard(
        'Valoración media',
        _totalResenias > 0
            ? '${_valoracionMedia.toStringAsFixed(1)} ★'
            : 'Sin reseñas',
        Icons.star_border_rounded,
        kDorado,
      ),
    ]);
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
                style: TextStyle(
                  fontSize: valor.length > 6 ? 16 : 26,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  // ─── Card Productos ──────────────────────────────────────────────────────────

  Widget _cardProductos() {
    return _DashCard(
      titulo: 'Productos recientes',
      icono: Icons.inventory_2_outlined,
      child: _productos.isEmpty
          ? _vacio('Sin productos aún')
          : Column(
              children: _productos.map((p) {
                final disponible = p['disponible'] == true || p['disponible'] == 1;
                return _filaItem(
                  nombre: p['nombre'] ?? '',
                  detalle: '\$${_formatPrecio(p['precio'])}',
                  badge: disponible ? 'Disponible' : 'No disponible',
                  badgeColor: disponible
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF3F4F6),
                  badgeTextColor: disponible
                      ? const Color(0xFF166534)
                      : const Color(0xFF6B7280),
                );
              }).toList(),
            ),
    );
  }

  // ─── Card Trabajadores ───────────────────────────────────────────────────────

  Widget _cardTrabajadores() {
    return _DashCard(
      titulo: 'Trabajadores',
      icono: Icons.people_outline,
      child: _trabajadores.isEmpty
          ? _vacio('Sin trabajadores aún')
          : Column(
              children: _trabajadores.map((t) {
                final nombre    = t['nombre'] ?? 'Sin nombre';
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
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0C447C))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF111827)),
                                overflow: TextOverflow.ellipsis),
                            if (t['email'] != null)
                              Text(t['email'],
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF6B7280)),
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      _badge('Activo', const Color(0xFFDCFCE7),
                          const Color(0xFF166534)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── Card Publicaciones ──────────────────────────────────────────────────────

  Widget _cardPublicaciones() {
    return _DashCard(
      titulo: 'Publicaciones activas',
      icono: Icons.campaign_outlined,
      child: _publicaciones.isEmpty
          ? _vacio('Sin publicaciones aún')
          : Column(
              children: _publicaciones.map((p) {
                return _filaItem(
                  nombre: p['nombre'] ?? p['titulo'] ?? '',
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

  // ─── Card Reseñas ────────────────────────────────────────────────────────────

  Widget _cardResenias() {
    return _DashCard(
      titulo: 'Reseñas recientes',
      icono: Icons.star_border_rounded,
      child: _resenias.isEmpty
          ? _vacio('Sin reseñas aún')
          : Column(
              children: _resenias.map((r) {
                final cal      = (r['calificacion'] as num?)?.toInt() ?? 0;
                final comentario = r['comentario'] as String?;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Estrellas
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (i) => Icon(
                              i < cal ? Icons.star : Icons.star_border,
                              size: 13,
                              color: kDorado,
                            )),
                          ),
                          if (comentario != null && comentario.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: SizedBox(
                                width: 160,
                                child: Text(
                                  comentario,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF6B7280)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        r['creado_en'] != null
                            ? _formatFecha(r['creado_en'])
                            : '',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _filaItem({
    required String nombre,
    required String detalle,
    required String badge,
    required Color  badgeColor,
    required Color  badgeTextColor,
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
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis),
                Text(detalle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280))),
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(texto,
          style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _vacio(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
          child: Text(msg,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF)))),
    );
  }

  String _formatPrecio(dynamic valor) {
    if (valor == null) return '0';
    if (valor is double) return valor.toInt().toString();
    if (valor is int)    return valor.toString();
    final n = num.tryParse(valor.toString());
    return n != null ? n.toInt().toString() : valor.toString();
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── DashCard ─────────────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String   titulo;
  final IconData icono;
  final Widget   child;
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
          Row(children: [
            Icon(icono, size: 16, color: kDorado),
            const SizedBox(width: 6),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827))),
          ]),
          const SizedBox(height: 4),
          const Divider(height: 16, thickness: 0.5),
          child,
        ],
      ),
    );
  }
}