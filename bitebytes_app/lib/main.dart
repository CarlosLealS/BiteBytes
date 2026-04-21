import 'package:flutter/material.dart';
import 'home_page.dart'; // cambiado
import 'search_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  bool get _hasLoginToken {
    return Uri.base.queryParameters.containsKey('token') &&
        Uri.base.queryParameters['token']!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiteBytes',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: _hasLoginToken ? const SearchPage() : const HomePage(),
    );
  }
}