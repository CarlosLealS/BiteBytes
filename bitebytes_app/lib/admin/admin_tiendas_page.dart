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

  Future<void> _enviarReseteoContrasena(Map<String, dynamic> tienda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Text(
          '¿Enviar un correo de restablecimiento de contraseña a ${tienda['duenio_nombre']} (${tienda['duenio_email']})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kAzul),
            child: const Text('Enviar correo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final res = await http.post(
        Uri.parse('$_base/api/admin/usuarios/${tienda['duenio_id']}/resetear-contrasena'),
        headers: _headers,
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Correo enviado a ${tienda['duenio_email']}')),
        );
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Error al enviar correo')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión')));
      }
    }
  }

  void _abrirFormulario() {
    showDialog(
      context: context,
      builder: (_) => _FormularioInvitarDuenio(
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón reseteo contraseña
                                IconButton(
                                  tooltip: 'Enviar reseteo de contraseña',
                                  icon: const Icon(Icons.lock_reset, color: _kAzul),
                                  onPressed: () => _enviarReseteoContrasena(t),
                                ),
                                // Botón eliminar
                                IconButton(
                                  tooltip: 'Eliminar tienda',
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _eliminarTienda(t['id']),
                                ),
                              ],
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

// ──────────────────────────────────────────────
// Formulario simplificado: solo email + tipo tienda
// ──────────────────────────────────────────────
class _FormularioInvitarDuenio extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onGuardado;
  const _FormularioInvitarDuenio({required this.usuario, required this.onGuardado});

  @override
  State<_FormularioInvitarDuenio> createState() => _FormularioInvitarDuenioState();
}

class _FormularioInvitarDuenioState extends State<_FormularioInvitarDuenio> {
  final _emailCtrl = TextEditingController();

  int  _tipoTiendaId = 1;
  bool _enviando     = false;

  String get _base  => Env.apiUrl;
  String get _token => widget.usuario['token'] ?? '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un email válido')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final res = await http.post(
        Uri.parse('$_base/api/admin/tiendas'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email':          email,
          'tipo_tienda_id': _tipoTiendaId,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitación enviada a $email')),
        );
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Error al enviar invitación')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
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
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kDorado.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.email_outlined, color: _kDorado, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Invitar dueño de tienda',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kAzul),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'El dueño recibirá un correo con un enlace para completar el registro de su cuenta y su tienda.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email del dueño',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Tipo de tienda
              DropdownButtonFormField<int>(
                value: _tipoTiendaId,
                decoration: const InputDecoration(
                  labelText: 'Tipo de tienda',
                  prefixIcon: Icon(Icons.store_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Tienda')),
                  DropdownMenuItem(value: 2, child: Text('Casino')),
                  DropdownMenuItem(value: 3, child: Text('Kiosco')),
                  DropdownMenuItem(value: 4, child: Text('Cafeteria')),
                ],
                onChanged: (v) => setState(() => _tipoTiendaId = v ?? 1),
              ),

              const SizedBox(height: 24),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kDorado,
                      foregroundColor: Colors.white,
                    ),
                    icon: _enviando
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_enviando ? 'Enviando…' : 'Enviar invitación'),
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
