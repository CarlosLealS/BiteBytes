import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class TrabajadoresPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const TrabajadoresPage({super.key, required this.usuario});

  @override
  State<TrabajadoresPage> createState() => _TrabajadoresPageState();
}

class _TrabajadoresPageState extends State<TrabajadoresPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _trabajadores = [];

  String get _base     => Env.apiUrl;
  String get _token    => widget.usuario['token'] ?? '';
  String get _tiendaId => widget.usuario['tienda_id'] ?? '';
  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();
  }

  Future<void> _cargarTrabajadores() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(
        Uri.parse('$_base/api/tienda/$_tiendaId/trabajadores'),
        headers: _headers,
      );
      if (!mounted) return;
      setState(() {
        _trabajadores = List<Map<String, dynamic>>.from(
            jsonDecode(res.body) as List? ?? []);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarTrabajador(String trabajadorId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar trabajador', style: TextStyle(fontSize: 16)),
        content: Text('¿Estás seguro de eliminar a $nombre de tu tienda? '
            'Su cuenta no será eliminada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await http.delete(
        Uri.parse('$_base/api/tienda/$_tiendaId/trabajadores/$trabajadorId'),
        headers: _headers,
      );
      await _cargarTrabajadores();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error al eliminar trabajador'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _verDatos(Map<String, dynamic> trabajador) {
    showDialog(
      context: context,
      builder: (_) => _DatosTrabajadorDialog(trabajador: trabajador),
    );
  }

  void _abrirFormulario() {
    showDialog(
      context: context,
      builder: (_) => _FormularioInvitacion(
        usuario: widget.usuario,
        onGuardado: _cargarTrabajadores,
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
              const Text('Trabajadores',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAzul.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_trabajadores.length} registrados',
                    style: const TextStyle(fontSize: 11, color: _kAzul)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _abrirFormulario,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Invitar trabajador'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDorado,
                  foregroundColor: _kAzul,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_cargando)
            const Expanded(
                child: Center(child: CircularProgressIndicator(color: _kDorado)))
          else if (_trabajadores.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 52,
                        color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Aún no tienes trabajadores registrados',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _abrirFormulario,
                      child: const Text('Invitar primer trabajador',
                          style: TextStyle(color: _kAzul)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: _kDorado,
                onRefresh: _cargarTrabajadores,
                child: ListView.separated(
                  itemCount: _trabajadores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final t = _trabajadores[i];
                    return _TrabajadorCard(
                      trabajador: t,
                      onEliminar: () => _eliminarTrabajador(
                          t['trabajador_id'], t['nombre'] ?? ''),
                      onVerDatos: () => _verDatos(t),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Card trabajador ───────────────────────────────────────────────────────────

class _TrabajadorCard extends StatelessWidget {
  final Map<String, dynamic> trabajador;
  final VoidCallback onEliminar;
  final VoidCallback onVerDatos;

  const _TrabajadorCard({
    required this.trabajador,
    required this.onEliminar,
    required this.onVerDatos,
  });

  @override
  Widget build(BuildContext context) {
    final nombre  = trabajador['nombre']  as String? ?? 'Sin nombre';
    final email   = trabajador['email']   as String? ?? '';
    final activo  = trabajador['activo']  as bool?   ?? false;
    final desde   = _formatFecha(trabajador['desde']?.toString() ?? '');
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _kAzul.withOpacity(0.1),
            child: Text(inicial,
                style: const TextStyle(
                    color: _kAzul,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: activo
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: activo
                                ? const Color(0xFF166534)
                                : const Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(email,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text('Desde: $desde',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Row(
            children: [
              _iconBtn(Icons.info_outline, _kAzul.withOpacity(0.7),
                  onVerDatos, tooltip: 'Ver datos'),
              const SizedBox(width: 6),
              _iconBtn(Icons.person_remove_outlined, Colors.red.shade300,
                  onEliminar, tooltip: 'Eliminar de tienda'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap,
      {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border:
                Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Dialog datos trabajador ───────────────────────────────────────────────────

class _DatosTrabajadorDialog extends StatelessWidget {
  final Map<String, dynamic> trabajador;
  const _DatosTrabajadorDialog({required this.trabajador});

  @override
  Widget build(BuildContext context) {
    final nombre  = trabajador['nombre'] as String? ?? '';
    final email   = trabajador['email']  as String? ?? '';
    final activo  = trabajador['activo'] as bool?   ?? false;
    final desde   = _formatFecha(trabajador['desde']?.toString() ?? '');
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _kAzul.withOpacity(0.1),
                child: Text(inicial,
                    style: const TextStyle(
                        color: _kAzul,
                        fontSize: 28,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: activo
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activo ? 'Cuenta activa' : 'Cuenta inactiva',
                  style: TextStyle(
                      fontSize: 11,
                      color: activo
                          ? const Color(0xFF166534)
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _datoRow(Icons.email_outlined, 'Correo', email),
              const SizedBox(height: 12),
              _datoRow(Icons.work_outline, 'Trabajador desde', desde),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cerrar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datoRow(IconData icono, String label, String valor) => Row(
        children: [
          Icon(icono, size: 16, color: _kDorado),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9CA3AF))),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      );

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Formulario invitación ─────────────────────────────────────────────────────

class _FormularioInvitacion extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onGuardado;

  const _FormularioInvitacion({
    required this.usuario,
    required this.onGuardado,
  });

  @override
  State<_FormularioInvitacion> createState() => _FormularioInvitacionState();
}

class _FormularioInvitacionState extends State<_FormularioInvitacion> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _enviando   = false;
  bool _enviado    = false;

  String get _base     => Env.apiUrl;
  String get _token    => widget.usuario['token'] ?? '';
  String get _tiendaId => widget.usuario['tienda_id'] ?? '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarInvitacion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final res = await http.post(
        Uri.parse('$_base/api/tienda/$_tiendaId/invitar-trabajador'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': _emailCtrl.text.trim()}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() { _enviando = false; _enviado = true; });
        widget.onGuardado();
      } else {
        final data = jsonDecode(res.body);
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['error'] ?? 'Error al enviar invitación'),
              backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error de conexión'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _enviado ? _vistaExito() : _vistaFormulario(),
        ),
      ),
    );
  }

  Widget _vistaExito() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: Color(0xFF166534), size: 28),
        ),
        const SizedBox(height: 16),
        const Text('¡Invitación enviada!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'Se envió un correo a ${_emailCtrl.text.trim()} con el enlace para completar su registro.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAzul,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cerrar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _vistaFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invitar trabajador',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Se enviará un correo con un enlace para que el trabajador complete su registro.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              labelStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.email_outlined,
                  size: 18, color: Color(0xFF6B7280)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kAzul),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (!v.contains('@')) return 'Ingresa un email válido';
              return null;
            },
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviarInvitacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDorado,
                    foregroundColor: _kAzul,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kAzul))
                      : const Text('Enviar invitación',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}