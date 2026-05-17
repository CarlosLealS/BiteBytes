import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bitebytes_app/config/env.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);
final _kBase   = Env.apiUrl;

// ─── Página principal ──────────────────────────────────────────────────────────

class MenuCasinoPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const MenuCasinoPage({super.key, required this.usuario});

  @override
  State<MenuCasinoPage> createState() => _MenuCasinoPageState();
}

class _MenuCasinoPageState extends State<MenuCasinoPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _menus = [];
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, List<Map<String, dynamic>>> _menusPorFecha = {};
  DateTime? _fechaSeleccionada;

  String _fechaKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> get _menusDiaSeleccionado {
    if (_fechaSeleccionada == null) return [];
    return _menusPorFecha[_fechaKey(_fechaSeleccionada!)] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = DateTime.now();
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
      final lista = List<Map<String, dynamic>>.from(
          jsonDecode(res.body) as List? ?? []);
      final porFecha = <String, List<Map<String, dynamic>>>{};
      for (final m in lista) {
        final fecha = m['fecha']?.toString().split('T')[0] ?? '';
        if (fecha.isNotEmpty) porFecha.putIfAbsent(fecha, () => []).add(m);
      }
      setState(() {
        _menus         = lista;
        _menusPorFecha = porFecha;
        _cargando      = false;
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
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
        const SnackBar(
            content: Text('Error al eliminar'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _abrirFormulario({Map<String, dynamic>? menu, DateTime? fechaInicial}) {
    showDialog(
      context: context,
      builder: (_) => _FormularioMenu(
        usuario: widget.usuario,
        menu: menu,
        fechaInicial: fechaInicial ?? _fechaSeleccionada,
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAzul.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Calendario',
                    style: TextStyle(fontSize: 11, color: _kAzul)),
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
                child:
                    Center(child: CircularProgressIndicator(color: _kDorado)))
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: _Calendario(
                      mesActual: _mesActual,
                      menusPorFecha: _menusPorFecha,
                      fechaSeleccionada: _fechaSeleccionada,
                      onAnterior: () => setState(() => _mesActual =
                          DateTime(_mesActual.year, _mesActual.month - 1)),
                      onSiguiente: () => setState(() => _mesActual =
                          DateTime(_mesActual.year, _mesActual.month + 1)),
                      onDiaTap: (fecha) =>
                          setState(() => _fechaSeleccionada = fecha),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _PanelDia(
                      fechaSeleccionada: _fechaSeleccionada,
                      menus: _menusDiaSeleccionado,
                      onAgregarMenu: () =>
                          _abrirFormulario(fechaInicial: _fechaSeleccionada),
                      onEditar: (m) => _abrirFormulario(menu: m),
                      onEliminar: (id) => _eliminar(id),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Panel derecho ─────────────────────────────────────────────────────────────

class _PanelDia extends StatelessWidget {
  final DateTime? fechaSeleccionada;
  final List<Map<String, dynamic>> menus;
  final VoidCallback onAgregarMenu;
  final void Function(Map<String, dynamic>) onEditar;
  final void Function(String) onEliminar;

  const _PanelDia({
    required this.fechaSeleccionada,
    required this.menus,
    required this.onAgregarMenu,
    required this.onEditar,
    required this.onEliminar,
  });

  String _formatFechaHeader(DateTime dt) {
    const dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final hoy = DateTime.now();
    final esHoy = dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day;
    final d = dias[dt.weekday - 1];
    return esHoy
        ? 'Hoy — $d ${dt.day} de ${meses[dt.month - 1]}'
        : '$d ${dt.day} de ${meses[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (fechaSeleccionada == null) {
      return const Center(
        child: Text('Selecciona un día en el calendario',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: _kAzul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatFechaHeader(fechaSeleccionada!),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827)),
                ),
              ),
              if (menus.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAzul.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${menus.length} ${menus.length == 1 ? 'menú' : 'menús'}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _kAzul,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              TextButton.icon(
                onPressed: onAgregarMenu,
                icon: const Icon(Icons.add, size: 15, color: _kDorado),
                label: const Text('Agregar menú',
                    style: TextStyle(
                        color: _kDorado,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  backgroundColor: _kDorado.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: menus.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_outlined,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No hay menús para este día',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 14)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onAgregarMenu,
                        icon: const Icon(Icons.add, size: 16, color: _kAzul),
                        label: const Text('Crear el primer menú',
                            style: TextStyle(color: _kAzul, fontSize: 13)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: menus.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MenuCard(
                    menu: menus[i],
                    indice: i + 1,
                    totalMenus: menus.length,
                    onEliminar: () => onEliminar(menus[i]['id']),
                    onEditar: () => onEditar(menus[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Calendario ────────────────────────────────────────────────────────────────

class _Calendario extends StatelessWidget {
  final DateTime mesActual;
  final Map<String, List<Map<String, dynamic>>> menusPorFecha;
  final DateTime? fechaSeleccionada;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final void Function(DateTime) onDiaTap;

  const _Calendario({
    required this.mesActual,
    required this.menusPorFecha,
    required this.fechaSeleccionada,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onDiaTap,
  });

  @override
  Widget build(BuildContext context) {
    final diasSemana = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
    final primerDia  = DateTime(mesActual.year, mesActual.month, 1);
    final diasMes    = DateTime(mesActual.year, mesActual.month + 1, 0).day;
    final offset     = (primerDia.weekday - 1) % 7;
    final hoy        = DateTime.now();
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
                   'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onAnterior,
                icon: const Icon(Icons.chevron_left, color: _kAzul),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: Text('${meses[mesActual.month - 1]} ${mesActual.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
              ),
              IconButton(
                onPressed: onSiguiente,
                icon: const Icon(Icons.chevron_right, color: _kAzul),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: diasSemana
                .map((d) => Expanded(
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: offset + diasMes,
            itemBuilder: (_, index) {
              if (index < offset) return const SizedBox();
              final dia      = index - offset + 1;
              final fecha    = DateTime(mesActual.year, mesActual.month, dia);
              final fechaStr = '${mesActual.year}-${mesActual.month.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}';
              final menusDelDia   = menusPorFecha[fechaStr] ?? [];
              final cantidadMenus = menusDelDia.length;
              final tieneMenu     = cantidadMenus > 0;
              final esHoy         = fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
              final esSeleccionado = fechaSeleccionada != null &&
                  fecha.year == fechaSeleccionada!.year &&
                  fecha.month == fechaSeleccionada!.month &&
                  fecha.day == fechaSeleccionada!.day;

              return GestureDetector(
                onTap: () => onDiaTap(fecha),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: esSeleccionado
                        ? _kDorado
                        : tieneMenu
                            ? _kAzul
                            : esHoy
                                ? _kDorado.withOpacity(0.15)
                                : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: esHoy && !tieneMenu && !esSeleccionado
                        ? Border.all(color: _kDorado, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$dia',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: tieneMenu || esHoy || esSeleccionado
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: esSeleccionado
                                ? _kAzul
                                : tieneMenu
                                    ? Colors.white
                                    : esHoy
                                        ? _kDorado
                                        : const Color(0xFF374151),
                          )),
                      if (tieneMenu && cantidadMenus > 1)
                        Container(
                          margin: const EdgeInsets.only(top: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: esSeleccionado
                                ? _kAzul.withOpacity(0.2)
                                : _kDorado,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$cantidadMenus',
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: _kAzul)),
                        )
                      else if (tieneMenu)
                        Container(
                          width: 4, height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: esSeleccionado ? _kAzul : _kDorado,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: _kAzul, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Con menú', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
              const SizedBox(width: 10),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: _kDorado, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Seleccionado', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
              const SizedBox(width: 10),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                    border: Border.all(color: _kDorado, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 4),
              const Text('Hoy', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card menú ─────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final Map<String, dynamic> menu;
  final int indice;
  final int totalMenus;
  final VoidCallback onEliminar;
  final VoidCallback onEditar;

  const _MenuCard({
    required this.menu,
    required this.indice,
    required this.totalMenus,
    required this.onEliminar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final fecha  = _formatFecha(menu['fecha']?.toString() ?? '');
    final esHoy  = _esHoy(menu['fecha']?.toString() ?? '');
    final platos = menu['platos'] as List? ?? [];
    final precioMenu = menu['precio'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esHoy ? _kDorado.withOpacity(0.5) : const Color(0xFFE5E7EB),
          width: esHoy ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                if (totalMenus > 1) ...[
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: esHoy ? _kDorado.withOpacity(0.3) : _kAzul.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('$indice',
                          style: TextStyle(
                              color: esHoy ? Colors.white : _kAzul,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.calendar_today_outlined,
                    size: 14,
                    color: esHoy ? _kDorado : const Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(fecha,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: esHoy ? Colors.white : const Color(0xFF374151))),
                if (esHoy) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: _kDorado,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('Hoy',
                        style: TextStyle(
                            fontSize: 10,
                            color: _kAzul,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                _iconBtn(Icons.edit_outlined,
                    esHoy ? Colors.white60 : _kAzul.withOpacity(0.6), onEditar),
                const SizedBox(width: 6),
                _iconBtn(Icons.delete_outline, Colors.red.shade300, onEliminar),
              ],
            ),
          ),

          // Nombre, descripción y precio del menú
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(menu['nombre'] ?? '',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827))),
                      if (menu['descripcion'] != null &&
                          menu['descripcion'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(menu['descripcion'],
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ],
                  ),
                ),
                // Precio del menú completo
                if (precioMenu != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kDorado.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _kDorado.withOpacity(0.4), width: 1),
                    ),
                    child: Column(
                      children: [
                        const Text('Precio menú',
                            style: TextStyle(
                                fontSize: 9,
                                color: _kAzul,
                                fontWeight: FontWeight.w500)),
                        Text('\$$precioMenu',
                            style: const TextStyle(
                                fontSize: 14,
                                color: _kAzul,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Platos
          if (platos.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: platos
                    .map((p) => _PlatoChip(plato: p as Map<String, dynamic>))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
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
      final dt = DateTime.parse(fecha);
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

// ─── Chip de plato ─────────────────────────────────────────────────────────────

class _PlatoChip extends StatelessWidget {
  final Map<String, dynamic> plato;
  const _PlatoChip({required this.plato});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plato['etiqueta'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kAzul.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(plato['etiqueta'],
                  style: const TextStyle(
                      fontSize: 9,
                      color: _kAzul,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 6),
          ],
          Text(plato['nombre'] ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          // Precio del plato es opcional
          if (plato['precio'] != null) ...[
            const SizedBox(width: 6),
            Text('\$${plato['precio']}',
                style: const TextStyle(
                    fontSize: 11,
                    color: _kAzul,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

// ─── Formulario menú ───────────────────────────────────────────────────────────

class _FormularioMenu extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final Map<String, dynamic>? menu;
  final DateTime? fechaInicial;
  final VoidCallback onGuardado;

  const _FormularioMenu({
    required this.usuario,
    required this.onGuardado,
    this.menu,
    this.fechaInicial,
  });

  @override
  State<_FormularioMenu> createState() => _FormularioMenuState();
}

class _FormularioMenuState extends State<_FormularioMenu> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _precioCtrl = TextEditingController(); // precio del menú completo
  DateTime? _fecha;
  List<_PlatoEditable> _platos = [];
  bool _guardando = false;

  bool get _esEdicion => widget.menu != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final m = widget.menu!;
      _nombreCtrl.text = m['nombre'] ?? '';
      _descCtrl.text   = m['descripcion'] ?? '';
      _precioCtrl.text = m['precio']?.toString() ?? '';
      _fecha = m['fecha'] != null ? DateTime.tryParse(m['fecha']) : null;
      final platos = m['platos'] as List? ?? [];
      _platos = platos
          .map((p) => _PlatoEditable.desdeJson(p as Map<String, dynamic>))
          .toList();
    } else {
      _fecha = widget.fechaInicial ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    for (final p in _platos) p.dispose();
    super.dispose();
  }

  void _agregarPlato() => setState(() => _platos.add(_PlatoEditable()));

  void _eliminarPlato(int i) => setState(() {
        _platos[i].dispose();
        _platos.removeAt(i);
      });

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('es', 'CL'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _kAzul, secondary: _kDorado),
        ),
        child: child!,
      ),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<String?> _subirImagen(_PlatoEditable plato) async {
    if (plato.imagenBytes == null) return plato.imagenUrl;
    final token   = widget.usuario['token'] ?? '';
    final request =
        http.MultipartRequest('POST', Uri.parse('$_kBase/api/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'imagen', plato.imagenBytes!,
      filename: plato.imagenNombre ?? 'imagen.jpg',
      contentType: MediaType.parse(plato.imagenMime ?? 'image/jpeg'),
    ));
    final response = await request.send();
    final body     = await response.stream.bytesToString();
    final data     = jsonDecode(body);
    return data['url'] as String?;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona una fecha'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final token    = widget.usuario['token'] ?? '';
      final tiendaId = widget.usuario['tienda_id'] ?? '';

      final platosJson = <Map<String, dynamic>>[];
      for (final p in _platos) {
        final url = await _subirImagen(p);
        platosJson.add({
          'nombre':      p.nombreCtrl.text.trim(),
          'descripcion': p.descCtrl.text.trim().isEmpty ? null : p.descCtrl.text.trim(),
          'imagen_url':  url,
          // precio del plato es opcional
          'precio':      p.precioCtrl.text.trim().isEmpty ? null : int.tryParse(p.precioCtrl.text.trim()),
          'etiqueta':    p.etiquetaCtrl.text.trim().isEmpty ? null : p.etiquetaCtrl.text.trim(),
        });
      }

      final body = jsonEncode({
        'tienda_id':   tiendaId,
        'fecha':       '${_fecha!.year}-${_fecha!.month.toString().padLeft(2, '0')}-${_fecha!.day.toString().padLeft(2, '0')}',
        'nombre':      _nombreCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        // precio del menú completo es opcional
        'precio':      _precioCtrl.text.trim().isEmpty ? null : int.tryParse(_precioCtrl.text.trim()),
        'platos':      platosJson,
      });

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };

      if (_esEdicion) {
        await http.put(
            Uri.parse('$_kBase/api/menu-casino/${widget.menu!['id']}'),
            headers: headers, body: body);
      } else {
        await http.post(Uri.parse('$_kBase/api/menu-casino'),
            headers: headers, body: body);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onGuardado();
    } catch (_) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error al guardar'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 560,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: _kAzul,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Text(_esEdicion ? 'Editar menú' : 'Nuevo menú del casino',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha
                      const Text('Fecha del menú',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151))),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _seleccionarFecha,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Text(
                                _fecha != null
                                    ? _formatFecha(_fecha!)
                                    : 'Seleccionar fecha',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _fecha != null
                                      ? const Color(0xFF111827)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Nombre del menú
                      _campo('Nombre del menú', _nombreCtrl,
                          requerido: true,
                          hint: 'Ej: Menú del día, Menú ejecutivo...'),
                      const SizedBox(height: 10),

                      // Descripción
                      _campo('Descripción (opcional)', _descCtrl,
                          maxLineas: 2,
                          hint: 'Ej: Incluye bebida y postre'),
                      const SizedBox(height: 10),

                      // ── Precio del menú completo ──────────────────────
                      _campo('Precio del menú (opcional)', _precioCtrl,
                          hint: 'Ej: 3500',
                          teclado: TextInputType.number,
                          prefijo: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 4),
                            child: Text('\$',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: _kAzul,
                                    fontWeight: FontWeight.w600)),
                          )),
                      const SizedBox(height: 4),
                      const Text(
                        'Si el menú tiene un precio único, ingrésalo aquí. '
                        'También puedes poner precios individuales por plato.',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 20),

                      // Platos
                      Row(
                        children: [
                          const Text('Platos',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827))),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _agregarPlato,
                            icon: const Icon(Icons.add,
                                size: 16, color: _kAzul),
                            label: const Text('Agregar plato',
                                style: TextStyle(
                                    color: _kAzul, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_platos.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 1),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.restaurant_outlined,
                                  size: 32, color: Color(0xFFD1D5DB)),
                              SizedBox(height: 8),
                              Text('Agrega los platos del menú',
                                  style: TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 13)),
                            ],
                          ),
                        )
                      else
                        ...List.generate(
                          _platos.length,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FormularioPlato(
                              plato: _platos[i],
                              numero: i + 1,
                              onEliminar: () => _eliminarPlato(i),
                              onImagenSeleccionada: () => setState(() {}),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: Color(0xFFE5E7EB), width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12)),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kAzul))
                          : Text(
                              _esEdicion ? 'Guardar cambios' : 'Crear menú',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime dt) {
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${dt.day} de ${meses[dt.month - 1]} ${dt.year}';
  }

  Widget _campo(
    String label,
    TextEditingController ctrl, {
    bool requerido = false,
    int maxLineas = 1,
    String? hint,
    TextInputType? teclado,
    Widget? prefijo,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLineas,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle:
            const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        prefix: prefijo,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kAzul),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      validator: requerido
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }
}

// ─── Formulario de plato individual ───────────────────────────────────────────

class _FormularioPlato extends StatefulWidget {
  final _PlatoEditable plato;
  final int numero;
  final VoidCallback onEliminar;
  final VoidCallback onImagenSeleccionada;

  const _FormularioPlato({
    required this.plato,
    required this.numero,
    required this.onEliminar,
    required this.onImagenSeleccionada,
  });

  @override
  State<_FormularioPlato> createState() => _FormularioplatoState();
}

class _FormularioplatoState extends State<_FormularioPlato> {
  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      widget.plato.imagenBytes  = bytes;
      widget.plato.imagenNombre = picked.name;
      widget.plato.imagenMime   = picked.mimeType ?? 'image/jpeg';
      widget.plato.imagenUrl    = null;
    });
    widget.onImagenSeleccionada();
  }

  @override
  Widget build(BuildContext context) {
    final tieneImagen = widget.plato.imagenBytes != null ||
        widget.plato.imagenUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                    color: _kAzul,
                    borderRadius: BorderRadius.circular(6)),
                child: Center(
                  child: Text('${widget.numero}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Plato',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151))),
              const Spacer(),
              InkWell(
                onTap: widget.onEliminar,
                child: const Icon(Icons.close,
                    size: 16, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Imagen
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60, height: 60,
                  child: widget.plato.imagenBytes != null
                      ? Image.memory(widget.plato.imagenBytes!,
                          fit: BoxFit.cover)
                      : widget.plato.imagenUrl != null
                          ? Image.network(widget.plato.imagenUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder())
                          : _placeholder(),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _seleccionarImagen,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 14, color: _kAzul),
                    label: Text(
                        tieneImagen ? 'Cambiar imagen' : 'Agregar imagen',
                        style: const TextStyle(color: _kAzul, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kAzul),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  if (tieneImagen) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() {
                        widget.plato.imagenBytes  = null;
                        widget.plato.imagenUrl    = null;
                        widget.plato.imagenNombre = null;
                      }),
                      child: const Text('Quitar imagen',
                          style:
                              TextStyle(fontSize: 10, color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nombre y etiqueta
          Row(
            children: [
              Expanded(
                  flex: 3,
                  child: _campoPlato(
                      'Nombre del plato *', widget.plato.nombreCtrl,
                      requerido: true)),
              const SizedBox(width: 8),
              Expanded(
                  flex: 2,
                  child: _campoPlato(
                      'Etiqueta', widget.plato.etiquetaCtrl,
                      hint: 'Ej: Entrada')),
            ],
          ),
          const SizedBox(height: 8),

          _campoPlato('Descripción (opcional)', widget.plato.descCtrl,
              maxLineas: 2),
          const SizedBox(height: 8),

          // Precio del plato — opcional
          Row(
            children: [
              SizedBox(
                width: 160,
                child: _campoPlato(
                    'Precio del plato (opcional)', widget.plato.precioCtrl,
                    hint: 'Ej: 1500',
                    teclado: TextInputType.number),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Déjalo vacío si el precio va en el menú completo.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFE5E7EB),
        child: const Center(
            child: Icon(Icons.restaurant_outlined,
                size: 24, color: Color(0xFF9CA3AF))),
      );

  Widget _campoPlato(
    String label,
    TextEditingController ctrl, {
    bool requerido = false,
    int maxLineas = 1,
    String? hint,
    TextInputType? teclado,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLineas,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12),
        hintStyle:
            const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _kAzul),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      validator: requerido
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : null,
    );
  }
}

// ─── Modelo editable de plato ──────────────────────────────────────────────────

class _PlatoEditable {
  final nombreCtrl   = TextEditingController();
  final descCtrl     = TextEditingController();
  final precioCtrl   = TextEditingController();
  final etiquetaCtrl = TextEditingController();

  Uint8List? imagenBytes;
  String?    imagenNombre;
  String?    imagenMime;
  String?    imagenUrl;

  _PlatoEditable();

  static _PlatoEditable desdeJson(Map<String, dynamic> json) {
    final p = _PlatoEditable();
    p.nombreCtrl.text   = json['nombre']      ?? '';
    p.descCtrl.text     = json['descripcion'] ?? '';
    p.precioCtrl.text   = json['precio']?.toString() ?? '';
    p.etiquetaCtrl.text = json['etiqueta']    ?? '';
    p.imagenUrl         = json['imagen_url']  as String?;
    return p;
  }

  void dispose() {
    nombreCtrl.dispose();
    descCtrl.dispose();
    precioCtrl.dispose();
    etiquetaCtrl.dispose();
  }
}