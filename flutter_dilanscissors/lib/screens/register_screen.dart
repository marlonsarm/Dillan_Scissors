import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'barber_pole.dart';
class AppColorsRegister {
  static const background = Color(0xFF15130F);
  static const surface = Color(0xFF211D17);
  static const gold = Color(0xFFB08D45);
  static const goldLight = Color(0xFFD4AF37);
  static const textPrimary = Color(0xFFF5F0E6);
  static const textSecondary = Color(0xFFA79C8A);
  static const divider = Color(0xFF332E24);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
 final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegistro() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

  if (_nombreController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _telefonoController.text.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Nombre, correo y teléfono son obligatorios";
      });
      return;
    }

    final resultado = await _authService.registro(
      nombre: _nombreController.text.trim(),
      email: _emailController.text.trim(),
      telefono: _telefonoController.text.trim(),
    );

    if (resultado["success"] == true) {
      final loginResultado = await _authService.loginCliente(
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (loginResultado["success"] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = resultado["data"]["error"] ?? "Error al registrarse";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsRegister.background,
     appBar: AppBar(
        backgroundColor: AppColorsRegister.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColorsRegister.textPrimary),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.network(
                "https://res.cloudinary.com/sla80nsi/image/upload/v1783786272/FOO_oyia7e.jpg", 
               fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
               Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BarberPole(width: 10, height: 66),
                      const SizedBox(width: 12),
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColorsRegister.goldLight, AppColorsRegister.gold],
                          ),
                          boxShadow: [
                            BoxShadow(color: AppColorsRegister.gold.withOpacity(0.4), blurRadius: 18, spreadRadius: 1),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            "https://res.cloudinary.com/sla80nsi/image/upload/v1783654872/lll_qzpvxc.jpg",
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.content_cut, color: Colors.black, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const BarberPole(width: 10, height: 66),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "CREAR CUENTA",
                    style: TextStyle(
                      color: AppColorsRegister.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColorsRegister.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColorsRegister.divider),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nombreController,
                          style: const TextStyle(color: AppColorsRegister.textPrimary, fontSize: 14),
                          decoration: _inputDecoration("Nombre completo", Icons.person_outline),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColorsRegister.textPrimary, fontSize: 14),
                          decoration: _inputDecoration("Correo electrónico", Icons.email_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _telefonoController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: AppColorsRegister.textPrimary, fontSize: 14),
                          decoration: _inputDecoration("Teléfono", Icons.phone_outlined),
                        ),
                     if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegistro,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColorsRegister.gold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                  )
                                : const Text(
                                    "REGISTRARME",
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "¿Ya tienes cuenta? ",
                        style: const TextStyle(color: AppColorsRegister.textSecondary, fontSize: 13),
                        children: [
                          TextSpan(
                            text: "Inicia sesión",
                            style: TextStyle(color: AppColorsRegister.goldLight, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColorsRegister.background,
      labelText: label,
      labelStyle: const TextStyle(color: AppColorsRegister.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColorsRegister.gold, size: 19),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColorsRegister.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColorsRegister.gold, width: 1.4),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}