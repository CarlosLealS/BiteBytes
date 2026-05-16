import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);
final _kBase   = Env.apiUrl;

class ProductosPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const ProductosPage({super.key, required this.usuario});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _productos   = [];
  List<Map<String, dynamic>> _categorias  = [];

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
      final headers  = {'Authorization': 'Bearer $token'};

      final res = await Future.wait([
        http.get(Uri.parse('$_kBase/api/tienda/$tiendaId/productos'), headers: headers),
        http.get(Uri.parse('$_kBase/api/categorias'), headers: headers),
      ]);

      if (!mounted) return;
      setState(() {
        _productos  = List<Map<String, dynamic>>.from(jsonDecode(res[0].body) as List? ?? []);
        _categorias = List<Map<String, dynamic>>.from(jsonDecode(res[1].body) as List? ?? []);
        _cargando   = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _toggleDisponible(Map<String, dynamic> producto) async {
    final token = widget.usuario['token'] ?? '';
    final nuevoEstado = !(producto['disponible'] as bool? ?? false);
    try {
      await http.patch(
        Uri.parse('$_kBase/api/productos/${producto['id']}'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'disponible': nuevoEstado}),
      );
      await _cargarDatos();
    } catch (_) {
      _mostrarError('No se pudo actualizar la disponibilidad');
    }
  }

  Future<void> _eliminarProducto(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar producto', style: TextStyle(fontSize: 16)),
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
        Uri.parse('$_kBase/api/productos/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _cargarDatos();
    } catch (_) {
      _mostrarError('No se pudo eliminar el producto');
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _abrirFormulario({Map<String, dynamic>? producto}) {
    showDialog(
      context: context,
      builder: (_) => _FormularioProducto(
        usuario: widget.usuario,
        categorias: _categorias,
        producto: producto,
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
              const Text('Mis productos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo producto'),
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
          else if (_productos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Aún no tienes productos',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _abrirFormulario(),
                      child: const Text('Crear primer producto', style: TextStyle(color: _kAzul)),
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
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _productos.length,
                  itemBuilder: (_, i) => _ProductoCard(
                    producto: _productos[i],
                    onToggle:   () => _toggleDisponible(_productos[i]),
                    onEliminar: () => _eliminarProducto(_productos[i]['id']),
                    onEditar:   () => _abrirFormulario(producto: _productos[i]),
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

class _ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback onToggle;
  final VoidCallback onEliminar;
  final VoidCallback onEditar;

  const _ProductoCard({
    required this.producto,
    required this.onToggle,
    required this.onEliminar,
    required this.onEditar,
  });

  // ── Convierte cualquier valor numérico del backend a entero sin decimales ──
  String _formatPrecio(dynamic valor) {
    if (valor is double) return valor.toInt().toString();
    if (valor is int)    return valor.toString();
    final n = num.tryParse(valor.toString());
    return n != null ? n.toInt().toString() : valor.toString();
  }

  @override
  Widget build(BuildContext context) {
    final disponible = producto['disponible'] as bool? ?? false;
    final imagenUrl  = producto['imagen_url'] as String?;
    final precio     = producto['precio'];
    final nombre     = producto['nombre'] ?? 'Sin nombre';

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
              height: 100, width: double.infinity,
              child: imagenUrl != null && imagenUrl.isNotEmpty
                  ? Image.network(imagenUrl, fit: BoxFit.cover,
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
                  Text(nombre,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // ── Precio sin decimales ──
                  Text(
                    precio != null ? '\$${_formatPrecio(precio)}' : '-',
                    style: const TextStyle(fontSize: 13, color: _kAzul, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: disponible ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          disponible ? 'Disponible' : 'No disponible',
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w500,
                            color: disponible ? const Color(0xFF166534) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _iconBtn(Icons.edit_outlined, _kAzul.withOpacity(0.7), onEditar),
                      const SizedBox(width: 4),
                      _iconBtn(Icons.delete_outline, Colors.red.shade300, onEliminar),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onToggle,
                    child: Row(
                      children: [
                        Switch(
                          value: disponible,
                          onChanged: (_) => onToggle(),
                          activeColor: _kAzul,
                          activeTrackColor: _kDorado.withOpacity(0.4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Text(
                          disponible ? 'Activo' : 'Inactivo',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(child: Icon(Icons.fastfood_outlined, size: 36, color: Color(0xFFD1D5DB))),
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );
}

// ─── Formulario ────────────────────────────────────────────────────────────────

class _FormularioProducto extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final List<Map<String, dynamic>> categorias;
  final Map<String, dynamic>? producto;
  final VoidCallback onGuardado;

  const _FormularioProducto({
    required this.usuario,
    required this.categorias,
    required this.onGuardado,
    this.producto,
  });

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _precioCtrl   = TextEditingController();
  final _descCtrl     = TextEditingController();

  int?          _categoriaId;
  bool          _disponible  = true;
  bool          _guardando   = false;

  // Imagen
  String?       _imagenExistente;
  Uint8List?    _imagenNuevaBytes;
  String?       _imagenNuevaNombre;
  String?       _imagenNuevaMime;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final p = widget.producto!;
      _nombreCtrl.text = p['nombre'] ?? '';
      // Precio como entero (sin decimales)
      final precioRaw = p['precio'];
      if (precioRaw != null) {
        _precioCtrl.text = precioRaw is double
            ? precioRaw.toInt().toString()
            : precioRaw.toString();
      }
      _descCtrl.text   = p['descripcion'] ?? '';
      _categoriaId     = p['categoria_id'] as int?;
      _disponible      = p['disponible'] as bool? ?? true;
      _imagenExistente = p['imagen_url'] as String?;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenNuevaBytes  = bytes;
      _imagenNuevaNombre = picked.name;
      _imagenNuevaMime   = picked.mimeType ?? 'image/jpeg';
      _imagenExistente   = null;
    });
  }

  Future<String?> _subirImagen() async {
    if (_imagenNuevaBytes == null) return null;
    final token   = widget.usuario['token'] ?? '';
    final request = http.MultipartRequest('POST', Uri.parse('$_kBase/api/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'imagen', _imagenNuevaBytes!,
      filename: _imagenNuevaNombre ?? 'imagen.jpg',
      contentType: MediaType.parse(_imagenNuevaMime ?? 'image/jpeg'),
    ));
    final response = await request.send();
    final body     = await response.stream.bytesToString();
    final data     = jsonDecode(body);
    return data['url'] as String?;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final token    = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';

      String? imagenUrl = _imagenExistente;
      if (_imagenNuevaBytes != null) {
        imagenUrl = await _subirImagen();
      }

      final body = jsonEncode({
        'nombre':       _nombreCtrl.text.trim(),
        'precio':       int.tryParse(_precioCtrl.text.trim()) ?? 0, // ← entero
        'descripcion':  _descCtrl.text.trim(),
        'imagen_url':   imagenUrl,
        'categoria_id': _categoriaId,
        'disponible':   _disponible,
        'tienda_id':    tiendaId,
      });

      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      if (_esEdicion) {
        await http.put(
          Uri.parse('$_kBase/api/productos/${widget.producto!['id']}'),
          headers: headers, body: body,
        );
      } else {
        await http.post(
          Uri.parse('$_kBase/api/productos'),
          headers: headers, body: body,
        );
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
        width: 420,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_esEdicion ? 'Editar producto' : 'Nuevo producto',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),

                _campo('Nombre', _nombreCtrl, requerido: true),
                const SizedBox(height: 12),

                // ── Precio solo enteros (pesos chilenos) ──
                _campoEntero('Precio (CLP)', _precioCtrl),
                const SizedBox(height: 12),

                _campo('Descripción (opcional)', _descCtrl, maxLineas: 2),
                const SizedBox(height: 12),

                const Text('Imagen (opcional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 8),

                if (_imagenExistente != null || _imagenNuevaBytes != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 120, width: double.infinity,
                          child: _imagenNuevaBytes != null
                              ? Image.memory(_imagenNuevaBytes!, fit: BoxFit.cover)
                              : Image.network(_imagenExistente!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholder()),
                        ),
                      ),
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _imagenExistente  = null;
                            _imagenNuevaBytes = null;
                          }),
                          child: Container(
                            width: 24, height: 24,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                OutlinedButton.icon(
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18, color: _kAzul),
                  label: Text(
                    _imagenExistente != null || _imagenNuevaBytes != null
                        ? 'Cambiar imagen'
                        : 'Agregar imagen',
                    style: const TextStyle(color: _kAzul, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kAzul),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  value: _categoriaId,
                  decoration: _inputDecoration('Categoría (opcional)'),
                  items: widget.categorias.map((c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _categoriaId = v),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Text('Disponible', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                    const Spacer(),
                    Switch(
                      value: _disponible,
                      onChanged: (v) => setState(() => _disponible = v),
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
                            : Text(_esEdicion ? 'Guardar cambios' : 'Crear producto',
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

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: const Center(child: Icon(Icons.fastfood_outlined, size: 36, color: Color(0xFFD1D5DB))),
  );

  // ── Campo genérico ──────────────────────────────────────────────────────────
  Widget _campo(String label, TextEditingController ctrl,
      {bool requerido = false, int maxLineas = 1, TextInputType? teclado}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLineas,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(label),
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
      decoration: _inputDecoration(label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Campo requerido';
        if (int.tryParse(v.trim()) == null) return 'Ingresa un número válido';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kAzul),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}