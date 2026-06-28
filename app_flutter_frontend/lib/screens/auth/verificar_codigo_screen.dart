import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class VerificarCodigoScreen extends StatefulWidget {
  final String email;

  const VerificarCodigoScreen({super.key, required this.email});

  @override
  State<VerificarCodigoScreen> createState() => _VerificarCodigoScreenState();
}

class _VerificarCodigoScreenState extends State<VerificarCodigoScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _codigoCtrl     = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool  _isLoading      = false;
  bool  _obscurePass    = true;
  bool  _obscureConfirm = true;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _restablecer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService().restablecerPassword(
        widget.email,
        _codigoCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('¡Contraseña actualizada! Ya puedes iniciar sesión.'),
            backgroundColor: Colors.green,
            duration:        Duration(seconds: 3),
          ),
        );
        // Navegar de vuelta al login, limpiando el stack de navegación
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        final msg = result['data']['msg'] ?? 'Error al restablecer la contraseña';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Sin conexión. Verifica tu internet e intenta de nuevo.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        foregroundColor: Colors.white,
        title: const Text('Verificar código'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Icon(Icons.verified_outlined, size: 56, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Ingresa tu código',
                          style: TextStyle(
                            fontSize:   20,
                            fontWeight: FontWeight.bold,
                            color:      Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Enviamos un código de 6 dígitos a\n${widget.email}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Código OTP
                      TextFormField(
                        controller:   _codigoCtrl,
                        keyboardType: TextInputType.number,
                        maxLength:    6,
                        textAlign:    TextAlign.center,
                        style: const TextStyle(
                          fontSize:      28,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: const InputDecoration(
                          labelText:  'Código de 6 dígitos',
                          border:     OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa el código';
                          if (v.length != 6) return 'Debe tener 6 dígitos';
                          if (int.tryParse(v) == null) return 'Solo dígitos numéricos';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nueva contraseña
                      TextFormField(
                        controller:  _passwordCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText:  'Nueva contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border:     const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirmar contraseña
                      TextFormField(
                        controller:  _confirmCtrl,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText:  'Confirmar contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border:     const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                          if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width:  double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _restablecer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Restablecer contraseña',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
