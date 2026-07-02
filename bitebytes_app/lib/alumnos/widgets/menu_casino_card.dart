import 'package:flutter/material.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

// ─── Lista horizontal de menús casino ──────────────────────────────────────────

class MenuCasinoList extends StatelessWidget {
  final List<Map<String, dynamic>> menus;
  const MenuCasinoList({super.key, required this.menus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: menus.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => MenuCasinoCard(menu: menus[i]),
      ),
    );
  }
}

class MenuCasinoCard extends StatelessWidget {
  final Map<String, dynamic> menu;
  const MenuCasinoCard({super.key, required this.menu});

  @override
  Widget build(BuildContext context) {
    final nombre  = menu['nombre'] as String? ?? menu['tienda_nombre'] as String? ?? 'Casino';
    final platos  = (menu['platos'] as List? ?? []).cast<Map<String, dynamic>>();
    final preview = platos.take(3).toList();

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => MenuCasinoDetalle(menu: menu),
      ),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F5C), Color(0xFF1A3580)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: _kAzul.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: _kDorado.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.restaurant, color: _kDorado, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            if (preview.isEmpty)
              const Text('Sin platos registrados',
                  style: TextStyle(color: Colors.white38, fontSize: 11))
            else
              ...preview.map((p) => _platoRow(p)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${platos.length} plato${platos.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('Ver menú →',
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _platoRow(Map<String, dynamic> plato) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plato['etiqueta'] != null)
            SizedBox(
              width: 50,
              child: Text(plato['etiqueta'],
                  style: TextStyle(
                      color: _kDorado.withOpacity(0.8),
                      fontSize: 10, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(plato['nombre'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ),
          if (plato['precio'] != null)
            Text('\$${plato['precio']}',
                style: const TextStyle(
                    color: _kDorado, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class MenuCasinoDetalle extends StatelessWidget {
  final Map<String, dynamic> menu;
  const MenuCasinoDetalle({super.key, required this.menu});

  @override
  Widget build(BuildContext context) {
    final nombre      = menu['nombre'] as String? ?? menu['tienda_nombre'] as String? ?? 'Casino';
    final tienda      = menu['tienda_nombre'] as String? ?? '';
    final descripcion = menu['descripcion'] as String?;
    final platos      = (menu['platos'] as List? ?? []).cast<Map<String, dynamic>>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _kAzul,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: _kDorado.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.restaurant, color: _kDorado, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        if (tienda.isNotEmpty)
                          Text(tienda,
                              style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            if (descripcion != null && descripcion.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: _kAzul.withOpacity(0.05),
                child: Text(descripcion,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic)),
              ),
            Flexible(
              child: platos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Sin platos registrados',
                            style: TextStyle(color: Colors.grey)),
                      ))
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: platos.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 20, endIndent: 20),
                      itemBuilder: (_, i) => PlatoTile(plato: platos[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzul, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlatoTile extends StatelessWidget {
  final Map<String, dynamic> plato;
  const PlatoTile({super.key, required this.plato});

  @override
  Widget build(BuildContext context) {
    final nombre      = plato['nombre']      as String? ?? '';
    final descripcion = plato['descripcion'] as String?;
    final etiqueta    = plato['etiqueta']    as String?;
    final precio      = plato['precio'];
    final imagenUrl   = plato['imagen_url']  as String?;
    final valoracion  = plato['valoracion_media'];
    final totalRes    = plato['total_resenias'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56, height: 56,
              child: imagenUrl != null && imagenUrl.isNotEmpty
                  ? Image.network(imagenUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (etiqueta != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: _kDorado.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(etiqueta,
                            style: const TextStyle(
                                fontSize: 9, color: _kDorado, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                if (descripcion != null && descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(descripcion,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (precio != null)
                      Text('\$$precio',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: _kAzul)),
                    const Spacer(),
                    if (valoracion != null && valoracion.toString() != 'null') ...[
                      const Icon(Icons.star_rounded, size: 14, color: _kDorado),
                      const SizedBox(width: 2),
                      Text(valoracion.toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (totalRes != null && (int.tryParse(totalRes.toString()) ?? 0) > 0)
                        Text(' ($totalRes)',
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF3F4F6),
    child: const Center(child: Icon(Icons.restaurant_menu, size: 24, color: Color(0xFFD1D5DB))),
  );
}