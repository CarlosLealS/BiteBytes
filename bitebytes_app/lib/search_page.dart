import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Caja superior con logo
          Container(
            width: double.infinity,
            color: const Color(0xFF001455),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo-ucn.png',
                  height: 80,
                ),
              ],
            ),
          ),

          // Barra de búsqueda debajo de la caja
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF001455)),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF001455)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
/*  ------------------------------------EN TRABAJO-------------------------------------------------
        // Mapa de locales
         Stack(
            children: [
              // Imagen de fondo
              Image.asset("assets/MapaUCN.png", width: double.infinity, fit: BoxFit.cover),
              // punto con tooltip
              Positioned(
                left: 120,
                top: 80,
                child: GestureDetector(
                  onTap: (){
                    //accion al tocar
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              )
            ]
          )
--------------------------------------------------------------------*/
        ],        
      ),
    );
  }
}