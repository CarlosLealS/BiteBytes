import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_page.dart';
import 'login.dart';
import 'alumnos/alumno_home_page.dart';
import 'duenio/duenio_shell.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String? get _token {
    final t = Uri.base.queryParameters['token'];
    return (t != null && t.isNotEmpty) ? t : null;
  }

  Map<String, dynamic> _decodeToken(String token) {
    try {
      final parts   = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;

    Widget home;
    if (token != null) {
      final payload = _decodeToken(token);
      final usuario = {
        'id':       payload['id'],
        'email':    payload['email'],
        'nombre':   payload['email']?.toString().split('@').first ?? 'Usuario',
        'rol':      payload['rol'],
        'tienda_id': payload['tienda_id'],
        'es_casino': payload['es_casino'],
        'token':    token,
      };

      if (usuario['rol'] == 'duenio_tienda' ||
          usuario['rol'] == 'admin' ||
          usuario['rol'] == 'super_admin') {
        home = DuenioShell(usuario: usuario);
      } else {
        home = AlumnoHomePage(usuario: usuario);
      }
    } else {
      home = const LoginPage();
    }

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
      home: home,
    );
  }
}