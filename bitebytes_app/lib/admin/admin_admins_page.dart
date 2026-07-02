import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class AdminAdminsPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AdminAdminsPage({super.key, required this.usuario});

  @override
  State<AdminAdminsPage> createState() => _AdminAdminsPageState();
}

class _AdminAdminsPageState extends State<AdminAdminsPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _admins = [];

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarAdmins();
  }

  Future<void> _cargarAdmins() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(Uri.parse('$_base/api/admin/admins'), headers: _headers);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _admins = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List? ?? []);
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarAdmin(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Administrador'),
        content: const Text('¿Estás seguro de que deseas eliminar este administrador? Perderá el acceso de inmediato.'),
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
      final res = await http.delete(Uri.parse('$_base/api/admin/admins/$id'), headers: _headers);
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Administrador eliminado correctamente')));
        }
        _cargarAdmins();
      } else {
        setState(() => _cargando = false);
        if (mounted) {
          final data = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Error al eliminar administrador')));
        }
      }
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  void _abrirFormulario() {
    showDialog(
      context: context,
      builder: (_) => _FormularioCrearAdmin(
        usuario: widget.usuario,
        onGuardado: _cargarAdmins,
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
        label: const Text('Añadir Administrador', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Administradores',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _kAzul),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _admins.isEmpty
                  ? const Center(child: Text('No hay administradores registrados.'))
                  : ListView.builder(
                      itemCount: _admins.length,
                      itemBuilder: (ctx, i) {
                        final admin = _admins[i];
                        final bool esElMismo = admin['id'] == widget.usuario['id'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _kDorado.withOpacity(0.2),
                              child: const Icon(Icons.admin_panel_settings, color: _kDorado),
                            ),
                            title: Text(admin['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${admin['email']} • Activo: ${admin['activo'] ? "Sí" : "No"}'),
                            trailing: esElMismo
                                ? const Tooltip(
                                    message: 'No puedes eliminarte a ti mismo',
                                    child: Icon(Icons.info_outline, color: Colors.grey),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _eliminarAdmin(admin['id']),
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

class _FormularioCrearAdmin extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onGuardado;
  const _FormularioCrearAdmin({required this.usuario, required this.onGuardado});

  @override
  State<_FormularioCrearAdmin> createState() => _FormularioCrearAdminState();
}

class _FormularioCrearAdminState extends State<_FormularioCrearAdmin> {
  final _nombreCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  bool _guardando     = false;

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final pass   = _passCtrl.text.trim();

    if (nombre.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rellena todos los campos')));
      return;
    }

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')));
      return;
    }

    setState(() => _guardando = true);

    try {
      final body = {
        'nombre': nombre,
        'email': email,
        'password': pass,
      };

      final res = await http.post(
        Uri.parse('$_base/api/admin/admins'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Administrador creado exitosamente')));
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Error al crear administrador')));
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Añadir Administrador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kAzul)),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del administrador', border: OutlineInputBorder()),
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
                        : const Text('Crear Administrador'),
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
