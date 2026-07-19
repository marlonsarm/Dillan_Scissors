import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_screen.dart';
import '../services/auth_service.dart';

// ============================================================
// PALETA — Reservar cita (independiente de AppColors, no rompe
// otras pantallas). Oscura elegante + versión VIP dorada, igual
// espíritu que home_screen.dart.
// ============================================================
class _BookingPaleta {
  final Color background;
  final Color surface;
  final Color gold;
  final Color goldLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color goldenBadge;

  const _BookingPaleta({
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

const _bookingPaletaNormal = _BookingPaleta(
  background: Color(0xFF15130F),
  surface: Color(0xFF211D17),
  gold: Color(0xFFB08D45),
  goldLight: Color(0xFFD4AF37),
  textPrimary: Color(0xFFF5F0E6),
  textSecondary: Color(0xFFA79C8A),
  divider: Color(0xFF332E24),
  goldenBadge: Color(0xFFD4AF37),
);

const _bookingPaletaVip = _BookingPaleta(
  background: Color(0xFF060504),
  surface: Color(0xFF1A140A),
  gold: Color(0xFFE8C468),
  goldLight: Color(0xFFF6DE9C),
  textPrimary: Color(0xFFFFFDF6),
  textSecondary: Color(0xFFC9B98A),
  divider: Color(0xFF3D2F12),
  goldenBadge: Color(0xFFFFD700),
);

class BookingScreen extends StatefulWidget {
  final String? estiloNombre;
  final String? estiloFoto;

  const BookingScreen({super.key, this.estiloNombre, this.estiloFoto});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final AuthService _authService = AuthService();

  int _pasoActual = 0; // 0: servicio, 1: fecha, 2: hora, 3: resumen

  List servicios = [];
  List<Map<String, dynamic>> diasDisponibles = [];
  List<String> horasDisponibles = [];
  bool cargandoServicios = true;
  bool cargandoDias = true;
  bool cargandoHoras = false;
  bool confirmando = false;
  String? errorGeneral;

  Map<String, dynamic>? servicioSeleccionado; // servicio principal
  List<Map<String, dynamic>> serviciosAdicionales = []; // opcionales
  String? diaSeleccionado; // formato 'yyyy-MM-dd'
  String? horarioSeleccionado; // hora tipo "09:30"

  // Estado Golden Member — solo para pintar la pantalla, no cambia lógica
  bool _esGoldenMember = false;

  // Textura de fondo sutil (misma línea visual que el Home)
  static const String _texturaFondo =
      'https://res.cloudinary.com/sla80nsi/image/upload/v1783618471/WhatsApp_Image_2026-07-09_at_12.33.32_PM_ysgh61.jpg';

  _BookingPaleta get _paleta => _esGoldenMember ? _bookingPaletaVip : _bookingPaletaNormal;

  double get precioTotal {
    double total = 0;
    if (servicioSeleccionado != null) {
      total += double.tryParse(servicioSeleccionado!['precio'].toString()) ?? 0;
    }
    for (final s in serviciosAdicionales) {
      total += double.tryParse(s['precio'].toString()) ?? 0;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _cargarServicios();
    _cargarDiasDisponibles();
    _verificarGolden();
  }

  Future<void> _verificarGolden() async {
    final token = await _authService.getToken();
    if (token == null) return;
    final golden = await _authService.getEsGoldenMember();
    if (!mounted) return;
    setState(() => _esGoldenMember = golden);
  }

  Future<void> _cargarServicios() async {
    try {
      final response = await http.get(Uri.parse('https://dillanscissors-production.up.railway.app/obtener_servicios'));
      if (response.statusCode == 200) {
        setState(() {
          servicios = jsonDecode(response.body);
          cargandoServicios = false;
        });
      }
    } catch (e) {
      setState(() {
        errorGeneral = 'Error cargando servicios: $e';
        cargandoServicios = false;
      });
    }
  }

  Future<void> _cargarDiasDisponibles() async {
    try {
      final response = await http.get(Uri.parse('https://dillanscissors-production.up.railway.app/dias_disponibles'));
      if (response.statusCode == 200) {
        setState(() {
          diasDisponibles = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          cargandoDias = false;
        });
      }
    } catch (e) {
      setState(() {
        errorGeneral = 'Error cargando días disponibles: $e';
        cargandoDias = false;
      });
    }
  }

  Future<void> _cargarHorasDisponibles(String dia) async {
    setState(() {
      cargandoHoras = true;
      horasDisponibles = [];
    });
    try {
      final adicionalesIds = serviciosAdicionales.map((s) => s['id']).join(',');
      final uri = Uri.parse(
        'https://dillanscissors-production.up.railway.app/disponibilidad?dia=$dia&servicio_id=${servicioSeleccionado!['id']}&adicionales=$adicionalesIds',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          horasDisponibles = List<String>.from(jsonDecode(response.body));
          cargandoHoras = false;
        });
      } else {
        setState(() {
          errorGeneral = 'No se pudo cargar la disponibilidad';
          cargandoHoras = false;
        });
      }
    } catch (e) {
      setState(() {
        errorGeneral = 'Error cargando horas: $e';
        cargandoHoras = false;
      });
    }
  }

  void _siguientePaso() {
    setState(() => _pasoActual++);
  }

  void _pasoAnterior() {
    if (_pasoActual == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _pasoActual--);
    }
  }

  Future<void> _confirmarReserva() async {
    setState(() {
      confirmando = true;
      errorGeneral = null;
    });

    final usuarioId = await _authService.getUsuarioId();

    try {
      final response = await http.post(
        Uri.parse('https://dillanscissors-production.up.railway.app/crear_reserva'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "usuario_id": int.parse(usuarioId ?? "0"),
          "servicio_id": servicioSeleccionado!['id'],
          "dia": diaSeleccionado,
          "hora_inicio": horarioSeleccionado,
          "servicios_adicionales": serviciosAdicionales.map((s) => s['id']).toList(),
          "estilo_referencia_nombre": widget.estiloNombre,
          "estilo_referencia_foto": widget.estiloFoto,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Actualizamos el estatus Golden guardado localmente
        await _authService.actualizarEstatusGolden(
          esGolden: data['es_golden_member'] ?? false,
          cortesCompletados: data['cortes_completados'] ?? 0,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSuccessScreen(
              servicioNombre: servicioSeleccionado!['nombre'],
              precio: servicioSeleccionado!['precio'].toString(),
              dia: diaSeleccionado!,
              hora: horarioSeleccionado!,
              esNuevoGolden: data['es_golden_member'] ?? false,
            ),
          ),
        );
      } else {
        setState(() {
          errorGeneral = data['error'] ?? 'No se pudo crear la reserva';
          confirmando = false;
        });
      }
    } catch (e) {
      setState(() {
        errorGeneral = 'Error de conexión: $e';
        confirmando = false;
      });
    }
  }

  // ---- Formatea "HH:mm" (24h) a "h:mm AM/PM" — solo visual ----
  String _formatHora12(String hora24) {
    final partes = hora24.split(':');
    int h = int.tryParse(partes[0]) ?? 0;
    final m = partes.length > 1 ? partes[1] : '00';
    final periodo = h >= 12 ? 'PM' : 'AM';
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:$m $periodo';
  }

  @override
  Widget build(BuildContext context) {
    final p = _paleta;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textPrimary),
          onPressed: _pasoAnterior,
        ),
        title: Row(
          children: [
            Text(
              'Reservar cita',
              style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            const Text('💈', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: Stack(
        children: [
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
          Column(
            children: [
              _buildStepper(p),
              const SizedBox(height: 4),
              Expanded(child: _buildPasoActual()),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- STEPPER VISUAL ----------
  Widget _buildStepper(_BookingPaleta p) {
    final titulos = ['Servicio', 'Fecha', 'Hora', 'Confirmar'];
    final iconos = [Icons.content_cut, Icons.calendar_month, Icons.access_time, Icons.check_circle];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(titulos.length, (index) {
          final activo = index <= _pasoActual;
          final completado = index < _pasoActual;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index != 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: activo
                                ? LinearGradient(colors: [p.gold, p.goldLight])
                                : null,
                            color: activo ? null : p.divider,
                          ),
                        ),
                      ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: activo
                            ? LinearGradient(colors: [p.goldLight, p.gold])
                            : null,
                        color: activo ? null : p.surface,
                        border: Border.all(
                          color: activo ? p.gold : p.divider,
                          width: 1.5,
                        ),
                        boxShadow: activo
                            ? [BoxShadow(color: p.gold.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]
                            : null,
                      ),
                      child: Center(
                        child: completado
                            ? const Icon(Icons.check, size: 15, color: Colors.black)
                            : Icon(
                                iconos[index],
                                size: 14,
                                color: activo ? Colors.black : p.textSecondary,
                              ),
                      ),
                    ),
                    if (index != titulos.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: completado ? p.gold : p.divider,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  titulos[index],
                  style: TextStyle(
                    fontSize: 11,
                    color: activo ? p.textPrimary : p.textSecondary,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPasoActual() {
    switch (_pasoActual) {
      case 0:
        return _buildPasoServicio();
      case 1:
        return _buildPasoFecha();
      case 2:
        return _buildPasoHora();
      default:
        return _buildPasoResumen();
    }
  }

  // ---------- PASO 1: SERVICIO ----------
  Widget _buildPasoServicio() {
    final p = _paleta;
    if (cargandoServicios) {
      return Center(child: CircularProgressIndicator(color: p.gold));
    }
    return Column(
      children: [
        if (widget.estiloNombre != null && widget.estiloNombre!.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.gold.withOpacity(0.18), p.surface],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.gold.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                if (widget.estiloFoto != null &&
                    widget.estiloFoto!.isNotEmpty &&
                    !widget.estiloFoto!.startsWith('PEGA_AQUI'))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.estiloFoto!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
                    ),
                  )
                else
                  Icon(Icons.content_cut, color: p.gold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Corte de referencia', style: TextStyle(color: p.textSecondary, fontSize: 11)),
                          const SizedBox(width: 4),
                          const Text('✂️', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      Text(
                        widget.estiloNombre!,
                        style: TextStyle(color: p.goldLight, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Text(
                'Elige tu servicio',
                style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              const Text('💈', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
    Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: servicios.length,
            itemBuilder: (context, index) {
              final servicio = servicios[index];
              final tieneImagen = servicio['imagen_url'] != null &&
                  servicio['imagen_url'].toString().isNotEmpty;
              final esAdicional = serviciosAdicionales.any((s) => s['id'] == servicio['id']);
              final seleccionado = (servicioSeleccionado != null && servicioSeleccionado!['id'] == servicio['id']) || esAdicional;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (servicioSeleccionado == null) {
                      servicioSeleccionado = servicio;
                    } else if (servicioSeleccionado!['id'] == servicio['id']) {
                      servicioSeleccionado = null;
                    } else if (esAdicional) {
                      serviciosAdicionales.removeWhere((s) => s['id'] == servicio['id']);
                    } else {
                      serviciosAdicionales.add(servicio);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: seleccionado ? p.gold : p.divider,
                      width: seleccionado ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: seleccionado ? p.gold.withOpacity(0.25) : Colors.black.withOpacity(0.25),
                        blurRadius: seleccionado ? 14 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            tieneImagen
                                ? Image.network(
                                    servicio['imagen_url'],
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: p.gold.withOpacity(0.08),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: p.gold,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => _placeholderServicio(p),
                                  )
                                : _placeholderServicio(p),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                                    stops: const [0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: p.gold.withOpacity(0.6)),
                                ),
                                child: Text(
                                  '\$${servicio['precio']}',
                                  style: TextStyle(
                                    color: p.goldLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (seleccionado)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [p.goldLight, p.gold]),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: p.gold.withOpacity(0.6), blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.check, color: Colors.black, size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                servicio['nombre'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (servicio['descripcion'] != null &&
                                  servicio['descripcion'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    servicio['descripcion'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.textSecondary,
                                      fontSize: 10.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              if (servicio['duracion_minutos'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 11, color: p.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${servicio['duracion_minutos']} min',
                                      style: TextStyle(
                                        color: p.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (servicioSeleccionado != null)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: p.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${1 + serviciosAdicionales.length} servicio${serviciosAdicionales.length > 0 ? 's' : ''} elegido${serviciosAdicionales.length > 0 ? 's' : ''}',
                        style: TextStyle(color: p.textSecondary, fontSize: 12),
                      ),
                      Text(
                        '\$${precioTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: p.goldLight,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _siguientePaso,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _placeholderServicio(_BookingPaleta p) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.surface, Colors.black],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_cut, color: p.gold.withOpacity(0.5), size: 30),
          const SizedBox(height: 6),
          Text(
            'Foto próximamente',
            style: TextStyle(color: p.gold.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
// ---------- PASO 2: FECHA (tarjeta de hoy + tira compacta) ----------
  Widget _buildPasoFecha() {
    final p = _paleta;
    if (cargandoDias) {
      return Center(child: CircularProgressIndicator(color: p.gold));
    }
    if (diasDisponibles.isEmpty) {
      return Center(
        child: Text('No hay fechas disponibles por ahora', style: TextStyle(color: p.textSecondary)),
      );
    }

    const nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const nombresDiasLargo = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const nombresMes = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];

    final hoyStr = DateTime.now().toIso8601String().substring(0, 10);
    final indiceHoy = diasDisponibles.indexWhere((d) => d['dia'] == hoyStr);
    final tieneHoy = indiceHoy != -1;
    final restoDias = List<Map<String, dynamic>>.from(diasDisponibles);
    if (tieneHoy) restoDias.removeAt(indiceHoy);

    void seleccionarDia(String dia) {
      setState(() {
        diaSeleccionado = dia;
        horarioSeleccionado = null;
      });
      _cargarHorasDisponibles(dia);
      _siguientePaso();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Elige tu día',
                style: TextStyle(color: p.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              const Text('🗓️', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona el día que más te acomode',
            style: TextStyle(color: p.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          if (tieneHoy) ...[
            GestureDetector(
              onTap: () => seleccionarDia(hoyStr),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.gold.withOpacity(0.22), p.surface],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.gold.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.goldLight, p.gold]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            nombresMes[DateTime.now().month - 1].toUpperCase(),
                            style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${DateTime.now().day}',
                            style: const TextStyle(fontSize: 17, color: Colors.black, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HOY',
                            style: TextStyle(color: p.goldLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                          Text(
                            '${nombresDiasLargo[DateTime.now().weekday - 1]} ${DateTime.now().day} de ${nombresMes[DateTime.now().month - 1]}',
                            style: TextStyle(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.goldLight, p.gold]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Ver horas',
                        style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'O elige otro día',
              style: TextStyle(color: p.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: restoDias.map((diaData) {
                  final dia = diaData['dia'] as String;
                  final fecha = DateTime.parse(dia);
                  final seleccionado = diaSeleccionado == dia;

                  return GestureDetector(
                    onTap: () => seleccionarDia(dia),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 74,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: seleccionado
                            ? LinearGradient(colors: [p.goldLight, p.gold])
                            : null,
                        color: seleccionado ? null : p.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: seleccionado ? p.gold : p.divider,
                          width: seleccionado ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nombresDias[fecha.weekday - 1].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: seleccionado ? Colors.black.withOpacity(0.7) : p.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fecha.day}',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: seleccionado ? Colors.black : p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nombresMes[fecha.month - 1],
                            style: TextStyle(
                              fontSize: 9.5,
                              color: seleccionado ? Colors.black.withOpacity(0.7) : p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- PASO 3: HORA (formato 12h, agrupado Mañana/Tarde) ----------
  Widget _buildPasoHora() {
    final p = _paleta;
    if (cargandoHoras) {
      return Center(child: CircularProgressIndicator(color: p.gold));
    }
Widget chip(String h) {
      final seleccionado = horarioSeleccionado == h;
      return GestureDetector(
        onTap: () {
          setState(() => horarioSeleccionado = h);
          _siguientePaso();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: seleccionado ? p.gold.withOpacity(0.10) : p.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado ? p.gold : p.divider,
              width: seleccionado ? 1.4 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                _formatHora12(h),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: seleccionado ? p.goldLight : p.textPrimary,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
              if (seleccionado)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Icon(Icons.check_circle, size: 12, color: p.gold),
                ),
            ],
          ),
        ),
      );
    }

    Widget gridHoras(List<String> horas) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
        ),
        itemCount: horas.length,
        itemBuilder: (context, index) => chip(horas[index]),
      );
    }
    final manana = horasDisponibles.where((h) => (int.tryParse(h.split(':')[0]) ?? 0) < 12).toList();
    final tarde = horasDisponibles.where((h) => (int.tryParse(h.split(':')[0]) ?? 0) >= 12).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Elige la hora',
                style: TextStyle(color: p.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              const Text('⏰', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: horasDisponibles.isEmpty
                ? Center(
                    child: Text(
                      'No hay horas disponibles este día',
                      style: TextStyle(color: p.textSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (manana.isNotEmpty) ...[
                          Row(
                            children: [
                              const Text('☀️', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Mañana',
                                style: TextStyle(color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  const SizedBox(height: 10),
                          gridHoras(manana),
                          const SizedBox(height: 22),
                        ],
                        if (tarde.isNotEmpty) ...[
                          Row(
                            children: [
                              const Text('🌙', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Tarde / Noche',
                                style: TextStyle(color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          gridHoras(tarde),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------- PASO 4: RESUMEN Y CONFIRMAR ----------
  Widget _buildPasoResumen() {
    final p = _paleta;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Resumen de tu cita',
                style: TextStyle(color: p.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              const Text('✅', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          if (_esGoldenMember)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.goldenBadge, p.gold]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: p.gold.withOpacity(0.4), blurRadius: 10)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👑', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'Reserva con beneficios Golden',
                    style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _filaResumen(p, Icons.content_cut, 'Servicio principal', servicioSeleccionado?['nombre'] ?? ''),
                if (serviciosAdicionales.isNotEmpty) ...[
                  Divider(height: 24, color: p.divider),
                  _filaResumen(p, Icons.add_circle_outline, 'Adicionales',
                      serviciosAdicionales.map((s) => s['nombre']).join(', ')),
                ],
                Divider(height: 24, color: p.divider),
                _filaResumen(p, Icons.calendar_month, 'Fecha', diaSeleccionado ?? ''),
                Divider(height: 24, color: p.divider),
                _filaResumen(
                  p,
                  Icons.access_time,
                  'Hora',
                  horarioSeleccionado != null ? _formatHora12(horarioSeleccionado!) : '',
                ),
                Divider(height: 24, color: p.divider),
                _filaResumen(p, Icons.attach_money, 'Total', '\$${precioTotal.toStringAsFixed(0)}'),
              ],
            ),
          ),
          if (errorGeneral != null) ...[
            const SizedBox(height: 16),
            Text(errorGeneral!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.goldLight, p.gold]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: p.gold.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: ElevatedButton(
                onPressed: confirmando ? null : _confirmarReserva,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: confirmando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        'CONFIRMAR RESERVA  ✂️',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaResumen(_BookingPaleta p, IconData icon, String label, String valor) {
    return Row(
      children: [
        Icon(icon, color: p.gold, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: p.textSecondary, fontSize: 14)),
        const Spacer(),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// PANTALLA DE ÉXITO — SIN CAMBIOS (no fue parte del pedido)
// ---------------------------------------------------------
class BookingSuccessScreen extends StatefulWidget {
  final String servicioNombre;
  final String precio;
  final String dia;
  final String hora;
  final bool esNuevoGolden;

  const BookingSuccessScreen({
    super.key,
    required this.servicioNombre,
    required this.precio,
    required this.dia,
    required this.hora,
    required this.esNuevoGolden,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.esNuevoGolden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarPopupGolden();
      });
    }
  }

  void _mostrarPopupGolden() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.goldenBadge, AppColors.gold],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 18),
                const Text(
                  '¡Bienvenido al club VIP!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ahora eres Cliente Golden 🏆\nDisfruta beneficios exclusivos en tus próximas visitas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('¡Genial!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 46),
              ),
              const SizedBox(height: 24),
              const Text(
                '¡Cita confirmada!',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Te esperamos en Dilan Scissors',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),

              if (widget.esNuevoGolden) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.goldenBadge, AppColors.gold]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '¡Ahora eres Golden Member!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _fila('Servicio', widget.servicioNombre),
                    const Divider(height: 20, color: AppColors.divider),
                    _fila('Fecha', widget.dia),
                    const Divider(height: 20, color: AppColors.divider),
                    _fila('Hora', widget.hora.length >= 5 ? widget.hora.substring(0, 5) : widget.hora),
                    const Divider(height: 20, color: AppColors.divider),
                    _fila('Precio', '\$${widget.precio}'),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Volver al inicio',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(valor, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
