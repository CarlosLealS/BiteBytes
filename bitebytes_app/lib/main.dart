import 'package:flutter/material.dart';
import 'home_page.dart'; // Importamos tu nueva página

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
        primarySwatch: Colors.orange, // Tema principal
      ),
      home: const HomePage(),
    );
  }
}

