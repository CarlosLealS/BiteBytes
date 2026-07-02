import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class TiendaPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const TiendaPage({super.key, required this.usuario});

  @override
  State<TiendaPage> createState() => _TiendaPageState();
}

class _TiendaPageState extends State<TiendaPage> {
  bool _cargando = true;
  Map<String, dynamic>? _tienda;
  List<Map<String, dynamic>> _productos     = [];
  List<Map<String, dynamic>> _publicaciones = [];
  List<Map<String, dynamic>> _resenias      = [];

  String get _base      => Env.apiUrl;
  String get _token     => widget.usuario['token'] ?? '';
  String get _tiendaId  => widget.usuario['tienda_id'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final res = await Future.wait([
        http.get(Uri.parse('$_base/api/tienda/$_tiendaId'),                       headers: _headers),
        http.get(Uri.parse('$_base/api/tienda/$_tiendaId/productos-disponibles'), headers: _headers),
        http.get(Uri.parse('$_base/api/tienda/$_tiendaId/publicaciones-activas'), headers: _headers),
        http.get(Uri.parse('$_base/api/tienda/$_tiendaId/resenias'),              headers: _headers),
      ]);
      if (!mounted) return;
      setState(() {
        _tienda        = jsonDecode(res[0].body) as Map<String, dynamic>?;
        _productos     = List<Map<String, dynamic>>.from(jsonDecode(res[1].body) as List? ?? []);
        _publicaciones = List<Map<String, dynamic>>.from(jsonDecode(res[2].body) as List? ?? []);
        _resenias      = List<Map<String, dynamic>>.from(jsonDecode(res[3].body) as List? ?? []);
        _cargando      = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _abrirEditor() {
    if (_tienda == null) return;
    showDialog(
      context: context,
      builder: (_) => _FormularioTienda(
        usuario:  widget.usuario,
        tienda:   _tienda!,
        onGuardado: _cargarDatos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kDorado));
    }

    if (_tienda == null) {
      return const Center(
        child: Text('No se encontró información de tu tienda',
            style: TextStyle(color: Color(0xFF9CA3AF))),
      );
    }

    final nombre    = _tienda!['nombre']      as String? ?? '';
    final horario   = _tienda!['horario']     as String? ?? '';
    final tipo      = _tienda!['tipo']        as String? ?? '';
    final desc      = _tienda!['descripcion'] as String?;
    final imagenUrl = (_tienda!['imagen_url'] as String? ?? '').isNotEmpty
        ? _tienda!['imagen_url'] as String : null;
    final valMedia  = _tienda!['valoracion_media'];
    final totalRes  = _tienda!['total_resenias'] ?? 0;

    return RefreshIndicator(
      color: _kDorado,
      onRefresh: _cargarDatos,
      child: CustomScrollView(
        slivers: [
          // Hero con imagen
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Imagen hero
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
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
                            colors: [Colors.transparent, _kAzul.withOpacity(0.85)],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16, left: 20, right: 20,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombre,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 22,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _kDorado.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(tipo,
                                        style: const TextStyle(
                                            color: _kDorado, fontSize: 11,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón editar
                Positioned(
                  top: 12, right: 12,
                  child: ElevatedButton.icon(
                    onPressed: _abrirEditor,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar tienda'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _kAzul,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info cards
                  Row(
                    children: [
                      _infoCard(Icons.schedule_outlined, 'Horario', horario),
                      const SizedBox(width: 10),
                      _infoCard(
                        Icons.star_rounded,
                        'Valoración',
                        valMedia != null
                            ? '$valMedia ★ ($totalRes reseñas)'
                            : 'Sin reseñas aún',
                        color: valMedia != null ? _kDorado : null,
                      ),
                    ],
                  ),

                  // Descripción
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB), width: 0.5),
                      ),
                      child: Text(desc,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280),
                              height: 1.5)),
                    ),
                  ],

                  // Publicaciones activas
                  if (_publicaciones.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _seccionTitulo('Publicaciones activas', Icons.campaign_outlined),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _publicaciones.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _PubCard(pub: _publicaciones[i]),
                      ),
                    ),
                  ],

                  // Productos
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _seccionTitulo('Productos', Icons.inventory_2_outlined),
                      const Spacer(),
                      Text('${_productos.length} disponibles',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _productos.isEmpty
                      ? _estadoVacio('Sin productos disponibles',
                          Icons.inventory_2_outlined)
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _productos.length,
                          itemBuilder: (_, i) =>
                              _ProductoCard(producto: _productos[i]),
                        ),

                  // Reseñas
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _seccionTitulo('Reseñas', Icons.star_outline_rounded),
                      const Spacer(),
                      Text('${_resenias.length} reseñas',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _resenias.isEmpty
                      ? _estadoVacio(
                          'Aún no tienes reseñas', Icons.rate_review_outlined)
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
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(valor,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: color ?? const Color(0xFF111827)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _seccionTitulo(String label, IconData icono) => Row(
    children: [
      Icon(icono, size: 16, color: _kDorado),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: Color(0xFF111827))),
    ],
  );

  Widget _estadoVacio(String msg, IconData icono) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
    ),
    child: Column(
      children: [
        Icon(icono, size: 32, color: const Color(0xFFD1D5DB)),
        const SizedBox(height: 8),
        Text(msg,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 13)),
      ],
    ),
  );
}

// ─── Tarjeta publicación ───────────────────────────────────────────────────────

class _PubCard extends StatelessWidget {
  final Map<String, dynamic> pub;
  const _PubCard({required this.pub});

  @override
  Widget build(BuildContext context) {
    final imagenes   = pub['imagenes'] as List? ?? [];
    final primeraImg = imagenes.isNotEmpty
        ? imagenes[0]['imagen_url'] as String? : null;
    final nombre = pub['nombre'] as String? ?? '';
    final precio = pub['precio_oferta'];

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 90, width: double.infinity,
              child: primeraImg != null
                  ? Image.network(primeraImg, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFF111827)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (precio != null) ...[
                  const SizedBox(height: 4),
                  Text('\$$precio',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _kAzul)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(child: Icon(Icons.campaign_outlined,
        size: 24, color: Color(0xFFD1D5DB))),
  );
}

// ─── Tarjeta producto ──────────────────────────────────────────────────────────

class _ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final nombre    = producto['nombre']      as String? ?? '';
    final precio    = producto['precio'];
    final imagenUrl = producto['imagen_url']  as String?;
    final categoria = producto['categoria']   as String?;
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categoria != null)
                  Text(categoria,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9CA3AF))),
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Color(0xFF111827)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (precio != null)
                      Text('\$$precio',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _kAzul)),
                    if (valMedia != null)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 11, color: _kDorado),
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
    child: const Center(child: Icon(Icons.fastfood_outlined,
        size: 28, color: Color(0xFFD1D5DB))),
  );
}

// ─── Tarjeta reseña ────────────────────────────────────────────────────────────

class _ReseniaCard extends StatelessWidget {
  final Map<String, dynamic> resenia;
  const _ReseniaCard({required this.resenia});

  @override
  Widget build(BuildContext context) {
    final nombre       = resenia['usuario_nombre'] as String? ?? 'Usuario';
    final calificacion = resenia['calificacion']   as int?    ?? 0;
    final comentario   = resenia['comentario']     as String?;
    final fecha        = _formatFecha(resenia['creado_en']?.toString() ?? '');
    final inicial      = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

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
                        color: _kAzul, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: Color(0xFF111827))),
                    Text(fecha,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  i < calificacion
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 14, color: _kDorado,
                )),
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
    } catch (_) { return iso; }
  }
}

// ─── Formulario edición tienda ─────────────────────────────────────────────────

class _FormularioTienda extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final Map<String, dynamic> tienda;
  final VoidCallback onGuardado;

  const _FormularioTienda({
    required this.usuario,
    required this.tienda,
    required this.onGuardado,
  });

  @override
  State<_FormularioTienda> createState() => _FormularioTiendaState();
}

class _FormularioTiendaState extends State<_FormularioTienda> {
  final _formKey     = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _horarioCtrl = TextEditingController();

  String?    _imagenExistente;
  Uint8List? _imagenNuevaBytes;
  String?    _imagenNuevaNombre;
  String?    _imagenNuevaMime;
  bool       _guardando = false;

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text  = widget.tienda['nombre']      as String? ?? '';
    _descCtrl.text    = widget.tienda['descripcion'] as String? ?? '';
    _horarioCtrl.text = widget.tienda['horario']     as String? ?? '';
    _imagenExistente  = widget.tienda['imagen_url']  as String?;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _horarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Recortar portada',
            toolbarColor: _kAzul,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Recortar portada',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    final bytes = await croppedFile.readAsBytes();
    setState(() {
      _imagenNuevaBytes  = bytes;
      _imagenNuevaNombre = picked.name;
      _imagenNuevaMime   = picked.mimeType ?? 'image/jpeg';
      _imagenExistente   = null;
    });
  }

  Future<String?> _subirImagen() async {
    if (_imagenNuevaBytes == null) return null;
    final request = http.MultipartRequest(
        'POST', Uri.parse('$_base/api/upload'));
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(http.MultipartFile.fromBytes(
      'imagen', _imagenNuevaBytes!,
      filename: _imagenNuevaNombre ?? 'imagen.jpg',
      contentType: MediaType.parse(_imagenNuevaMime ?? 'image/jpeg'),
    ));
    final response = await request.send();
    final body     = await response.stream.bytesToString();
    return jsonDecode(body)['url'] as String?;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      String? imagenUrl = _imagenExistente;
      if (_imagenNuevaBytes != null) {
        imagenUrl = await _subirImagen();
      }

      final tiendaId = widget.tienda['id'] as String? ?? '';
      await http.put(
        Uri.parse('$_base/api/tienda/$tiendaId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre':      _nombreCtrl.text.trim(),
          'descripcion': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'horario':     _horarioCtrl.text.trim().isEmpty ? null : _horarioCtrl.text.trim(),
          'imagen_url':  imagenUrl,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onGuardado();
    } catch (_) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneImagen = _imagenExistente != null || _imagenNuevaBytes != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Editar tienda',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),

                // Imagen
                const Text('Imagen de portada',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: Color(0xFF374151))),
                const SizedBox(height: 8),

                if (tieneImagen) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 140, width: double.infinity,
                          child: _imagenNuevaBytes != null
                              ? Image.memory(_imagenNuevaBytes!, fit: BoxFit.cover)
                              : Image.network(_imagenExistente!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholder()),
                        ),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _imagenExistente  = null;
                            _imagenNuevaBytes = null;
                          }),
                          child: Container(
                            width: 26, height: 26,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                OutlinedButton.icon(
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      size: 18, color: _kAzul),
                  label: Text(
                    tieneImagen ? 'Cambiar imagen' : 'Agregar imagen',
                    style: const TextStyle(color: _kAzul, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kAzul),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                _campo('Nombre de la tienda', _nombreCtrl, requerido: true),
                const SizedBox(height: 12),
                _campo('Descripción (opcional)', _descCtrl, maxLineas: 3),
                const SizedBox(height: 12),
                _campo('Horario (opcional)', _horarioCtrl,
                    hint: 'Ej: Lun-Vie 8:00 - 18:00'),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDorado,
                          foregroundColor: _kAzul,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _guardando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _kAzul))
                            : const Text('Guardar cambios',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(child: Icon(Icons.store_outlined,
        size: 36, color: Color(0xFFD1D5DB))),
  );

  Widget _campo(String label, TextEditingController ctrl,
      {bool requerido = false, int maxLineas = 1, String? hint}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLineas,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kAzul),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      validator: requerido
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }
}