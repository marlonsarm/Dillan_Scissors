import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'home_screen.dart'; // para usar AppColors
import 'booking_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

// ============================================================
// Paleta oscura "Street Elegante" — réplica local para que la
// galería combine con el resto de la app (home_screen usa una
// paleta privada que no se puede importar desde aquí).
// ============================================================
class _GalColors {
  static const background = Color(0xFF15130F);
  static const surface = Color(0xFF211D17);
  static const gold = Color(0xFFB08D45);
  static const goldLight = Color(0xFFD4AF37);
  static const textPrimary = Color(0xFFF5F0E6);
  static const textSecondary = Color(0xFFA79C8A);
  static const divider = Color(0xFF332E24);
}

class GalleryScreen extends StatefulWidget {
  final List<Map<String, String>> portafolio;
  const GalleryScreen({super.key, required this.portafolio});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String categoriaSeleccionada = 'Todos';
  String busqueda = '';
final Set<String> favoritos = {};
  final AuthService _authService = AuthService();

  Future<void> _manejarReservar(BuildContext context, {String? estiloNombre, String? estiloFoto}) async {
    final token = await _authService.getToken();
    if (!context.mounted) return;
    if (token != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(estiloNombre: estiloNombre, estiloFoto: estiloFoto),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para reservar')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // Alturas cíclicas para el efecto masonry (mientras no tengas dimensiones reales de cada foto)
  final List<double> _alturas = [230, 300, 260, 190, 280, 240];

  List<Map<String, String>> get _filtrado {
    var lista = widget.portafolio;
    if (categoriaSeleccionada != 'Todos') {
      lista = lista.where((f) => f['categoria'] == categoriaSeleccionada).toList();
    }
    if (busqueda.trim().isNotEmpty) {
      final q = busqueda.trim().toLowerCase();
      lista = lista.where((f) => (f['tag'] ?? '').toLowerCase().contains(q)).toList();
    }
    return lista;
  }
void _abrirLightbox(int index, List<Map<String, String>> lista) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
     final item = lista[index];
          final esFavorito = favoritos.contains(item['url']);
          final maxAltoDialog = MediaQuery.of(context).size.height * 0.85;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxAltoDialog),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(item['url']!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                            onTap: () {
                                  setState(() {
                                    esFavorito ? favoritos.remove(item['url']) : favoritos.add(item['url']!);
                                  });
                                  setDialogState(() {});
                                },
                                child: CircleAvatar(
                                  backgroundColor: Colors.black45,
                                  child: Icon(
                                    esFavorito ? Icons.favorite : Icons.favorite_border,
                                    color: esFavorito ? _GalColors.gold : Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirPantallaCompleta(index, lista);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _GalColors.gold),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: Icon(Icons.fullscreen, color: _GalColors.gold, size: 18),
                      label: Text('Ver completa', style: TextStyle(color: _GalColors.gold, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrirPantallaCompleta(int index, List<Map<String, String>> lista) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: PhotoViewGallery.builder(
            itemCount: lista.length,
            pageController: PageController(initialPage: index),
            builder: (context, i) => PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(lista[i]['url']!),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
   final categorias = ['Todos', 'Fades', 'Diseños', 'Barba', 'Clásicos', 'Estilo Urbano'];
    final lista = _filtrado;

  return Scaffold(
      backgroundColor: _GalColors.background,
      appBar: AppBar(
        backgroundColor: _GalColors.background,
        elevation: 0,
        foregroundColor: _GalColors.textPrimary,
        title: const Text('Galería completa', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ---- Buscador ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(
              onChanged: (v) => setState(() => busqueda = v),
              style: const TextStyle(color: _GalColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar corte (ej. fade, barba...)',
                hintStyle: const TextStyle(color: _GalColors.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: _GalColors.gold, size: 20),
                filled: true,
                fillColor: _GalColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _GalColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _GalColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _GalColors.gold),
                ),
              ),
            ),
          ),
          // ---- Chips de categoría ----
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categorias[index];
                final seleccionado = cat == categoriaSeleccionada;
                return GestureDetector(
                  onTap: () => setState(() => categoriaSeleccionada = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                      color: seleccionado ? _GalColors.gold : _GalColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: seleccionado ? _GalColors.gold : _GalColors.divider),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: seleccionado ? Colors.black : _GalColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ---- Grid tipo masonry ----
          Expanded(
            child: lista.isEmpty
             ? const Center(
                    child: Text('No hay cortes que coincidan', style: TextStyle(color: _GalColors.textSecondary)),
                  )
                : MasonryGridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                 final item = lista[index];
                      final esNuevo = item['esNuevo'] == 'true';
                      final esFavorito = favoritos.contains(item['url']);
                      final altura = _alturas[index % _alturas.length];

                   final tieneFoto = !(item['url'] ?? '').startsWith('PEGA_AQUI');
                      return GestureDetector(
                        onTap: tieneFoto ? () => _abrirLightbox(index, lista) : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: altura,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (tieneFoto)
                                  Image.network(
                                    item['url']!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: _GalColors.divider,
                                      child: const Icon(Icons.content_cut, color: _GalColors.gold),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [_GalColors.surface, Colors.black],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.content_cut, color: _GalColors.gold.withOpacity(0.5), size: 26),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Próximamente',
                                          style: TextStyle(color: _GalColors.gold.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                        stops: const [0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              if (esNuevo)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                     decoration: BoxDecoration(
                                        color: _GalColors.gold,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'NUEVO',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                               child: GestureDetector(
                                    onTap: () => setState(() {
                                      esFavorito ? favoritos.remove(item['url']) : favoritos.add(item['url']!);
                                    }),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.black45,
                                  child: Icon(
                                        esFavorito ? Icons.favorite : Icons.favorite_border,
                                        color: esFavorito ? _GalColors.gold : Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}