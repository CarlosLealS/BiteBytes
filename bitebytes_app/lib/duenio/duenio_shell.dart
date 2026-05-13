import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'tienda_page.dart';
import 'productos_page.dart';
import 'publicaciones_page.dart';
import 'trabajadores_page.dart';
import 'valoraciones_page.dart';
import 'capacitacion_page.dart';

const kAzul = Color(0xFF0B1F5C);
const kDorado = Color(0xFFF5A623);
const kAzulClaro = Color(0xFF1A3080);

class DuenioShell extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const DuenioShell({super.key, required this.usuario});

  @override
  State<DuenioShell> createState() => _DuenioShellState();
}

class _DuenioShellState extends State<DuenioShell> {
  int _paginaActual = 0;

  final List<_NavItem> _navItems = [
    _NavItem(icono: Icons.dashboard_outlined,      label: 'Dashboard'),
    _NavItem(icono: Icons.store_outlined,           label: 'Mi tienda'),
    _NavItem(icono: Icons.inventory_2_outlined,     label: 'Productos'),
    _NavItem(icono: Icons.campaign_outlined,        label: 'Publicaciones'),
    _NavItem(icono: Icons.people_outline,           label: 'Trabajadores'),
    _NavItem(icono: Icons.star_border_rounded,      label: 'Valoraciones'),
    _NavItem(icono: Icons.school_outlined,          label: 'Capacitación'),
  ];

  Widget _paginaActiva() {
    switch (_paginaActual) {
      case 0: return DashboardPage(usuario: widget.usuario);
      case 1: return const TiendaPage();
      case 2: return ProductosPage(usuario: widget.usuario);
      case 3: return PublicacionesPage(usuario: widget.usuario);
      case 4: return const TrabajadoresPage();
      case 5: return const ValoracionesPage();
      case 6: return const CapacitacionPage();
      default: return DashboardPage(usuario: widget.usuario);
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
            onItemTap: (i) => setState(() => _paginaActual = i),
          ),
          Expanded(
            child: Column(
              children: [
                _Topbar(
                  titulo: _navItems[_paginaActual].label,
                  usuario: widget.usuario,
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

class _Sidebar extends StatelessWidget {
  final List<_NavItem> navItems;
  final int paginaActual;
  final Map<String, dynamic> usuario;
  final ValueChanged<int> onItemTap;

  const _Sidebar({
    required this.navItems,
    required this.paginaActual,
    required this.usuario,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      color: kAzul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarLogo(nombreTienda: usuario['tienda'] ?? 'Mi Tienda'),
          const SizedBox(height: 8),
          _seccion('General'),
          _item(0),
          _item(1),
          _seccion('Gestión'),
          _item(2),
          _item(3),
          _item(4),
          _seccion('Análisis'),
          _item(5),
          _seccion('Ayuda'),
          _item(6),
          const Spacer(),
          const Divider(color: Colors.white12, thickness: 0.5, height: 1),
          _SidebarFooter(usuario: usuario),
        ],
      ),
    );
  }

  Widget _seccion(String label) => Padding(
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
    final item = navItems[index];
    final activo = paginaActual == index;
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
                color: activo ? kDorado : Colors.white54),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                color: activo ? kDorado : Colors.white60,
                fontSize: 13,
                fontWeight: activo ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  final String nombreTienda;
  const _SidebarLogo({required this.nombreTienda});

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
          const Text(
            'BiteBytes',
            style: TextStyle(
              color: kDorado,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            nombreTienda,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final Map<String, dynamic> usuario;
  const _SidebarFooter({required this.usuario});

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
              style: const TextStyle(color: kDorado, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              usuario['nombre'] ?? 'Usuario',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
            tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
          ),
        ],
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  final String titulo;
  final Map<String, dynamic> usuario;
  const _Topbar({required this.titulo, required this.usuario});

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
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              )),
          const Spacer(),
          Text(
            usuario['email'] ?? '',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 15,
            backgroundColor: kAzul,
            child: Text(
              (usuario['nombre'] as String? ?? 'U')[0].toUpperCase(),
              style: const TextStyle(color: kDorado, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icono;
  final String label;
  const _NavItem({required this.icono, required this.label});
}