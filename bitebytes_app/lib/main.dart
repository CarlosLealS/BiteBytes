import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_page.dart';
import 'search_page.dart';
import 'login.dart';
import 'home_page_principal.dart';
import 'duenio/duenio_shell.dart';

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
      theme: ThemeData(primarySwatch: Colors.orange),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'CL')],
      locale: const Locale('es', 'CL'),
      home: _hasLoginToken ? const HomePagePrincipal() : const LoginPage(),
    );
  }
}