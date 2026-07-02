import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import '../login.dart';
import 'search_page.dart';
import 'tienda_detalle_page.dart';
import 'tienda_modal.dart';
import 'widgets/pub_card.dart';
import 'widgets/menu_casino_card.dart';
import 'ofertas_page.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

// ─── Página principal ──────────────────────────────────────────────────────────

class AlumnoHomePage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AlumnoHomePage({super.key, required this.usuario});

  @override
  State<AlumnoHomePage> createState() => _AlumnoHomePageState();
}

class _AlumnoHomePageState extends State<AlumnoHomePage> {
  int  _seccionActual = 0;
  bool _cargando      = true;

  List<Map<String, dynamic>> _menusCasino        = [];
  List<Map<String, dynamic>> _publicaciones      = [];
  List<Map<String, dynamic>> _tiendas            = [];
  List<Map<String, dynamic>> _resultadosBusqueda = [];

  final _busquedaCtrl = TextEditingController();
  bool _buscando = false;

  // Sanción activa
  Map<String, dynamic>? _sancion;

  String get _token    => widget.usuario['token'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarSancion();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSancion() async {
    try {
      final res = await http.get(
        Uri.parse('${Env.apiUrl}/api/mi-sancion'),
        headers: _headers,
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _sancion = data['sancionado'] == true ? data : null);
      }
    } catch (_) {}
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final base = Env.apiUrl;
      final res  = await Future.wait([
        http.get(Uri.parse('$base/api/menu-casino/hoy'),       headers: _headers),
        http.get(Uri.parse('$base/api/publicaciones/activas'), headers: _headers),
        http.get(Uri.parse('$base/api/tiendas'),               headers: _headers),
      ]);
      if (!mounted) return;
      setState(() {
        _menusCasino   = _parseList(res[0].body);
        _publicaciones = _parseList(res[1].body);
        _tiendas       = _parseList(res[2].body);
        _cargando      = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _buscarProductos(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _resultadosBusqueda = []; _buscando = false; });
      return;
    }
    setState(() => _buscando = true);
    try {
      final res = await http.get(
        Uri.parse('${Env.apiUrl}/api/productos/buscar?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      );
      if (!mounted) return;
      setState(() {
        _resultadosBusqueda = _parseList(res.body);
        _buscando           = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      await http.post(
        Uri.parse('${Env.apiUrl}/api/auth/logout'),
        headers: _headers,
      );
    } catch (_) {}
    if (!mounted) return;
    html.window.history.replaceState(null, '', Uri.base.toString().split('?')[0]);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _irATienda(String tiendaId) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TiendaDetallePage(
        tiendaId: tiendaId,
        usuario:  widget.usuario,
      ),
    ));
  }

  List<Map<String, dynamic>> _parseList(String body) =>
      List<Map<String, dynamic>>.from(jsonDecode(body) as List? ?? []);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _Navbar(
            usuario:      widget.usuario,
            seccionActual: _seccionActual,
            onSeccion:    (i) => setState(() => _seccionActual = i),
            busquedaCtrl: _busquedaCtrl,
            onBuscar:     _buscarProductos,
            onLogout:     _cerrarSesion,
          ),
          // Banner de sanción activa
          if (_sancion != null) _BannerSancion(sancion: _sancion!),
          Expanded(
            child: _busquedaCtrl.text.isNotEmpty
                ? _PantallaResultados(
                    query:     _busquedaCtrl.text,
                    resultados: _resultadosBusqueda,
                    buscando:  _buscando,
                    usuario:   widget.usuario,
                    onIrTienda: _irATienda,
                  )
                : _seccionActual == 0
                    ? _PantallaInicio(
                        cargando:      _cargando,
                        menusCasino:   _menusCasino,
                        publicaciones: _publicaciones,
                        tiendas:       _tiendas,
                        usuario:       widget.usuario,
                        onRefresh:     _cargarDatos,
                        onIrTienda:    _irATienda,
                      )
                    : _PantallaMapa(usuario: widget.usuario),
          ),
        ],
      ),
    );
  }
}

// ─── Banner de Sanción ─────────────────────────────────────────────────────────

class _BannerSancion extends StatelessWidget {
  final Map<String, dynamic> sancion;
  const _BannerSancion({required this.sancion});

  String _tiempoRestante() {
    final fin = sancion['fin'] != null ? DateTime.tryParse(sancion['fin']) : null;
    if (fin == null) return 'indefinida';
    final ahora   = DateTime.now();
    final restante = fin.toLocal().difference(ahora);
    if (restante.isNegative) return 'terminada';
    final dias  = restante.inDays;
    final horas = restante.inHours.remainder(24);
    final mins  = restante.inMinutes.remainder(60);
    if (dias > 0) return '$dias d ${horas}h ${mins}m';
    if (horas > 0) return '${horas}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final motivo = sancion['motivo'] as String? ?? 'Infracción a las normas comunitarias';
    final tiempo = _tiempoRestante();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1111), Color(0xFFB71C1C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu cuenta tiene una sanción activa',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Motivo: $motivo',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Tiempo restante: $tiempo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Navbar ────────────────────────────────────────────────────────────────────

class _Navbar extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final int seccionActual;
  final ValueChanged<int> onSeccion;
  final TextEditingController busquedaCtrl;
  final ValueChanged<String> onBuscar;
  final VoidCallback onLogout;

  const _Navbar({
    required this.usuario,
    required this.seccionActual,
    required this.onSeccion,
    required this.busquedaCtrl,
    required this.onBuscar,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final nombre   = usuario['nombre'] as String? ?? 'U';
    final inicial  = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Container(
      height: 56,
      color: _kAzul,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Image.asset('assets/logo-ucn.png', height: 36, width: 36),
          const SizedBox(width: 10),
          const Text('BiteBytes',
              style: TextStyle(color: _kDorado, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(width: 20),
          _navLink('Inicio', 0),
          const SizedBox(width: 4),
          _navLink('Mapa', 1),
          const SizedBox(width: 16),

          // Buscador
          Expanded(
            child: Container(
              height: 34,
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: busquedaCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Buscar productos en todas las tiendas...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: onBuscar,
                    ),
                  ),
                  if (busquedaCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () { busquedaCtrl.clear(); onBuscar(''); },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.close, color: Colors.white54, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Avatar
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => PerfilModal(usuario: usuario, onLogout: onLogout),
            ),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: _kDorado.withOpacity(0.2),
              child: Text(inicial,
                  style: const TextStyle(
                      color: _kDorado, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLink(String label, int index) {
    final activo = seccionActual == index;
    return GestureDetector(
      onTap: () => onSeccion(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? _kDorado.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
              color: activo ? _kDorado : Colors.white54,
              fontSize: 12,
              fontWeight: activo ? FontWeight.w500 : FontWeight.w400,
            )),
      ),
    );
  }
}

// ─── Pantalla inicio ───────────────────────────────────────────────────────────

class _PantallaInicio extends StatefulWidget {
  final bool cargando;
  final List<Map<String, dynamic>> menusCasino;
  final List<Map<String, dynamic>> publicaciones;
  final List<Map<String, dynamic>> tiendas;
  final Map<String, dynamic> usuario;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onIrTienda;

  const _PantallaInicio({
    required this.cargando,
    required this.menusCasino,
    required this.publicaciones,
    required this.tiendas,
    required this.usuario,
    required this.onRefresh,
    required this.onIrTienda,
  });

  @override
  State<_PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<_PantallaInicio> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cargando) {
      return const Center(child: CircularProgressIndicator(color: _kDorado));
    }
    return RefreshIndicator(
      color: _kDorado,
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BannerHero(
              usuario:      widget.usuario,
              onVerOfertas: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfertasPage(usuario: widget.usuario),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.menusCasino.isNotEmpty) ...[
                    _titulo('Menú Casino — hoy', Icons.restaurant_outlined),
                    const SizedBox(height: 12),
                    MenuCasinoList(menus: widget.menusCasino),
                    const SizedBox(height: 24),
                  ],
                  if (widget.publicaciones.isNotEmpty) ...[
                    _titulo('Publicaciones activas', Icons.campaign_outlined),
                    const SizedBox(height: 12),
                    CarruselPublicaciones(
                      publicaciones: widget.publicaciones,
                      usuario: widget.usuario,
                    ),
                    const SizedBox(height: 24),
                  ],
                  _titulo('Tiendas del campus', Icons.store_outlined),
                  const SizedBox(height: 12),
                  _GridTiendas(
                    tiendas: widget.tiendas,
                    onIrTienda: widget.onIrTienda,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String label, IconData icono) => Row(
    children: [
      Icon(icono, size: 16, color: _kDorado),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
    ],
  );
}

// ─── Banner hero ───────────────────────────────────────────────────────────────

class _BannerHero extends StatelessWidget {
  final VoidCallback? onVerOfertas;
  final Map<String, dynamic> usuario;
  const _BannerHero({this.onVerOfertas, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Fondo_home.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.1),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bite Bytes',
                    style: TextStyle(
                        fontSize: 44, fontFamily: 'FugazOne',
                        color: Colors.white, height: 1.1)),
                const SizedBox(height: 8),
                const Text('Descubre las mejores promociones\ncerca de ti',
                    style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5)),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: onVerOfertas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                        color: _kDorado, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ver ofertas',
                            style: TextStyle(color: _kAzul, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: _kAzul),
                      ],
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

// ─── Grid tiendas ──────────────────────────────────────────────────────────────

class _GridTiendas extends StatelessWidget {
  final List<Map<String, dynamic>> tiendas;
  final ValueChanged<String> onIrTienda;

  const _GridTiendas({required this.tiendas, required this.onIrTienda});

  static Color _colorTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'casino':    return const Color(0xFF0B1F5C);
      case 'cafeteria': return const Color(0xFFE8751A);
      case 'kiosco':    return const Color(0xFF6B7280);
      default:          return const Color(0xFF374151);
    }
  }

  static IconData _iconoTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'casino':    return Icons.restaurant;
      case 'cafeteria': return Icons.coffee_outlined;
      case 'kiosco':    return Icons.storefront_outlined;
      default:          return Icons.store_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tiendas.isEmpty) {
      return const Center(
        child: Text('Sin tiendas disponibles',
            style: TextStyle(color: Color(0xFF9CA3AF))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 68,
      ),
      itemCount: tiendas.length,
      itemBuilder: (_, i) {
        final t     = tiendas[i];
        final tipo  = t['tipo'] as String? ?? '';
        final color = _colorTipo(tipo);
        final id    = t['id'] as String? ?? '';

        return InkWell(
          onTap: () => onIrTienda(id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(_iconoTipo(tipo), size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t['nombre'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(tipo, style: TextStyle(fontSize: 10, color: color)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Resultados búsqueda ───────────────────────────────────────────────────────

class _PantallaResultados extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> resultados;
  final bool buscando;
  final Map<String, dynamic> usuario;
  final ValueChanged<String> onIrTienda;

  const _PantallaResultados({
    required this.query,
    required this.resultados,
    required this.buscando,
    required this.usuario,
    required this.onIrTienda,
  });

  @override
  Widget build(BuildContext context) {
    if (buscando) {
      return const Center(child: CircularProgressIndicator(color: _kDorado));
    }
    if (resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text('Sin resultados para "$query"',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: resultados.length,
      itemBuilder: (_, i) {
        final p         = resultados[i];
        final imagenUrl = p['imagen_url'] as String?;
        final tiendaId  = p['tienda_id'] as String? ?? '';

        return InkWell(
          onTap: () => onIrTienda(tiendaId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    height: 100, width: double.infinity,
                    child: imagenUrl != null && imagenUrl.isNotEmpty
                        ? Image.network(imagenUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['tienda_nombre'] ?? '',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                      const SizedBox(height: 2),
                      Text(p['nombre'] ?? '',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: Color(0xFF111827)),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('\$${p['precio'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: _kAzul)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(child: Icon(Icons.fastfood_outlined, size: 32, color: Color(0xFFD1D5DB))),
  );
}

// ─── Pantalla mapa ─────────────────────────────────────────────────────────────

class _PantallaMapa extends StatelessWidget {
  final Map<String, dynamic> usuario;
  const _PantallaMapa({required this.usuario});

  @override
  Widget build(BuildContext context) => SearchPage(usuario: usuario);
}

// ─── Modal perfil ──────────────────────────────────────────────────────────────

class PerfilModal extends StatelessWidget {
  final Map<String, dynamic>? usuario;
  final VoidCallback? onLogout;
  const PerfilModal({super.key, this.usuario, this.onLogout});

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
              onPressed: onLogout,
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