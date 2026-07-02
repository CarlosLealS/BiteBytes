import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'home_page.dart';
import 'registro_trabajador_page.dart';
import 'registro_duenio_page.dart';
import 'resetear_contrasena_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Detectar token y ruta en la URL
    final token = Uri.base.queryParameters['token'];
    final path  = Uri.base.path;

    final esRegistroTrabajador =
        path.contains('registro-trabajador') && token != null;
    final esRegistroDuenio =
        path.contains('registro-duenio') && token != null;
    final esResetContrasena =
        path.contains('resetear-contrasena') && token != null;

    Widget paginaInicial;
    if (esRegistroTrabajador) {
      paginaInicial = RegistroTrabajadorPage(token: token!);
    } else if (esRegistroDuenio) {
      paginaInicial = RegistroDuenioPage(token: token!);
    } else if (esResetContrasena) {
      paginaInicial = ResetearContrasenaPage(token: token!);
    } else if (token != null && token.isNotEmpty) {
      paginaInicial = const LoginPage();
    } else {
      paginaInicial = const HomePage();
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
      home: paginaInicial,
    );
  }
}