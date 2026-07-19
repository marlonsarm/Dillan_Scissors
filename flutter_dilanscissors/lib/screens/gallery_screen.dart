import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

// ============================================================
// Paleta oscura "Street Elegante" — réplica local para que la
// galería combine con el resto de la app.
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
  final Set<String> favoritos = {};

  // Alturas cíclicas para el efecto masonry
  final List<double> _alturas = [220, 290, 250, 320, 200, 270];

  List<Map<String, String>> get _fotosValidas {
    return widget.portafolio
        .where((f) => !(f['url'] ?? '').startsWith('PEGA_AQUI'))
        .toList();
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
    final lista = _fotosValidas;

    return Scaffold(
      backgroundColor: _GalColors.background,
      appBar: AppBar(
        backgroundColor: _GalColors.background,
        elevation: 0,
        foregroundColor: _GalColors.textPrimary,
        title: const Text(
          'Detrás de cámaras',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              'Un vistazo a la barbería, más allá de los cortes.',
              style: TextStyle(color: _GalColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? Center(
                    child: Text(
                      'Todavía no hay fotos por aquí',
                      style: TextStyle(color: _GalColors.textSecondary),
                    ),
                  )
                : MasonryGridView.count(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final item = lista[index];
                      final esFavorito = favoritos.contains(item['url']);
                      final altura = _alturas[index % _alturas.length];

                      return GestureDetector(
                        onTap: () => _abrirPantallaCompleta(index, lista),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: altura,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  item['url']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: _GalColors.divider,
                                    child: const Icon(Icons.image_outlined, color: _GalColors.gold),
                                  ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                                        stops: const [0.65, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      esFavorito
                                          ? favoritos.remove(item['url'])
                                          : favoritos.add(item['url']!);
                                    }),
                                    child: CircleAvatar(
                                      radius: 15,
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