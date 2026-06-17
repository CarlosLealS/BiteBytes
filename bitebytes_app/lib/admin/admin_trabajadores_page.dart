import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class AdminTrabajadoresPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AdminTrabajadoresPage({super.key, required this.usuario});

  @override
  State<AdminTrabajadoresPage> createState() => _AdminTrabajadoresPageState();
}

class _AdminTrabajadoresPageState extends State<AdminTrabajadoresPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _trabajadores = [];

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();
  }

  Future<void> _cargarTrabajadores() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(Uri.parse('$_base/api/admin/trabajadores'), headers: _headers);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _trabajadores = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List? ?? []);
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarTrabajador(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Trabajador'),
        content: const Text('¿Estás seguro de que deseas eliminar este trabajador de la tienda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _cargando = true);
    try {
      final res = await http.delete(Uri.parse('$_base/api/admin/trabajadores/$id'), headers: _headers);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trabajador eliminado')));
        _cargarTrabajadores();
      } else {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar trabajador')));
      }
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  void _abrirFormulario() {
    showDialog(
      context: context,
      builder: (_) => _FormularioCrearTrabajador(
        usuario: widget.usuario,
        onGuardado: _cargarTrabajadores,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kDorado));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: _kDorado,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Añadir Trabajador', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Trabajadores',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _kAzul),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _trabajadores.isEmpty
                  ? const Center(child: Text('No hay trabajadores registrados.'))
                  : ListView.builder(
                      itemCount: _trabajadores.length,
                      itemBuilder: (ctx, i) {
                        final t = _trabajadores[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _kDorado.withOpacity(0.2),
                              child: const Icon(Icons.person, color: _kDorado),
                            ),
                            title: Text(t['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${t['email']} • Tienda: ${t['tienda_nombre']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _eliminarTrabajador(t['trabajador_id']),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioCrearTrabajador extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onGuardado;
  const _FormularioCrearTrabajador({required this.usuario, required this.onGuardado});

  @override
  State<_FormularioCrearTrabajador> createState() => _FormularioCrearTrabajadorState();
}

class _FormularioCrearTrabajadorState extends State<_FormularioCrearTrabajador> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  
  String? _tiendaId;
  List<Map<String, dynamic>> _tiendas = [];
  bool _cargandoTiendas = true;
  bool _guardando       = false;

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';

  @override
  void initState() {
    super.initState();
    _cargarTiendas();
  }

  Future<void> _cargarTiendas() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/admin/tiendas'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _tiendas = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          if (_tiendas.isNotEmpty) {
            _tiendaId = _tiendas.first['id'];
          }
          _cargandoTiendas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoTiendas = false);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final pass   = _passCtrl.text.trim();

    if (nombre.isEmpty || email.isEmpty || pass.isEmpty || _tiendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rellena todos los campos')));
      return;
    }

    setState(() => _guardando = true);

    try {
      final body = {
        'tienda_id': _tiendaId,
        'nombre': nombre,
        'email': email,
        'password': pass,
      };

      final res = await http.post(
        Uri.parse('$_base/api/admin/trabajadores'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;
      if (res.statusCode == 201) {
        widget.onGuardado();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trabajador creado')));
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Error')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: _cargandoTiendas
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Añadir Trabajador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kAzul)),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _tiendaId,
                      decoration: const InputDecoration(labelText: 'Tienda', border: OutlineInputBorder()),
                      items: _tiendas.map((t) => DropdownMenuItem<String>(
                        value: t['id'],
                        child: Text(t['nombre']),
                      )).toList(),
                      onChanged: (v) => setState(() => _tiendaId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del trabajador', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                      obscureText: true,
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _guardando ? null : () => Navigator.pop(context),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _guardando ? null : _guardar,
                          style: ElevatedButton.styleFrom(backgroundColor: _kAzul, foregroundColor: Colors.white),
                          child: _guardando
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Crear Trabajador'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
