import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'package:bitebytes_app/login.dart';
import 'admin_tiendas_page.dart';
import 'admin_trabajadores_page.dart';
import 'admin_reportes_page.dart';

const kAzul      = Color(0xFF0B1F5C);
const kDorado    = Color(0xFFF5A623);

class AdminShell extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const AdminShell({super.key, required this.usuario});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _paginaActual = 0;

  List<_NavItem> get _navItems {
    return [
      _NavItem(icono: Icons.store_outlined, label: 'Tiendas UCN', seccion: 'Administración'),
      _NavItem(icono: Icons.people_outline, label: 'Trabajadores UCN', seccion: 'Administración'),
      _NavItem(icono: Icons.flag_outlined, label: 'Reportes', seccion: 'Moderación'),
    ];
  }

  Widget _paginaActiva() {
    final label = _navItems[_paginaActual].label;
    switch (label) {
      case 'Tiendas UCN':      return AdminTiendasPage(usuario: widget.usuario);
      case 'Trabajadores UCN': return AdminTrabajadoresPage(usuario: widget.usuario);
      case 'Reportes':         return AdminReportesPage(usuario: widget.usuario);
      default:                 return AdminTiendasPage(usuario: widget.usuario);
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

// ─── Sidebar ───────────────────────────────────────────────────────────────────

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
          _SidebarLogo(),
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
    final item   = navItems[index];
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
            Icon(item.icono, size: 18, color: activo ? kDorado : Colors.white54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: activo ? kDorado : Colors.white60,
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sidebar Logo ──────────────────────────────────────────────────────────────

class _SidebarLogo extends StatelessWidget {
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
              const Expanded(
                child: Text('Panel Administrativo UCN',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Admin',
                    style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w500)),
              ),
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
              (usuario['nombre'] as String? ?? 'A')[0].toUpperCase(),
              style: const TextStyle(color: kDorado, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(usuario['nombre'] ?? 'Administrador',
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

  const _Topbar({
    required this.titulo,
    required this.usuario,
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
          const Spacer(),
          Text(usuario['email'] ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 15,
            backgroundColor: kAzul,
            child: Text(
              (usuario['nombre'] as String? ?? 'A')[0].toUpperCase(),
              style: const TextStyle(color: kDorado, fontSize: 12, fontWeight: FontWeight.w600),
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
