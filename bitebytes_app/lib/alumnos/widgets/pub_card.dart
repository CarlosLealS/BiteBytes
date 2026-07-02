import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import '../tienda_detalle_page.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

// ─── Carrusel de publicaciones ─────────────────────────────────────────────────

class CarruselPublicaciones extends StatelessWidget {
  final List<Map<String, dynamic>> publicaciones;
  final Map<String, dynamic> usuario;
  final bool mostrarBotonTienda;

  const CarruselPublicaciones({
    super.key,
    required this.publicaciones,
    required this.usuario,
    this.mostrarBotonTienda = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: publicaciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => PubCard(
          pub: publicaciones[i],
          usuario: usuario,
          mostrarBotonTienda: mostrarBotonTienda,
        ),
      ),
    );
  }
}

// ─── Tarjeta de publicación ────────────────────────────────────────────────────

class PubCard extends StatelessWidget {
  final Map<String, dynamic> pub;
  final Map<String, dynamic> usuario;
  final bool mostrarBotonTienda;

  const PubCard({
    super.key,
    required this.pub,
    required this.usuario,
    this.mostrarBotonTienda = true,
  });

  @override
  Widget build(BuildContext context) {
    final imagenes   = pub['imagenes'] as List? ?? [];
    final primeraImg = imagenes.isNotEmpty
        ? imagenes[0]['imagen_url'] as String?
        : null;
    final nombre = pub['nombre']        as String? ?? '';
    final precio = pub['precio_oferta'];
    final tienda = pub['tienda_nombre'] as String? ?? '';

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: DetallePromocionCard(
            promocion: pub,
            usuario: usuario,
            mostrarBotonTienda: mostrarBotonTienda,
          ),
        ),
      ),
      child: Container(
        width: 190,
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
                            borderRadius: BorderRadius.circular(20)),
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

// ─── Detalle promoción ─────────────────────────────────────────────────────────

class DetallePromocionCard extends StatefulWidget {
  final Map<String, dynamic> promocion;
  final Map<String, dynamic> usuario;
  final bool mostrarBotonTienda;

  const DetallePromocionCard({
    super.key,
    required this.promocion,
    required this.usuario,
    this.mostrarBotonTienda = true,
  });

  @override
  State<DetallePromocionCard> createState() => _DetallePromocionCardState();
}

class _DetallePromocionCardState extends State<DetallePromocionCard> {
  bool _cargandoResenias = true;
  List<Map<String, dynamic>> _resenias = [];
  Map<String, dynamic>? _miResenia;

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';
  String get _pubId => widget.promocion['id']?.toString() ?? '';

  double get _promedio {
    if (_resenias.isEmpty) return 0;
    final suma = _resenias.fold<num>(
        0, (acc, r) => acc + (r['calificacion'] as num? ?? 0));
    return suma / _resenias.length;
  }

  @override
  void initState() {
    super.initState();
    _cargarResenias();
  }

  Future<void> _cargarResenias() async {
    if (_pubId.isEmpty) {
      setState(() => _cargandoResenias = false);
      return;
    }
    setState(() => _cargandoResenias = true);
    try {
      final headers = {'Authorization': 'Bearer $_token'};
      final res = await Future.wait([
        http.get(Uri.parse('$_base/api/publicacion/$_pubId/resenias'),   headers: headers),
        http.get(Uri.parse('$_base/api/publicacion/$_pubId/mi-resenia'), headers: headers),
      ]);
      if (!mounted) return;
      final miRes = jsonDecode(res[1].body);
      setState(() {
        _resenias = List<Map<String, dynamic>>.from(
            jsonDecode(res[0].body) as List? ?? []);
        _miResenia = miRes is Map ? Map<String, dynamic>.from(miRes) : null;
        _cargandoResenias = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoResenias = false);
    }
  }

  void _irATienda() {
    final tiendaId = widget.promocion['tienda_id']?.toString();
    if (tiendaId == null || tiendaId.isEmpty) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.push(MaterialPageRoute(
      builder: (_) => TiendaDetallePage(
        tiendaId: tiendaId,
        usuario:  widget.usuario,
      ),
    ));
  }

  void _abrirFormularioResenia() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioReseniaPublicacion(
        usuario: widget.usuario,
        publicacionId: _pubId,
        reseniaExistente: _miResenia,
        onGuardado: _cargarResenias,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final promocion   = widget.promocion;
    final imagenes    = promocion['imagenes'] as List? ?? [];
    final primeraImg  = imagenes.isNotEmpty
        ? imagenes[0]['imagen_url'] as String?
        : null;
    final tieneTienda = widget.mostrarBotonTienda &&
        (promocion['tienda_id']?.toString() ?? '').isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 500),
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
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

                      // ── Promedio de reseñas ─────────────────────────────
                      const SizedBox(height: 14),
                      if (_cargandoResenias)
                        const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Row(
                          children: [
                            _Estrellas(promedio: _promedio),
                            const SizedBox(width: 8),
                            Text(
                              _resenias.isEmpty
                                  ? 'Sin reseñas todavía'
                                  : '${_promedio.toStringAsFixed(1)} (${_resenias.length})',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),

                      // ── Botón ir a la tienda ─────────────────────────────
                      if (tieneTienda) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _irATienda,
                            icon: const Icon(Icons.storefront_outlined,
                                size: 18, color: _kAzul),
                            label: const Text('Ir a la tienda',
                                style: TextStyle(
                                    color: _kAzul,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _kAzul),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],

                      // ── Reseñas ──────────────────────────────────────────
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.star_outline_rounded,
                              size: 16, color: _kDorado),
                          const SizedBox(width: 6),
                          const Text('Reseñas',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827))),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _abrirFormularioResenia,
                            icon: Icon(
                              _miResenia != null
                                  ? Icons.edit_outlined
                                  : Icons.add,
                              size: 16, color: _kAzul,
                            ),
                            label: Text(
                              _miResenia != null
                                  ? 'Editar mi reseña'
                                  : 'Escribir reseña',
                              style: const TextStyle(
                                  color: _kAzul, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_cargandoResenias)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: _kDorado)),
                        )
                      else if (_resenias.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('Sé el primero en dejar una reseña',
                                style: TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 12)),
                          ),
                        )
                      else
                        Column(
                          children: _resenias
                              .map((r) => _ReseniaItem(resenia: r))
                              .toList(),
                        ),

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

// ─── Estrellas de promedio ──────────────────────────────────────────────────────

class _Estrellas extends StatelessWidget {
  final double promedio;
  const _Estrellas({required this.promedio});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icono;
        if (promedio >= i + 1) {
          icono = Icons.star_rounded;
        } else if (promedio > i && promedio < i + 1) {
          icono = Icons.star_half_rounded;
        } else {
          icono = Icons.star_outline_rounded;
        }
        return Icon(icono, size: 18, color: _kDorado);
      }),
    );
  }
}

// ─── Item de reseña ────────────────────────────────────────────────────────────

class _ReseniaItem extends StatelessWidget {
  final Map<String, dynamic> resenia;
  const _ReseniaItem({required this.resenia});

  @override
  Widget build(BuildContext context) {
    final nombre       = resenia['usuario_nombre'] as String? ?? 'Usuario';
    final calificacion = resenia['calificacion']   as int?    ?? 0;
    final comentario   = resenia['comentario']     as String?;
    final fecha        = _formatFecha(resenia['creado_en']?.toString() ?? '');
    final inicial      = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _kAzul.withOpacity(0.1),
                child: Text(inicial,
                    style: const TextStyle(
                        color: _kAzul,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontSize: 12,
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
                    size: 12,
                    color: _kDorado,
                  ),
                ),
              ),
            ],
          ),
          if (comentario != null && comentario.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comentario,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
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

// ─── Formulario reseña de publicación ──────────────────────────────────────────

class _FormularioReseniaPublicacion extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String publicacionId;
  final Map<String, dynamic>? reseniaExistente;
  final VoidCallback onGuardado;

  const _FormularioReseniaPublicacion({
    required this.usuario,
    required this.publicacionId,
    required this.onGuardado,
    this.reseniaExistente,
  });

  @override
  State<_FormularioReseniaPublicacion> createState() =>
      _FormularioReseniaPublicacionState();
}

class _FormularioReseniaPublicacionState
    extends State<_FormularioReseniaPublicacion> {
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
        Uri.parse('$_base/api/publicacion/${widget.publicacionId}/resenias'),
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