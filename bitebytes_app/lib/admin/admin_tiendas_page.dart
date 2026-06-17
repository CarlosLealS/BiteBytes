import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class AdminTiendasPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AdminTiendasPage({super.key, required this.usuario});

  @override
  State<AdminTiendasPage> createState() => _AdminTiendasPageState();
}

class _AdminTiendasPageState extends State<AdminTiendasPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _tiendas = [];

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarTiendas();
  }

  Future<void> _cargarTiendas() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(Uri.parse('$_base/api/admin/tiendas'), headers: _headers);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _tiendas = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List? ?? []);
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarTienda(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Tienda'),
        content: const Text('¿Estás seguro de que deseas eliminar esta tienda? Esta acción eliminará en cascada todos sus productos y publicaciones.'),
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
      final res = await http.delete(Uri.parse('$_base/api/admin/tiendas/$id'), headers: _headers);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tienda eliminada')));
        _cargarTiendas();
      } else {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar tienda')));
      }
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  void _abrirFormulario() {
    showDialog(
      context: context,
      builder: (_) => _FormularioCrearTienda(
        usuario: widget.usuario,
        onGuardado: _cargarTiendas,
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
        label: const Text('Añadir Tienda', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Tiendas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _kAzul),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tiendas.isEmpty
                  ? const Center(child: Text('No hay tiendas registradas.'))
                  : ListView.builder(
                      itemCount: _tiendas.length,
                      itemBuilder: (ctx, i) {
                        final t = _tiendas[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _kAzul.withOpacity(0.1),
                              child: const Icon(Icons.store, color: _kAzul),
                            ),
                            title: Text(t['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${t['tipo']} • Dueño: ${t['duenio_nombre']} (${t['duenio_email']})'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _eliminarTienda(t['id']),
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

class _FormularioCrearTienda extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onGuardado;
  const _FormularioCrearTienda({required this.usuario, required this.onGuardado});

  @override
  State<_FormularioCrearTienda> createState() => _FormularioCrearTiendaState();
}

class _FormularioCrearTiendaState extends State<_FormularioCrearTienda> {
  final _nombreTiendaCtrl  = TextEditingController();
  final _descCtrl          = TextEditingController();
  final _duenioNombreCtrl  = TextEditingController();
  final _duenioEmailCtrl   = TextEditingController();
  final _duenioPassCtrl    = TextEditingController();
  
  int _tipoTiendaId = 1;
  bool _guardando   = false;

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';

  Future<void> _guardar() async {
    final nombreT = _nombreTiendaCtrl.text.trim();
    final dNombre = _duenioNombreCtrl.text.trim();
    final dEmail  = _duenioEmailCtrl.text.trim();
    final dPass   = _duenioPassCtrl.text.trim();

    if (nombreT.isEmpty || dNombre.isEmpty || dEmail.isEmpty || dPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rellena todos los campos obligatorios')));
      return;
    }

    setState(() => _guardando = true);

    try {
      final body = {
        'nombre_tienda': nombreT,
        'descripcion': _descCtrl.text.trim(),
        'tipo_tienda_id': _tipoTiendaId,
        'duenio_nombre': dNombre,
        'duenio_email': dEmail,
        'duenio_password': dPass,
      };

      final res = await http.post(
        Uri.parse('$_base/api/admin/tiendas'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tienda creada')));
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
        width: 450,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Crear Tienda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kAzul)),
              const SizedBox(height: 16),
              
              const Text('Datos de la Tienda', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreTiendaCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de tienda', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción (Opcional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _tipoTiendaId,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Tienda')),
                  DropdownMenuItem(value: 2, child: Text('Casino')),
                  DropdownMenuItem(value: 3, child: Text('Kiosco')),
                  DropdownMenuItem(value: 4, child: Text('Cafeteria')),
                ],
                onChanged: (v) => setState(() => _tipoTiendaId = v ?? 1),
              ),

              const SizedBox(height: 24),
              const Text('Datos del Dueño', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _duenioNombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del dueño', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duenioEmailCtrl,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duenioPassCtrl,
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
                        : const Text('Crear Tienda'),
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
