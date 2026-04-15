import 'package:flutter/material.dart';
import 'search_page.dart'; // cambiado

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiteBytes',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const SearchPage(),
    );
  }
}