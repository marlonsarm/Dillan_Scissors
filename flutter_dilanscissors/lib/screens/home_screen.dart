import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'gallery_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'booking_screen.dart';
import 'profile_screen.dart';

// ============================================================
// PALETA ORIGINAL — se mantiene intacta porque otras pantallas
// (login, registro, booking, perfil, galería) la importan.
// NO SE BORRA NI SE MODIFICA.
// ============================================================
class AppColors {
  static const background = Color(0xFFFAF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const gold = Color(0xFFB08D45);
  static const goldLight = Color(0xFF8C6E2F);
  static const textPrimary = Color(0xFF2B2620);
  static const textSecondary = Color(0xFF8C8377);
  static const divider = Color(0xFFE3DACB);
  static const goldenBadge = Color(0xFFD4AF37);
}

// ============================================================
// NUEVA PALETA — "Street Elegante" (solo se usa dentro de
// home_screen.dart, no afecta otras pantallas)
// ============================================================
class _Paleta {
  final Color background;
  final Color surface;
  final Color gold;
  final Color goldLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color goldenBadge;
  final List<Color> headerGradient;

  const _Paleta({
    required this.background,
    required this.surface,
    required this.gold,
    required this.goldLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.goldenBadge,
    required this.headerGradient,
  });
}

const _paletaNormal = _Paleta(
  background: Color(0xFF15130F),
  surface: Color(0xFF211D17),
  gold: Color(0xFFB08D45),
  goldLight: Color(0xFFD4AF37),
  textPrimary: Color(0xFFF5F0E6),
  textSecondary: Color(0xFFA79C8A),
  divider: Color(0xFF332E24),
  goldenBadge: Color(0xFFD4AF37),
  headerGradient: [Color(0xFF0C0B09), Color(0xFF1C1913)],
);

const _paletaVip = _Paleta(
  background: Color(0xFF060504),
  surface: Color(0xFF1A140A),
  gold: Color(0xFFE8C468),
  goldLight: Color(0xFFF6DE9C),
  textPrimary: Color(0xFFFFFDF6),
  textSecondary: Color(0xFFC9B98A),
  divider: Color(0xFF3D2F12),
  goldenBadge: Color(0xFFFFD700),
  headerGradient: [Color(0xFF000000), Color(0xFF2A2005)],
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  List servicios = [];
  bool cargando = true;
  String? error;
  final AuthService _authService = AuthService();

  bool _logueado = false;
  String? _nombreUsuario;
  String? _fotoUrlUsuario;
  bool _esGoldenMember = false;
  Map<String, dynamic>? _proximaReserva;

 late AnimationController _entradaController;
  late Animation<double> _fadeAnimation;
  late AnimationController _shimmerController;

  // ============================================================
  // 📸 ESPACIOS PARA TUS IMÁGENES (Cloudinary)
  // Reemplaza cada valor con tu link real. Mientras no lo hagas,
  // se muestra un ícono de reemplazo — no rompe nada.
  // ============================================================

  // Foto principal del barbero (header)
  static const String _fotoBarbero = 'https://res.cloudinary.com/sla80nsi/image/upload/v1783654872/lll_qzpvxc.jpg';

 // Foto de ambiente del local (silla, espejo, decoración)
  static const String _fotoAmbiente = 'https://res.cloudinary.com/sla80nsi/image/upload/v1783655092/fgh_l9kil7.jpg';

 // Foto de un corte en proceso (para el collage del header, estilo Mustache's)
  static const String _fotoCorteProceso = 'https://res.cloudinary.com/sla80nsi/image/upload/v1783655092/fgh_l9kil7.jpg';

  // 🏷️ Logo/sello de marca — se usa como marca de agua y en el "stamp" del lightbox
  static const String _logoUrl = 'https://res.cloudinary.com/sla80nsi/image/upload/v1783654278/logo_whjwun.jpg';
  

  // 🎨 Textura de fondo tipo grafiti (muy sutil, opacidad baja, no distrae)
  static const String _texturaFondo = 'https://res.cloudinary.com/sla80nsi/image/upload/v1783618471/WhatsApp_Image_2026-07-09_at_12.33.32_PM_ysgh61.jpg';

  // 📸 Imagen representativa por servicio (usa el mismo "nombre" que devuelve tu backend)
 static const Map<String, List<String>> _imagenesServicios = {
    'Corte Niño': [
      'https://res.cloudinary.com/sla80nsi/image/upload/v1783588970/WhatsApp_Image_2026-07-09_at_4.22.11_AM_k7taza.jpg',
      'PEGA_AQUI_CORTE_NINO_2',
      'PEGA_AQUI_CORTE_NINO_3',
    ],
    'Corte Hombre': [
      'https://res.cloudinary.com/sla80nsi/image/upload/v1783588985/WhatsApp_Image_2026-07-09_at_4.22.13_AM_po4gal.jpg',
      'PEGA_AQUI_CORTE_HOMBRE_2',
      'PEGA_AQUI_CORTE_HOMBRE_3',
    ],
    'Corte Barba y Cejas': [
      'PEGA_AQUI_FOTO_SERVICIO_BARBA_CEJAS',
      'PEGA_AQUI_BARBA_CEJAS_2',
      'PEGA_AQUI_BARBA_CEJAS_3',
    ],
    'Cejas': [
      'PEGA_AQUI_FOTO_SERVICIO_CEJAS',
      'PEGA_AQUI_CEJAS_2',
      'PEGA_AQUI_CEJAS_3',
    ],
    'Barba': [
      'PEGA_AQUI_FOTO_SERVICIO_BARBA',
      'PEGA_AQUI_BARBA_2',
      'PEGA_AQUI_BARBA_3',
    ],
  };
  

  // Redes sociales — reemplaza por tus links reales
  static const String _linkInstagram = 'https://www.instagram.com/_dilanscissors_?igsh=cGI0d3F6aWR6YzRo';
  static const String _linkWhatsapp = 'https://wa.me/573156365714';
  static const String _linkTiktok = 'https://www.tiktok.com/@dilanscissors?_r=1&_t=ZS-97sgtzZj6Kz';
  static const String _linkFacebook = 'https://www.facebook.com/share/1Pgs9VLVgC/?mibextid=wwXIfr';

  // Ubicación (Google Maps)
  static const String _linkMaps = 'https://maps.app.goo.gl/YJw3dGsL5NgYtVLc6?g_st=iw';

  // ---- Frases de marca — deja la que más te guste, borra las otras ----
  static const String _fraseMarca = 'El Arte De La Exelencia';
  // Otras opciones:
  // static const String _fraseMarca = 'Clásico por fuera, calle por dentro.';
  // static const String _fraseMarca = 'Tu corte, tu sello.';
  // static const String _fraseMarca = 'Corte con carácter.';

  // ---- Social proof (edita estos números cuando quieras) ----
  static const int _cortesRealizados = 5000;
  static const int _clientesFelices = 3000;
  static const double _rating = 4.8;

 // Imagen de fondo sutil detrás de la card destacada del portafolio
  // (se muestra con opacidad baja, no compite con la foto principal)
  static const String _fondoPortafolio =
      'https://res.cloudinary.com/sla80nsi/image/upload/v1783627835/b1_roeolp.jpg';

  // Portafolio del barbero — reemplaza con las URLs reales
  static const String _fotoBase =
      'https://res.cloudinary.com/sla80nsi/image/upload/v1783654278/logo_whjwun.jpg';

 // ============================================================s
  // 📸 Cada corte del portafolio puede tener hasta 6 fotos extra
  // que aparecen en el mini-galería al hacer click (foto2 a foto7).
  // Pega tus links de Cloudinary reemplazando cada 'PEGA_AQUI_...'.
  // Si dejas alguna sin reemplazar, se muestra "Próximamente" y no
  // rompe nada.
  // ============================================================
  final List<Map<String, String>> portafolio = [
   {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783654278/logo_whjwun.jpg',
      'tag': 'Fade cláhttpssico',
      'categoria': 'Fades',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627411/d7_udpfkf.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627411/d8_r5rn37.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627412/d6_vi7fif.jpg',
      'foto5': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627416/d2_jlrweg.jpg',
      'foto6': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627412/d5_eawr6l.jpg',
      'foto7': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627417/d1_spgftg.jpg',
      'foto8': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783627414/d3_ov5kgy.jpg',
    },
   {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628420/%C3%B11_wt38md.jpg',
      'tag': 'Fade bajo',
      'categoria': 'Fades',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783590193/WhatsApp_Image_2026-07-09_at_4.40.21_AM_w2axon.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783590224/img.jpg_hkesxa.jpg',
     'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628419/%C3%B12_xuyvd4.jpg',
    },
    {
    'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783618797/img_principal_la8pee.jpg',
      'tag': 'Fade alto',
      'categoria': 'Fades',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783618919/im_2_i80ld5.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783618946/img_3_hgiuxj.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783618971/img_4_v1qehf.jpg',
      'foto5': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783618996/img_5_iplya3.jpg',
      
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628735/o1_qiaise.jpg',
      'tag': 'Diseño tribal',
      'categoria': 'Diseños',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628734/o2_agdufk.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628733/o3_dwj2y0.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628733/o4_pkrkgd.jpg',
    },
  {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783623694/j1_cjxzmd.jpg',
      'tag': 'Dilan Sccisors',
      'categoria': 'Diseños',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783623710/j3_ktfjkl.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783623694/j2_ckhkqf.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783623711/j4_ttnrmi.jpg',
      'foto5': 'PEGA_AQUI_DISENO_LINEAS_5',
    
    },
   {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624911/k1_ro7m4w.jpg',
      'tag': 'Barba perfilada',
      'categoria': 'Barba',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624911/k2_gywpy8.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624910/k3_mncip4.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624910/k4_kgpox7.jpg',
    
    },
   {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624902/m1_kzfw3d.jpg',
      'tag': 'Barba completa',
      'categoria': 'Barba',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624901/m4_prdgwh.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624901/m3_mzbss6.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783624902/m2_sa73cr.jpg',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630335/t8_ehmoox.jpg',
      'tag': 'Clásico ejecutivo',
      'categoria': 'Clásicos',
      'foto2': 'PEGA_AQUI_CLASICO_EJECUTIVO_2',
      'foto3': 'PEGA_AQUI_CLASICO_EJECUTIVO_3',
      'foto4': 'PEGA_AQUI_CLASICO_EJECUTIVO_4',
      'foto5': 'PEGA_AQUI_CLASICO_EJECUTIVO_5',
      'foto6': 'PEGA_AQUI_CLASICO_EJECUTIVO_6',
      'foto7': 'PEGA_AQUI_CLASICO_EJECUTIVO_7',
    },
   {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625296/l1_s2xibu.jpg',
      'tag': 'Clásico peinado',
      'categoria': 'Clásicos',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625295/l3_fnxcmy.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625296/l2_ees631.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625295/l4_nv1luh.jpg',

    },
   {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625626/h1_iqarvu.jpg',
      'tag': 'Estilo urbano',
      'categoria': 'Estilo Urbano',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625625/h2_d7lqrg.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625625/h3_ivqurm.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783625624/h4_cstoan.jpg',

    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628207/f1_hq0eyl.jpg',
      'tag': 'Actitud calle',
      'categoria': 'Estilo Urbano',
      'foto2': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628206/f2_t56m6u.jpg',
      'foto3': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628205/f3_psdshn.jpg',
      'foto4': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783628205/f4_xxpq3k.jpg',
    },
 ];

  // ============================================================
  // 📸 Fotos de la pantalla "Galería completa" — INDEPENDIENTE
  // del Portafolio de arriba. Agrega aquí las que quieras sin
  // afectar la sección Portafolio del home.
  // ============================================================
  final List<Map<String, String>> fotosGaleria = [
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630343/t1_x1nhlu.jpg',
      'tag': 'Corte 1',
      'categoria': 'Fades',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630342/t2_seqc9z.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630341/t3_e8cj6n.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630340/t4_zbbe21.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630339/t5_k2uzbj.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630338/t6_brw0a3.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630336/t7_nu9rsu.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630334/t9_uqfsvp.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630335/t8_ehmoox.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630333/t10_m02irn.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },
    {
      'url': 'https://res.cloudinary.com/sla80nsi/image/upload/v1783630334/t9_uqfsvp.jpg',
      'tag': 'Corte 2',
      'categoria': 'Diseños',
    },

  ];

  String categoriaSeleccionada = 'Todos';
  final List<Map<String, String>> testimonios = [
    {
      'nombre': 'Andrés G.',
      'comentario': 'Excelente atención, el mejor fade que me han hecho. Ya soy cliente fijo.',
      'estrellas': '5',
    },
    {
      'nombre': 'Camilo R.',
      'comentario': 'Muy puntual y profesional. El diseño quedó perfecto, súper recomendado.',
      'estrellas': '5',
    },
   {
      'nombre': 'Julián M.',
      'comentario': 'Ambiente agradable y buena música. Salí muy contento con el corte.',
      'estrellas': '4',
    },
    {
      'nombre': 'Steven P.',
      'comentario': 'Ese fade quedó con actitud, tal cual lo pedí. Aquí sí saben del estilo.',
      'estrellas': '5',
    },
    {
      'nombre': 'Kevin D.',
      'comentario': 'Llegué con una idea loca y el bro la hizo realidad. Nivel top.',
      'estrellas': '5',
    },
    {
      'nombre': 'Brayan S.',
      'comentario': 'Buena energía en el local, buena música y el corte quedó una locura.',
      'estrellas': '5',
    },
    {
      'nombre': 'Nicolás T.',
      'comentario': 'Detalle en cada línea, se nota la dedicación. Ya tengo mi barbero fijo.',
      'estrellas': '5',
    },
    {
      'nombre': 'Santiago R.',
      'comentario': 'Ambiente relax, trato de parce y el resultado habla solo. Recomendado 100%.',
      'estrellas': '4',
    },
  ];

  List<Map<String, String>> get portafolioFiltrado {
    if (categoriaSeleccionada == 'Todos') return portafolio;
    return portafolio.where((f) => f['categoria'] == categoriaSeleccionada).toList();
  }

  _Paleta get _paleta => (_logueado && _esGoldenMember) ? _paletaVip : _paletaNormal;

  @override
  void initState() {
    super.initState();
    obtenerServicios();
    _verificarSesion();

    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  _fadeAnimation = CurvedAnimation(parent: _entradaController, curve: Curves.easeOut);
    _entradaController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _entradaController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _verificarSesion() async {
    final token = await _authService.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() => _logueado = false);
      return;
    }
    final nombre = await _authService.getNombre();
    final foto = await _authService.getFotoUrl();
    final golden = await _authService.getEsGoldenMember();
    final reservas = await _authService.getMisReservas();

    Map<String, dynamic>? proxima;
    final hoy = DateTime.now();
    final candidatas = reservas.where((r) {
      final estado = r['estado'];
      return estado == 'pendiente' || estado == 'confirmada';
    }).toList();

    candidatas.sort((a, b) {
      final diaA = DateTime.tryParse(a['dia'] ?? '') ?? DateTime(2100);
      final diaB = DateTime.tryParse(b['dia'] ?? '') ?? DateTime(2100);
      return diaA.compareTo(diaB);
    });

    for (final r in candidatas) {
      final dia = DateTime.tryParse(r['dia'] ?? '');
      if (dia != null && !dia.isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
        proxima = r;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _logueado = true;
      _nombreUsuario = nombre;
      _fotoUrlUsuario = foto;
      _esGoldenMember = golden;
      _proximaReserva = proxima;
    });
  }

  Future<void> obtenerServicios() async {
    try {
      final response = await http.get(
        Uri.parse('https://dillanscissors-production.up.railway.app/obtener_servicios'),
      );
      if (response.statusCode == 200) {
        setState(() {
          servicios = jsonDecode(response.body);
          cargando = false;
        });
      } else {
        setState(() {
          error = 'Error del servidor: ${response.statusCode}';
          cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error de conexión: $e';
        cargando = false;
      });
    }
  }

  Future<void> _abrirLink(String url) async {
    if (url.isEmpty || url.startsWith('PEGA_AQUI')) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _paleta;
    return Scaffold(
      backgroundColor: p.background,
  body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            if (!_texturaFondo.startsWith('PEGA_AQUI'))
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: Image.network(
                    _texturaFondo,
                    repeat: ImageRepeat.repeat,
                    fit: BoxFit.none,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 430,
                  pinned: true,
                  backgroundColor: p.background,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildBarberHeader(p),
                  ),
                ),
                SliverToBoxAdapter(child: _buildStatsBar(p)),


             SliverToBoxAdapter(child: _buildPortfolio(p)),
                SliverToBoxAdapter(child: _buildQuoteBanner(p)),
                SliverToBoxAdapter(child: _buildFotoBanner(p)),
                SliverToBoxAdapter(child: _buildPorQueElegirnos(p)),
                SliverToBoxAdapter(child: _buildTestimonios(p)),
                if (_logueado && !_esGoldenMember)
                  SliverToBoxAdapter(child: _buildGoldenTeaser(p)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Servicios',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(width: 40, height: 2, color: p.gold),
                      ],
                    ),
                  ),
                ),
                cargando
                    ? SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: p.gold),
                        ),
                      )
                    : error != null
                        ? SliverFillRemaining(
                            child: Center(
                              child: Text(
                                error!,
                                style: TextStyle(color: p.textSecondary),
                              ),
                            ),
                          )
                      : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                             childAspectRatio: 1.5,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final servicio = servicios[index];
                                  return _ServiceCard(
                                    servicio: servicio,
                                    paleta: p,
                                    esDestacado: index == 0,
                                  );
                                },
                                childCount: servicios.length,
                              ),
                            ),
                          ),
           SliverToBoxAdapter(child: _buildFooter(p)),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
            if (_proximaReserva != null) _buildRecordatorioCita(p),
            _buildTopBar(p),
          ],
        ),
      ),
      floatingActionButton: Column(

        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'whatsapp_fab',
            onPressed: () => _abrirLink(_linkWhatsapp),
            backgroundColor: const Color(0xFF25D366),
            mini: true,
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: () => _manejarReservar(context),
            backgroundColor: p.gold,
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            label: const Text(
              'Reservar cita',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _manejarReservar(BuildContext context, {String? estiloNombre, String? estiloFoto}) async {
    final token = await _authService.getToken();
    if (!context.mounted) return;

    if (token != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingScreen(
            estiloNombre: estiloNombre,
            estiloFoto: estiloFoto,
          ),
        ),
      );
    } else {
      _mostrarOpcionesLogin(context);
    }
  }
  void _mostrarOpcionesLogin(BuildContext context) {
    final p = _paleta;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, color: p.gold, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Necesitas una cuenta para reservar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicia sesión o regístrate en segundos para agendar tu cita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Iniciar sesión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: p.gold),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Crear cuenta',
                    style: TextStyle(color: p.gold, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(_Paleta p) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () async {
              if (_logueado) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                _verificarSesion();
              } else {
                _mostrarOpcionesLogin(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.35),
                border: Border.all(
                  color: _esGoldenMember ? p.goldenBadge : Colors.white70,
                  width: _esGoldenMember ? 2.2 : 1.2,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                backgroundImage: (_logueado &&
                        _fotoUrlUsuario != null &&
                        _fotoUrlUsuario!.isNotEmpty)
                    ? NetworkImage(_fotoUrlUsuario!)
                    : null,
                child: (!_logueado ||
                        _fotoUrlUsuario == null ||
                        _fotoUrlUsuario!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordatorioCita(_Paleta p) {
    final r = _proximaReserva!;
    final dia = DateTime.tryParse(r['dia'] ?? '');
    final hora = (r['hora_inicio'] ?? r['hora'] ?? '').toString();
    final horaCorta = hora.length >= 5 ? hora.substring(0, 5) : hora;

    String textoFecha = r['dia'] ?? '';
    if (dia != null) {
      final hoy = DateTime.now();
      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      final diff = dia.difference(hoySinHora).inDays;
      if (diff == 0) {
        textoFecha = 'Hoy';
      } else if (diff == 1) {
        textoFecha = 'Mañana';
      } else {
        const nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
        textoFecha = '${nombresDias[dia.weekday - 1]} ${dia.day}';
      }
    }

   return Padding(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: p.goldLight.withOpacity(0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available, color: p.goldLight, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$textoFecha · $horaCorta',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        r['servicio_nombre'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- NUEVA SECCIÓN: barra de social proof ----
  Widget _buildStatsBar(_Paleta p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(p, '+$_cortesRealizados', 'Cortes'),
          _dividerVertical(p),
          _statItem(p, '$_rating★', 'Rating'),
          _dividerVertical(p),
          _statItem(p, '+$_clientesFelices', 'Clientes felices'),
        ],
      ),
    );
  }

  Widget _dividerVertical(_Paleta p) => Container(width: 1, height: 34, color: p.divider);

  Widget _statItem(_Paleta p, String numero, String label) {
    return Column(
      children: [
        Text(
          numero,
          style: TextStyle(color: p.gold, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: p.textSecondary, fontSize: 11)),
      ],
    );
  }

  // ---- NUEVA SECCIÓN: banner de frase destacada (quote grande) ----
 Widget _buildQuoteBanner(_Paleta p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, p.gold.withOpacity(0.14), Colors.black],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.gold.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: p.gold.withOpacity(0.18), blurRadius: 22, spreadRadius: 1),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"',
                  style: TextStyle(
                    color: p.gold,
                    fontSize: 64,
                    height: 0.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _fraseMarca,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(width: 40, height: 3, color: p.gold),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const _Marca(size: 58),
        ],
      ),
    );
  }
  // ---- NUEVA SECCIÓN: banner con foto de ambiente ----
  Widget _buildFotoBanner(_Paleta p) {
    final tieneFoto = !_fotoAmbiente.startsWith('https://res.cloudinary.com/sla80nsi/image/upload/v1783587445/WhatsApp_Image_2026-07-09_at_3.56.37_AM_vsbxli.jpg');
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        fit: StackFit.expand,
        children: [
       tieneFoto
              ? _ImagenRecortada(
                  url: _fotoAmbiente,
                  recorteInferior: 0.18,
                  placeholderVacio: () => Container(color: p.surface),
                )
              : Container(color: p.surface),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 16,
            right: 18,
            child: Row(
              children: [
               const Expanded(
                  child: Text(
                    'Dilan Hamet Villamizar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- NUEVA SECCIÓN: por qué elegirme ----
  Widget _buildPorQueElegirnos(_Paleta p) {
    final items = [
      {'icono': Icons.content_cut, 'texto': 'Experiencia real y resultados consistentes'},
      {'icono': Icons.spa_outlined, 'texto': 'Productos premium en cada servicio'},
      {'icono': Icons.event_available, 'texto': 'Reservas sin filas, todo desde la app'},
      {'icono': Icons.workspace_premium, 'texto': 'Beneficios exclusivos para clientes Golden'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
            '¿Por qué elegirme?',
            style: TextStyle(color: p.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item['icono'] as IconData, color: p.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['texto'] as String,
                        style: TextStyle(color: p.textPrimary, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ---- NUEVA SECCIÓN: teaser Golden para no-VIP ----
  Widget _buildGoldenTeaser(_Paleta p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF3A2E12)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.goldenBadge.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: p.goldenBadge, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Sé Cliente Golden',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Reserva tu primera cita y desbloquea beneficios exclusivos: prioridad en agenda, interfaz premium y más.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolio(_Paleta p) {
    final categorias = ['Todos', 'Fades', 'Diseños', 'Barba', 'Clásicos', 'Estilo Urbano'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Portafolio',
                style: TextStyle(color: p.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: p.divider)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categorias[index];
                final seleccionado = cat == categoriaSeleccionada;
                return GestureDetector(
                  onTap: () => setState(() => categoriaSeleccionada = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: seleccionado ? p.gold : p.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: seleccionado ? p.gold : p.divider),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: seleccionado ? Colors.black : p.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      const SizedBox(height: 14),
          if (portafolioFiltrado.isNotEmpty)
          SizedBox(
              height: 320,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fondo sutil que ocupa todo el ancho de la sección
                  if (!_fondoPortafolio.startsWith('PEGA_AQUI'))
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Opacity(
                          opacity: 0.16,
                          child: Image.network(
                            _fondoPortafolio,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                Center(
                    child: Container(
                      width: 330,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [p.gold, p.goldLight, p.gold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: p.gold.withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                  child: _PortfolioTile(
                        item: portafolioFiltrado[0],
                        height: 310,
                        paleta: p,
                        onReservar: (nombre, foto) =>
                            _manejarReservar(context, estiloNombre: nombre, estiloFoto: foto),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          if (portafolioFiltrado.length > 1)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: portafolioFiltrado.length - 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final item = portafolioFiltrado[index + 1];
                return _PortfolioTile(
                  item: item,
                  height: 135,
                  paleta: p,
                  onReservar: (nombre, foto) =>
                      _manejarReservar(context, estiloNombre: nombre, estiloFoto: foto),
                );
              },
            ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GalleryScreen(portafolio: fotosGaleria)),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: p.gold),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: Icon(Icons.grid_view_rounded, color: p.gold, size: 18),
              label: Text(
                'Ver galería completa',
                style: TextStyle(color: p.gold, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonios(_Paleta p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lo que dicen nuestros clientes',
            style: TextStyle(color: p.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: testimonios.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final t = testimonios[index];
                final estrellas = int.tryParse(t['estrellas'] ?? '5') ?? 5;
                return Container(
                  width: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < estrellas ? Icons.star : Icons.star_border,
                            color: p.gold,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          t['comentario'] ?? '',
                          style: TextStyle(color: p.textPrimary, fontSize: 12.5, height: 1.35),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '— ${t['nombre']}',
                        style: TextStyle(color: p.goldLight, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildBarberHeader(_Paleta p) {
    final esGolden = _logueado && _esGoldenMember;
    final tieneFotoBarbero = !_fotoBarbero.startsWith('PEGA_AQUI');
    final tieneFotoCorte = !_fotoCorteProceso.startsWith('PEGA_AQUI');
    final tieneFotoAmbiente = !_fotoAmbiente.startsWith('PEGA_AQUI');

 Widget fotoCollage(String url, bool tiene, IconData iconoVacio) {
      return tiene
          ? _ImagenRecortada(
              url: url,
              recorteInferior: 0.18,
              placeholderVacio: () => Container(
                color: Colors.black,
                child: Icon(iconoVacio, color: p.gold.withOpacity(0.4), size: 28),
              ),
            )
          : Container(
              color: Colors.black,
              child: Icon(iconoVacio, color: p.gold.withOpacity(0.4), size: 28),
            );
    }

    Widget corner({required bool top, required bool left}) {
      return Positioned(
        top: top ? 6 : null,
        bottom: top ? null : 6,
        left: left ? 6 : null,
        right: left ? null : 6,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: _EsquinaPainter(color: p.goldenBadge, top: top, left: left),
          ),
        ),
      );
    }

  return Container(
      decoration: BoxDecoration(
        boxShadow: esGolden
            ? [
                BoxShadow(
                  color: p.goldenBadge.withOpacity(0.55),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      foregroundDecoration: esGolden
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: p.goldenBadge.withOpacity(0.8), width: 2),
              ),
            )
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ---- Foto principal del barbero, centrada ----
          fotoCollage(_fotoBarbero, tieneFotoBarbero, Icons.person),
          if (esGolden) corner(top: true, left: true),
          if (esGolden) corner(top: true, left: false),
          if (esGolden) corner(top: false, left: true),
          if (esGolden) corner(top: false, left: false),
          // ---- Overlay: oscuro normal / oscuro+dorado en VIP ----
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: esGolden
                    ? [
                        Colors.black.withOpacity(0.75),
                        p.goldenBadge.withOpacity(0.22),
                        Colors.black.withOpacity(0.88),
                      ]
                    : [
                        Colors.black.withOpacity(0.75),
                        Colors.black.withOpacity(0.30),
                        Colors.black.withOpacity(0.88),
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // ---- Sello VIP (solo Golden Member) ----
          if (esGolden)
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.goldenBadge, width: 2),
                  color: Colors.black.withOpacity(0.55),
                  boxShadow: [
                    BoxShadow(color: p.goldenBadge.withOpacity(0.6), blurRadius: 14, spreadRadius: 1),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: p.goldenBadge, size: 15),
                    Text(
                      'VIP',
                      style: TextStyle(
                        color: p.goldenBadge,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ---- Contenido de texto (tipografía grande, estilo editorial) ----
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
             Row(
                    children: [
                      Text(
                        esGolden ? 'ACCESO PRIORITARIO' : 'BIENVENIDO',
                        style: TextStyle(
                          color: p.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('💈', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                _TituloAnimado(colorOro: p.gold, esVip: esGolden, shimmerController: _shimmerController),
                  const SizedBox(height: 6),
                  Text(
                    _fraseMarca,
                    style: TextStyle(
                      color: p.gold,
                      fontSize: 20,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star, color: p.gold, size: 15),
                      Icon(Icons.star, color: p.gold, size: 15),
                      Icon(Icons.star, color: p.gold, size: 15),
                      Icon(Icons.star, color: p.gold, size: 15),
                      Icon(Icons.star_half, color: p.gold, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        '$_rating ($_clientesFelices reseñas)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildRedesSociales(p),
                  const SizedBox(height: 10),
                  _buildMensajeUsuario(p),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
 Widget _buildRedesSociales(_Paleta p) {
    Widget icono(IconData icono, String link) {
      return GestureDetector(
        onTap: () => _abrirLink(link),
        child: Container(
          width: 46,
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.gold.withOpacity(0.28), Colors.black.withOpacity(0.45)],
            ),
            border: Border.all(color: p.gold.withOpacity(0.75), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: p.gold.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icono, color: p.goldLight, size: 22),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icono(Icons.camera_alt_rounded, _linkInstagram),
        icono(Icons.chat_bubble_rounded, _linkWhatsapp),
        icono(Icons.music_note_rounded, _linkTiktok),
        icono(Icons.facebook_rounded, _linkFacebook),
      ],
    );
  }

  Widget _buildMensajeUsuario(_Paleta p) {
 if (_logueado && _esGoldenMember) {
      return Column(
        children: [
          Container(
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
                BoxShadow(
                  color: p.gold.withOpacity(0.5),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('👑', style: TextStyle(fontSize: 15)),
                SizedBox(width: 7),
                Text(
                  'CLIENTE GOLDEN',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '⚡ Acceso prioritario · Atención preferencial',
            style: TextStyle(color: p.goldenBadge, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    if (_logueado && !_esGoldenMember) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
              'Reserva tu 1ra cita y sé Golden 🥇',
              style: TextStyle(color: p.goldLight, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ---- NUEVA SECCIÓN: footer ----
  Widget _buildFooter(_Paleta p) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(color: p.surface),
      child: Column(
        children: [
          _buildRedesSociales(p),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _abrirLink(_linkMaps),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, color: p.gold, size: 16),
                const SizedBox(width: 6),
                Text('Ver ubicación', style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lun - Sáb · 9:00 AM - 9:00 PM',
            style: TextStyle(color: p.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Dilan Scissors',
            style: TextStyle(color: p.gold, fontSize: 13, fontWeight: FontWeight.w700),
          ),
       Text(
            _fraseMarca,
            style: TextStyle(color: p.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            width: 40,
            color: p.divider,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _abrirLink('https://www.instagram.com/marlonsarm?igsh=M2FzN3I5dWR3YXJ1&utm_source=qr'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.code_rounded, size: 12, color: p.textSecondary.withOpacity(0.6)),
                const SizedBox(width: 5),
                Text.rich(
                  TextSpan(
                    text: 'Desarrollado por ',
                    style: TextStyle(color: p.textSecondary.withOpacity(0.6), fontSize: 10.5),
                    children: [
                      TextSpan(
                        text: 'Marlon Londoño',
                        style: TextStyle(
                          color: p.textSecondary.withOpacity(0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- WIDGET: Foto del portafolio con tag y lightbox ----
class _PortfolioTile extends StatelessWidget {
  final Map<String, String> item;
  final double height;
  final double? width;
  final _Paleta paleta;
  final void Function(String nombre, String foto)? onReservar;

  const _PortfolioTile({
    required this.item,
    required this.height,
    required this.paleta,
    this.width,
    this.onReservar,
  });

 void _abrirLightbox(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => _SelloLightbox(item: item, paleta: paleta, onReservar: onReservar),
    );
  }
 @override
  Widget build(BuildContext context) {
    final tieneFoto = !item['url']!.startsWith('PEGA_AQUI');
    return GestureDetector(
      onTap: tieneFoto ? () => _abrirLightbox(context) : null,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: tieneFoto ? null : Border.all(color: paleta.gold.withOpacity(0.3)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tieneFoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  item['url']!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: paleta.surface,
                      child: Center(
                        child: CircularProgressIndicator(color: paleta.gold, strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: paleta.surface,
                    child: Icon(Icons.image_not_supported_outlined, color: paleta.textSecondary),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [paleta.surface, Colors.black],
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_cut, color: paleta.gold.withOpacity(0.5), size: 20),
                    const SizedBox(height: 4),
                    Text(
                      'Próximamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: paleta.gold.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
     Positioned(
              right: 8,
              bottom: 8,
              child: _Marca(size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- WIDGET: Tarjeta de servicio — grid card con foto, ribbon y sello ----
class _ServiceCard extends StatelessWidget {
  final dynamic servicio;
  final _Paleta paleta;
  final bool esDestacado;

  const _ServiceCard({
    required this.servicio,
    required this.paleta,
    this.esDestacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = servicio['nombre'] ?? '';
    final descripcion = servicio['descripcion']?.toString() ?? '';
    final precio = servicio['precio']?.toString() ?? '';
    final imagenBackend = servicio['imagen_url']?.toString();
    final imagenes = _HomeScreenState._imagenesServicios[nombre] ?? const <String>[];
    final imagenPrincipal = (imagenBackend != null && imagenBackend.isNotEmpty)
        ? imagenBackend
        : (imagenes.isNotEmpty ? imagenes[0] : null);
    final tieneImagen = imagenPrincipal != null && !imagenPrincipal.startsWith('PEGA_AQUI');

    return Container(
      decoration: BoxDecoration(
        color: paleta.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
     child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: tieneImagen
                    ? Image.network(
                        imagenPrincipal!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackIcono(),
                      )
                    : _fallbackIcono(),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: paleta.gold.withOpacity(0.6)),
                  ),
                  child: Text(
                    '\$$precio',
                    style: TextStyle(
                      color: paleta.goldLight,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (esDestacado)
                Positioned(
                  top: 10,
                  left: -30,
                  child: Transform.rotate(
                    angle: -0.78,
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      color: paleta.goldenBadge,
                      alignment: Alignment.center,
                      child: const Text(
                        '🔥 TOP',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
           const Positioned(
                bottom: 6,
                right: 6,
                child: _Marca(size: 22),
              ),
            ],
          ),
        ),
      Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: paleta.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (descripcion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 0.5),
                    child: Text(
                      descripcion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: paleta.textSecondary, fontSize: 7, height: 1.05),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _fallbackIcono() {
  return Container(
      color: paleta.gold.withOpacity(0.12),
      alignment: Alignment.center,
      child: Icon(Icons.content_cut, color: paleta.gold, size: 32),
    );
  }
}

// ---- WIDGET: Carrusel compacto de fotos de un servicio (se abre al hacer clic en la tarjeta) ----
class _ServicioLightbox extends StatefulWidget {
  final String nombre;
  final List<String> imagenes;
  final _Paleta paleta;

  const _ServicioLightbox({
    required this.nombre,
    required this.imagenes,
    required this.paleta,
  });

  @override
  State<_ServicioLightbox> createState() => _ServicioLightboxState();
}

class _ServicioLightboxState extends State<_ServicioLightbox> {
  late final PageController _pageController;
  int _paginaActual = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validas = widget.imagenes.where((u) => !u.startsWith('PEGA_AQUI')).toList();
    final fotos = validas.isEmpty ? ['PEGA_AQUI_SIN_FOTOS'] : validas;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 140),
      child: Container(
        decoration: BoxDecoration(
          color: widget.paleta.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.paleta.gold.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: fotos.length,
                  onPageChanged: (i) => setState(() => _paginaActual = i),
                  itemBuilder: (context, index) {
                    final url = fotos[index];
                    if (url.startsWith('PEGA_AQUI')) {
                      return Container(
                        color: widget.paleta.background,
                        alignment: Alignment.center,
                        child: Icon(Icons.content_cut,
                            color: widget.paleta.gold.withOpacity(0.4), size: 26),
                      );
                    }
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: widget.paleta.background,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: widget.paleta.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.nombre,
              style: TextStyle(
                color: widget.paleta.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                fotos.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _paginaActual ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _paginaActual
                        ? widget.paleta.gold
                        : widget.paleta.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- WIDGET: recorta una franja inferior de la imagen (para esconder cosas pegadas abajo) ----
class _ImagenRecortada extends StatelessWidget {
  final String url;
  final double recorteInferior; // fracción a esconder desde abajo (0.15 = 15%)
  final BoxFit fit;
  final Widget Function()? placeholderVacio;

  const _ImagenRecortada({
    required this.url,
    this.recorteInferior = 0.18,
    this.fit = BoxFit.cover,
    this.placeholderVacio,
  });

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('PEGA_AQUI')) {
      return placeholderVacio?.call() ?? const SizedBox.shrink();
    }
    final escala = 1 / (1 - recorteInferior);
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.scale(
          scale: escala,
          alignment: Alignment.topCenter,
          child: Image.network(
            url,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => placeholderVacio?.call() ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// ---- WIDGET: Marca de agua / sello (logo DS) ----
class _Marca extends StatelessWidget {
  final double size;
  const _Marca({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    if (_HomeScreenState._logoUrl.startsWith('PEGA_AQUI')) {
      return const SizedBox.shrink();
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6),
        ],
      ),
child: ClipOval(
        child: Opacity(
          opacity: 0.9,
          child: _ImagenRecortada(
            url: _HomeScreenState._logoUrl,
            recorteInferior: 0.15,
          ),
        ),
      ),
    );
  }
}

// ---- WIDGET: Título "Dilan Scissors" animado — toque dorado ----
class _TituloAnimado extends StatefulWidget {
  final Color colorOro;
  final bool esVip;
  final AnimationController? shimmerController;
  const _TituloAnimado({required this.colorOro, this.esVip = false, this.shimmerController});

  @override
  State<_TituloAnimado> createState() => _TituloAnimadoState();
}

class _TituloAnimadoState extends State<_TituloAnimado> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _colorAnim = TweenSequence<Color?>([
      TweenSequenceItem(tween: ColorTween(begin: Colors.white, end: widget.colorOro), weight: 50),
      TweenSequenceItem(tween: ColorTween(begin: widget.colorOro, end: Colors.white), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_controller.isAnimating) _controller.forward(from: 0);
      },
    child: !widget.esVip || widget.shimmerController == null
          ? AnimatedBuilder(
              animation: _colorAnim,
              builder: (context, child) {
                return Text(
                  'Dilan\nScissors',
                  style: TextStyle(
                    color: _colorAnim.value,
                    fontSize: 38,
                    height: 0.98,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: widget.colorOro.withOpacity(0.5), blurRadius: 12),
                    ],
                  ),
                );
              },
            )
          : AnimatedBuilder(
              animation: widget.shimmerController!,
              builder: (context, child) {
                final t = widget.shimmerController!.value;
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [widget.colorOro, Colors.white, widget.colorOro],
                      stops: const [0.35, 0.5, 0.65],
                      begin: Alignment(-1 - t * 2, 0),
                      end: Alignment(1 - t * 2, 0),
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Dilan\nScissors',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 0.98,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(color: widget.colorOro.withOpacity(0.5), blurRadius: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
// ---- PAINTER: esquina tipo "corner bracket" dorada ----
class _EsquinaPainter extends CustomPainter {
  final Color color;
  final bool top;
  final bool left;
  _EsquinaPainter({required this.color, required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double x = left ? 0 : size.width;
    final double y = top ? 0 : size.height;
    final double dx = left ? 1 : -1;
    final double dy = top ? 1 : -1;

    path.moveTo(x, y + (size.height * 0.7) * dy);
    path.lineTo(x, y);
    path.lineTo(x + (size.width * 0.7) * dx, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EsquinaPainter oldDelegate) => false;
}

// ---- WIDGET: Lightbox con "sello estampándose" + mini-galería del corte ----
class _SelloLightbox extends StatefulWidget {
  final Map<String, String> item;
  final _Paleta paleta;
  final void Function(String nombre, String foto)? onReservar;

  const _SelloLightbox({required this.item, required this.paleta, this.onReservar});

  @override
  State<_SelloLightbox> createState() => _SelloLightboxState();
}

class _SelloLightboxState extends State<_SelloLightbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _selloScale;
  late final Animation<double> _selloOpacity;
  late final Animation<double> _fotoOpacity;

  // 6 miniaturas adicionales del mismo corte.
  // Mientras no subas más fotos en Cloudinary, se muestran como
  // "Próximamente" (mismo patrón que ya usas en el resto de la app).
  // Para activarlas, agrega en el item del portafolio las claves
  // 'foto2', 'foto3', 'foto4', 'foto5', 'foto6', 'foto7' con tus URLs.
  late final List<String> _miniaturas;

  @override
  void initState() {
    super.initState();
   _miniaturas = [
      widget.item['foto2'],
      widget.item['foto3'],
      widget.item['foto4'],
      widget.item['foto5'],
      widget.item['foto6'],
      widget.item['foto7'],
      widget.item['foto8'],
      widget.item['foto9'],
      widget.item['foto10'],
    ]
        .where((url) => url != null && url.isNotEmpty && !url.startsWith('PEGA_AQUI'))
        .cast<String>()
        .toList();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _selloScale = Tween<double>(begin: 2.2, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_controller);
    _selloOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(_controller);
    _fotoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 55),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _miniaturaVacia() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.paleta.surface, Colors.black],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.content_cut, color: widget.paleta.gold.withOpacity(0.4), size: 16),
    );
  }

  Widget _miniatura(String url) {
    final tiene = !url.startsWith('PEGA_AQUI');
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: tiene
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _miniaturaVacia(),
            )
          : _miniaturaVacia(),
    );
  }

  @override
  Widget build(BuildContext context) {
   final maxAltoDialog = MediaQuery.of(context).size.height * 0.92;
    final maxAnchoDialog = MediaQuery.of(context).size.width * 0.94;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxAltoDialog, maxWidth: maxAnchoDialog),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.paleta.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.paleta.gold.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                

              ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                    aspectRatio: 14 / 9,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: _fotoOpacity.value,
                              child: Image.network(widget.item['url']!, fit: BoxFit.cover),
                            ),
                            if (_selloOpacity.value > 0)
                              Opacity(
                                opacity: _selloOpacity.value,
                                child: Transform.scale(
                                  scale: _selloScale.value,
                                  child: const _Marca(size: 70),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item['tag'] ?? '',
                  style: TextStyle(
                    color: widget.paleta.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                  children: _miniaturas.map(_miniatura).toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onReservar?.call(widget.item['tag']!, widget.item['url']!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.paleta.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Reservar este corte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
