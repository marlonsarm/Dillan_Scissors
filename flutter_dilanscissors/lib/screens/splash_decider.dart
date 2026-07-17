import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'admin_screen.dart';
import '../services/auth_service.dart';

class _SplashColors {
  static const background = Color(0xFF15130F);
  static const gold = Color(0xFFB08D45);
  static const goldLight = Color(0xFFD4AF37);
}

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _decidirRuta();
  }

  Future<void> _decidirRuta() async {
    final sesionValida = await _authService.sesionValida();

    if (!sesionValida) {
      await _authService.logout(); // limpia token vencido o corrupto, si existía
      _irA(const HomeScreen());
      return;
    }

    final rol = await _authService.getRol();
    if (rol == "admin") {
      _irA(const AdminScreen());
    } else {
      _irA(const HomeScreen());
    }
  }

  void _irA(Widget pantalla) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => pantalla),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _SplashColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.content_cut, color: _SplashColors.gold, size: 48),
            SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_SplashColors.goldLight),
            ),
          ],
        ),
      ),
    );
  }
}