import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

// ============================================================
// PALETA DEL PERFIL — replica exacta de la paleta del Home
// (Home la tiene como clase privada, no se puede importar,
// así que se reconstruye aquí con los mismos valores).
// ============================================================
class _ProfilePaleta {
  final Color background;
  final Color surface;
  final Color gold;
  final Color goldLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color goldenBadge;

  const _ProfilePaleta({
    required this.background,
    required this.surface,
    required this.gold,
    required this.goldLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.goldenBadge,
  });
}

const _paletaPerfilNormal = _ProfilePaleta(
  background: Color(0xFF15130F),
  surface: Color(0xFF211D17),
  gold: Color(0xFFB08D45),
  goldLight: Color(0xFFD4AF37),
  textPrimary: Color(0xFFF5F0E6),
  textSecondary: Color(0xFFA79C8A),
  divider: Color(0xFF332E24),
  goldenBadge: Color(0xFFD4AF37),
);

const _paletaPerfilVip = _ProfilePaleta(
  background: Color(0xFF060504),
  surface: Color(0xFF1A140A),
  gold: Color(0xFFE8C468),
  goldLight: Color(0xFFF6DE9C),
  textPrimary: Color(0xFFFFFDF6),
  textSecondary: Color(0xFFC9B98A),
  divider: Color(0xFF3D2F12),
  goldenBadge: Color(0xFFFFD700),
);


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  final AuthService _authService = AuthService();

  String nombre = '';
  String email = '';
  String? fotoUrl;
  bool esGoldenMember = false;
  int cortesCompletados = 0;
  List<dynamic> misReservas = [];
  bool cargando = true;
  bool subiendoFoto = false;

 // ---- Datos de Cloudinary (unsigned upload) ----
  static const String _cloudName = 'sla80nsi';
 static const String _uploadPreset = 'dilanscissors_preset';

  // ---- Marca de agua de fondo (misma foto del barbero que usa el Home) ----
  static const String _logoMarcaAgua =
      'https://res.cloudinary.com/sla80nsi/image/upload/v1783587815/WhatsApp_Image_2026-07-09_at_4.02.26_AM_vgxfon.jpg';

  _ProfilePaleta get _paleta => esGoldenMember ? _paletaPerfilVip : _paletaPerfilNormal;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }
Future<void> _cargarDatos() async {
    await _authService.refrescarPerfilDesdeServidor();
    final n = await _authService.getNombre();
    final e = await _authService.getEmail();
    final f = await _authService.getFotoUrl();
    final golden = await _authService.getEsGoldenMember();
    final cortes = await _authService.getCortesCompletados();
    final reservas = await _authService.getMisReservas();

    if (!mounted) return;
    setState(() {
      nombre = n ?? 'Usuario';
      email = e ?? '';
      fotoUrl = f;
      esGoldenMember = golden;
      cortesCompletados = cortes;
      misReservas = reservas;
      cargando = false;
    });
  }

  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 88,
    );

    if (imagen == null) return;

    setState(() => subiendoFoto = true);

    try {
      final Uint8List bytes = await imagen.readAsBytes();

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: imagen.name),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nuevaUrl = data['secure_url'];

        final ok = await _authService.actualizarFotoPerfil(nuevaUrl);
        if (ok && mounted) {
          setState(() => fotoUrl = nuevaUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada')),
          );
        }
      } else {
        throw Exception('Error al subir a Cloudinary: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => subiendoFoto = false);
    }
  }

Future<void> _cerrarSesion() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

 Future<void> _mostrarDialogoCancelar(dynamic reserva) async {
    final motivoController = TextEditingController();
    bool enviando = false;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
     builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: _paleta.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_busy, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Cancelar reserva',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${reserva['servicio_nombre'] ?? ''} · ${reserva['dia'] ?? ''} ${reserva['hora'] ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cuéntanos el motivo (el barbero lo verá):',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: motivoController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ej: Se me complicó el horario...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: enviando ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Volver', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: enviando
                            ? null
                            : () async {
                                if (motivoController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Escribe un motivo para cancelar')),
                                  );
                                  return;
                                }
                                setDialogState(() => enviando = true);
                                final resultado = await _authService.cancelarReserva(
                                  reservaId: reserva['id'],
                                  motivo: motivoController.text.trim(),
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                                if (resultado['success'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Reserva cancelada')),
                                  );
                                  _cargarDatos();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No se pudo cancelar, intenta de nuevo')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: enviando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Sí, cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'confirmada':
        return Colors.green;
      case 'pendiente':
        return Colors.amber.shade700;
      case 'cancelada':
        return Colors.red;
      case 'completada':
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

 @override
  Widget build(BuildContext context) {
    final p = _paleta;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        title: Text(
          'Mi perfil',
          style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                _logoMarcaAgua,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          cargando
              ? Center(child: CircularProgressIndicator(color: p.gold))
              : RefreshIndicator(
                  color: p.gold,
                  backgroundColor: p.surface,
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    children: [
                      Center(child: _buildAvatar()),
                const SizedBox(height: 16),
                      Center(
                        child: Text(
                          nombre,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Center(
                        child: Text(
                          email,
                          style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (esGoldenMember)
                        Center(child: _buildGoldenBadge())
                      else
                        Center(child: _buildGoldenTeaserPerfil(p)),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Text(
                            'Mis reservas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Container(height: 1, color: p.divider)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (misReservas.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.divider),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Aún no tienes reservas',
                            style: TextStyle(color: p.textSecondary, fontSize: 13),
                          ),
                        )
                      else
                        ...misReservas.map((r) => _buildReservaCard(r, p)),
                      const SizedBox(height: 34),
                      OutlinedButton.icon(
                        onPressed: _cerrarSesion,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                        label: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildGoldenTeaserPerfil(_ProfilePaleta p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.gold.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 15, color: p.gold),
          const SizedBox(width: 6),
          Text(
            'Reserva y sé Golden 🥇',
            style: TextStyle(color: p.goldLight, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

 Widget _buildAvatar() {
    final p = _paleta;
    return Stack(
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: esGoldenMember ? p.goldenBadge : p.gold,
              width: esGoldenMember ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (esGoldenMember ? p.goldenBadge : p.gold).withOpacity(0.45),
                blurRadius: 26,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: fotoUrl != null && fotoUrl!.isNotEmpty
                ? Image.network(fotoUrl!, fit: BoxFit.cover)
                : Container(
                    color: p.surface,
                    child: Icon(Icons.person, size: 58, color: p.gold),
                  ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: GestureDetector(
            onTap: subiendoFoto ? null : _cambiarFoto,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: p.gold,
                shape: BoxShape.circle,
                border: Border.all(color: p.background, width: 2),
              ),
              child: subiendoFoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt, size: 18, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

 Widget _buildGoldenBadge() {
    final p = _paleta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.goldenBadge, p.gold, p.goldenBadge],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: p.gold.withOpacity(0.5), blurRadius: 14, spreadRadius: 1, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 7),
          Text(
            'CLIENTE GOLDEN · $cortesCompletados cortes',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
Widget _buildReservaCard(dynamic r, _ProfilePaleta p) {
    final estado = r['estado'] ?? 'pendiente';
    final estiloNombre = r['estilo_referencia_nombre'];
    final estiloFoto = r['estilo_referencia_foto'];
    final tieneEstilo = estiloNombre != null && estiloNombre.toString().isNotEmpty;
    final tieneFotoEstilo = estiloFoto != null &&
        estiloFoto.toString().isNotEmpty &&
        !estiloFoto.toString().startsWith('PEGA_AQUI');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: _colorEstado(estado),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          if (tieneFotoEstilo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                estiloFoto,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
         Text(
                  r['servicio_nombre'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary, fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${r['dia'] ?? ''}  ${r['hora'] ?? ''}',
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                ),
                if (tieneEstilo) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.content_cut, size: 11, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Estilo: $estiloNombre',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _colorEstado(estado).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: _colorEstado(estado),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (estado == 'pendiente' || estado == 'confirmada') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _mostrarDialogoCancelar(r),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}