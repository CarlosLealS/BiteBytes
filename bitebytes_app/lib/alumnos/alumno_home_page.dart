import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import '../login.dart';
import 'search_page.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);
final _kBase   = Env.apiUrl;

class AlumnoHomePage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AlumnoHomePage({super.key, required this.usuario});

  @override
  State<AlumnoHomePage> createState() => _AlumnoHomePageState();
}

class _AlumnoHomePageState extends State<AlumnoHomePage> {
  int _seccionActual = 0;
  bool _cargando = true;
  List<Map<String, dynamic>> _menusCasino        = [];
  List<Map<String, dynamic>> _publicaciones      = [];
  List<Map<String, dynamic>> _tiendas            = [];
  List<Map<String, dynamic>> _resultadosBusqueda = [];
  final _busquedaCtrl = TextEditingController();
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final token   = widget.usuario['token'] ?? '';
      final headers = {'Authorization': 'Bearer $token'};
      print('Token: $token');
      print('Base URL: $_kBase');
      
      final res = await Future.wait([
        http.get(Uri.parse('$_kBase/api/menu-casino/hoy'),       headers: headers),
        http.get(Uri.parse('$_kBase/api/publicaciones/activas'), headers: headers),
        http.get(Uri.parse('$_kBase/api/tiendas'),               headers: headers),
      ]);
      
      print('Respuestas recibidas:');
      print('Menú Casino: ${res[0].statusCode} - ${res[0].body}');
      print('Publicaciones: ${res[1].statusCode} - ${res[1].body}');
      print('Tiendas: ${res[2].statusCode} - ${res[2].body}');
      
      if (!mounted) return;
      setState(() {
        _menusCasino   = List<Map<String, dynamic>>.from(jsonDecode(res[0].body) as List? ?? []);
        _publicaciones = List<Map<String, dynamic>>.from(jsonDecode(res[1].body) as List? ?? []);
        _tiendas       = List<Map<String, dynamic>>.from(jsonDecode(res[2].body) as List? ?? []);
        _cargando      = false;
        print('Datos cargados: menús=${_menusCasino.length}, publicaciones=${_publicaciones.length}, tiendas=${_tiendas.length}');
      });
    } catch (e) {
      print('Error cargando datos: $e');
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
      final token = widget.usuario['token'] ?? '';
      final res = await http.get(
        Uri.parse('$_kBase/api/productos/buscar?q=${Uri.encodeComponent(query)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      setState(() {
        _resultadosBusqueda = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List? ?? []);
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      final token = widget.usuario['token'] ?? '';
      if (token.isEmpty) {
        _limpiarURLYNavegar();
        return;
      }

      await http.post(
        Uri.parse('$_kBase/api/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      // Aunque haya error, procedemos a navegar
    } finally {
      if (mounted) {
        _limpiarURLYNavegar();
      }
    }
  }

  void _limpiarURLYNavegar() {
    // Limpiar parámetros de URL para evitar redirección automática
    html.window.history.replaceState(null, '', Uri.base.toString().split('?')[0]);
    _navegarAlLogin();
  }

  void _navegarAlLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _Navbar(
            usuario: widget.usuario,
            seccionActual: _seccionActual,
            onSeccion: (i) => setState(() => _seccionActual = i),
            busquedaCtrl: _busquedaCtrl,
            onBuscar: _buscarProductos,
            onLogout: _cerrarSesion,
          ),
          Expanded(
            child: _busquedaCtrl.text.isNotEmpty
                ? _PantallaResultados(
                    query: _busquedaCtrl.text,
                    resultados: _resultadosBusqueda,
                    buscando: _buscando,
                  )
                : _seccionActual == 0
                    ? _PantallaInicio(
                        cargando: _cargando,
                        menusCasino: _menusCasino,
                        publicaciones: _publicaciones,
                        tiendas: _tiendas,
                        onRefresh: _cargarDatos,
                      )
                    : _PantallaMapa(usuario: widget.usuario),
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
    final iniciales = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

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
          _navLink('Inicio', 0, seccionActual, onSeccion),
          const SizedBox(width: 4),
          _navLink('Mapa', 1, seccionActual, onSeccion),
          const SizedBox(width: 16),
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
              child: Text(iniciales,
                  style: const TextStyle(
                      color: _kDorado, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLink(String label, int index, int actual, ValueChanged<int> onTap) {
    final activo = actual == index;
    return GestureDetector(
      onTap: () => onTap(index),
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
  final Future<void> Function() onRefresh;

  const _PantallaInicio({
    required this.cargando,
    required this.menusCasino,
    required this.publicaciones,
    required this.tiendas,
    required this.onRefresh,
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
              onVerOfertas: () => _scrollCtrl.animateTo(
                400,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.menusCasino.isNotEmpty) ...[
                    _seccionTitulo('Menú Casino — hoy', Icons.restaurant_outlined),
                    const SizedBox(height: 12),
                    _MenuCasinoGrid(menus: widget.menusCasino),
                    const SizedBox(height: 24),
                  ],
                  if (widget.publicaciones.isNotEmpty) ...[
                    _seccionTitulo('Publicaciones activas', Icons.campaign_outlined),
                    const SizedBox(height: 12),
                    _CarruselPublicaciones(publicaciones: widget.publicaciones),
                    const SizedBox(height: 24),
                  ],
                  _seccionTitulo('Tiendas del campus', Icons.store_outlined),
                  const SizedBox(height: 12),
                  _GridTiendas(tiendas: widget.tiendas),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionTitulo(String label, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: _kDorado),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ],
    );
  }
}

// ─── Banner hero ───────────────────────────────────────────────────────────────

class _BannerHero extends StatelessWidget {
  final VoidCallback? onVerOfertas;
  const _BannerHero({this.onVerOfertas});

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
                      fontSize: 44,
                      fontFamily: 'FugazOne',
                      color: Colors.white,
                      height: 1.1,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Descubre las mejores promociones\ncerca de ti',
                  style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: onVerOfertas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kDorado,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ver ofertas',
                            style: TextStyle(
                              color: _kAzul,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
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

// ─── Menú Casino Grid ──────────────────────────────────────────────────────────

class _MenuCasinoGrid extends StatelessWidget {
  final List<Map<String, dynamic>> menus;
  const _MenuCasinoGrid({required this.menus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: menus.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _MenuCasinoCard(menu: menus[i]),
      ),
    );
  }
}

class _MenuCasinoCard extends StatelessWidget {
  final Map<String, dynamic> menu;
  const _MenuCasinoCard({required this.menu});

  @override
  Widget build(BuildContext context) {
    final nombre  = menu['nombre'] as String? ?? menu['tienda_nombre'] as String? ?? 'Casino';
    final platos  = (menu['platos'] as List? ?? []).cast<Map<String, dynamic>>();
    // Muestra hasta 3 platos en la tarjeta
    final preview = platos.take(3).toList();

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _MenuCasinoDetalle(menu: menu),
      ),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F5C), Color(0xFF1A3580)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kAzul.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kDorado.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, color: _kDorado, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),

            // Platos preview
            if (preview.isEmpty)
              const Text('Sin platos registrados',
                  style: TextStyle(color: Colors.white38, fontSize: 11))
            else
              ...preview.map((p) => _platoRow(p)),

            const Spacer(),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${platos.length} plato${platos.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Ver menú →',
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _platoRow(Map<String, dynamic> plato) {
    final etiqueta = plato['etiqueta'] as String?;
    final nombre   = plato['nombre']   as String? ?? '';
    final precio   = plato['precio'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (etiqueta != null)
            SizedBox(
              width: 50,
              child: Text(etiqueta,
                  style: TextStyle(
                      color: _kDorado.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(nombre,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ),
          if (precio != null)
            Text('\$$precio',
                style: const TextStyle(
                    color: _kDorado, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Detalle Menú Casino ───────────────────────────────────────────────────────

class _MenuCasinoDetalle extends StatelessWidget {
  final Map<String, dynamic> menu;
  const _MenuCasinoDetalle({required this.menu});

  @override
  Widget build(BuildContext context) {
    final nombre      = menu['nombre']        as String? ?? menu['tienda_nombre'] as String? ?? 'Casino';
    final tienda      = menu['tienda_nombre'] as String? ?? '';
    final descripcion = menu['descripcion']   as String?;
    final platos      = (menu['platos'] as List? ?? []).cast<Map<String, dynamic>>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _kAzul,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _kDorado.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant, color: _kDorado, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        if (tienda.isNotEmpty)
                          Text(tienda,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),

            // Descripción
            if (descripcion != null && descripcion.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: _kAzul.withOpacity(0.05),
                child: Text(descripcion,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic)),
              ),

            // Lista de platos
            Flexible(
              child: platos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Sin platos registrados',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: platos.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 20, endIndent: 20),
                      itemBuilder: (_, i) => _PlatoTile(plato: platos[i]),
                    ),
            ),

            // Botón cerrar
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cerrar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatoTile extends StatelessWidget {
  final Map<String, dynamic> plato;
  const _PlatoTile({required this.plato});

  @override
  Widget build(BuildContext context) {
    final nombre      = plato['nombre']      as String? ?? '';
    final descripcion = plato['descripcion'] as String?;
    final etiqueta    = plato['etiqueta']    as String?;
    final precio      = plato['precio'];
    final imagenUrl   = plato['imagen_url']  as String?;
    final valoracion  = plato['valoracion_media'];
    final totalRes    = plato['total_resenias'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen o ícono
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56, height: 56,
              child: imagenUrl != null && imagenUrl.isNotEmpty
                  ? Image.network(imagenUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconoPlaceholder())
                  : _iconoPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Etiqueta + nombre
                Row(
                  children: [
                    if (etiqueta != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kDorado.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(etiqueta,
                            style: const TextStyle(
                                fontSize: 9,
                                color: _kDorado,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),

                // Descripción
                if (descripcion != null && descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(descripcion,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 6),

                // Precio + valoración
                Row(
                  children: [
                    if (precio != null)
                      Text('\$$precio',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kAzul)),
                    const Spacer(),
                    if (valoracion != null && valoracion.toString() != 'null') ...[
                      const Icon(Icons.star_rounded,
                          size: 14, color: _kDorado),
                      const SizedBox(width: 2),
                      Text(valoracion.toString(),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      if (totalRes != null && int.tryParse(totalRes.toString())! > 0)
                        Text(' ($totalRes)',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconoPlaceholder() => Container(
    color: const Color(0xFFF3F4F6),
    child: const Center(
        child: Icon(Icons.restaurant_menu,
            size: 24, color: Color(0xFFD1D5DB))),
  );
}

// ─── Carrusel publicaciones ────────────────────────────────────────────────────

class _CarruselPublicaciones extends StatelessWidget {
  final List<Map<String, dynamic>> publicaciones;
  const _CarruselPublicaciones({required this.publicaciones});

  @override
  Widget build(BuildContext context) {
    print('_CarruselPublicaciones: ${publicaciones.length} publicaciones');
    for (var i = 0; i < publicaciones.length; i++) {
      final pub = publicaciones[i];
      print('Pub $i: ${pub['nombre']} - Tienda: ${pub['tienda_nombre']} - Imagenes: ${pub['imagenes']}');
    }
    
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: publicaciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _PubCard(pub: publicaciones[i]),
      ),
    );
  }
}

class _PubCard extends StatelessWidget {
  final Map<String, dynamic> pub;
  const _PubCard({required this.pub});

  @override
  Widget build(BuildContext context) {
    final imagenes   = pub['imagenes'] as List? ?? [];
    print('_PubCard: imagenes recibidas = $imagenes');
    final primeraImg = imagenes.isNotEmpty ? imagenes[0]['imagen_url'] as String? : null;
    print('_PubCard: primeraImg = $primeraImg');
    
    final nombre     = pub['nombre'] ?? '';
    final precio     = pub['precio_oferta'];
    final tienda     = pub['tienda_nombre'] ?? '';

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: DetallePromocionCard(promocion: pub),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 100, width: double.infinity,
                child: primeraImg != null
                    ? Image.network(primeraImg, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tienda.isNotEmpty)
                    Text(tienda,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280))),
                  const SizedBox(height: 2),
                  Text(nombre,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827)),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (precio != null)
                        Text('\$$precio',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _kAzul)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Activa',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(
        child: Icon(Icons.campaign_outlined,
            size: 28, color: Color(0xFFD1D5DB))),
  );
}

// ─── Grid tiendas ──────────────────────────────────────────────────────────────

class _GridTiendas extends StatelessWidget {
  final List<Map<String, dynamic>> tiendas;
  const _GridTiendas({required this.tiendas});

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
        final t    = tiendas[i];
        final tipo = t['tipo'] as String? ?? '';
        final color = _colorTipo(tipo);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(tipo,
                            style: TextStyle(fontSize: 10, color: color)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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

  const _PantallaResultados({
    required this.query,
    required this.resultados,
    required this.buscando,
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
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 14)),
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
        childAspectRatio: 0.85,
      ),
      itemCount: resultados.length,
      itemBuilder: (_, i) {
        final p         = resultados[i];
        final imagenUrl = p['imagen_url'] as String?;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
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
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280))),
                    const SizedBox(height: 2),
                    Text(p['nombre'] ?? '',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('\$${p['precio'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kAzul)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(
        child: Icon(Icons.fastfood_outlined,
            size: 32, color: Color(0xFFD1D5DB))),
  );
}

// ─── Detalle promoción ─────────────────────────────────────────────────────────

class DetallePromocionCard extends StatelessWidget {
  final Map<String, dynamic> promocion;
  const DetallePromocionCard({super.key, required this.promocion});

  @override
  Widget build(BuildContext context) {
    final imagenes   = promocion['imagenes'] as List? ?? [];
    final primeraImg = imagenes.isNotEmpty
        ? imagenes[0]['imagen_url'] as String?
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 500),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: primeraImg != null
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(
                              minHeight: 180, maxHeight: 300),
                          child: Image.network(primeraImg,
                              fit: BoxFit.cover, width: double.infinity),
                        )
                      : Container(
                          height: 160,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.image_not_supported,
                                size: 48, color: Colors.grey),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(promocion['nombre'] ?? '',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _kAzul)),
                      const SizedBox(height: 8),
                      Text(promocion['descripcion'] ?? 'Sin descripción',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
                      const SizedBox(height: 12),
                      if (promocion['precio_oferta'] != null)
                        Text('\$${promocion['precio_oferta']}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _kDorado)),
                      const SizedBox(height: 8),
                      Text('Tienda: ${promocion['tienda_nombre'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAzul,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pantalla mapa ─────────────────────────────────────────────────────────────

class _PantallaMapa extends StatelessWidget {
  final Map<String, dynamic> usuario;
  const _PantallaMapa({required this.usuario});

  @override
  Widget build(BuildContext context) => SearchPage(usuario: usuario);
}