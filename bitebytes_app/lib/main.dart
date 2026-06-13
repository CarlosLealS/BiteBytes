import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'registro_trabajador_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Detectar token de invitación en la URL
    final token = Uri.base.queryParameters['token'];
    final esRegistroTrabajador =
        Uri.base.path.contains('registro-trabajador') && token != null;

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
      home: esRegistroTrabajador
          ? RegistroTrabajadorPage(token: token!)
          : const LoginPage(),
    );
  }
}