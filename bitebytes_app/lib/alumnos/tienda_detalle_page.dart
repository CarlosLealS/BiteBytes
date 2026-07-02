import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'widgets/pub_card.dart';
import 'widgets/menu_casino_card.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class TiendaDetallePage extends StatefulWidget {
  final String tiendaId;
  final Map<String, dynamic> usuario;

  const TiendaDetallePage({
    super.key,
    required this.tiendaId,
    required this.usuario,
  });

  @override
  State<TiendaDetallePage> createState() => _TiendaDetallePageState();
}

class _TiendaDetallePageState extends State<TiendaDetallePage> {
  bool _cargando = true;
  Map<String, dynamic>? _tienda;
  List<Map<String, dynamic>> _productos     = [];
  List<Map<String, dynamic>> _publicaciones = [];
  List<Map<String, dynamic>> _resenias      = [];
  List<Map<String, dynamic>> _menusCasino   = [];
  Map<String, dynamic>? _miResenia;
  Set<String> _favoritosIds = {};

  String get _base => Env.apiUrl;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final token   = widget.usuario['token'] ?? '';
      final headers = {'Authorization': 'Bearer $token'};
      final id      = widget.tiendaId;

      final res = await Future.wait([
        http.get(Uri.parse('$_base/api/tienda/$id'),                       headers: headers),
        http.get(Uri.parse('$_base/api/tienda/$id/productos-disponibles'), headers: headers),
        http.get(Uri.parse('$_base/api/tienda/$id/publicaciones-activas'), headers: headers),
        http.get(Uri.parse('$_base/api/tienda/$id/resenias'),              headers: headers),
        http.get(Uri.parse('$_base/api/tienda/$id/mi-resenia'),            headers: headers),
        http.get(Uri.parse('$_base/api/favoritos/ids'),                    headers: headers),
        http.get(Uri.parse('$_base/api/menu-casino/hoy'),                  headers: headers),
      ]);

      if (!mounted) return;
      setState(() {
        _tienda        = jsonDecode(res[0].body) as Map<String, dynamic>?;
        _productos     = List<Map<String, dynamic>>.from(jsonDecode(res[1].body) as List? ?? []);
        _publicaciones = List<Map<String, dynamic>>.from(jsonDecode(res[2].body) as List? ?? []);
        _resenias      = List<Map<String, dynamic>>.from(jsonDecode(res[3].body) as List? ?? []);
        final miRes    = jsonDecode(res[4].body);
        _miResenia     = miRes is Map ? Map<String, dynamic>.from(miRes) : null;
        _favoritosIds  = Set<String>.from(jsonDecode(res[5].body) as List? ?? []);

        final todosMenus = List<Map<String, dynamic>>.from(jsonDecode(res[6].body) as List? ?? []);
        _menusCasino   = todosMenus
            .where((m) => m['tienda_id']?.toString() == widget.tiendaId)
            .toList();

        _cargando      = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _toggleFavorito(String productoId) async {
    final token   = widget.usuario['token'] ?? '';
    final headers = {'Authorization': 'Bearer $token'};
    final esFav   = _favoritosIds.contains(productoId);

    setState(() {
      if (esFav) {
        _favoritosIds.remove(productoId);
      } else {
        _favoritosIds.add(productoId);
      }
    });

    try {
      if (esFav) {
        await http.delete(Uri.parse('$_base/api/favoritos/$productoId'), headers: headers);
      } else {
        await http.post(Uri.parse('$_base/api/favoritos/$productoId'), headers: headers);
      }
    } catch (_) {
      setState(() {
        if (esFav) {
          _favoritosIds.add(productoId);
        } else {
          _favoritosIds.remove(productoId);
        }
      });
    }
  }

  void _abrirFormularioResenia() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioResenia(
        usuario: widget.usuario,
        tiendaId: widget.tiendaId,
        reseniaExistente: _miResenia,
        onGuardado: _cargarDatos,
      ),
    );
  }

  void _abrirDetallePublicacion(Map<String, dynamic> pub) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: DetallePromocionCard(
        promocion: pub,
        usuario: widget.usuario,
        mostrarBotonTienda: false,
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _kDorado)),
      );
    }

    if (_tienda == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: _kAzul, foregroundColor: Colors.white),
        body: const Center(child: Text('Tienda no encontrada')),
      );
    }

    final nombre    = _tienda!['nombre']      as String? ?? '';
    final horario   = _tienda!['horario']     as String? ?? '';
    final tipo      = _tienda!['tipo']        as String? ?? '';
    final imagenUrl = (_tienda!['imagen_url'] as String? ?? '').isNotEmpty
        ? _tienda!['imagen_url'] as String
        : null;
    final valMedia  = _tienda!['valoracion_media'];
    final totalRes  = _tienda!['total_resenias'] ?? 0;
    final desc      = _tienda!['descripcion'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        slivers: [
          // ── AppBar con imagen hero ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _kAzul,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(nombre,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imagenUrl != null
                      ? Image.network(imagenUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _heroPlaceholder(tipo))
                      : _heroPlaceholder(tipo),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, _kAzul.withOpacity(0.8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info cards ──────────────────────────────────────────
                  Row(
                    children: [
                      _infoCard(Icons.schedule_outlined, 'Horario', horario),
                      const SizedBox(width: 10),
                      _infoCard(Icons.storefront_outlined, 'Tipo', tipo),
                      const SizedBox(width: 10),
                      _infoCard(
                        Icons.star_rounded,
                        'Valoración',
                        valMedia != null ? '$valMedia ★ ($totalRes)' : 'Sin reseñas',
                        color: valMedia != null ? _kDorado : null,
                      ),
                    ],
                  ),

                  // ── Descripción ─────────────────────────────────────────
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
                  ],

                  // ── Menú del día (casino) ────────────────────────────────
                  if (_menusCasino.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _seccionTitulo('Menú del día', Icons.restaurant_outlined),
                    const SizedBox(height: 12),
                    MenuCasinoList(menus: _menusCasino),
                  ],

                  // ── Publicaciones activas ───────────────────────────────
                  if (_publicaciones.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _seccionTitulo('Publicaciones activas', Icons.campaign_outlined),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 232,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _publicaciones.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _PubCard(
                          pub: _publicaciones[i],
                          onTap: () => _abrirDetallePublicacion(_publicaciones[i]),
                        ),
                      ),
                    ),
                  ],

                  // ── Productos disponibles ───────────────────────────────
                  const SizedBox(height: 24),
                  _seccionTitulo('Productos disponibles', Icons.inventory_2_outlined),
                  const SizedBox(height: 12),
                  _productos.isEmpty
                      ? const Text('Sin productos disponibles',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: _productos.length,
                          itemBuilder: (_, i) {
                            final p = _productos[i];
                            return _ProductoCard(
                              producto: p,
                              esFavorito: _favoritosIds.contains(p['id']),
                              onToggleFavorito: () => _toggleFavorito(p['id']),
                            );
                          },
                        ),

                  // ── Reseñas ─────────────────────────────────────────────
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _seccionTitulo('Reseñas', Icons.star_outline_rounded),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _abrirFormularioResenia,
                        icon: Icon(
                          _miResenia != null ? Icons.edit_outlined : Icons.add,
                          size: 16, color: _kAzul,
                        ),
                        label: Text(
                          _miResenia != null ? 'Editar mi reseña' : 'Escribir reseña',
                          style: const TextStyle(color: _kAzul, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _resenias.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 0.5),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 32, color: Color(0xFFD1D5DB)),
                              SizedBox(height: 8),
                              Text('Sé el primero en dejar una reseña',
                                  style: TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 13)),
                            ],
                          ),
                        )
                      : Column(
                          children: _resenias
                              .map((r) => _ReseniaCard(resenia: r))
                              .toList(),
                        ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPlaceholder(String tipo) {
    final icono = tipo == 'casino'
        ? Icons.restaurant
        : tipo == 'cafeteria'
            ? Icons.coffee_outlined
            : Icons.store_outlined;
    return Container(
      color: _kAzul,
      child: Center(child: Icon(icono, size: 64, color: Colors.white24)),
    );
  }

  Widget _infoCard(IconData icono, String label, String valor, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 16, color: color ?? _kDorado),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(valor,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color ?? const Color(0xFF111827)),
                overflow: TextOverflow.ellipsis),
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
      ],
    );
  }
}

// ─── Tarjeta publicación ───────────────────────────────────────────────────────

class _PubCard extends StatelessWidget {
  final Map<String, dynamic> pub;
  final VoidCallback onTap;

  const _PubCard({required this.pub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imagenes   = pub['imagenes'] as List? ?? [];
    final primeraImg = imagenes.isNotEmpty ? imagenes[0]['imagen_url'] as String? : null;
    final nombre     = pub['nombre']        as String? ?? '';
    final precio     = pub['precio_oferta'];
    final desc       = pub['descripcion']   as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
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
                  // Badge "Activa"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Activa',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 6),

                  // Nombre
                  Text(nombre,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),

                  // Descripción
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],

                  const SizedBox(height: 8),

                  // Precio + hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (precio != null)
                        Text('\$$precio',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kAzul)),
                      const Text('Ver más →',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
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
        child: Icon(Icons.campaign_outlined, size: 28, color: Color(0xFFD1D5DB))),
  );
}

// ─── Tarjeta producto ──────────────────────────────────────────────────────────

class _ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final bool esFavorito;
  final VoidCallback onToggleFavorito;

  const _ProductoCard({
    required this.producto,
    required this.esFavorito,
    required this.onToggleFavorito,
  });

  @override
  Widget build(BuildContext context) {
    final nombre    = producto['nombre']     as String? ?? '';
    final precio    = producto['precio'];
    final imagenUrl = producto['imagen_url'] as String?;
    final categoria = producto['categoria']  as String?;
    final valMedia  = producto['valoracion_media'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  height: 90, width: double.infinity,
                  child: imagenUrl != null && imagenUrl.isNotEmpty
                      ? Image.network(imagenUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
              ),
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: onToggleFavorito,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      esFavorito ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: esFavorito ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categoria != null)
                  Text(categoria,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (precio != null)
                      Text('\$$precio',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kAzul)),
                    if (valMedia != null)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 11, color: _kDorado),
                          const SizedBox(width: 2),
                          Text(valMedia.toString(),
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF6B7280))),
                        ],
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

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(
        child: Icon(Icons.fastfood_outlined, size: 28, color: Color(0xFFD1D5DB))),
  );
}

// ─── Tarjeta reseña ────────────────────────────────────────────────────────────

class _ReseniaCard extends StatelessWidget {
  final Map<String, dynamic> resenia;
  const _ReseniaCard({required this.resenia});

  @override
  Widget build(BuildContext context) {
    final nombre      = resenia['usuario_nombre'] as String? ?? 'Usuario';
    final calificacion = resenia['calificacion']  as int?    ?? 0;
    final comentario  = resenia['comentario']     as String?;
    final fecha       = _formatFecha(resenia['creado_en']?.toString() ?? '');
    final inicial     = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: _kAzul.withOpacity(0.1),
                child: Text(inicial,
                    style: const TextStyle(
                        color: _kAzul,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827))),
                    Text(fecha,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < calificacion
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: _kDorado,
                  ),
                ),
              ),
            ],
          ),
          if (comentario != null && comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comentario,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
          ],
        ],
      ),
    );
  }

  String _formatFecha(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Hoy';
      if (diff.inDays == 1) return 'Ayer';
      if (diff.inDays < 7) return 'hace ${diff.inDays} días';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Formulario reseña ─────────────────────────────────────────────────────────

class _FormularioResenia extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String tiendaId;
  final Map<String, dynamic>? reseniaExistente;
  final VoidCallback onGuardado;

  const _FormularioResenia({
    required this.usuario,
    required this.tiendaId,
    required this.onGuardado,
    this.reseniaExistente,
  });

  @override
  State<_FormularioResenia> createState() => _FormularioReseniaState();
}

class _FormularioReseniaState extends State<_FormularioResenia> {
  final _comentarioCtrl = TextEditingController();
  int  _calificacion = 0;
  bool _guardando    = false;

  String get _base => Env.apiUrl;

  @override
  void initState() {
    super.initState();
    if (widget.reseniaExistente != null) {
      _calificacion        = widget.reseniaExistente!['calificacion'] as int?    ?? 0;
      _comentarioCtrl.text = widget.reseniaExistente!['comentario']   as String? ?? '';
    }
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_calificacion == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona una calificación'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final token = widget.usuario['token'] ?? '';
      await http.post(
        Uri.parse('$_base/api/tienda/${widget.tiendaId}/resenias'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'calificacion': _calificacion,
          'comentario': _comentarioCtrl.text.trim().isEmpty
              ? null
              : _comentarioCtrl.text.trim(),
        }),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onGuardado();
    } catch (_) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error al guardar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.reseniaExistente != null ? 'Editar reseña' : 'Escribir reseña',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // Estrellas
          const Text('Calificación',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151))),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => setState(() => _calificacion = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    i < _calificacion
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 36,
                    color: _kDorado,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Comentario
          TextField(
            controller: _comentarioCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cuéntanos tu experiencia (opcional)...',
              hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kAzul),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Publicar reseña',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}