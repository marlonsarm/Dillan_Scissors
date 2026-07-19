import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'admin_screen.dart';
import 'barber_pole.dart';
class AppColorsLogin {
  static const background = Color(0xFF15130F);
  static const surface = Color(0xFF211D17);
  static const gold = Color(0xFFB08D45);
  static const goldLight = Color(0xFFD4AF37);
  static const textPrimary = Color(0xFFF5F0E6);
  static const textSecondary = Color(0xFFA79C8A);
  static const divider = Color(0xFF332E24);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
 final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _authService = AuthService();

 bool _isLoading = false;
  bool _obscure = true;
  bool _esCliente = true;
  String? _errorMessage;

  List<String> _historialCorreos = [];
  List<String> _historialTelefonos = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final correos = _esCliente
        ? await _authService.getHistorialCorreosCliente()
        : await _authService.getHistorialCorreosBarbero();
    final telefonos = _esCliente
        ? await _authService.getHistorialTelefonosCliente()
        : <String>[];
    if (!mounted) return;
    setState(() {
      _historialCorreos = correos;
      _historialTelefonos = telefonos;
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final resultado = _esCliente
        ? await _authService.loginCliente(
            email: _emailController.text.trim(),
            telefono: _telefonoController.text.trim(),
          )
        : await _authService.loginBarbero(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

    setState(() => _isLoading = false);

    if (resultado["success"] == true) {
      if (_esCliente) {
        await _authService.guardarCorreoClienteHistorial(_emailController.text.trim());
        await _authService.guardarTelefonoClienteHistorial(_telefonoController.text.trim());
      } else {
        await _authService.guardarCorreoBarberoHistorial(_emailController.text.trim());
      }
      if (!mounted) return;
      final rol = resultado["data"]["usuario"]["rol"];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              rol == "admin" ? const AdminScreen() : const HomeScreen(),
        ),
      );
    } else {
      setState(() {
        _errorMessage = resultado["data"]["error"] ?? "Error al iniciar sesión";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
      backgroundColor: AppColorsLogin.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12, // súbelo o bájalo a tu gusto (0.0 a 1.0)
              child: Image.network(
                "https://res.cloudinary.com/sla80nsi/image/upload/v1783786272/FOO_oyia7e.jpg", // 👈 tu URL de fondo
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
            Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BarberPole(width: 12, height: 76),
                      const SizedBox(width: 14),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColorsLogin.goldLight, AppColorsLogin.gold],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColorsLogin.gold.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            "https://res.cloudinary.com/sla80nsi/image/upload/v1783654872/lll_qzpvxc.jpg",
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.content_cut, color: Colors.black, size: 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const BarberPole(width: 12, height: 76),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "DILAN SCISSORS",
                    style: TextStyle(
                      color: AppColorsLogin.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "El Arte De La Excelencia",
                    style: TextStyle(
                      color: AppColorsLogin.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 34),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColorsLogin.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColorsLogin.divider),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColorsLogin.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColorsLogin.divider),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _esCliente = true);
                                    _cargarHistorial();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _esCliente ? AppColorsLogin.gold : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      "CLIENTE",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _esCliente ? Colors.black : AppColorsLogin.textSecondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                onTap: () {
                                    setState(() => _esCliente = false);
                                    _cargarHistorial();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_esCliente ? AppColorsLogin.gold : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      "BARBERO",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_esCliente ? Colors.black : AppColorsLogin.textSecondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.length < 3) {
                              return const Iterable<String>.empty();
                            }
                            return _historialCorreos.where((opcion) => opcion
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (String seleccion) {
                            _emailController.text = seleccion;
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: AppColorsLogin.surface,
                                borderRadius: BorderRadius.circular(10),
                                elevation: 6,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 160, maxWidth: 304),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final opcion = options.elementAt(index);
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          opcion,
                                          style: const TextStyle(color: AppColorsLogin.textPrimary, fontSize: 13),
                                        ),
                                        onTap: () => onSelected(opcion),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            controller.text = _emailController.text;
                            controller.addListener(() {
                              _emailController.text = controller.text;
                            });
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppColorsLogin.textPrimary, fontSize: 14),
                              decoration: _decoration("Correo electrónico", Icons.email_outlined),
                            );
                          },
                        ),
                       const SizedBox(height: 14),
                      if (_esCliente)
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.length < 3) {
                                return const Iterable<String>.empty();
                              }
                              return _historialTelefonos.where((opcion) => opcion
                                  .toLowerCase()
                                  .contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (String seleccion) {
                              _telefonoController.text = seleccion;
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: AppColorsLogin.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  elevation: 6,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 160, maxWidth: 304),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final opcion = options.elementAt(index);
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            opcion,
                                            style: const TextStyle(color: AppColorsLogin.textPrimary, fontSize: 13),
                                          ),
                                          onTap: () => onSelected(opcion),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              controller.text = _telefonoController.text;
                              controller.addListener(() {
                                _telefonoController.text = controller.text;
                              });
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: AppColorsLogin.textPrimary, fontSize: 14),
                                decoration: _decoration("Número de teléfono", Icons.phone_outlined),
                              );
                            },
                          )
                        else
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            style: const TextStyle(color: AppColorsLogin.textPrimary, fontSize: 14),
                            decoration: _decoration("Contraseña", Icons.lock_outline).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColorsLogin.textSecondary,
                                  size: 19,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
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
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColorsLogin.gold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                  )
                                : const Text(
                                    "INICIAR SESIÓN",
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "¿No tienes cuenta? ",
                        style: const TextStyle(color: AppColorsLogin.textSecondary, fontSize: 13),
                        children: [
                          TextSpan(
                            text: "Regístrate",
                            style: TextStyle(color: AppColorsLogin.goldLight, fontWeight: FontWeight.w700),
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

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColorsLogin.background,
      labelText: label,
      labelStyle: const TextStyle(color: AppColorsLogin.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColorsLogin.gold, size: 19),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColorsLogin.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColorsLogin.gold, width: 1.4),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}