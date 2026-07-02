import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'package:intl/intl.dart';
import 'tienda_detalle_page.dart';

const _kAzul   = Color(0xFF0B1F5C);
const _kDorado = Color(0xFFF5A623);

class OfertasPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const OfertasPage({super.key, required this.usuario});

  @override
  State<OfertasPage> createState() => _OfertasPageState();
}

class _OfertasPageState extends State<OfertasPage> {
  bool _cargando = true;
  List<dynamic> _ofertas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await http.get(Uri.parse('${Env.apiUrl}/api/publicaciones/ofertas'));
      if (!mounted) return;
      setState(() {
        _ofertas = jsonDecode(res.body) as List? ?? [];
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: _kAzul,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.local_offer, color: _kDorado, size: 20),
            SizedBox(width: 8),
            Text('Ofertas y Promociones',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kDorado))
          : _ofertas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No hay ofertas activas en este momento',
                          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _cargar,
                        child: const Text('Volver a intentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kDorado,
                  onRefresh: _cargar,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _ofertas.length,
                    itemBuilder: (ctx, i) => _OfertaCard(
                      oferta: _ofertas[i],
                      usuario: widget.usuario,
                    ),
                  ),
                ),
    );
  }
}

class _OfertaCard extends StatelessWidget {
  final dynamic oferta;
  final Map<String, dynamic> usuario;
  const _OfertaCard({required this.oferta, required this.usuario});

  String _formatPrecio(dynamic valor) {
    if (valor == null) return '';
    final n = num.tryParse(valor.toString());
    return n != null ? NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0).format(n) : '';
  }

  @override
  Widget build(BuildContext context) {
    final imagenes   = oferta['imagenes'] as List? ?? [];
    final primeraImg = imagenes.isNotEmpty ? imagenes[0]['imagen_url'] as String? : null;
    final precio     = oferta['precio_oferta'];
    final expira     = oferta['expira_en'] != null ? DateTime.tryParse(oferta['expira_en']) : null;
    final tiendaNombre = oferta['tienda_nombre'] ?? '';
    final nombre       = oferta['nombre'] ?? '';
    final desc         = oferta['descripcion'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TiendaDetallePage(
            tiendaId: oferta['tienda_id'],
            usuario: usuario,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: primeraImg != null
                        ? Image.network(primeraImg, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                // Badge oferta
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kDorado,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _kDorado.withOpacity(0.4), blurRadius: 6)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer, size: 12, color: _kAzul),
                        SizedBox(width: 4),
                        Text('OFERTA',
                            style: TextStyle(fontSize: 10, color: _kAzul,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
                // Chip tienda
                Positioned(
                  bottom: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tiendaNombre,
                        style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const Spacer(),
                    if (precio != null) ...[
                      Text(_formatPrecio(precio),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: _kAzul)),
                    ],
                    if (expira != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Expira: ${DateFormat('dd/MM HH:mm').format(expira.toLocal())}',
                            style: const TextStyle(fontSize: 11, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TiendaDetallePage(
                              tiendaId: oferta['tienda_id'],
                              usuario: usuario,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAzul,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Ver tienda', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF9FAFB),
    child: Center(
      child: Icon(Icons.local_offer_outlined, size: 40, color: Colors.grey.shade300),
    ),
  );
}
