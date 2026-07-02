import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bitebytes_app/config/env.dart';
import 'login.dart';

class ResetearContrasenaPage extends StatefulWidget {
  final String token;
  const ResetearContrasenaPage({super.key, required this.token});

  @override
  State<ResetearContrasenaPage> createState() => _ResetearContrasenaPageState();
}

class _ResetearContrasenaPageState extends State<ResetearContrasenaPage> {
  final _formKey      = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool    _verPassword  = false;
  bool    _verConfirm   = false;
  bool    _guardando    = false;
  bool    _tokenValido  = false;
  bool    _verificando  = true;
  String? _errorToken;
  String? _emailUsuario;
  String? _nombreUsuario;

  static final String _base = Env.apiUrl;

  @override
  void initState() {
    super.initState();
    _verificarToken();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarToken() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/auth/verificar-reset-contrasena?token=${widget.token}'),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _tokenValido   = true;
          _emailUsuario  = data['email'] as String?;
          _nombreUsuario = data['nombre'] as String?;
          _verificando   = false;
        });
      } else {
        final data = jsonDecode(res.body);
        setState(() {
          _tokenValido = false;
          _errorToken  = data['error'] ?? 'El enlace es inválido o ha expirado';
          _verificando = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tokenValido = false;
        _errorToken  = 'No se pudo conectar al servidor';
        _verificando = false;
      });
    }
  }

  Future<void> _resetear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final res = await http.post(
        Uri.parse('$_base/api/auth/resetear-contrasena'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token':    widget.token,
          'password': _passwordCtrl.text.trim(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Error al actualizar contraseña'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        setState(() => _guardando = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/campus_fondo.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _verificando
                    ? const CircularProgressIndicator(color: Color(0xFFF5A623))
                    : !_tokenValido
                        ? _vistaTokenInvalido()
                        : _vistaFormulario(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaTokenInvalido() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 56),
        const SizedBox(height: 16),
        Text(
          _errorToken ?? 'Enlace inválido o expirado',
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B1F5C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ir al inicio de sesión'),
        ),
      ],
    );
  }

  Widget _vistaFormulario() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'BiteBytes',
          style: TextStyle(
            fontSize: 36, fontWeight: FontWeight.bold,
            color: Colors.white, letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),

        // Indicador del usuario
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1F5C).withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_nombreUsuario ?? ''} · $_emailUsuario',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Nueva contraseña',
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
        const SizedBox(height: 32),

        Form(
          key: _formKey,
          child: Column(
            children: [
              // Nueva contraseña
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_verPassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDec('Nueva contraseña', Icons.lock_outline,
                    sufijo: IconButton(
                      icon: Icon(
                        _verPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54, size: 20,
                      ),
                      onPressed: () => setState(() => _verPassword = !_verPassword),
                    )),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  if (v.trim().length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Confirmar contraseña
              TextFormField(
                controller: _confirmCtrl,
                obscureText: !_verConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDec('Confirmar contraseña', Icons.lock_outline,
                    sufijo: IconButton(
                      icon: Icon(
                        _verConfirm ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54, size: 20,
                      ),
                      onPressed: () => setState(() => _verConfirm = !_verConfirm),
                    )),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  if (v.trim() != _passwordCtrl.text.trim()) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _resetear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1F5C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Cambiar contraseña',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String label, IconData icono, {Widget? sufijo}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icono, color: Colors.white54, size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF5A623), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
