import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);
const _kBase   = 'http://172.16.13.105:3000';

class PublicacionesPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const PublicacionesPage({super.key, required this.usuario});

  @override
  State<PublicacionesPage> createState() => _PublicacionesPageState();
}

class _PublicacionesPageState extends State<PublicacionesPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _publicaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final token    = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';
      final res = await http.get(
        Uri.parse('$_kBase/api/tienda/$tiendaId/publicaciones'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      setState(() {
        _publicaciones = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List? ?? []);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _eliminar(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar publicación', style: TextStyle(fontSize: 16)),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final token = widget.usuario['token'] ?? '';
      await http.delete(
        Uri.parse('$_kBase/api/publicaciones/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _cargarDatos();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirFormulario({Map<String, dynamic>? pub}) {
    showDialog(
      context: context,
      builder: (_) => _FormularioPublicacion(
        usuario: widget.usuario,
        publicacion: pub,
        onGuardado: _cargarDatos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Publicaciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva publicación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDorado,
                  foregroundColor: _kAzul,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_cargando)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kDorado)))
          else if (_publicaciones.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Aún no tienes publicaciones',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _abrirFormulario(),
                      child: const Text('Crear primera publicación', style: TextStyle(color: _kAzul)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: _kDorado,
                onRefresh: _cargarDatos,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _publicaciones.length,
                  itemBuilder: (_, i) => _PublicacionCard(
                    pub: _publicaciones[i],
                    onEliminar: () => _eliminar(_publicaciones[i]['id']),
                    onEditar: () => _abrirFormulario(pub: _publicaciones[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Card ──────────────────────────────────────────────────────────────────────

class _PublicacionCard extends StatelessWidget {
  final Map<String, dynamic> pub;
  final VoidCallback onEliminar;
  final VoidCallback onEditar;

  const _PublicacionCard({required this.pub, required this.onEliminar, required this.onEditar});

  // ── Convierte cualquier valor numérico del backend a entero sin decimales ──
  String _formatPrecio(dynamic valor) {
    if (valor is double) return valor.toInt().toString();
    if (valor is int)    return valor.toString();
    final n = num.tryParse(valor.toString());
    return n != null ? n.toInt().toString() : valor.toString();
  }

  @override
  Widget build(BuildContext context) {
    final imagenes    = pub['imagenes'] as List? ?? [];
    final primeraImg  = imagenes.isNotEmpty ? imagenes[0]['imagen_url'] as String? : null;
    final activa      = pub['activa'] as bool? ?? false;
    final nombre      = pub['nombre'] ?? '';
    final descripcion = pub['descripcion'] ?? '';
    final precio      = pub['precio_oferta'];
    final publicarEn  = pub['publicar_en'];
    final expiraEn    = pub['expira_en'];
    final estado      = _calcularEstado(activa, publicarEn, expiraEn);

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
              height: 110, width: double.infinity,
              child: primeraImg != null
                  ? Image.network(primeraImg, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _estadoBadge(estado),
                  const SizedBox(height: 6),
                  Text(nombre,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(descripcion,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  // ── Precio sin decimales ──
                  if (precio != null)
                    Text('\$${_formatPrecio(precio)}',
                        style: const TextStyle(fontSize: 14, color: _kAzul, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (publicarEn != null) _fechaRow(Icons.play_circle_outline, 'Inicia', publicarEn),
                  if (expiraEn   != null) _fechaRow(Icons.stop_circle_outlined, 'Expira', expiraEn),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _iconBtn(Icons.edit_outlined, _kAzul.withOpacity(0.7), onEditar),
                      const SizedBox(width: 6),
                      _iconBtn(Icons.delete_outline, Colors.red.shade300, onEliminar),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calcularEstado(bool activa, dynamic publicarEn, dynamic expiraEn) {
    if (!activa) return 'inactiva';
    final ahora = DateTime.now();
    if (publicarEn != null) {
      final inicio = DateTime.tryParse(publicarEn.toString());
      if (inicio != null && ahora.isBefore(inicio)) return 'programada';
    }
    if (expiraEn != null) {
      final fin = DateTime.tryParse(expiraEn.toString());
      if (fin != null && ahora.isAfter(fin)) return 'expirada';
    }
    return 'activa';
  }

  Widget _estadoBadge(String estado) {
    Color bg; Color fg; String label;
    switch (estado) {
      case 'activa':     bg = const Color(0xFFDCFCE7); fg = const Color(0xFF166534); label = 'Activa'; break;
      case 'programada': bg = const Color(0xFFEFF6FF); fg = const Color(0xFF1D4ED8); label = 'Programada'; break;
      case 'expirada':   bg = const Color(0xFFFEF2F2); fg = const Color(0xFFB91C1C); label = 'Expirada'; break;
      default:           bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280); label = 'Inactiva';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _fechaRow(IconData icono, String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icono, size: 12, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 4),
          Text('$label: ${_formatFecha(valor.toString())}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: Center(child: Icon(Icons.campaign_outlined, size: 38, color: Colors.grey.shade300)),
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );
}

// ─── Formulario ────────────────────────────────────────────────────────────────

class _FormularioPublicacion extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final Map<String, dynamic>? publicacion;
  final VoidCallback onGuardado;

  const _FormularioPublicacion({required this.usuario, required this.onGuardado, this.publicacion});

  @override
  State<_FormularioPublicacion> createState() => _FormularioPublicacionState();
}

class _FormularioPublicacionState extends State<_FormularioPublicacion> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _precioCtrl = TextEditingController();

  List<String>       _imagenesExistentes = [];
  List<_ImagenNueva> _imagenesNuevas     = [];

  DateTime? _publicarEn;
  DateTime? _expiraEn;
  bool _activa    = true;
  bool _guardando = false;

  bool get _esEdicion => widget.publicacion != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final p = widget.publicacion!;
      _nombreCtrl.text = p['nombre'] ?? '';
      _descCtrl.text   = p['descripcion'] ?? '';
      // Precio como entero (sin decimales)
      final precioRaw = p['precio_oferta'];
      if (precioRaw != null) {
        _precioCtrl.text = precioRaw is double
            ? precioRaw.toInt().toString()
            : precioRaw.toString();
      }
      _activa     = p['activa'] as bool? ?? true;
      _publicarEn = p['publicar_en'] != null ? DateTime.tryParse(p['publicar_en']) : null;
      _expiraEn   = p['expira_en']   != null ? DateTime.tryParse(p['expira_en'])   : null;
      final imgs = p['imagenes'] as List? ?? [];
      _imagenesExistentes = imgs.map((i) => i['imagen_url'].toString()).toList();
    } else {
      _publicarEn = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenesNuevas.add(_ImagenNueva(
        bytes: bytes,
        nombre: picked.name,
        mimeType: picked.mimeType ?? 'image/jpeg',
      ));
    });
  }

  Future<String?> _subirImagen(_ImagenNueva img) async {
    final token   = widget.usuario['token'] ?? '';
    final request = http.MultipartRequest('POST', Uri.parse('$_kBase/api/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'imagen', img.bytes,
      filename: img.nombre,
      contentType: MediaType.parse(img.mimeType),
    ));
    final response = await request.send();
    final body     = await response.stream.bytesToString();
    final data     = jsonDecode(body);
    return data['url'] as String?;
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final inicial = esInicio ? (_publicarEn ?? DateTime.now()) : (_expiraEn ?? DateTime.now());
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'CL'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAzul, secondary: _kDorado),
        ),
        child: child!,
      ),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAzul, secondary: _kDorado),
        ),
        child: child!,
      ),
    );
    if (hora == null) return;
    final resultado = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    setState(() => esInicio ? _publicarEn = resultado : _expiraEn = resultado);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final token    = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';

      final List<String> todasLasUrls = List.from(_imagenesExistentes);
      for (final img in _imagenesNuevas) {
        final url = await _subirImagen(img);
        if (url != null) todasLasUrls.add(url);
      }

      final body = jsonEncode({
        'tienda_id':     tiendaId,
        'nombre':        _nombreCtrl.text.trim(),
        'descripcion':   _descCtrl.text.trim(),
        // ← precio como entero, null si está vacío
        'precio_oferta': _precioCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_precioCtrl.text.trim()),
        'publicar_en':   _publicarEn?.toIso8601String(),
        'expira_en':     _expiraEn?.toIso8601String(),
        'activa':        _activa,
        'imagenes':      todasLasUrls,
      });

      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      if (_esEdicion) {
        await http.put(Uri.parse('$_kBase/api/publicaciones/${widget.publicacion!['id']}'),
            headers: headers, body: body);
      } else {
        await http.post(Uri.parse('$_kBase/api/publicaciones'),
            headers: headers, body: body);
      }

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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_esEdicion ? 'Editar publicación' : 'Nueva publicación',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                _campo('Nombre', _nombreCtrl, requerido: true),
                const SizedBox(height: 12),
                _campo('Descripción', _descCtrl, maxLineas: 3),
                const SizedBox(height: 12),

                // ── Precio solo enteros (pesos chilenos) ──
                _campoEntero('Precio oferta CLP (opcional)', _precioCtrl),
                const SizedBox(height: 16),

                const Text('Programación',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                _selectorFecha('Fecha y hora de inicio', _publicarEn, () => _seleccionarFecha(true)),
                const SizedBox(height: 8),
                _selectorFecha('Fecha y hora de fin (opcional)', _expiraEn, () => _seleccionarFecha(false),
                    onLimpiar: _expiraEn != null ? () => setState(() => _expiraEn = null) : null),
                const SizedBox(height: 16),

                const Text('Imágenes (opcional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 8),

                if (_imagenesExistentes.isNotEmpty || _imagenesNuevas.isNotEmpty) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._imagenesExistentes.asMap().entries.map((e) => _miniatura(
                        child: Image.network(e.value, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24)),
                        onEliminar: () => setState(() => _imagenesExistentes.removeAt(e.key)),
                      )),
                      ..._imagenesNuevas.asMap().entries.map((e) => _miniatura(
                        child: Image.memory(e.value.bytes, fit: BoxFit.cover),
                        onEliminar: () => setState(() => _imagenesNuevas.removeAt(e.key)),
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                OutlinedButton.icon(
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18, color: _kAzul),
                  label: const Text('Agregar imagen', style: TextStyle(color: _kAzul, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kAzul),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    const Text('Publicar activa',
                        style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                    const Spacer(),
                    Switch(
                      value: _activa,
                      onChanged: (v) => setState(() => _activa = v),
                      activeColor: _kAzul,
                      activeTrackColor: _kDorado.withOpacity(0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDorado, foregroundColor: _kAzul, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _guardando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _kAzul))
                            : Text(_esEdicion ? 'Guardar cambios' : 'Crear publicación',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _miniatura({required Widget child, required VoidCallback onEliminar}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 70, height: 70, child: child),
        ),
        Positioned(
          top: 2, right: 2,
          child: GestureDetector(
            onTap: onEliminar,
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectorFecha(String label, DateTime? valor, VoidCallback onTap, {VoidCallback? onLimpiar}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                valor != null ? _formatFecha(valor) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: valor != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            if (onLimpiar != null)
              GestureDetector(
                onTap: onLimpiar,
                child: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Campo genérico ──────────────────────────────────────────────────────────
  Widget _campo(String label, TextEditingController ctrl,
      {bool requerido = false, int maxLineas = 1, TextInputType? teclado, String? hint}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLineas,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDec(label, hint: hint),
      validator: requerido ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
    );
  }

  // ── Campo precio: solo dígitos enteros (pesos chilenos, sin decimales) ──────
  Widget _campoEntero(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 13),
      decoration: _inputDec(label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null; // opcional
        if (int.tryParse(v.trim()) == null) return 'Ingresa un número válido';
        return null;
      },
    );
  }

  InputDecoration _inputDec(String label, {String? hint}) => InputDecoration(
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
  );
}

class _ImagenNueva {
  final Uint8List bytes;
  final String nombre;
  final String mimeType;
  const _ImagenNueva({required this.bytes, required this.nombre, required this.mimeType});
}