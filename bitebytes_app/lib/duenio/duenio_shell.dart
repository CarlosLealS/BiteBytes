import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'dashboard_page.dart';
import 'tienda_page.dart';
import 'productos_page.dart';
import 'publicaciones_page.dart';
import 'trabajadores_page.dart';
import 'valoraciones_page.dart';
import 'capacitacion_page.dart';
import 'menu_casino_page.dart';
import 'package:bitebytes_app/login.dart';

const kAzul      = Color(0xFF0B1F5C);
const kDorado    = Color(0xFFF5A623);
const kAzulClaro = Color(0xFF1A3080);

class DuenioShell extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const DuenioShell({super.key, required this.usuario});

  @override
  State<DuenioShell> createState() => _DuenioShellState();
}

class _DuenioShellState extends State<DuenioShell> {
  int _paginaActual = 0;

  bool get _esCasino =>
      widget.usuario['es_casino'] == true ||
      widget.usuario['es_casino'] == 'true';

  // true si es trabajador_tienda (no dueño)
  bool get _esTrabajador =>
      widget.usuario['rol'] == 'trabajador_tienda';

  List<_NavItem> get _navItems {
    final items = [
      _NavItem(icono: Icons.dashboard_outlined,  label: 'Dashboard',     seccion: 'General'),
      _NavItem(icono: Icons.store_outlined,       label: 'Mi tienda',     seccion: 'General'),
      _NavItem(icono: Icons.inventory_2_outlined, label: 'Productos',     seccion: 'Gestión'),
      _NavItem(icono: Icons.campaign_outlined,    label: 'Publicaciones', seccion: 'Gestión'),
    ];

    // Solo dueños ven Trabajadores
    if (!_esTrabajador) {
      items.add(_NavItem(icono: Icons.people_outline, label: 'Trabajadores', seccion: 'Gestión'));
    }

    // Solo casinos ven Menú Casino
    if (_esCasino) {
      items.add(_NavItem(icono: Icons.restaurant_menu_outlined, label: 'Menú Casino', seccion: 'Gestión'));
    }

    items.addAll([
      _NavItem(icono: Icons.star_border_rounded, label: 'Valoraciones', seccion: 'Análisis'),
      _NavItem(icono: Icons.school_outlined,     label: 'Capacitación', seccion: 'Ayuda'),
    ]);

    return items;
  }

  Widget _paginaActiva() {
    final label = _navItems[_paginaActual].label;
    switch (label) {
      case 'Dashboard':     return DashboardPage(usuario: widget.usuario);
      case 'Mi tienda':     return TiendaPage(usuario: widget.usuario);
      case 'Productos':     return ProductosPage(usuario: widget.usuario);
      case 'Publicaciones': return PublicacionesPage(usuario: widget.usuario);
      case 'Trabajadores':  return TrabajadoresPage(usuario: widget.usuario);
      case 'Menú Casino':   return MenuCasinoPage(usuario: widget.usuario);
      case 'Valoraciones':  return ValoracionesPage(usuario: widget.usuario);
      case 'Capacitación':  return const CapacitacionPage();
      default:              return DashboardPage(usuario: widget.usuario);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          _Sidebar(
            navItems: _navItems,
            paginaActual: _paginaActual,
            usuario: widget.usuario,
            esCasino: _esCasino,
            esTrabajador: _esTrabajador,
            onItemTap: (i) => setState(() => _paginaActual = i),
          ),
          Expanded(
            child: Column(
              children: [
                _Topbar(
                  titulo: _navItems[_paginaActual].label,
                  usuario: widget.usuario,
                  esCasino: _esCasino,
                  esTrabajador: _esTrabajador,
                ),
                Expanded(child: _paginaActiva()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<_NavItem> navItems;
  final int paginaActual;
  final Map<String, dynamic> usuario;
  final bool esCasino;
  final bool esTrabajador;
  final ValueChanged<int> onItemTap;

  const _Sidebar({
    required this.navItems,
    required this.paginaActual,
    required this.usuario,
    required this.esCasino,
    required this.esTrabajador,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final secciones = <String>[];
    for (final item in navItems) {
      if (!secciones.contains(item.seccion)) secciones.add(item.seccion);
    }

    return Container(
      width: 210,
      color: kAzul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarLogo(
            nombreTienda: usuario['tienda'] ?? 'Mi Tienda',
            esCasino: esCasino,
            esTrabajador: esTrabajador,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final seccion in secciones) ...[
                  _seccionLabel(seccion),
                  for (int i = 0; i < navItems.length; i++)
                    if (navItems[i].seccion == seccion)
                      _item(i),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, thickness: 0.5, height: 1),
          _SidebarFooter(usuario: usuario),
        ],
      ),
    );
  }

  Widget _seccionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _item(int index) {
    final item        = navItems[index];
    final activo      = paginaActual == index;
    final esCasinoItem = item.label == 'Menú Casino';

    return InkWell(
      onTap: () => onItemTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: activo ? kDorado.withOpacity(0.15) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: activo ? kDorado : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(item.icono, size: 18,
                color: activo
                    ? kDorado
                    : esCasinoItem
                        ? Colors.white70
                        : Colors.white54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: activo
                      ? kDorado
                      : esCasinoItem
                          ? Colors.white70
                          : Colors.white60,
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (esCasinoItem && !activo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kDorado.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Casino',
                    style: TextStyle(color: kDorado, fontSize: 9, fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sidebar Logo ──────────────────────────────────────────────────────────────

class _SidebarLogo extends StatelessWidget {
  final String nombreTienda;
  final bool esCasino;
  final bool esTrabajador;
  const _SidebarLogo({
    required this.nombreTienda,
    required this.esCasino,
    required this.esTrabajador,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BiteBytes',
              style: TextStyle(
                color: kDorado,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(nombreTienda,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              if (esTrabajador) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Trabajador',
                      style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w500)),
                ),
              ] else if (esCasino) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kDorado.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Casino',
                      style: TextStyle(color: kDorado, fontSize: 9, fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Footer ────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final Map<String, dynamic> usuario;
  const _SidebarFooter({required this.usuario});

  Future<void> _cerrarSesion(BuildContext context) async {
    try {
      final token = usuario['token'] as String? ?? '';
      if (token.isEmpty) {
        _limpiarURLYNavegar(context);
        return;
      }
      await http.post(
        Uri.parse('${Env.apiUrl}/api/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
    } finally {
      if (context.mounted) _limpiarURLYNavegar(context);
    }
  }

  void _limpiarURLYNavegar(BuildContext context) {
    html.window.history.replaceState(null, '', Uri.base.toString().split('?')[0]);
    _navegarAlLogin(context);
  }

  void _navegarAlLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: kDorado.withOpacity(0.2),
            child: Text(
              (usuario['nombre'] as String? ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                  color: kDorado, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(usuario['nombre'] ?? 'Usuario',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
    );
  }
}

// ─── Topbar ────────────────────────────────────────────────────────────────────

class _Topbar extends StatelessWidget {
  final String titulo;
  final Map<String, dynamic> usuario;
  final bool esCasino;
  final bool esTrabajador;

  const _Topbar({
    required this.titulo,
    required this.usuario,
    required this.esCasino,
    required this.esTrabajador,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
          const Spacer(),
          if (esTrabajador)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.badge_outlined, size: 13, color: Color(0xFF6B7280)),
                  SizedBox(width: 4),
                  Text('Trabajador',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else if (esCasino)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kAzul.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant, size: 13, color: kAzul),
                  SizedBox(width: 4),
                  Text('Casino',
                      style: TextStyle(fontSize: 11, color: kAzul,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Text(usuario['email'] ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 15,
            backgroundColor: kAzul,
            child: Text(
              (usuario['nombre'] as String? ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                  color: kDorado, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modelo NavItem ────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icono;
  final String label;
  final String seccion;
  const _NavItem({required this.icono, required this.label, required this.seccion});
}