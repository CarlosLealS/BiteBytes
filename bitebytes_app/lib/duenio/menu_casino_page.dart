import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

// ─── Constantes ────────────────────────────────────────────────
const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);
const _kBase   = 'http://localhost:3000';

// ─── Página principal ──────────────────────────────────────────
class MenuCasinoPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const MenuCasinoPage({super.key, required this.usuario});

  @override
  State<MenuCasinoPage> createState() => _MenuCasinoPageState();
}

class _MenuCasinoPageState extends State<MenuCasinoPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _menus = [];

  @override
  void initState() {
    super.initState();
    _cargarMenus();
  }

  Future<void> _cargarMenus() async {
    setState(() => _cargando = true);
    try {
      final token    = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';
      final res = await http.get(
        Uri.parse('$_kBase/api/menu-casino/tienda/$tiendaId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      setState(() {
        _menus    = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List? ?? []);
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
        title: const Text('Eliminar menú', style: TextStyle(fontSize: 16)),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final token = widget.usuario['token'] ?? '';
      await http.delete(
        Uri.parse('$_kBase/api/menu-casino/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _cargarMenus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirFormulario({Map<String, dynamic>? menu}) {
    showDialog(
      context: context,
      builder: (_) => _FormularioMenu(
        usuario: widget.usuario,
        menu: menu,
        onGuardado: _cargarMenus,
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
              const Text('Menú Casino',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAzul.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Por fecha', style: TextStyle(fontSize: 11, color: _kAzul)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo menú'),
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
          else if (_menus.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu_outlined, size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Aún no tienes menús creados',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _abrirFormulario(),
                      child: const Text('Crear primer menú', style: TextStyle(color: _kAzul)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: _kDorado,
                onRefresh: _cargarMenus,
                child: ListView.separated(
                  itemCount: _menus.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MenuCard(
                    usuario: widget.usuario,
                    menu: _menus[i],
                    onEliminar: () => _eliminar(_menus[i]['id']),
                    onEditar: () => _abrirFormulario(menu: _menus[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Card menú ────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final Map<String, dynamic> menu;
  final VoidCallback onEliminar;
  final VoidCallback onEditar;

  const _MenuCard({
    required this.usuario,
    required this.menu,
    required this.onEliminar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = _formatFecha(menu['fecha']?.toString() ?? '');
    final esHoy = _esHoy(menu['fecha']?.toString() ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esHoy ? _kDorado.withOpacity(0.5) : const Color(0xFFE5E7EB),
          width: esHoy ? 1.5 : 0.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: esHoy ? _kAzul : const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: esHoy ? _kDorado : const Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(fecha,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: esHoy ? Colors.white : const Color(0xFF374151))),
                if (esHoy) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _kDorado, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Hoy',
                        style: TextStyle(fontSize: 10, color: _kAzul, fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                if (menu['precio'] != null)
                  Text('\$${menu['precio']}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: esHoy ? _kDorado : _kAzul)),
                const SizedBox(width: 12),
                _iconBtn(Icons.edit_outlined, _kAzul.withOpacity(0.6), onEditar),
                const SizedBox(width: 6),
                _iconBtn(Icons.delete_outline, Colors.red.shade300, onEliminar),
                const SizedBox(width: 6),
                // Botón para abrir formulario de platos
                                _iconBtn(Icons.restaurant_menu_outlined, _kDorado, () {
                  showDialog(
                    context: context,
                    builder: (_) => _FormularioPlato(
                      usuario: usuario,
                      menuId: menu['id'].toString(),
                      onGuardado: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Plato guardado correctamente'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _campoMenu('Entrada',     menu['entrada'],      Icons.soup_kitchen_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _campoMenu('Plato fondo', menu['plato_fondo'],  Icons.dinner_dining)),
                const SizedBox(width: 12),
                Expanded(child: _campoMenu('Postre',      menu['postre'],       Icons.icecream_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _campoMenu('Vegetariano', menu['vegetariano'],  Icons.eco_outlined)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoMenu(String label, dynamic valor, IconData icono) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 13, color: _kDorado),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          valor?.toString() ?? '—',
          style: TextStyle(
            fontSize: 12,
            color: valor != null ? const Color(0xFF111827) : const Color(0xFFD1D5DB),
          ),
        ),
      ],
    );
  }

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

  bool _esHoy(String fecha) {
    try {
      final dt  = DateTime.parse(fecha);
      final hoy = DateTime.now();
      return dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day;
    } catch (_) { return false; }
  }

  String _formatFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      const meses = ['enero','febrero','marzo','abril','mayo','junio',
                     'julio','agosto','septiembre','octubre','noviembre','diciembre'];
      return '${dt.day} de ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) { return fecha; }
  }
}

// ─── Formulario menú ──────────────────────────────────────────
class _FormularioMenu extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final Map<String, dynamic>? menu;
  final VoidCallback onGuardado;

  const _FormularioMenu({
    required this.usuario,
    required this.onGuardado,
    this.menu,
  });

  @override
  State<_FormularioMenu> createState() => _FormularioMenuState();
}

class _FormularioMenuState extends State<_FormularioMenu> {
  final _formKey       = GlobalKey<FormState>();
  final _precioCtrl    = TextEditingController();
  DateTime? _fecha;
  bool _guardando = false;

  bool get _esEdicion => widget.menu != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final m = widget.menu!;
      _precioCtrl.text  = m['precio']?.toString() ?? '';
      _fecha = m['fecha'] != null ? DateTime.tryParse(m['fecha']) : null;
    } else {
      _fecha = DateTime.now();
    }
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('es', 'CL'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kAzul, secondary: _kDorado),
        ),
        child: child!,
      ),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _guardando = true);

    try {
      final token    = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';

      final body = jsonEncode({
        'tienda_id':   tiendaId,
        'fecha':       _fecha!.toIso8601String().split('T')[0],
        'precio':      _precioCtrl.text.trim().isEmpty   ? null : double.tryParse(_precioCtrl.text.trim()),
      });

      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      if (_esEdicion) {
        await http.put(
          Uri.parse('$_kBase/api/menu-casino/${widget.menu!['id']}'),
          headers: headers, body: body,
        );
      } else {
        await http.post(
          Uri.parse('$_kBase/api/menu-casino'),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _esEdicion ? 'Editar menú' : 'Nuevo menú del casino',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Fecha del menú',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              InkWell(
                onTap: _seleccionarFecha,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFD1D5DB),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 8),
                      Text(
                        _fecha != null
                            ? _formatFecha(_fecha!)
                            : 'Seleccionar fecha',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _campo(
                'Precio (opcional)',
                _precioCtrl,
                teclado: TextInputType.number,
                hint: 'Ej: 2500',
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                      ),
                      child: _guardando
                          ? const CircularProgressIndicator()
                          : Text(
                              _esEdicion
                                  ? 'Guardar cambios'
                                  : 'Crear menú',
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFecha(DateTime dt) {
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${dt.day} de ${meses[dt.month - 1]} ${dt.year}';
  }

  Widget _campo(String label, TextEditingController ctrl,
      {String? hint, TextInputType? teclado}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
    );
  }
}


// ─── Formulario plato ─────────────────────────────────────────

class _FormularioPlato extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String menuId;
  final Map<String, dynamic>? plato;
  final VoidCallback onGuardado;

  const _FormularioPlato({
    required this.usuario,
    required this.menuId,
    required this.onGuardado,
    this.plato,
  });

  @override
  State<_FormularioPlato> createState() => _FormularioPlatoState();
}

class _FormularioPlatoState extends State<_FormularioPlato> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  Uint8List? _imagenBytes;
  String? _imagenNombre;
  String? _imagenMime;

  bool _guardando = false;

  bool get _esEdicion => widget.plato != null;
  String? get _imagenUrlActual => widget.plato?['imagen_url'] as String?;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _nombreCtrl.text = widget.plato!['nombre'] ?? '';
      _descCtrl.text   = widget.plato!['descripcion'] ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imagenBytes  = bytes;
        _imagenNombre = picked.name;
        _imagenMime   = picked.mimeType ?? 'image/jpeg';
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar imagen'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del plato es obligatorio'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final token = widget.usuario['token'] ?? '';
      final uri = _esEdicion
          ? Uri.parse('$_kBase/api/menu-casino/platos/${widget.plato!['id']}')
          : Uri.parse('$_kBase/api/menu-casino/${widget.menuId}/platos');

      final request = _esEdicion
          ? http.MultipartRequest('PUT', uri)
          : http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['nombre'] = _nombreCtrl.text.trim();
      request.fields['descripcion'] = _descCtrl.text.trim();

      if (_imagenBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'imagen',
            _imagenBytes!,
            filename: _imagenNombre ?? 'imagen.jpg',
            contentType: MediaType.parse(_imagenMime ?? 'image/jpeg'),
          ),
        );
      }

      final response = await request.send();
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pop(context);
        widget.onGuardado();
      } else {
        final body = await response.stream.bytesToString();
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${response.statusCode}\n$body'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_esEdicion ? 'Editar plato' : 'Agregar plato',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),

              const Text('Imagen del plato',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _imagenBytes != null ? _kDorado : const Color(0xFFD1D5DB),
                      width: _imagenBytes != null ? 1.5 : 0.5,
                    ),
                  ),
                  child: _imagenBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_imagenBytes!, fit: BoxFit.cover))
                      : _imagenUrlActual != null
                          ? Image.network(_imagenUrlActual!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _uploadPlaceholder())
                          : _uploadPlaceholder(),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Opcional · JPG, PNG o WEBP · máx. 5MB',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nombreCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Nombre del plato *',
                  hintText: 'Ej: Entrada, Plato fondo, Postre...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAzul)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej: Ensalada mixta con tomate cherry',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAzul)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
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
                        backgroundColor: _kDorado,
                        foregroundColor: _kAzul,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _guardando
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kAzul))
                          : Text(_esEdicion ? 'Guardar cambios' : 'Agregar plato',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

    Widget _uploadPlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 28,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            'Subir imagen',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      );
}
